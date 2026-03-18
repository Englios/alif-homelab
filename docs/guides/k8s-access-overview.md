# Kubernetes Access Overview

This repo now tracks Kubernetes access as:

- **Shared identity** through internal OIDC over Tailscale.
- **Human RBAC** through group-based roles and bindings.
- **Bot RBAC** through machine-identity bindings plus namespaced roles.

Long term, both humans and always-on external bots should authenticate through the same internal OIDC provider over Tailscale, with RBAC deciding what each identity can do.

That means several earlier pieces are now **legacy migration paths**, not the preferred steady-state design.

## Current live state

The bot currently runs **outside** the cluster on its own VM as an LLM-based experiment runner.

That bot currently has:

- cluster-scoped read-only access to nodes, namespaces, storage classes, ingress classes, all events, and node metrics
- full CRUD-style access in the `inference-engine` namespace
- debug access for `pods/exec`, `pods/portforward`, and `services/proxy` inside `inference-engine`

The off-cluster bot now uses the same internal OIDC system that humans should eventually use, exposed only on the Tailscale network. `hermes-vm` is responsible for generating and managing its own local kubeconfig from that OIDC configuration.

The repo also includes an extra manifest for `experiment`, but that namespace has **not** been created or applied yet.

For future expansion, the repo now also includes a reusable namespace template for additional bot-managed namespaces such as `benchmark`, `celery-pipeline`, or `qwen-test`.

## Guides

- [Shared identity and OIDC](./k8s-bot-oidc-keycloak.md)
- [Human cluster access](./k8s-human-access.md)
- [Bot cluster access](./k8s-bot-access.md)

## Repo layout

- Shared identity: `infrastructure/access/identity/oidc/`
- Human RBAC: `infrastructure/access/rbac/humans/`
- Bot RBAC: `infrastructure/access/rbac/bots/`
- OIDC exec kubeconfig template: `templates/kubeconfig.oidc-exec.template.yaml`
- OIDC API server example: `templates/k3s-oidc-config.example.yaml`

## What is no longer primary

These are no longer the preferred long-term path once OIDC is live:

- manually minted bot kubeconfigs
- direct service-account-token auth for the always-on VM bot
- separate human and bot identity systems

Keep them only as temporary migration aids or for explicit break-glass use if you still need them.

## Ownership boundary

Manage **cluster access policy in this repo**.

That includes:

- human RBAC roles and bindings
- shared bot/service account access patterns
- cluster-scoped read permissions
- namespace access granted to automation identities that are part of the homelab platform

Manage **application-shipped RBAC in the application repo** only when the RBAC is tightly coupled to the workload being deployed.

For example, keep app-local permissions in `inference-engine-deployment` when they are deployed together with the app itself, such as:

- a service account used only by one inference workload
- a Role/RoleBinding required by a single deployment in its own namespace

For the current `homelab-automation-bot`, the source of truth should stay in `homelab-k8s` because it is a cluster access policy decision, not just an app packaging detail.
