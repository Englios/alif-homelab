# clusters/homelab — Cluster Identity Configuration

This directory contains the Flux bootstrap root and thin Flux Kustomizations
for the homelab k3s cluster ("homelab"). This is the physical/logical cluster
identity — not an app environment.

## Principles

- **Thin**: Only Flux bootstrap manifests, thin Flux Kustomizations,
  external-app Flux integration resources, and centralized SOPS secrets live here.
- **Workload manifests** for native cluster services live under
  `infrastructure/<service>/` (e.g., `infrastructure/vaultwarden/`).
- **External workloads** (e.g., ai-trade) keep manifests in their own repos;
  this directory only owns Flux integration resources (GitRepository,
  Kustomization, image automation).
- **apps/** is legacy/pre-GitOps. Future native GitOps services belong under
  `infrastructure/<name>/` with a thin `clusters/homelab/<name>.yaml`
  Flux Kustomization pointing to it.

## Structure

```
clusters/homelab/
├── README.md                       # This file
├── kustomization.yaml              # Bootstrap root; lists thin Kustomizations
├── aitrade/                        # ai-trade Flux integration resources
│   ├── gitrepository.yaml          # GitRepository pointing to ai-trade repo
│   ├── aitrade-prod-kustomization.yaml  # Kustomization for ai-trade manifests
│   ├── image-repository.yaml       # ImageRepository for ghcr.io/englios/aitrade
│   ├── image-policy.yaml           # Semver policy for automated updates
│   ├── image-automation.yaml       # ImageUpdateAutomation committing new tags
│   ├── kustomization.yaml          # Kustomize inventory listing all above
│   └── README.md
├── aitrade-flux.yaml               # Flux Kustomization that reconciles aitrade/
├── vaultwarden.yaml                # Flux Kustomization that reconciles vaultwarden
│                                   # (path: ./infrastructure/vaultwarden)
├── node-labels.md                  # Node placement documentation
└── secrets/                        # Encrypted SOPS secrets
    ├── README.md
    ├── aitrade-auth.sops.yaml.example
    └── vaultwarden-secrets.sops.yaml.example
```

## Current Status

- **Flux bootstrap** has NOT been run yet. See `docs/guides/flux-setup.md`.
- **ai-trade** is the first Flux-integrated workload, added alongside
  **Vaultwarden** (password manager) in the same scaffolding PR.
- Native homelab workloads (minecraft-server in `apps/`, etc.) remain manual
  `kubectl apply`.
- All Flux-managed resources are created with `suspend: true`. Cutovers
  are staged — see `docs/runbooks/flux-cutover.md` (ai-trade) and
  `docs/runbooks/vaultwarden.md`.
