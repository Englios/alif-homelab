# infrastructure/object-storage — Shared S3 (RustFS)

Shared S3-compatible object storage for homelab projects, managed by Flux via
`clusters/homelab/object-storage.yaml`.

## Status

- **RustFS 1.0.3**, single replica, single 100 GiB local-path volume on the
  `system` node (debian).
- **Tailscale only.** The operator exposes the Service as the tailnet device
  `s3`. No Ingress, no LAN NodePort.
- **No offsite copy yet.** The volume lives on the same machine as the
  workloads that use it. Add an offsite backup before storing anything that
  exists nowhere else.

## Endpoints

| Use | URL |
|---|---|
| S3 API | `http://s3.munchkin-komodo.ts.net:9000` |
| Console | `http://s3.munchkin-komodo.ts.net:9001/rustfs/console/` |

Use path-style addressing and any region string (e.g. `us-east-1`).

## Root credentials

Stored in the SOPS-encrypted `clusters/homelab/secrets/object-storage-secrets.sops.yaml`
(Secret `rustfs-root`). Read them on the cluster with:

```bash
kubectl -n object-storage get secret rustfs-root -o jsonpath='{.data.RUSTFS_ACCESS_KEY}' | base64 -d; echo
kubectl -n object-storage get secret rustfs-root -o jsonpath='{.data.RUSTFS_SECRET_KEY}' | base64 -d; echo
```

Use root only for the console and for onboarding projects. Store the copy you
use in Vaultwarden once it is running.

## Onboarding a project

Each project gets one bucket (a prefix per kind of data) and one user with full access to that bucket only. Never hand out root keys.

```bash
mc alias set homelab http://s3.munchkin-komodo.ts.net:9000 <root-access> <root-secret>
mc mb homelab/<project>
mc version enable homelab/<project>   # keep old object versions
mc admin user add homelab <project> <generated-secret>
mc admin policy create homelab <project>-rw policy.json
mc admin policy attach homelab <project>-rw --user <project>
```

`policy.json` (full access to the project's bucket only):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:*"],
    "Resource": ["arn:aws:s3:::<project>", "arn:aws:s3:::<project>/*"]
  }]
}
```

Record each project's keys in Vaultwarden.

### Current projects

| Project | Buckets | Users |
|---|---|---|
| MEXT planning (Hermes) | `mext` (`state/`, `artifacts/`) | `mext` (rw) |

## Notes

- Do not add a `namespace:` override to `kustomization.yaml`: kustomize would
  rewrite `metadata.namespace` inside the SOPS-encrypted Secret and break its
  MAC, so Flux fails with "Could not decrypt value".
- Hardware move: the data is a local-path volume under
  `/var/lib/rancher/k3s/storage/` on the debian node. Before migrating, mirror
  every bucket out (`mc mirror`) and verify, then mirror back after.
