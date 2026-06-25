# infrastructure/vaultwarden — Vaultwarden Password Manager

This directory contains the workload manifests for
[Vaultwarden](https://github.com/dani-garcia/vaultwarden), a self-hosted
Bitwarden-compatible password manager. It is managed by Flux via the thin
Kustomization at `clusters/homelab/vaultwarden.yaml`.

## Status

- **Suspended** — All resources have `suspend: true` or equivalent.
  Deployment must be manually staged.
- **No public ingress** — ClusterIP Service only. Access is via
  Tailscale (or another in-cluster proxy) only.
- **Single-replica** — SQLite backend; no HA. Data loss is possible on
  PVC/node failure. External backups are Phase 2.

## Resources

| File | Kind | Purpose |
|------|------|---------|
| `namespace.yaml` | Namespace | `vaultwarden` namespace |
| `pvc.yaml` | PersistentVolumeClaim | 10 GiB RWO for SQLite + attachments |
| `deployment.yaml` | Deployment | Single-replica Vaultwarden server |
| `service.yaml` | Service | ClusterIP on port 80 |
| `networkpolicy.yaml` | NetworkPolicy | Restrictive ingress/egress rules |
| `backup-cronjob.yaml` | CronJob | Local same-PVC DB backup (suspended) |
| `kustomization.yaml` | Kustomize | Resource inventory |

## Key Configurations

- **Image**: `vaultwarden/server:1.36.0-alpine` (pinned)
- **Signups**: Disabled by default (`SIGNUPS_ALLOWED=false`)
- **Invitations**: Disabled by default (`INVITATIONS_ALLOWED=false`)
- **WebSocket**: Enabled (`WEBSOCKET_ENABLED=true`)
- **Admin panel**: Protected by `ADMIN_TOKEN` (in SOPS secret)
- **Domain**: Tailscale URL (TODO, in SOPS secret)
- **Backend storage**: SQLite at `/data/db.sqlite3`

## Access

There is no Ingress. Access Vaultwarden from within the cluster at
`http://vaultwarden.vaultwarden.svc.cluster.local` or via a Tailscale
sidecar / in-cluster proxy labeled with
`app.kubernetes.io/part-of: vaultwarden-access` to pass the NetworkPolicy.

## Prerequisites

Before resuming the `vaultwarden` Flux Kustomization:
1. Flux must be bootstrapped into the cluster.
2. The `sops-age` Secret must exist in `flux-system`.
3. `clusters/homelab/secrets/vaultwarden-secrets.sops.yaml` must be generated
   (copy the example, fill in real values, encrypt with SOPS).
