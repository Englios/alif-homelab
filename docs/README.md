# 📚 Homelab Documentation

Entry point for homelab-k8s documentation.

---

## 🗂️ Structure

```
docs/
├── guides/       # Step-by-step tutorials
├── howto/        # Technical reference
├── plans/        # Internal planning
└── runbooks/     # Staged operations
```

---

## 🚀 Quick Links

### Guides
| Guide | Description |
|-------|-------------|
| [Headless WOL Overview](./guides/headless-wol-overview.md) | Remote boot gaming PC |
| [Headless WOL Guide](./guides/headless-wol-guide.md) | Full setup tutorial |
| [k3s Setup](./guides/k3s-setup.md) | Cluster configuration |
| [Kubernetes Access Index](./guides/k8s-access-index.md) | Entry point for access documentation |
| [Kubernetes Access Overview](./guides/k8s-access-overview.md) | Current access model and repo files |
| [Kubernetes Human Access](./guides/k8s-human-access.md) | How human users should access the cluster |
| [Kubernetes Bot Access](./guides/k8s-bot-access.md) | Bot RBAC and machine identity access |
| [Kubernetes Bot OIDC with Keycloak over Tailscale](./guides/k8s-bot-oidc-keycloak.md) | Shared internal OIDC for the always-on VM bot |
| [Flux Setup](./guides/flux-setup.md) | Bootstrap Flux and configure SOPS |
| [Node Labels](../clusters/homelab/node-labels.md) | Node pool placement strategy (control-plane uses `system`) |
| [Makefile.cluster](../Makefile.cluster) | SSH-proxied `make flux-*` targets for any device |

### Howto
| Doc | Description |
|-----|-------------|
| [Tailscale + k3s](./howto/tailscale-k3s-networking.md) | VPN + cluster networking |
| [Architecture Strategy](./howto/architecture-evolution-strategy.md) | Repo structure evolution |
| [SOPS Secrets](./howto/sops-secrets.md) | Encrypted secret management with age |

### Plans
| Doc | Description |
|-----|-------------|
| [Headless WOL Runbook](./plans/headless-wol-runbook.md) | Implementation details |
| [Minecraft Roadmap](./plans/minecraft-roadmap.md) | Server feature roadmap |
| [Flux Move Plan](./plans/flux-move.md) | ai-trade Flux migration decision log |

### Runbooks
| Doc | Description |
|-----|-------------|
| [Flux Cutover](./runbooks/flux-cutover.md) | Staged ai-trade cutover and rollback |
| [Vaultwarden](./runbooks/vaultwarden.md) | Password manager bootstrap and ops |

---

**New to Flux?** Start with the [Flux Setup](./guides/flux-setup.md) guide.

---

## 💡 Start Here

New to homelab? → [Headless WOL Overview](./guides/headless-wol-overview.md)
