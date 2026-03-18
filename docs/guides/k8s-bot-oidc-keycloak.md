# Kubernetes Bot OIDC with Keycloak over Tailscale

This guide describes the recommended steady-state setup for the always-on experiment bot running on `hermes-vm`.

## Goal

Give the off-cluster bot self-refreshing Kubernetes credentials without exposing the OIDC issuer publicly.

## Network model

Keep the OIDC issuer internal to the tailnet.

Known tailnet hosts in this homelab:

- control plane: `debian.munchkin-komodo.ts.net`
- bot VM: `hermes-vm.munchkin-komodo.ts.net`

Recommended pattern:

- run Keycloak where the bot can reach it over Tailscale
- publish the issuer on a tailnet-only DNS name
- configure k3s to trust that internal issuer URL
- pin the IdP workload to `debian`, not `pop-os`

Do **not** publish the issuer on a public internet hostname just for the bot.

## Recommended issuer shape

Example issuer URL:

```text
https://debian.munchkin-komodo.ts.net/realms/homelab
```

If you reverse-proxy Keycloak behind a dedicated internal path or host, keep the final issuer URL stable and use that exact value everywhere.

## Why Keycloak here

For this always-on off-cluster bot, Keycloak is the most practical OIDC provider because it supports machine-oriented client credentials cleanly.

That gives you:

- a dedicated non-human client identity
- short-lived tokens
- self-refreshing credentials via kubelogin exec auth
- no browser login loop on the VM

## Step 1: Stand up Keycloak on an internal-only endpoint

Run Keycloak somewhere inside your trusted network, then make it reachable from both:

- `debian.munchkin-komodo.ts.net` (k3s control plane)
- `hermes-vm.munchkin-komodo.ts.net` (the bot VM)

Important requirements:

- the certificate must match the issuer hostname
- the issuer must be reachable over Tailscale
- the issuer URL must not change after Kubernetes is configured to trust it

Repo scaffold:

- `infrastructure/keycloak/namespace.yaml`
- `infrastructure/keycloak/deployment.yaml`
- `infrastructure/keycloak/service.yaml`
- `infrastructure/keycloak/secret.yaml`
- `infrastructure/keycloak/ingress.yaml`
- `infrastructure/keycloak/kustomization.yaml`

Apply it with:

```bash
kubectl apply -k infrastructure/keycloak
```

## Step 2: Configure a realm and a machine client

In Keycloak:

1. Create realm: `homelab`
2. Create a confidential client for Kubernetes bot auth
3. Enable client credentials / service account style access
4. Record the client ID and client secret
5. Ensure the token contains the claim you want Kubernetes to use for username
6. If you want group-based RBAC later, add a mapper for groups

Suggested values:

- realm: `homelab`
- Kubernetes API OIDC client ID: `kubernetes`
- bot client ID: `homelab-automation-bot`

## Step 3: Configure k3s API server

On the control plane, merge the OIDC settings into `/etc/rancher/k3s/config.yaml`.

Use `templates/k3s-oidc-config.example.yaml` as the base, replacing placeholders with your internal issuer URL.

For this homelab, the critical value should look like:

```yaml
kube-apiserver-arg:
  - oidc-issuer-url=https://debian.munchkin-komodo.ts.net/realms/homelab
```

Also set:

- `oidc-client-id`
- `oidc-username-claim`
- `oidc-groups-claim`
- `oidc-username-prefix`
- `oidc-groups-prefix`
- `oidc-ca-file` if your issuer uses a private CA

Then restart k3s:

```bash
sudo systemctl restart k3s
```

## Step 4: Bind the machine identity in Kubernetes RBAC

Bind the OIDC machine identity to the same effective permissions the bot already has.

Keep the existing service-account RBAC for now as a fallback/bootstrap path, but the long-term steady-state binding should target the OIDC identity.

Typical approaches:

- bind a specific OIDC username to a RoleBinding / ClusterRoleBinding
- or bind an OIDC group if you want the option to swap machine identities later

## Step 5: Configure the bot kubeconfig on `hermes-vm`

Use:

- `templates/kubeconfig.oidc-exec.template.yaml`

Set the issuer to the internal Keycloak URL, for example:

```text
https://debian.munchkin-komodo.ts.net/realms/homelab
```

The bot kubeconfig should use an exec block so kubelogin can fetch and refresh tokens automatically.

## Step 6: Install kubelogin on the bot VM

On `hermes-vm`, install the kubectl OIDC login plugin.

The kubeconfig should then be able to refresh tokens without browser interaction, using client credentials.

## Validation checklist

From the bot VM:

1. Confirm the issuer is reachable over Tailscale.
2. Confirm TLS validates cleanly.
3. Confirm kubelogin can fetch a token non-interactively.
4. Confirm `kubectl auth can-i` matches the intended RBAC.
5. Confirm token refresh works without operator intervention.

## Recommended rollout

1. Keep the current service-account kubeconfig working.
2. Deploy Keycloak on an internal-only endpoint.
3. Configure k3s OIDC trust.
4. Create the machine client.
5. Build and test the OIDC exec kubeconfig on `hermes-vm`.
6. Switch the bot over after validation.
7. Keep the old service-account path only as an emergency fallback until you are confident in OIDC.
