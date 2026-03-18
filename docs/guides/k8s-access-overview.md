# Kubernetes Access Overview

This repo now tracks Kubernetes access in two separate paths:

- **Humans** use individual identities with group-based RBAC.
- **Bots** use dedicated `ServiceAccount` identities with tightly scoped permissions.

Long term, both humans and always-on external bots should authenticate through the same internal OIDC provider over Tailscale, with RBAC deciding what each identity can do.

That means several earlier pieces are now **fallback/bootstrap paths**, not the preferred steady-state design.

## Current live state

The cluster currently has a bot service account named `homelab-automation-bot` applied in the `inference-engine` namespace.

That bot currently runs **outside** the cluster on its own VM as an LLM-based experiment runner.

That bot currently has:

- cluster-scoped read-only access to nodes, namespaces, storage classes, ingress classes, all events, and node metrics
- full CRUD-style access in the `inference-engine` namespace
- debug access for `pods/exec`, `pods/portforward`, and `services/proxy` inside `inference-engine`

Today, that off-cluster bot can use a short-lived kubeconfig minted from the service account as a bootstrap path. Because the bot is always on and expected to refresh its own credentials, the better steady-state model is the same internal OIDC system that humans should eventually use, exposed only on the Tailscale network.

The repo also includes an extra manifest for `experiment`, but that namespace has **not** been created or applied yet.

For future expansion, the repo now also includes a reusable namespace template for additional bot-managed namespaces such as `benchmark`, `celery-pipeline`, or `qwen-test`.

## Guides

- [Human cluster access](./k8s-human-access.md)
- [Bot cluster access](./k8s-bot-access.md)

## Repo files

- Shared human role catalog: `infrastructure/access/rbac/role-catalog.yaml`
- Live bot access: `infrastructure/access/rbac/bot-access.yaml`
- OIDC bot bindings: `infrastructure/access/rbac/bot-access.oidc.yaml`
- Future experiment bot access: `infrastructure/access/rbac/bot-access.experiment.yaml`
- Reusable future namespace template: `infrastructure/access/rbac/bot-access.namespace-template.yaml`
- Token kubeconfig template: `templates/kubeconfig.token.template.yaml`
- OIDC API server example: `templates/k3s-oidc-config.example.yaml`
- Token kubeconfig helper: `scripts/make-token-kubeconfig.sh`

## What is no longer primary

These are still useful, but they are no longer the preferred long-term path once OIDC is live:

- manually minted bot kubeconfigs
- direct service-account-token auth for the always-on VM bot
- separate human and bot identity systems

Keep them only for bootstrap, break-glass access, or temporary fallback during migration.

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
