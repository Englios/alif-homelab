# Kubernetes Bot Access

This guide covers the automation bot access model for the homelab cluster.

## Current live bot

The live cluster now has:

- service account: `homelab-automation-bot`
- home namespace: `inference-engine`
- manifest: `infrastructure/access/rbac/bot-access.yaml`
- runtime location: external VM, not an in-cluster Pod
- purpose: external LLM agent that runs Kubernetes experiments with constrained access

Today, the service-account-based kubeconfig remains the working bootstrap path. Once internal OIDC is live, that bootstrap path should become fallback-only.

Applied state verified in-cluster:

- cluster-scoped read-only access to `nodes`, `namespaces`, `storageclasses`, `ingressclasses`, cluster-wide events visibility, and `metrics.k8s.io` node metrics
- full CRUD-style access in `inference-engine`
- `create` access for `pods/exec`, `pods/portforward`, and `services/proxy` in `inference-engine`

## Permission matrix

| Scope | Resources | Verbs |
|------|-----------|-------|
| Cluster | `nodes`, `namespaces`, `storageclasses`, `ingressclasses`, `events`, `events.events.k8s.io`, `nodes.metrics.k8s.io` | `get`, `list`, `watch` |
| `inference-engine` | `*` | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` |
| `inference-engine` debug | `pods/exec`, `pods/portforward`, `services/proxy` | `create` |

## Apply the live bot profile

```bash
kubectl apply -f infrastructure/access/rbac/bot-access.yaml
```

## Future experiment namespace access

The repo also includes:

- `infrastructure/access/rbac/bot-access.experiment.yaml`

Apply it only after the `experiment` namespace exists:

```bash
kubectl apply -f infrastructure/access/rbac/bot-access.experiment.yaml
```

That manifest reuses the same service account from `inference-engine` and grants matching namespace-local access in `experiment`.

## Future namespace expansion

If you later want the same bot to manage another namespace such as `benchmark`, `celery-pipeline`, or `qwen-test`, use:

- `infrastructure/access/rbac/bot-access.namespace-template.yaml`

Replace `<TARGET_NAMESPACE>` with the real namespace name, then apply it after that namespace exists.

## OIDC binding path

For the long-term VM bot identity, use:

- `infrastructure/access/rbac/bot-access.oidc.yaml`

This binds the expected OIDC machine username:

- `oidc:service-account-homelab-automation-bot`

to the same effective cluster and namespace permissions.

This becomes the preferred path once the Keycloak client and k3s OIDC trust are live.

## Why this bot model is safe enough

- The bot is a workload identity, not a human login.
- Cluster-wide permissions are read-only.
- Write access is restricted to explicit namespaces.
- Debug permissions are limited to the namespaces where the bot is allowed to operate.

## Where this RBAC should live

For this homelab, the current bot RBAC should live in `homelab-k8s`, not in `inference-engine-deployment`.

Why:

- it grants cluster-scoped read access
- it can span multiple namespaces over time
- it represents platform policy, not just one app's deployment manifest

Use the inference app repo for RBAC only when a role is packaged and deployed as part of that single application.

## Generate a kubeconfig for the bot

Use:

- `templates/kubeconfig.token.template.yaml`
- `scripts/make-token-kubeconfig.sh`

The helper is for bot or short-lived automation credentials. It is not the preferred path for normal human access.

## Recommended renewal model

Because the current bot runs **outside** the cluster on its own VM, there are two practical modes:

### Current working model

- short-lived kubeconfig minted from the `homelab-automation-bot` service account
- delivered to the VM by an owner or trusted automation path
- rotated by minting a fresh token and replacing the kubeconfig

This is the simplest bootstrap model and it fits the current permission boundary, but it is not the best steady-state answer for an always-on bot.

### Recommended steady-state model for automatic renewal

Use a dedicated **machine identity** flow through the same internal OIDC provider that humans will use.

That means:

- the API server trusts your OIDC provider
- the bot authenticates as a non-human client
- the bot gets short-lived tokens from the IdP and renews them automatically

Keep the OIDC issuer **internal-only**.

For this homelab, the right exposure model is:

- reachable over Tailscale only
- not published on a public internet hostname
- preferably addressed by a Tailscale DNS name or other internal hostname

Using an internal hostname is usually better than using a raw IP because the issuer URL and TLS certificate have to match exactly.

Because the bot is always on, this is now the recommended steady-state answer.

## Who should mint the bot kubeconfig?

Mint a kubeconfig when the bot runs **outside** the cluster and you need a bootstrap path, a fallback path, or the simplest temporary solution.

An owner or trusted automation path should mint the bot kubeconfig.

Do **not** design the bot to bootstrap its own cluster credentials.

Why:

- the bot would need some other privileged bootstrap credential first
- self-issuing credentials makes rotation and audit boundaries weaker
- owner-controlled minting keeps the trust boundary simple

OIDC is still the better path for **humans** by default.

For this bot, OIDC-style machine identity is also the better steady-state path because it lives off-cluster and needs to renew credentials on its own.

Recommended pattern:

### In-cluster bot

1. Run the bot as a Pod in `inference-engine`.
2. Set `serviceAccountName: homelab-automation-bot`.
3. Let the app use in-cluster auth.
4. Kubernetes handles token rotation automatically.

### Off-cluster bot

1. An owner or secure CI job creates a short-lived token for the service account.
2. That trusted path writes the kubeconfig.
3. The bot receives the finished kubeconfig through your normal secret delivery path.
4. Rotate by minting a fresh token and replacing the kubeconfig.

### Off-cluster bot with automatic renewal

1. Configure k3s API server OIDC settings.
2. Create a dedicated non-human client or workload identity in your IdP.
3. Map that identity to the Kubernetes RBAC you want.
4. Let the bot fetch and refresh short-lived OIDC tokens on the VM.

This is more complex than the service-account kubeconfig path, but it is the cleaner answer here because auto-renewal is a hard requirement.

Use `templates/kubeconfig.oidc-exec.template.yaml` as the starting point for the bot's self-refreshing kubeconfig.

Use `templates/k3s-oidc-config.example.yaml` with an internal Tailscale-only issuer URL when wiring the API server.

That same internal issuer should also become the long-term auth path for human users.

## Verification commands

These checks were used for the live bot:

```bash
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get nodes
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot list namespaces
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get storageclasses.storage.k8s.io
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get ingressclasses.networking.k8s.io
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot list events.events.k8s.io -A
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get nodes.metrics.k8s.io
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot create deployments.apps -n inference-engine
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot create pods/exec -n inference-engine
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot create services/proxy -n inference-engine
```
