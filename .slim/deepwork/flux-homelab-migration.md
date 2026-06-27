# Flux homelab migration deepwork state

## Goal

Move cluster GitOps ownership from `ai-trade/.kube/flux` to `homelab-k8s/clusters/homelab` so Flux is clearly operated from the homelab cluster repo while ai-trade remains the application repo.

## Final user decisions

- Solve both problems: Flux controllers should run in the Debian k3s cluster, and homelab-k8s should become the operational control plane.
- Scope: ai-trade only for the first migration; leave keycloak, monitoring, minecraft manual for now.
- Keep ai-trade workload manifests in `ai-trade/.kube/overlays/{prod,paper}`.
- Reuse the existing ai-trade Flux deploy key for the new `GitRepository/aitrade`.
- Store that deploy key as a SOPS-encrypted Kubernetes Secret in homelab-k8s.
- Use Vaultwarden as the primary future secret manager, plus an offline break-glass backup because Vaultwarden will run inside the same cluster.
- Branches: `feature/flux-bootstrap` in homelab-k8s first, then `feature/flux-out-of-repo` in ai-trade.
- Add `make flux-status` to ai-trade.
- Add a setter-marker lint; do not skip it.

## Confirmed repo context

- `ai-trade/.kube/flux/flux-system` currently contains Flux bootstrap manifests, `aitrade-prod` Kustomization, and image automation resources.
- `ai-trade/.kube/overlays/prod/kustomization.yaml` contains the image setter marker used by Flux ImageUpdateAutomation.
- Flux controller manifests currently only select `kubernetes.io/os: linux`; workloads already pin to `kubernetes.io/hostname: debian`.
- `homelab-k8s` has no Flux setup today; it is k3s on single Debian node, mostly manually applied manifests.
- `homelab-k8s/docs/howto/architecture-evolution-strategy.md` already anticipates GitOps as a future phase.

## Execution plan

1. Oracle review of plan before implementation.
2. Homelab repo first: add Flux/SOPS docs and scaffolding, with live `flux bootstrap`/cutover commands documented rather than run unless explicitly authorized.
3. Validate repo-only changes.
4. ai-trade cleanup second: docs, Makefile target, setter-marker lint, eventual `.kube/flux` removal after homelab side is healthy.

## Safety notes

- Do not run `flux bootstrap`, `kubectl create secret`, or `flux resume` against the live cluster without explicit confirmation.
- Do not commit cleartext age private keys, deploy keys, kubeconfigs, or decrypted secret files.
- Avoid Kubernetes Job for printing the age key. Prefer SSH to the homelab node and `lp`, with temp-file shred afterwards.

## Oracle review accepted feedback

- Blocker: migrated `ImageUpdateAutomation/aitrade` must use `sourceRef.name: aitrade`, not `flux-system`, or it will push image bump commits to homelab-k8s instead of ai-trade.
- Use two GitRepositories: `flux-system` for homelab-k8s and `aitrade` for ai-trade.
- Name the ai-trade deploy-key Secret `aitrade-auth`; do not collide with the bootstrap-owned `Secret/flux-system`.
- Keep new `Kustomization/aitrade-prod` suspended for initial PR/review to avoid double reconciliation.
- Add a runbook with explicit cutover and rollback steps before deleting anything from ai-trade.
- Add SOPS setup, deploy-key extraction, recovery, and ImageUpdateAutomation verification docs.
- Add physical/offline age-key backup guidance: Vaultwarden primary later, plus printed/USB break-glass copy.
- Validate exact setter marker `# {"$imagepolicy": "flux-system:aitrade:tag"}` remains in ai-trade prod kustomization.

## Homelab scaffold status

