# Repository Index for Agents

Use this file as the token-efficient navigation layer. Read only the route required for the current task.

## Repository purpose

GitOps configuration for Alif's homelab k3s cluster: Flux-managed services, SOPS-encrypted secrets, Tailscale-only access, plus the legacy Minecraft stack and the headless Wake-on-LAN tooling.

## Cluster facts

| Item | Value |
|---|---|
| Nodes | `debian` (control plane, pool `system`, 100.96.172.63), `pop-os` (worker, pool `gpu`) |
| Also on `debian` | libvirt VM `hermes-vm` (Hermes agent for the MEXT project) |
| GitOps | Flux, `flux-system` GitRepository → this repo's `master` |
| Secrets | SOPS + age; Flux decrypts with Secret `flux-system/sops-age`; the age private key is only on the homelab host |
| Network | Tailscale operator (`tag:k8s`); tailnet `munchkin-komodo.ts.net`; HTTPS certs enabled |
| Storage | `local-path` only (node-local) |
| Access | `ssh homelab-debian-remote` (tailnet) then `kubectl` / `flux` on the node |

## Minimal startup context

Always begin with:

1. `AGENTS.md`
2. this index
3. exactly one task route below

Do not scan the repository recursively. Do not open `.slim/deepwork/` unless the task needs history.

## Task routing

| Task | Primary files | Optional files |
|---|---|---|
| Add a new native service | `clusters/homelab/README.md`, `infrastructure/object-storage/` (reference layout), `.agents/skills/flux-change-verification/SKILL.md` | `clusters/homelab/node-labels.md`, `docs/howto/tailscale-k3s-networking.md` |
| Shared S3 (RustFS) — onboarding, buckets, keys | `infrastructure/object-storage/README.md`, `.agents/plans/Object_Storage_Plan.md` | `clusters/homelab/object-storage.yaml` |
| Vaultwarden | `infrastructure/vaultwarden/README.md`, `docs/runbooks/vaultwarden.md` | `.agents/plans/Backup_Plan.md` |
| Create or edit a secret | `.agents/skills/sops-secret-edit/SKILL.md`, `clusters/homelab/secrets/README.md` | `docs/howto/sops-secrets.md`, `.sops.yaml` |
| Flux status, reconcile, debugging | `Makefile.cluster`, `docs/guides/flux-setup.md` | `clusters/homelab/kustomization.yaml` |
| Tailscale exposure | `infrastructure/tailscale-operator/proxyclass-system.yaml`, `infrastructure/vaultwarden/ingress.yaml` (HTTPS), `infrastructure/object-storage/service.yaml` (TCP) | `docs/howto/tailscale-k3s-networking.md` |
| ai-trade deployment | `clusters/homelab/aitrade/README.md`, `clusters/homelab/aitrade-flux.yaml` | `docs/plans/flux-move.md`, `docs/runbooks/flux-cutover.md` |
| Cluster access / RBAC / OIDC | `docs/guides/k8s-access-index.md` | `infrastructure/access/`, `infrastructure/keycloak/` |
| Monitoring | `infrastructure/monitoring/kustomization.yaml` | `.slim/deepwork/monitoring-migration.md` |
| Minecraft (legacy, manual) | `apps/minecraft-server/README.md` | `apps/minecraft-server/docs/` |
| Wake-on-LAN / gaming PC | `docs/guides/headless-wol-overview.md`, `scripts/wol-pc.sh` | `docs/guides/headless-wol-guide.md` |
| GPU worker | `scripts/setup-gpu-worker.sh`, `misc/runtime-nvidia.yaml` | `infrastructure/monitoring/dcgm-exporter.yaml` |
| Backups / disaster recovery | `.agents/plans/Backup_Plan.md` | service READMEs |
| Hardware upgrade or node migration | `.agents/plans/Hardware_Upgrade_Plan.md` | `.agents/plans/Backup_Plan.md` |
| Rebuild / tear up and down (Ansible) | `.agents/plans/Homelab_Provisioning_Plan.md` | `docs/guides/k3s-setup.md` |
| Review a PR or agent branch | `.agents/skills/pr-review-summary/SKILL.md` | changed files, `flux-change-verification` |
| Remediate review findings | `.agents/skills/review-remediation/SKILL.md` | existing PR, changed files |

## Domain boundaries

| Path | Meaning | Agent treatment |
|---|---|---|
| `clusters/homelab/` | Flux bootstrap root, thin Flux Kustomizations, external-app Flux resources, SOPS secrets | Keep thin; one `<name>.yaml` per service |
| `clusters/homelab/flux-system/` | Flux-generated bootstrap | Do not hand-edit except documented patches |
| `clusters/homelab/secrets/` | Encrypted secrets and `.example` templates | Encrypted only; use the SOPS skill |
| `infrastructure/<name>/` | Native GitOps service manifests | Primary place for new services |
| `apps/` | Legacy, manually applied manifests | Do not add new services here |
| `docs/` | Human guides, how-tos, runbooks, past plans | Update when behaviour changes |
| `scripts/`, `templates/`, `misc/` | Host tooling and templates | Read before changing host setup |
| `.agents/` | Index, plans, skills | Technical guidance |
| `.slim/deepwork/` | Historical agent working state | Skip by default |
| `GEMINI.md` | Gemini tutoring persona | Not repository rules |

## Hard-won rules

- **No kustomize `namespace:` override next to a SOPS Secret.** Kustomize rewrites `metadata.namespace` inside the encrypted file and breaks its MAC; Flux fails with "Could not decrypt value". This silently blocked Vaultwarden from June to November 2026.
- **Bitwarden clients need HTTPS.** Use a Tailscale `Ingress` (`ingressClassName: tailscale`) for HTTP apps; use the `tailscale.com/expose` Service annotation only for raw TCP (e.g. S3).
- **Tailscale proxies run on `debian`.** Label every exposed Service or Ingress `tailscale.com/proxy-class: system`. On `pop-os`, TCP proxies crash installing nftables rules, and the desktop sleeps.
- **NetworkPolicy namespace selectors are label selectors.** Use `kubernetes.io/metadata.name: <ns>`; there is no `matchNames`.
- **local-path volumes live on one node.** Pin stateful services to a node pool and mirror data out before any hardware change.
- **Merging is deploying.** Flux reconciles `master` automatically.

## Change rules

- Work on `agent/*` branches; open a PR; squash merge only.
- Pin image versions; prefer a release that is at least about two weeks old.
- Do not commit plaintext secrets, age keys, kubeconfigs or decrypted files.
- After merge, confirm the Flux Kustomization is Ready and the workload is healthy.

## Current plans

- `.agents/plans/Object_Storage_Plan.md` — active
- `.agents/plans/Backup_Plan.md` — active
- `.agents/plans/Hardware_Upgrade_Plan.md` — active (hardware being researched)
- `.agents/plans/Homelab_Provisioning_Plan.md` — kiv

## Current skills

- `.agents/skills/flux-change-verification/SKILL.md`
- `.agents/skills/sops-secret-edit/SKILL.md`
- `.agents/skills/pr-review-summary/SKILL.md`
- `.agents/skills/review-remediation/SKILL.md`

## Index maintenance

Update both this file and `.agents/repo-index.yaml` when a service, task route, plan, skill, or ownership rule is added or changes.
