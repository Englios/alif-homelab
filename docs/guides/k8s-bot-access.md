# Kubernetes Bot Access

This guide covers the automation bot access model for the homelab cluster.

## Current live bot

The live cluster now has:

- service account: `homelab-automation-bot`
- home namespace: `inference-engine`
- manifest: `infrastructure/access/rbac/bot-access.yaml`

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

## Why this bot model is safe enough

- The bot is a workload identity, not a human login.
- Cluster-wide permissions are read-only.
- Write access is restricted to explicit namespaces.
- Debug permissions are limited to the namespaces where the bot is allowed to operate.

## Generate a kubeconfig for the bot

Use:

- `templates/kubeconfig.token.template.yaml`
- `scripts/make-token-kubeconfig.sh`

The helper is for bot or short-lived automation credentials. It is not the preferred path for normal human access.

## Verification commands

These checks were used for the live bot:

```bash
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get nodes
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot list namespaces
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get storageclasses.storage.k8s.io
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get ingressclasses.networking.k8s.io
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get events.events.k8s.io -A
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot get nodes.metrics.k8s.io
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot create deployments.apps -n inference-engine
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot create pods/exec -n inference-engine
kubectl auth can-i --as=system:serviceaccount:inference-engine:homelab-automation-bot create services/proxy -n inference-engine
```
