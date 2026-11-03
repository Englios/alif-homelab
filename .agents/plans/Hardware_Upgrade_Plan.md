# Hardware Upgrade Plan

**Status:** active (hardware being researched by Alif)
**Owner:** Alif
**Last updated:** 2026-11-03

## Current hardware (debian)

- x86_64, 8 cores, 15 GiB RAM (about 3 GiB free on 2026-11-03), 914 GB disk (660 GB free).
- Runs the k3s control plane, every `system`-pool workload and the libvirt VM `hermes-vm`.
- `pop-os` is a GPU desktop worker; do not plan always-on services on it.

## Constraints for the new machine

- RAM is the current bottleneck: k3s, hermes-vm, monitoring and future services.
- Storage is `local-path`. Data moves only by copying it; nothing replicates.
- Tailscale identities (`debian`, `s3`, `vaultwarden`, `hermes-vm`) should keep their names so clients don't change.

## Migration checklist (draft)

1. [ ] Finish `Backup_Plan.md` steps 2–4 first. Done when there are offsite copies of Vaultwarden, the RustFS buckets and the age key.
2. [ ] Decide: replace `debian` in place, or add the new machine as a node and move the `system` pool onto it.
3. [ ] Inventory every PVC (`kubectl get pvc -A`) and decide for each: migrate or recreate.
4. [ ] Freeze writers: suspend the Hermes cron, scale the stateful Deployments to 0.
5. [ ] Copy the data: `mc mirror` the buckets; copy the Vaultwarden PVC; move the hermes-vm disk image.
6. [ ] Bring the services up on the new node (node-pool labels, ProxyClass `system`) and verify each endpoint.
7. [ ] Run a restore check, then unfreeze.

## Open questions

- Single node or multi-node? Multi-node would allow replicated storage (Longhorn) and a RustFS cluster later.
- Keep the `debian` hostname?

Related: `Homelab_Provisioning_Plan.md` (Ansible would make step 6 repeatable).
