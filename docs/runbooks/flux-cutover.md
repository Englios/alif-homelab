# Flux Cutover Runbook — ai-trade Migration

> **Status**: Planning / Not yet executed.
>
> This runbook describes the staged cutover of ai-trade from its current
> Flux setup (in the ai-trade repo) to the new Flux setup managed from
> homelab-k8s. All resources have been pre-created with `suspend: true`
> to prevent premature reconciliation.

## Prerequisites

Before starting the cutover, confirm:

- [ ] Flux is bootstrapped into the cluster from homelab-k8s.
- [ ] `clusters/homelab/secrets/aitrade-auth.sops.yaml` exists and is encrypted.
- [ ] The `sops-age` Secret exists in `flux-system` with the correct age key.
- [ ] The `ghcr-pull` Secret exists in `flux-system` (for ImageRepository).
- [ ] You have `kubectl` and `flux` CLI access to the cluster.
- [ ] You have push access to both `homelab-k8s` and `ai-trade` repos.

## Stage 0: Preflight Checks

### 0.1 Verify Flux bootstrap

```bash
flux check
kubectl -n flux-system get pods
kubectl -n flux-system get gitrepository flux-system -o wide
kubectl -n flux-system get kustomization flux-system -o wide
```

All pods should be `Running`, the GitRepository should be ready, and the
Kustomization should show `Ready=True`.

### 0.1a Apply node labels to the control-plane node

Required before resuming the `flux-system` and `vaultwarden`
Kustomizations, or pods will fail to schedule.

```bash
NODE=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
kubectl label node "$NODE" homelab.englios.dev/node-pool=system --overwrite
kubectl label node "$NODE" homelab.englios.dev/node-pool=apps --overwrite
```

See `clusters/homelab/node-labels.md` for the full placement strategy.

### 0.2 Verify SOPS key is in place

```bash
kubectl -n flux-system get secret sops-age
```

If missing, create it:

```bash
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=<path-to-age-key>
```

### 0.2a Wire controller node-selector patch

After `flux bootstrap` has generated `clusters/homelab/flux-system/`,
add the controller node-selector patch:

```bash
# Edit clusters/homelab/flux-system/kustomization.yaml and add:
patches:
  - path: patches/controller-node-selector.yaml

git add clusters/homelab/flux-system
git commit -m "feat(flux): pin controllers to system node pool"
git push
```

### 0.3 Verify the encrypted deploy key is committed

```bash
sops filestatus clusters/homelab/secrets/aitrade-auth.sops.yaml
```

If this fails, re-encrypt the file or check the age key.

### 0.4 Backup the old ai-trade Flux resources (optional)

If the old Flux setup in the ai-trade repo is still running, back up its
state:

```bash
kubectl get kustomization -n flux-system aitrade-prod -o yaml > /tmp/aitrade-prod-backup.yaml
kubectl get gitrepository -n flux-system aitrade -o yaml > /tmp/aitrade-gitrepo-backup.yaml
kubectl get imageupdateautomation -n flux-system aitrade -o yaml > /tmp/aitrade-iua-backup.yaml
```

## Stage 1: Resume the aitrade-flux Control Kustomization

The `aitrade-flux` Kustomization is the control plane that reconciles all
aitrade resources under `clusters/homelab/aitrade/`. Resuming it will create
the GitRepository, ImageRepository, ImagePolicy, ImageUpdateAutomation,
and the (still-suspended) `aitrade-prod` Kustomization.

### 1.1 Push the current state

Ensure all files are committed and pushed to the `master` branch:

```bash
git add -A
git commit -m "feat(flux): add ai-trade Flux scaffolding"
git push origin master
```

### 1.2 Resume aitrade-flux

```bash
flux resume kustomization aitrade-flux
```

### 1.3 Verify the child resources are created

Wait 1-2 minutes, then:

```bash
kubectl -n flux-system get gitrepository aitrade
kubectl -n flux-system get imagerepository aitrade
kubectl -n flux-system get imagepolicy aitrade
kubectl -n flux-system get imageupdateautomation aitrade
kubectl -n flux-system get kustomization aitrade-prod
```

All should exist. The GitRepository should clone successfully.
The `aitrade-prod` Kustomization should show `Suspended=True`.

### 1.4 Verify the ai-trade GitRepository clones

