# clusters/homelab/aitrade — ai-trade Flux Resources

This directory contains the Flux CRDs that manage the **ai-trade** trading
system workload. The workload manifests themselves live in the
[ai-trade](https://github.com/Englios/ai-trade.git) repository under
`.kube/overlays/prod/`.

## What's Here

| File | Kind | Purpose |
|------|------|---------|
| `gitrepository.yaml` | GitRepository | Points to ai-trade repo, authenticated via `aitrade-auth` SSH deploy key |
| `aitrade-prod-kustomization.yaml` | Kustomization | Syncs `./.kube/overlays/prod` from ai-trade into the cluster |
| `image-repository.yaml` | ImageRepository | Scans ghcr.io/englios/aitrade for new tags |
| `image-policy.yaml` | ImagePolicy | Semver policy (`>=0.0.0`) for automated updates |
| `image-automation.yaml` | ImageUpdateAutomation | Commits updated image tags back to ai-trade `master` |
| `kustomization.yaml` | Kustomize | Lists the above resources + the encrypted deploy-key secret |

## Key Design Decisions

- **Two-repo model**: `flux-system` GitRepository points to homelab-k8s
  (bootstrapped repo); `aitrade` GitRepository points to the ai-trade repo.
  This keeps workload versioning decoupled from Flux infrastructure.
- **Suspended initially**: All Flux resources are created with
  `spec.suspend: true`. Cutover is manually staged. See
  `docs/runbooks/flux-cutover.md`.
- **Secrets**: The SSH deploy key (`aitrade-auth`) is encrypted with
  SOPS/age. The GitRepository uses SSH URL
  (`ssh://git@github.com/Englios/ai-trade.git`) so Flux authenticates
  via the `identity` / `identity.pub` / `known_hosts` fields in the
  Secret. The key must be write-enabled for ImageUpdateAutomation to push
  tag-bump commits. See `docs/howto/sops-secrets.md`.
- **Image automation**: `ImageUpdateAutomation` uses sourceRef `aitrade`
  (the GitRepository, not `flux-system`), and pushes tag bumps back to
  the ai-trade repo `master` branch.

## Prerequisites

Before these resources can be reconciled:

1. Flux must be bootstrapped into the cluster (see `docs/guides/flux-setup.md`).
2. The `sops-age` Secret must exist in the `flux-system` namespace
   (contains the age private key for SOPS decryption).
3. `clusters/homelab/aitrade/aitrade-auth.sops.yaml` must exist and be
   encrypted with the correct SSH deploy key values. To create for the
   first time, copy from the example at
   `clusters/homelab/secrets/aitrade-auth.sops.yaml.example`, replace
   placeholders, and encrypt with SOPS.
4. The `ghcr-pull` docker-registry Secret must exist in `flux-system`
   (for ImageRepository to authenticate with GHCR).
