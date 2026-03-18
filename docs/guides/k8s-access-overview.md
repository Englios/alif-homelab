# Kubernetes Access Overview

This repo now tracks Kubernetes access in two separate paths:

- **Humans** use individual identities with group-based RBAC.
- **Bots** use dedicated `ServiceAccount` identities with tightly scoped permissions.

## Current live state

The cluster currently has a bot service account named `homelab-automation-bot` applied in the `inference-engine` namespace.

That bot currently has:

- cluster-scoped read-only access to nodes, namespaces, storage classes, ingress classes, and node metrics
- full CRUD-style access in the `inference-engine` namespace
- debug access for `pods/exec`, `pods/portforward`, and `services/proxy` inside `inference-engine`

The repo also includes an extra manifest for `experiment`, but that namespace has **not** been created or applied yet.

## Guides

- [Human cluster access](./k8s-human-access.md)
- [Bot cluster access](./k8s-bot-access.md)

## Repo files

- Shared human role catalog: `infrastructure/access/rbac/role-catalog.yaml`
- Live bot access: `infrastructure/access/rbac/bot-access.yaml`
- Future experiment bot access: `infrastructure/access/rbac/bot-access.experiment.yaml`
- Token kubeconfig template: `templates/kubeconfig.token.template.yaml`
- OIDC API server example: `templates/k3s-oidc-config.example.yaml`
- Token kubeconfig helper: `scripts/make-token-kubeconfig.sh`