```bash
kubectl -n flux-system get gitrepository aitrade -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

Should output `True`. If `False`, check the deploy key and secretRef:

```bash
kubectl -n flux-system describe gitrepository aitrade
kubectl -n flux-system get secret aitrade-auth
```

## Stage 2: Verify Image Automation

### 2.1 Check ImageRepository

```bash
kubectl -n flux-system get imagerepository aitrade -o jsonpath='{.status.lastScanResult}'
```

Should show a recent scan result with the latest tag.

### 2.2 Check ImagePolicy

```bash
kubectl -n flux-system get imagepolicy aitrade -o jsonpath='{.status.latestImage}'
```

Should show the latest image with the resolved semver tag.

### 2.3 Verify ImageUpdateAutomation is suspended

```bash
kubectl -n flux-system get imageupdateautomation aitrade -o jsonpath='{.spec.suspend}'
```

Should be `true`.

## Stage 3: Final Resume of ai-trade Workload

Only proceed when you are ready for Flux to take over ai-trade management.

### 3.1 Resume aitrade-prod

```bash
flux resume kustomization aitrade-prod
```

### 3.2 Verify workload resources appear

```bash
# Check the ai-trade namespace exists
kubectl get ns aitrade-prod

# Check pods, deployments, etc.
kubectl -n aitrade-prod get all

# Check the Kustomization status
kubectl -n flux-system get kustomization aitrade-prod -o wide
```

### 3.3 (Optional) Resume ImageUpdateAutomation

If you want automated image tag updates:

```bash
flux resume imageupdateautomation aitrade
```

### 3.4 Release test

Trigger a release tag (or wait for one) and verify the image automation
picks it up:

```bash
# After a new release tag is pushed to ai-trade:
# Wait for ImageRepository scan (interval: 10m)
# Wait for ImagePolicy to resolve new semver (interval: varies)
# The ImageUpdateAutomation will commit the new tag.

# Verify the commit appeared in ai-trade repo
# https://github.com/Englios/ai-trade/commits/master
```

## Rollback Commands

### Rollback Stage 1 (before resuming aitrade-prod)

If `aitrade-flux` causes issues (e.g., GitRepository fails to clone):

```bash
# Suspend the control Kustomization
flux suspend kustomization aitrade-flux

# Delete the child resources (they will be recreated on resume, so this
# is safe while suspended)
kubectl -n flux-system delete gitrepository aitrade
kubectl -n flux-system delete imagerepository aitrade
kubectl -n flux-system delete imagepolicy aitrade
kubectl -n flux-system delete imageupdateautomation aitrade
kubectl -n flux-system delete kustomization aitrade-prod

# Fix the issue (deploy key, path, etc.), commit, push
# Then re-run from Stage 1
```

### Rollback Stage 3 (after resuming aitrade-prod)

If the ai-trade workload doesn't reconcile correctly:

```bash
# 1. Suspend the workload Kustomization
flux suspend kustomization aitrade-prod

# 2. Revert to the previous Flux state
if [ -f /tmp/aitrade-prod-backup.yaml ]; then
  kubectl apply -f /tmp/aitrade-prod-backup.yaml
fi

# 3. Investigate the issue
kubectl -n flux-system describe kustomization aitrade-prod
kubectl -n aitrade-prod get events --sort-by='.lastTimestamp'
```

### Full rollback (restore old Flux setup)

```bash
# 1. Suspend all new resources
flux suspend kustomization aitrade-flux
flux suspend kustomization aitrade-prod
flux suspend imageupdateautomation aitrade

# 2. Restore old resources from backup
kubectl apply -f /tmp/aitrade-prod-backup.yaml
kubectl apply -f /tmp/aitrade-gitrepo-backup.yaml
kubectl apply -f /tmp/aitrade-iua-backup.yaml

# 3. Verify old setup works
kubectl -n flux-system get kustomization aitrade-prod
```

## Verification Checklist

After successful cutover:

- [ ] `flux get kustomization aitrade-flux` → Ready
- [ ] `flux get kustomization aitrade-prod` → Ready
- [ ] `flux get gitrepository aitrade` → Ready
- [ ] `flux get imagerepository aitrade` → Last scan result populated
- [ ] `flux get imagepolicy aitrade` → LatestImage set
- [ ] `flux get imageupdateautomation aitrade` → Ready (if resumed)
- [ ] `kubectl -n aitrade-prod get pods` → All running
- [ ] ai-trade journal and supervisor pods are operational
- [ ] Image automation commits are appearing in ai-trade repo

## Notes

- The `aitrade-prod` Kustomization does NOT use `dependsOn`. It relies
  directly on the `aitrade` GitRepository, which is created by the
  `aitrade-flux` control Kustomization.
- ImageUpdateAutomation is initially suspended to prevent premature tag
  bumps. Resume it only after confirming the workload is healthy.
- If you need to update the deploy key, re-encrypt the secret file with
  `sops --encrypt --in-place` and push.
