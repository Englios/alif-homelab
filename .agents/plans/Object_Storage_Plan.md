# Object Storage Plan

**Status:** active
**Owner:** Alif
**Last updated:** 2026-11-03

## Goal

One shared, S3-compatible store on the homelab that any project can use with its own buckets and keys, reachable only over Tailscale.

## Decisions made

| Decision | Choice | Why |
|---|---|---|
| Software | RustFS (`rustfs/rustfs:1.0.3`) | Easy to use (web console, MinIO/AWS tooling, IAM-style policies, versioning) and reusable for other projects. Garage was the conservative alternative. |
| Deployment | k3s manifests under `infrastructure/object-storage/`, Flux-managed | Same pattern as other native services |
| Exposure | Tailscale operator, Service expose, device `s3`, ProxyClass `system` | No LAN or public exposure; WireGuard encryption |
| Storage | One 100 GiB `local-path` volume on `debian` | Single node today |
| Root credentials | SOPS Secret `rustfs-root`; used only for the console and onboarding | Each project gets its own user |

## Done

- [x] Deploy RustFS (#14). Done when the Flux Kustomization is Ready and the pod runs.
- [x] Pin Tailscale proxies to `debian` (#16). Done when `s3` `/health` returns 200 over the tailnet (verified 2026-11-03).

## Next

1. [ ] Copy the root credentials into Vaultwarden. Done when the entry exists.
2. [ ] Onboard MEXT. Create the buckets `mext-state` and `mext-artifacts` (versioning on), the users `mext-hermes` (rw on both) and `mext-laptop` (read `mext-artifacts`), and store their keys in Vaultwarden. Done when each key can list only its own buckets.
3. [ ] Tailnet ACL check. Done when `hermes-vm` and the laptop reach `s3:9000`, and nothing that needs no access can.
4. [ ] Offsite copy (see `Backup_Plan.md`). Done before any bucket holds data that exists nowhere else.
5. [ ] Monitoring: a health alert for RustFS and for volume usage.
6. [ ] Upgrades: move to a newer RustFS release once it has been out for about two weeks; read the release notes for breaking changes.

## Open questions

- Should future in-cluster workloads use S3 directly (label `app.kubernetes.io/part-of: object-storage-access`), or always go through the tailnet?
- Keycloak OIDC login for the console (RustFS supports OpenID). Only worth it once Keycloak is GitOps-managed.

## Consumers

| Project | Buckets | Users | Notes |
|---|---|---|---|
| MEXT planning (Hermes) | `mext-state`, `mext-artifacts` | `mext-hermes`, `mext-laptop` | Litestream for SQLite plus rclone for generated notes; the plan lives in the MEXT repo |
