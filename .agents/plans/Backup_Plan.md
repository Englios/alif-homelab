# Backup Plan

**Status:** active
**Owner:** Alif
**Last updated:** 2026-11-03

## Problem

All stateful services use `local-path` volumes on `debian`, and `hermes-vm` runs on the same machine. One disk or host failure loses everything. Nothing is copied off the machine today.

## Data to protect

| Data | Location | Priority |
|---|---|---|
| Vaultwarden DB and attachments | PVC `vaultwarden/vaultwarden-data` | Critical |
| RustFS buckets (MEXT state and artifacts, future projects) | PVC `object-storage/rustfs-data` | High |
| age private key | homelab host only | Critical; the break-glass copy must exist offline |
| Minecraft world | PVC in `minecraft` | Medium |
| hermes-vm disk | libvirt image on `debian` | Low once its state lives in S3 |

## Decisions made

- Vaultwarden's same-PVC CronJob is not a backup; it stays suspended until a real target exists.
- The age key's primary store is Vaultwarden, with an offline paper/USB break-glass copy (from `docs/plans/flux-move.md`).

## Next

1. [ ] Choose the offsite target. Options: Cloudflare R2, Google Drive, or the MacBook over Tailscale. Leaning: R2 with rclone `crypt`. Done when the choice is recorded here.
2. [ ] Back up the age key offline. Done when a paper or USB copy exists and has been test-decrypted once.
3. [ ] Back up Vaultwarden: a nightly CronJob that runs a SQLite `.backup` plus attachments and uploads to the offsite target, encrypted. Done when a restore into a scratch pod opens the vault.
4. [ ] Back up RustFS: a nightly `rclone sync` or `mc mirror` of every bucket to the offsite target, encrypted. Done when one bucket has been restored and verified by hash.
5. [ ] Monitoring: alert when the last successful backup is older than 48 h.
6. [ ] Write a restore runbook in `docs/runbooks/`. Done when the restore has been rehearsed end to end.

## Open questions

- Retention: how many daily and weekly copies to keep?
- Does the Minecraft world need to be included?
