# Homelab Provisioning Plan (Ansible)

**Status:** kiv (keep in view; not started)
**Owner:** Alif
**Last updated:** 2026-11-03

## Goal

Tear the homelab host up and down repeatably: OS packages, Tailscale, k3s, node labels, libvirt and hermes-vm, Flux bootstrap and the sops-age Secret.

## Decisions made

- **Ansible, not Terraform.** This is a bare-metal host with no cloud API, so Terraform has nothing to manage.
- Flux remains the source of truth for in-cluster state. Ansible stops at "cluster bootstrapped and Flux pointed at this repo".

## Proposed scope (draft)

| Role | Covers |
|---|---|
| `base` | packages, users, SSH hardening, sysctl (`net.ipv6.conf.all.forwarding`) |
| `tailscale` | install, join with an auth key from Vaultwarden, tags |
| `k3s_server` / `k3s_agent` | install a pinned version, `tls-san` with the Tailscale IP, node-pool labels |
| `gpu_worker` | replaces `scripts/setup-gpu-worker.sh` |
| `libvirt_hermes` | libvirt, the hermes-vm definition, disk restore |
| `flux_bootstrap` | flux CLI, bootstrap, `sops-age` Secret from the offline key |
| `teardown` | reverse order, with data export first |

## When to start

Before or during the hardware upgrade (see `Hardware_Upgrade_Plan.md`), so that the new machine is the first one built from it.

## Open questions

- Where do inventory secrets live (Ansible Vault or Vaultwarden lookups)?
- Is `pop-os` managed too, or only `debian`?