- `feature/flux-bootstrap` bookmark created in homelab-k8s (Jujutsu working copy).
- Repo-only Flux/SOPS scaffold completed by fixer. No live `flux`/`kubectl` commands were run.
- Key files added in homelab-k8s: `.sops.yaml`, `clusters/prod/aitrade/*`, `clusters/prod/aitrade-flux-kustomization.yaml`, `clusters/prod/secrets/*`, and docs under `docs/guides`, `docs/howto`, `docs/runbooks`, `docs/plans`.
- Verified important oracle blocker in scaffold: `clusters/prod/aitrade/image-automation.yaml` uses `sourceRef.name: aitrade`.
- Verified ai-trade auth secret naming in scaffold: `GitRepository/aitrade` should reference `aitrade-auth`.

## Scope addition

- User requested Vaultwarden in the same homelab-k8s PR.
- Treat Vaultwarden as another suspended/not-live cluster app scaffold until explicitly cut over.
- Vaultwarden will be primary operator-accessible secret manager later, but not the only copy of SOPS age private key; offline break-glass backup remains required.

## Vaultwarden research accepted context

- Use official image `vaultwarden/server` or `ghcr.io/dani-garcia/vaultwarden`, pinned to a specific release. Current recommendation from research: `vaultwarden/server:1.36.0-alpine` or equivalent pinned GHCR tag; avoid `latest`.
- Small homelab should use SQLite first: one Deployment replica, RWO PVC mounted at `/data`; no external DB in this PR.
- Required secret/config values: `ADMIN_TOKEN`, `DOMAIN`, `SIGNUPS_ALLOWED`, `WEBSOCKET_ENABLED=true`, `ROCKET_PORT=80`, `DATA_FOLDER=/data`, `INVITATIONS_ALLOWED=true`; SMTP optional later.
- Use `ClusterIP` Service initially. Prefer Tailscale-only exposure; avoid public ingress unless later hardened with rate limits/IP allowlists.
- Backup/restore must be documented. Back up `/data` contents: SQLite DB, attachments, sends, config, RSA keys. Prefer admin backup endpoint or PVC snapshot/off-cluster backup later.
- Vaultwarden in-cluster is daily-use convenience, not offline root of trust. SOPS age private key still needs offline paper/USB backup.

## Vaultwarden oracle review accepted feedback

- Set `INVITATIONS_ALLOWED=false` by default unless a specific invitation use case appears.
- Include a NetworkPolicy in the first PR; Vaultwarden is high-value and should not be reachable by every in-cluster pod.
- Include a backup CronJob manifest in the PR but keep it suspended. Local same-PVC backups only protect from accidental DB-file deletion, not PVC/node loss.
- Document external backup push as Phase 2: S3-compatible target, NAS, or SSH/SCP to another machine.
- Layout should be `clusters/prod/vaultwarden/` with namespace, deployment, service, pvc, networkpolicy, backup-cronjob, and kustomization.
- SOPS secret should be `clusters/prod/secrets/vaultwarden-secrets.sops.yaml`.
- Same PR is acceptable because resources are non-live/suspended, but keep docs and manifests clearly separated from Flux migration pieces.

## Validation finding

- Initial repo-only `kubectl kustomize clusters/prod/{aitrade,vaultwarden}` failed because kustomizations referenced intentionally-missing real SOPS secret files.
- Fixed by leaving SOPS secret resources as explicit TODO comments until encrypted files are generated; this keeps repo validation green and avoids committing fake or cleartext secrets.
- Validation also found unsafe docs examples that decrypted secrets to stdout with `head`; patched to use metadata-only checks (`sops filestatus`, Kubernetes Secret metadata) and SSH+`lp` paper printing.

## Homelab layout review accepted feedback

- Keep `clusters/prod/` thin: Flux bootstrap, thin Flux Kustomizations, external-app Flux resources, and centralized SOPS secrets only.
- Move Vaultwarden workload manifests from `clusters/prod/vaultwarden/` to `infrastructure/vaultwarden/`, matching existing `infrastructure/keycloak/` pattern.
- Keep `clusters/prod/aitrade/` because those files are cluster Flux resources for an external app repo, not workload manifests.
- Replace `clusters/prod/vaultwarden-flux-kustomization.yaml` with `clusters/prod/vaultwarden.yaml` pointing to `./infrastructure/vaultwarden`.
- Rename `clusters/prod/aitrade-flux-kustomization.yaml` to `clusters/prod/aitrade-flux.yaml`.
- Document `apps/` as legacy/pre-GitOps; future native services should graduate to `infrastructure/<name>/` with thin cluster Kustomizations.

