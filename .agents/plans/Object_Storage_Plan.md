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

- [x] Root credentials copied into Vaultwarden (Alif, 2026-11-03).
- [x] Onboard MEXT (2026-11-03): one bucket `mext` (versioning on) with the prefixes `state/` and `artifacts/`. Policies: `mext-hermes-rw` (`s3:*` on `mext`) and `mext-laptop-ro` (list with an `s3:prefix` condition, read `mext/artifacts/*`). Users `mext-hermes` and `mext-laptop`. Verified: Hermes reads and writes both prefixes; the laptop reads only `artifacts/`; neither can create buckets.
- [x] Tailnet reachability: `hermes-vm` and the laptop both reach `s3:9000`.

## Next

1. [ ] Copy the `mext-hermes` and `mext-laptop` keys into Vaultwarden. Working copies: `~/.config/mext-app/s3.env` (mode 600) on `hermes-vm` and on the laptop.
2. [ ] Offsite copy (see `Backup_Plan.md`). Done before any bucket holds data that exists nowhere else.
3. [ ] Monitoring: a health alert for RustFS and for volume usage.
4. [ ] Upgrades: move to a newer RustFS release once it has been out for about two weeks; read the release notes for breaking changes.

## Layout convention

One bucket per project, with a prefix per kind of data (`<project>/<purpose>/…`). Scope keys with prefix policies (`s3:prefix` condition on `ListBucket`, a resource ARN `<bucket>/<prefix>/*` for objects). Prefixes cost nothing in performance.

## Onboarding without the console

There is no `mc` on the hosts. The admin API takes plain JSON over SigV4, so `curl --aws-sigv4 "aws:amz:us-east-1:s3"` works:
`PUT /rustfs/admin/v3/add-canned-policy?name=<p>`, `PUT /rustfs/admin/v3/add-user?accessKey=<u>` with `{"secretKey":…,"status":"enabled"}`, and `POST /rustfs/admin/v3/idp/builtin/policy/attach` with `{"policies":[…],"user":…}`. Buckets: `aws s3api create-bucket` / `put-bucket-versioning`.

## Open questions

- Should future in-cluster workloads use S3 directly (label `app.kubernetes.io/part-of: object-storage-access`), or always go through the tailnet?
- Keycloak OIDC login for the console (RustFS supports OpenID). Only worth it once Keycloak is GitOps-managed.

## Consumers

| Project | Buckets | Users | Notes |
|---|---|---|---|
| MEXT planning (Hermes) | `mext` (`state/`, `artifacts/`) | `mext-hermes` (rw), `mext-laptop` (read `artifacts/`) | Litestream for SQLite plus rclone for generated notes; the plan lives in the MEXT repo |
