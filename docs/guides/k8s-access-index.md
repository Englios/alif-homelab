# Kubernetes Access Index

This is the main entry point for Kubernetes access documentation in this repo.

## Current state

- Human access is documented separately from bot access.
- The live automation bot is currently applied in `inference-engine`.
- Additional bot access for `experiment` is prepared in the repo but not yet applied.
- A reusable namespace template is available for future bot targets such as `benchmark`, `celery-pipeline`, or `qwen-test`.
- The long-term identity direction is one internal OIDC provider over Tailscale for both humans and the always-on VM bot.

## Guides

- [Kubernetes Access Overview](./k8s-access-overview.md) — Current repo and cluster access state
- [Kubernetes Human Access](./k8s-human-access.md) — Human onboarding, RBAC groups, and OIDC path
- [Kubernetes Bot Access](./k8s-bot-access.md) — Bot service account scope and verification
- [Kubernetes Bot OIDC with Keycloak over Tailscale](./k8s-bot-oidc-keycloak.md) — Internal-only machine identity for the always-on VM bot

## Key manifests and templates

- `infrastructure/access/rbac/role-catalog.yaml`
- `infrastructure/access/rbac/bot-access.yaml`
- `infrastructure/access/rbac/bot-access.oidc.yaml`
- `infrastructure/access/rbac/bot-access.experiment.yaml`
- `infrastructure/access/rbac/bot-access.namespace-template.yaml`
- `templates/kubeconfig.oidc-exec.template.yaml`
- `templates/k3s-oidc-config.example.yaml`
