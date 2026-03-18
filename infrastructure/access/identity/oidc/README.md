# Internal OIDC Identity

This directory contains the shared OIDC identity system used by both humans and non-human machine identities.

Current provider:

- Keycloak over Tailscale

Primary components:

- `../../../../infrastructure/keycloak/` — in-cluster Keycloak deployment
- `../../../../templates/k3s-oidc-config.example.yaml` — k3s API server OIDC settings
- `../../../../templates/kubeconfig.oidc-exec.template.yaml` — exec-based kubeconfig shape for external clients
