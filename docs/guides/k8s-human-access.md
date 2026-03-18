# Kubernetes Human Access

This guide covers how to grant human users access to the homelab k3s cluster without sharing the admin kubeconfig.

## Recommended model

Use **individual human identities** plus **group-based RBAC**.

- **Now**: per-user client certificates
- **Later**: OIDC with the same Kubernetes groups
- **Never by default**: shared admin kubeconfigs for normal users

The existing `scripts/setup-kubectl.sh` flow is still an owner/admin bootstrap path. It should not be used as the standard onboarding flow for new users.

## Shared role catalog

Apply the shared roles first:

```bash
kubectl apply -f infrastructure/access/rbac/role-catalog.yaml
```

This creates:

- `homelab:readonly`
- `homelab:namespace-operator`
- `homelab:platform-admin`

Example bindings in this repo:

- `infrastructure/access/rbac/examples/readonly-global-binding.example.yaml`
- `infrastructure/access/rbac/examples/namespace-operator-minecraft.yaml`

## Near-term path: client certificates

For this homelab, the cleanest short-term model is:

1. Generate a client key and CSR for each user.
2. Put the username in the certificate CN.
3. Put Kubernetes groups in the certificate organization fields.
4. Sign the certificate.
5. Build a user kubeconfig from `templates/kubeconfig.template.yaml`.

With client certificates:

- **CN** maps to the Kubernetes username
- **O** fields map to Kubernetes groups

This path does **not** require API server changes because k3s already supports client-certificate authentication.

## Suggested onboarding workflow

1. Ensure the user has Tailscale access.
2. Apply the shared roles.
3. Apply the group bindings for that user's job.
4. Issue a short-lived certificate.
5. Build the kubeconfig.
6. Validate with `kubectl auth can-i`.

Example:

```bash
kubectl auth can-i --as=alice --as-group=homelab:readonly get pods -A
kubectl auth can-i --as=alice --as-group=homelab:minecraft-operators patch deployment -n minecraft
```

## Long-term path: OIDC

When you want easier offboarding, MFA, and centralized identity, move human access to OIDC.

Use `templates/k3s-oidc-config.example.yaml` as the starting point for `/etc/rancher/k3s/config.yaml` on the control plane.

Typical flow:

1. Choose an OIDC provider such as Authentik, Dex, or Keycloak.
2. Place the provider CA at `/etc/rancher/k3s/oidc/ca.crt` if needed.
3. Merge the OIDC flags into the k3s config.
4. Restart k3s.
5. Bind IdP groups to the same Kubernetes groups already used by RBAC.

Because the RBAC is group-based, authentication can change later without reworking authorization.

## Offboarding guidance

- Prefer short-lived certificates.
- Keep owner-level access limited to a very small number of people.
- Avoid direct user bindings when a group binding will do.