## Homelab phase review accepted feedback

- Add `clusters/homelab/kustomization.yaml` before bootstrap to avoid Flux version-dependent plain-mode behavior.
- Root kustomization lists suspended thin Kustomizations now (`aitrade-flux.yaml`, `vaultwarden.yaml`) and documents post-bootstrap addition/verification of generated Flux manifests.
- Update `docs/guides/flux-setup.md` to require replacing `.sops.yaml` age public key placeholder, correct bootstrap wording, verify root kustomization, and verify generated `Kustomization/flux-system.spec.path` is `./clusters/homelab`.

## Validation results

- homelab-k8s:
  - `kubectl kustomize clusters/homelab --load-restrictor LoadRestrictionsNone` passed.
  - `kubectl kustomize infrastructure/vaultwarden --load-restrictor LoadRestrictionsNone` passed.
  - `kubectl kustomize clusters/homelab/aitrade --load-restrictor LoadRestrictionsNone` passed.
  - Grep for `clusters/prod` returned no hits.
  - Grep for unsafe decrypt-to-stdout snippets returned no hits.
- ai-trade:
  - Removed `.kube/flux/flux-system/*` manifests.
  - Updated `.kube/README.md`, `RELEASING.md`, `README.md`, and `AGENTS.md` to point to homelab-k8s as the Flux owner.
  - Added `make lint-kube-image-setter` and included it in `make verify`.
  - Added `make flux-status`.
  - `make lint-kube-image-setter` passed.
  - `kubectl kustomize .kube/overlays/prod --load-restrictor LoadRestrictionsNone` passed.
  - Grep for `.kube/flux`, `FLUX_GIT_WRITE_TOKEN`, and old `sourceRef.name: flux-system` patterns returned no hits in md/yaml/example/Makefile files.

## Caveat

- ai-trade worktree had pre-existing unrelated changes in `app/agent-harness/tests/*`; do not include them in this migration commit unless user explicitly wants to.

## Final state and what's next

### Final state

- **homelab-k8s PR #10**: scaffold only, not yet merged. Contains:
  - `clusters/homelab/` cluster identity root
  - `infrastructure/vaultwarden/` Vaultwarden manifests
  - `clusters/homelab/secrets/` SOPS examples
  - `clusters/homelab/aitrade/` Flux integration for ai-trade
  - `clusters/homelab/flux-system/patches/controller-node-selector.yaml` controller node-selector
  - `Makefile.cluster` SSH-proxied `make flux-*` targets
  - runbooks, plans, howtos
- **ai-trade PR #67**: merged. Removed `.kube/flux/`, added `make flux-status` and `make lint-kube-image-setter`, updated docs.
- **Cluster**: `Kustomization/flux-system` running on `master@sha1:4774b454`, aitrade-flux and aitrade-prod Ready, image automation active.
- **Tested end-to-end**: ai-trade cutover succeeded; image automation committing tag bumps; pods rolling.

### What is left on the agenda

1. **Merge homelab-k8s PR #10**. The scaffold is complete and cluster-tested. After merging, the homelab repo becomes the canonical cluster definition.

2. **Validate a real end-to-end release** with a small tag (e.g. `v0.1.14`). Verify the image automation commit lands on ai-trade `master` and `Kustomization/aitrade-prod` reconciles.

3. **Move out-of-band cluster secrets into the repo**:
   - `Secret/sops-age` (age private key)
   - `Secret/ghcr-pull` (GitHub PAT for image registry)
   - `Secret/aitrade-auth` (already in repo via SOPS)
   These should become SOPS-encrypted files in `clusters/homelab/secrets/` with the corresponding Kustomization resources so they survive a cluster rebuild.

4. **Wire the controller node-selector patch** in `clusters/homelab/flux-system/kustomization.yaml`. The patch is already shipped in the repo; just add the reference and commit.

