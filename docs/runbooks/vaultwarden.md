# Vaultwarden Runbook

> **Status**: Planning / Not yet executed.
>
> Vaultwarden is deployed as a **suspended, single-replica, SQLite-backed**
> Deployment, accessible only via ClusterIP. There is no public Ingress.
> Access is through a Tailscale sidecar or in-cluster proxy that carries
> the label `app.kubernetes.io/part-of: vaultwarden-access`.

## Prerequisites

- [ ] Flux bootstrapped into the cluster from homelab-k8s.
- [ ] `sops-age` Secret exists in `flux-system`.
- [ ] `clusters/homelab/secrets/vaultwarden-secrets.sops.yaml` is encrypted
      and committed (see `docs/howto/sops-secrets.md`).
- [ ] The cluster has a default StorageClass that can provision a 10 GiB
      RWO volume.

## Bootstrap

### 0. Apply node labels to the control-plane node

```bash
NODE=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
kubectl label node "$NODE" homelab.englios.dev/node-pool=system --overwrite
kubectl label node "$NODE" homelab.englios.dev/node-pool=apps --overwrite
```

The Vaultwarden patch in `infrastructure/vaultwarden/patches/deployment-node-selector.yaml`
requires the `homelab.englios.dev/node-pool=system` label to be present, or the
pod will be unschedulable.

### 1. Prepare the encrypted secret

```bash
# Copy the example
cp clusters/homelab/secrets/vaultwarden-secrets.sops.yaml.example \
   clusters/homelab/secrets/vaultwarden-secrets.sops.yaml

# Edit with real values (see example file for instructions)
# At minimum, set ADMIN_TOKEN and DOMAIN (Tailscale URL).
vim clusters/homelab/secrets/vaultwarden-secrets.sops.yaml

# Encrypt with SOPS
sops --encrypt --in-place clusters/homelab/secrets/vaultwarden-secrets.sops.yaml

# Verify encryption metadata without printing secret values
sops filestatus clusters/homelab/secrets/vaultwarden-secrets.sops.yaml

# Commit
git add -A
git commit -m "feat(vaultwarden): add encrypted secrets"
git push origin master
```

### 2. Resume the Vaultwarden Flux Kustomization

```bash
flux resume kustomization vaultwarden
```

### 3. Verify resources

```bash
# Check namespace exists
kubectl get ns vaultwarden

# Check PVC is bound
kubectl -n vaultwarden get pvc vaultwarden-data

# Check pods
kubectl -n vaultwarden get pods

# Check service
kubectl -n vaultwarden get svc vaultwarden
```

### 4. Access Vaultwarden

Vaultwarden is not exposed via Ingress. Access it from within the cluster:

```bash
# From a pod in the same namespace with the vaultwarden-access label:
curl http://vaultwarden.vaultwarden.svc.cluster.local

# Or port-forward for testing:
kubectl -n vaultwarden port-forward svc/vaultwarden 8080:80
# Then visit http://localhost:8080
```

For production access, deploy a Tailscale sidecar or reverse proxy
(e.g., nginx) in the `vaultwarden` namespace with the label
`app.kubernetes.io/part-of: vaultwarden-access`.

### 5. First admin setup

1. Access Vaultwarden via port-forward (above).
2. Create the first admin account (by default, `SIGNUPS_ALLOWED=false`
   and `INVITATIONS_ALLOWED=false`, so you must use the admin panel).
3. Navigate to `/admin` and log in with the `ADMIN_TOKEN`.
4. From the admin panel, invite yourself (if `INVITATIONS_ALLOWED` was
   temporarily changed) or create the first user.

> **Security**: After creating the first user, keep `SIGNUPS_ALLOWED=false`
> and `INVITATIONS_ALLOWED=false` (the defaults). Use the admin panel to
> invite additional users as needed.

## Backup and Restore

### Local Backup (suspended CronJob)

The CronJob `vaultwarden-local-backup` copies `db.sqlite3` to
`/data/backups/db-<timestamp>.sqlite3` daily and prunes backups older
than 30 days. It is **suspended by default** and runs on the same PVC.

**Limitation**: This is NOT a real backup — it does not protect against
PVC corruption, node failure, or cluster loss. It only guards against
accidental data corruption.

### Manual backup

```bash
# Copy the SQLite database off-cluster
kubectl -n vaultwarden exec deploy/vaultwarden -- cat /data/db.sqlite3 > ~/vaultwarden-backup-$(date +%Y%m%d).sqlite3
```

### Restore from backup

```bash
# Scale down to ensure no writes
kubectl -n vaultwarden scale deploy vaultwarden --replicas=0

# Copy backup into the PVC
# (requires a temporary pod with the PVC mounted)

# Scale back up
kubectl -n vaultwarden scale deploy vaultwarden --replicas=1
```

### External backup (Phase 2)

An off-cluster backup (e.g., to S3-compatible storage or another node)
is planned but not yet implemented. The local CronJob is a placeholder.

## NetworkPolicy Details

The `networkpolicy.yaml` enforces:
- **Ingress**: Only pods with `app.kubernetes.io/part-of: vaultwarden-access`
  may connect to ports 80 and 3012.
- **Egress**:
  - DNS (UDP 53) to kube-dns pods.
  - HTTPS (TCP 443) to the internet (excluding RFC 1918 ranges) for
    icon fetches and SMTP.
  - Inter-pod traffic within the namespace for liveness/readiness probes.

## Important Notes

- **No public ingress**: Vaultwarden is ClusterIP-only. All access goes
  through Tailscale or a labeled proxy.
- **SQLite, not HA**: Single-replica with `Recreate` strategy. Expect
  brief downtime during upgrades.
- **Break-glass**: The Vaultwarden admin credentials are in the
  SOPS-encrypted secret. The age key to decrypt it is in Vaultwarden
  itself (circular dependency). Ensure you have an offline age key backup
  (paper/USB) before relying on Vaultwarden as the primary password store.
  See `docs/howto/sops-secrets.md#backup-and-recovery`.
