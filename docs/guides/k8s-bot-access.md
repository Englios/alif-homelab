# Kubernetes Bot Access

This guide covers the automation bot access model for the homelab cluster.

## Current live bot

The live cluster now has:

- OIDC machine identity bound through `infrastructure/access/rbac/bots/oidc-bindings.yaml`
- shared bot permission definitions in `infrastructure/access/rbac/bots/definitions.yaml`
- runtime location: external VM, not an in-cluster Pod
- purpose: external LLM agent that runs Kubernetes experiments with constrained access

The old service-account identity has been removed from the live cluster. `hermes-vm` should use the OIDC machine identity path only.

Applied state verified in-cluster:

- cluster-scoped read-only access to `nodes`, `namespaces`, `storageclasses`, `ingressclasses`, cluster-wide events visibility, and `metrics.k8s.io` node metrics
- namespaced read-only access across the cluster for common workload resources (`pods`, `pods/log`, `services`, `endpoints`, `persistentvolumeclaims`, `configmaps`, `events`, `deployments`, `replicasets`, `statefulsets`, `daemonsets`, `jobs`, `cronjobs`, `ingresses`, `networkpolicies`, `horizontalpodautoscalers`)
- full CRUD-style access in `inference-engine`
- full CRUD-style access in `experiment` (after that namespace role and binding are applied)
- `create` access for `pods/exec`, `pods/portforward`, and `services/proxy` in `inference-engine`

## Permission matrix

| Scope | Resources | Verbs |
| ----- | --------- | ----- |
| Cluster | `nodes`, `namespaces`, `storageclasses`, `ingressclasses`, `events`, `events.events.k8s.io`, `nodes.metrics.k8s.io` | `get`, `list`, `watch` |
| Cluster (namespaced resources) | `pods`, `pods/log`, `services`, `endpoints`, `persistentvolumeclaims`, `configmaps`, `events`, `deployments`, `replicasets`, `statefulsets`, `daemonsets`, `jobs`, `cronjobs`, `ingresses`, `networkpolicies`, `horizontalpodautoscalers` | `get`, `list`, `watch` |
| `inference-engine` | `*` | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` |
| `experiment` | `*` | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` |
| `inference-engine` debug | `pods/exec`, `pods/portforward`, `services/proxy` | `create` |

## Apply the bot permission definitions

```bash
kubectl apply -f infrastructure/access/rbac/bots/definitions.yaml
```

## Future experiment namespace access

The repo also includes:

- `infrastructure/access/rbac/bots/experiment-role.yaml`

Apply it only after the `experiment` namespace exists:

```bash
kubectl apply -f infrastructure/access/rbac/bots/experiment-role.yaml
```

That manifest defines the matching namespace-local permissions in `experiment`.

## Future namespace expansion

If you later want the same bot to manage another namespace such as `benchmark`, `celery-pipeline`, or `qwen-test`, use:

- `infrastructure/access/rbac/bots/namespace-role.template.yaml`
- `infrastructure/access/rbac/bots/namespace-role.template.yaml`

Replace `<TARGET_NAMESPACE>` with the real namespace name, then apply it after that namespace exists.

## OIDC binding path

For the long-term VM bot identity, use:

- `infrastructure/access/rbac/bots/oidc-bindings.yaml`
- `infrastructure/access/rbac/bots/oidc-bindings.yaml`

This binds the expected OIDC machine username:

- `oidc:service-account-homelab-automation-bot`

to the same effective cluster and namespace permissions.

This is now the active path for `hermes-vm`.

## Why this bot model is safe enough

- The bot is a workload identity, not a human login.
- Cluster-wide permissions are read-only.
- Write access is restricted to explicit namespaces (`inference-engine` and `experiment`).
- Debug permissions are limited to the namespaces where the bot is allowed to operate.

## Where this RBAC should live

For this homelab, the current bot RBAC should live in `homelab-k8s`, not in `inference-engine-deployment`.

Why:

- it grants cluster-scoped read access
- it can span multiple namespaces over time
- it represents platform policy, not just one app's deployment manifest

Use the inference app repo for RBAC only when a role is packaged and deployed as part of that single application.

## Generate a kubeconfig for the bot

`hermes-vm` should generate and manage its own local OIDC kubeconfig using `templates/kubeconfig.oidc-exec.template.yaml` as the reference shape.

## Recommended renewal model

Because the current bot runs **outside** the cluster on its own VM, there are two practical modes:

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

## Off-cluster bot with automatic renewal

1. Configure k3s API server OIDC settings.
2. Create a dedicated non-human client or workload identity in your IdP.
3. Map that identity to the Kubernetes RBAC you want.
4. Let the bot fetch and refresh short-lived OIDC tokens on the VM.
5. Let `hermes-vm` own its local kubeconfig generation and storage.

This is the intended and active answer because auto-renewal is a hard requirement.

Use `templates/kubeconfig.oidc-exec.template.yaml` as the starting point for the bot's self-refreshing kubeconfig.

Use `templates/k3s-oidc-config.example.yaml` with an internal Tailscale-only issuer URL when wiring the API server.

That same internal issuer should also become the long-term auth path for human users.

## Verification commands

These checks were used for the old service-account path during earlier validation:

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