5. **Add the AI trade node-pool selector**. The ai-trade overlays still pin to `kubernetes.io/hostname: debian`. Migrate to `homelab.englios.dev/node-pool: trading` once a dedicated pool exists.

6. **Bring up Vaultwarden** (already in the repo) — user said "we'll have to run vaultwarden properly later":
   - Generate the encrypted `Secret/vaultwarden-secrets.sops.yaml`
   - Resume `Kustomization/vaultwarden`
   - Verify it is reachable via Tailscale only (no public ingress)
   - Move age key into Vaultwarden as the primary store

7. **Add SOPS-encrypted copy of `sops-age` and `ghcr-pull`**:
   - Create `clusters/homelab/secrets/sops-age.sops.yaml`
   - Create `clusters/homelab/secrets/ghcr-pull.sops.yaml`
   - Add corresponding Kustomization patches so the cluster rebuilds are reproducible
   - Move them out of band-once secrets into reproducible repo state

8. **Homelab architecture evolution Phase 2**:
   - Decide whether to rename repo (e.g. `k8s-infra` or `cluster-infra`) since `clusters/homelab/` is redundant with repo name `homelab-k8s`
   - Migrate `apps/minecraft-server` to `infrastructure/minecraft/` with a thin `clusters/homelab/minecraft.yaml` Flux Kustomization
   - Decide on `apps/` removal
   - When ai-trade overlays have node-selector migration, document the rename or removal of `kubernetes.io/hostname` selectors

9. **External backup target for Vaultwarden**:
   - Phase 1 backup CronJob is in repo but only writes to the same PVC
   - Add an off-cluster backup target (S3-compatible, NAS, or SCP to another machine)

10. **Ansible-style remote command pattern**:
    - The `Makefile.cluster` SSH-proxied targets are a step toward running `kubectl`/`flux` from any device
    - Consider a `kubectl`-on-jumpbox or `teleport`/`tsh` pattern for engineers on other devices

11. **Vaultwarden on Tailscale**:
    - Expose the ClusterIP via a Tailscale sidecar/operator
    - Set up DNS name (MagicDNS) and HTTPS
    - Document the access flow for family members and engineers

12. **Documentation cleanup**:
    - Update `homelab-k8s/README.md` once PR #10 is merged
    - Update `ai-trade/AGENTS.md` to reference the new GitOps control plane
    - Add a top-level `homelab-k8s/docs/runbooks/flux-cutover.md` recap with the actual flow used in this migration

13. **Monitor the cluster**:
    - Bring up kube-prometheus-stack (already in `infrastructure/monitoring/`)
    - Set up Flux notifications (Receiver, Provider, Alert) for production observability
    - Currently no notifications are configured

14. **CI for the homelab repo**:
    - Add a `make verify` style target: format + lint (kubeval, kubeconform) + repo-only kustomize build
    - The PR ran without a CI gate

15. **Replace the manual `make flux-status` with a real `flux` alias setup**:
    - Add a one-line `kubectl` completion alias or a `task` runner on each engineer's machine
    - The current SSH-based flow works but is not ergonomic for daily use

### Files and artifacts to preserve

- `homelab-k8s/PR-10` (the scaffold PR) — merge it
- `homelab-k8s/.sops.yaml` — replace placeholder with real age public key
- `homelab-k8s/clusters/homelab/aitrade/aitrade-auth.sops.yaml` — already encrypted and live
- `~/age.key` (on homelab node) — store in Vaultwarden + paper/USB
- `~/aitrade-deploykey` (SSH key for ai-trade GitHub access) — backup offline
- `ghcr-pull` PAT — store in Vaultwarden / 1Password
- The leaked `ghp_HxuHY...` PAT — already revoked

### What I will not do

- I will not run live cluster commands again without explicit confirmation
- I will not commit any encrypted secret with a public key
- I will not create or rotate SSH/PAT tokens without confirmation
- I will not re-bootstrap Flux without explicit confirmation
