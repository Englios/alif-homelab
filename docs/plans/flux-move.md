# Flux Move Plan — ai-trade Operational Ownership

## Summary

Move the Flux operational ownership of ai-trade from the ai-trade
repository into homelab-k8s. The ai-trade repo retains its workload
manifests (`.kube/overlays/prod/`); homelab-k8s takes over the Flux
resources (GitRepository, Kustomization, image automation) that drive
reconciliation and deployment.

## Motivation

- **Separation of concerns**: Flux infrastructure lives alongside cluster
  configuration (homelab-k8s), not inside the workload repo.
- **Single control plane**: The homelab-k8s repo becomes the single source
  of truth for what runs in the cluster and how.
- **Foundation for GitOps**: Once the ai-trade migration proves the model,
  it can be extended to other workloads (minecraft-server, monitoring, etc.).

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Number of GitRepositories | 2 | `flux-system` → homelab-k8s; `aitrade` → ai-trade. Keeps workload versioning decoupled. |
| ImageUpdateAutomation sourceRef | `aitrade` (GitRepository) | Automation writes tag bumps to the ai-trade repo, not the flux-system repo. |
| Deploy key Secret name | `aitrade-auth` | Distinguishes it from the `flux-system` Secret used by bootstrap. |
| Initial state | Suspended (`suspend: true`) | Prevents premature reconciliation before all preconditions are met. |
| SOPS decryption | `aitrade-flux` Kustomization only | The control Kustomization decrypts secrets; the workload Kustomization does not need it. |
| Primary secret store | Vaultwarden | Age private key lives in Vaultwarden; offline paper/USB is break-glass. Vaultwarden itself is deployed as a suspended Flux workload in the same PR. |
| Secret printing | SSH + `lp` + `shred` | No K8s Job — avoids secret exposure in pod logs/etcd. |
| Cluster identity path | `clusters/homelab/` | Physical/logical cluster name, not an app environment. |

## Architecture

```
homelab-k8s (bootstrapped repo)
  └── clusters/homelab/
      ├── gotk-components.yaml               ← created by flux bootstrap
      ├── gotk-sync.yaml                     ← created by flux bootstrap
      ├── aitrade-flux.yaml                  ← Flux Kustomization (control plane)
      │     sourceRef: flux-system
      │     path: ./clusters/homelab/aitrade
      │     decryption: sops (sops-age)
      ├── vaultwarden.yaml                   ← Flux Kustomization (control plane)
      │     sourceRef: flux-system
      │     path: ./infrastructure/vaultwarden
      │     decryption: sops (sops-age)
      ├── aitrade/
      │     ├── gitrepository.yaml           ← GitRepository → ai-trade repo
      │     ├── aitrade-prod-kustomization.yaml ← Flux Kustomization (workload)
      │     │     sourceRef: aitrade
      │     │     path: ./.kube/overlays/prod
      │     ├── image-*.yaml                 ← image automation resources
      │     └── kustomization.yaml
      ├── node-labels.md                     ← Node pool placement strategy
      └── secrets/                           ← SOPS-encrypted
          ├── aitrade-auth.sops.yaml
          └── vaultwarden-secrets.sops.yaml

  └── infrastructure/
      └── vaultwarden/                       ← native workload manifests
          ├── namespace.yaml
          ├── pvc.yaml
          ├── deployment.yaml
          ├── service.yaml
          ├── networkpolicy.yaml
          ├── backup-cronjob.yaml
          └── kustomization.yaml

ai-trade (workload repo)
  └── .kube/overlays/prod/             ← workload manifests (unchanged)
      └── kustomization.yaml           ← gets image tag updates from automation
```

## Migration Steps (High-Level)

1. **Scaffold** — Create all Flux resource manifests in homelab-k8s (this PR).
   Vaultwarden (password manager) is included in the same scaffold PR as a
   suspended, ClusterIP-only, single-replica workload managed by Flux.
2. **Bootstrap** — Run `flux bootstrap` from homelab-k8s (see `docs/guides/flux-setup.md`).
3. **Pre-cutover** — Create `sops-age` Secret, encrypt `aitrade-auth.sops.yaml`.
4. **Stage 1** — Resume `aitrade-flux` Kustomization; verify resources created.
5. **Stage 2** — Verify image automation resources are working.
6. **Stage 3** — Resume `aitrade-prod` Kustomization; verify workload healthy.
7. **Post-cutover** — Resume `ImageUpdateAutomation`; verify tag bumps work.
8. **Cleanup** — Remove old Flux resources from ai-trade repo (optional).

See `docs/runbooks/flux-cutover.md` for the detailed staged procedure.

## Files Changed / Added

| File | Action |
|------|--------|
| `.gitignore` | Updated |
| `.sops.yaml` | Added |
| `clusters/homelab/README.md` | Added |
| `clusters/homelab/kustomization.yaml` | Added |
| `clusters/homelab/aitrade/README.md` | Added |
| `clusters/homelab/aitrade/gitrepository.yaml` | Added |
| `clusters/homelab/aitrade/aitrade-prod-kustomization.yaml` | Added |
| `clusters/homelab/aitrade/image-repository.yaml` | Added |
| `clusters/homelab/aitrade/image-policy.yaml` | Added |
| `clusters/homelab/aitrade/image-automation.yaml` | Added |
| `clusters/homelab/aitrade/kustomization.yaml` | Added |
| `clusters/homelab/secrets/README.md` | Added |
| `clusters/homelab/secrets/aitrade-auth.sops.yaml.example` | Added |
| `clusters/homelab/aitrade-flux.yaml` | Added |
| `clusters/homelab/vaultwarden.yaml` | Added |
| `clusters/homelab/node-labels.md` | Added |
| `infrastructure/vaultwarden/namespace.yaml` | Added |
| `infrastructure/vaultwarden/pvc.yaml` | Added |
| `infrastructure/vaultwarden/deployment.yaml` | Added |
| `infrastructure/vaultwarden/service.yaml` | Added |
| `infrastructure/vaultwarden/networkpolicy.yaml` | Added |
| `infrastructure/vaultwarden/backup-cronjob.yaml` | Added |
| `infrastructure/vaultwarden/kustomization.yaml` | Added |
| `infrastructure/vaultwarden/README.md` | Added |
| `docs/guides/flux-setup.md` | Added |
| `docs/howto/sops-secrets.md` | Added |
| `docs/runbooks/flux-cutover.md` | Added |
| `docs/runbooks/vaultwarden.md` | Added |
| `docs/plans/flux-move.md` | Added |
| `README.md` | Updated |
| `docs/README.md` | Updated |
| `docs/howto/architecture-evolution-strategy.md` | Updated |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Deploy key exposure | Unauthorized repo access | Encrypted at rest with SOPS; age key in Vaultwarden |
| Bootstrap failure | Cluster state drift | Pre-flight checks in runbook; backup old Flux state |
| Image automation commits to wrong repo | Broken CI/CD | sourceRef verified; update path targets ai-trade repo |
| SOPS decryption fails in Flux | Resources not created | Verify sops-age Secret; test decryption locally first |
| Network partition during cutover | Partial state | All changes are suspend/resume — reversible |
