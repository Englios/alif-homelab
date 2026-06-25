# Flux Setup Guide

> **⚠️ WARNING: Do NOT run these commands yet.** This is a reference runbook.
> Each section documents what needs to happen, but no `flux bootstrap` or
> `kubectl` commands have been executed from this repo. Execute them only
> when you are ready to perform the actual bootstrap.

## Prerequisites

- A working k3s cluster (`kubectl get nodes` returns ready nodes).
- `flux` CLI installed (see [fluxcd.io/install](https://fluxcd.io/flux/installation/)).
- `sops` CLI installed (see [getsops.io](https://getsops.io/)).
- `age` CLI installed (see [age docs](https://github.com/FiloSottile/age)).
- An age key pair for SOPS encryption (see `docs/howto/sops-secrets.md`).
- `.sops.yaml` updated with the real age **public** key before encrypting
  any secrets. The placeholder recipient must be replaced.
- Read `docs/runbooks/flux-cutover.md` and prepare a backup of the old
  ai-trade Flux resources. Bootstrap changes the cluster's GitOps control
  plane; verify you can roll back to the current ai-trade-managed state.
- Apply the node-pool labels on the control-plane node (see
  `clusters/homelab/node-labels.md`). The controller node-selector patch
  requires `homelab.englios.dev/node-pool=system`.

## Bootstrap Flux from homelab-k8s

Flux is bootstrapped using **this repository** (homelab-k8s) as the source
of truth for Flux infrastructure. The ai-trade workload repository is
referenced as a secondary GitRepository.

### 1. Verify cluster access

```bash
# Sanity check
kubectl cluster-info
kubectl get nodes
```

### 2. Bootstrap Flux

```bash
flux bootstrap github \
  --owner=Englios \
  --repository=homelab-k8s \
  --branch=master \
  --path=./clusters/homelab \
  --personal \
  --network-policy=false
```

What this does:
- Creates the `flux-system` namespace.
- Installs Flux CRDs and controllers.
- Creates a `GitRepository` named `flux-system` pointing to this repo.
- Creates a `Kustomization` named `flux-system` that reconciles `./clusters/homelab`.
- Commits the Flux manifests (`gotk-components.yaml`, `gotk-sync.yaml`) to this repo.
- The `Kustomization/flux-system` then reconciles the existing
  `clusters/homelab/aitrade-flux.yaml` and `clusters/homelab/vaultwarden.yaml`
  resources. They are both `suspend: true`, so they are created but do not
  reconcile deeper resources until resumed.

### 2a. Verify the root kustomization includes all resources

After bootstrap, the `clusters/homelab/` directory will contain generated
Flux manifests. Verify the root kustomization is complete:

```bash
# Dry-run the root. If this fails with an accumulating-resources error,
# inspect whether bootstrap generated a flux-system/ subdirectory and add it
# to clusters/homelab/kustomization.yaml.
kubectl kustomize clusters/homelab --load-restrictor LoadRestrictionsNone

# Check that either gotk-*.yaml files are listed (flat layout) or flux-system/
# is listed (subdirectory layout).
grep -E 'gotk-|flux-system' clusters/homelab/kustomization.yaml
```

Commit any bootstrap changes to `clusters/homelab/kustomization.yaml` before
proceeding.

### 3. Post-bootstrap verification

```bash
# Check Flux components are running
kubectl -n flux-system get pods

# Check the flux-system GitRepository is ready
kubectl -n flux-system get gitrepository flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Check the flux-system Kustomization is ready
kubectl -n flux-system get kustomization flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Verify the flux-system Kustomization watches the cluster identity root.
# Expected output: ./clusters/homelab
kubectl -n flux-system get kustomization flux-system -o jsonpath='{.spec.path}'
```

### 4. Verify the committed Flux manifests

After bootstrap completes, Flux will have committed generated Flux manifests
to the repo. Depending on Flux CLI version, they may be flat files under
`clusters/homelab/` or a `flux-system/` subdirectory. Verify the generated
files exist:

```bash
ls -la clusters/homelab/
# Should show generated Flux manifests either as gotk-*.yaml files or a
# flux-system/ directory.
```

### 5. Create the `sops-age` Secret

Before any encrypted secrets can be decrypted, the age private key must
be available in the cluster:

```bash
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=<path-to-age-private-key>
```

Verify:

```bash
kubectl -n flux-system get secret sops-age
```

### 6. (Optional) Verify SOPS decryption works

```bash
sops filestatus clusters/homelab/secrets/aitrade-auth.sops.yaml
```

If the metadata check succeeds, SOPS can read the file. Proceed to the cutover
runbook: `docs/runbooks/flux-cutover.md`.

## SOPS / Age Key Recovery

- **Primary store**: Vaultwarden (see homelab vault setup).
- **Break-glass backup**: Encrypted age key on an offline paper/USB backup.
  See `docs/howto/sops-secrets.md#backup-and-recovery`.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `flux bootstrap` fails with "no GitHub token" | Missing `GITHUB_TOKEN` env var | Set `export GITHUB_TOKEN=ghp_...` |
| GitRepository stuck at "unable to clone" | Missing or wrong deploy key | Verify `aitrade-auth` Secret exists and key is correct |
| Kustomization not reconciling | Suspended | `flux resume kustomization aitrade-flux` |
| SOPS decryption fails | Missing `sops-age` Secret | Check `kubectl -n flux-system get secret sops-age` |

## Next Steps

After bootstrap is complete and the `sops-age` Secret is created, follow
the staged cutover runbook: `docs/runbooks/flux-cutover.md`.
