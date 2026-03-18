# Keycloak over Tailscale

This directory contains the repo-side scaffold for the internal OIDC provider.

Purpose:

- one internal OIDC provider for humans and the always-on VM bot
- private exposure over Tailscale only
- k3s API server trusts the internal issuer URL
- pinned to the `debian` control-plane node so it does not depend on `pop-os`

Files:

- `namespace.yaml`
- `kustomization.yaml`
- `deployment.yaml`
- `service.yaml`
- `secret.yaml`
- `ingress.yaml`

Notes:

- this repo currently assumes `debian.munchkin-komodo.ts.net` as the internal issuer hostname
- apply with `kubectl apply -k infrastructure/keycloak`
- the remaining host-side step is updating `/etc/rancher/k3s/config.yaml` to trust the issuer
- see `docs/guides/k8s-bot-oidc-keycloak.md` for the full flow
