# 🏗️ Architecture Evolution Strategy

## 📋 **Document Purpose**
This document outlines our planned evolution from simple app-level overlays to sophisticated environment-level management for the homelab-k8s monorepo.

## 🎯 **Overall Strategy: Start Simple → Refactor Smart**

### **Philosophy**
- **Start with working solutions** over perfect architecture
- **Learn from real pain points** before adding complexity  
- **Practice refactoring skills** on real systems
- **Document lessons learned** throughout evolution

---

## 🌱 **Phase 1: Simple App-Level Overlays**

### **Structure**
```
homelab-k8s/
├── apps/                    # Legacy/pre-GitOps manifests
│   ├── minecraft-server/
│   │   └── deployment/           # Existing manifests (base)
│   └── ...                        # Future apps should go to infrastructure/<name>/
├── clusters/
│   └── homelab/                  # Flux bootstrap root and cluster identity
│       ├── aitrade/               # ai-trade Flux integration resources
│       ├── secrets/               # SOPS-encrypted secrets
│       ├── aitrade-flux.yaml      # Flux Kustomization for ai-trade
│       ├── vaultwarden.yaml       # Flux Kustomization for vaultwarden
│       └── node-labels.md         # Node pool placement strategy
├── infrastructure/               # Native cluster service workload manifests (GitOps)
│   ├── vaultwarden/              # Vaultwarden password manager
│   ├── access/
│   ├── bore-server/
│   ├── gpu-feature-discovery/
│   ├── keycloak/
│   └── monitoring/
└── docs/
```

### **Characteristics**
- **apps/** is legacy/pre-GitOps — native services go to `infrastructure/<name>/`
- **`clusters/homelab/`** is the Flux bootstrap path, not an app environment
- **Simple to understand and implement**
- **Good for learning Kustomize basics**

### **Key Distinctions**
| Path | Purpose | GitOps? |
|------|---------|---------|
| `apps/` | Legacy/pre-GitOps manifests (manual `kubectl apply`) | No |
| `infrastructure/<name>/` | Native cluster service workload manifests | Yes (via Flux) |
| `clusters/homelab/<name>.yaml` | Thin Flux Kustomizations pointing to infrastructure/ | Yes |
| `clusters/homelab/aitrade/` | External-app Flux integration resources (manifests in own repo) | Yes |

---

## 🚀 **Phase 2: Environment-Level Management**

### **Target Structure**
```
homelab-k8s/
├── apps/                         # Legacy/pre-GitOps manifests
│   └── minecraft-server/
│       └── deployment/           # Base manifests only
├── clusters/
│   └── homelab/                  # Flux bootstrap + cluster identity
├── infrastructure/               # Native GitOps service manifests
│   ├── vaultwarden/
│   ├── monitoring/
│   └── ...
└── environments/                 # (Future) Environment-centric management
    ├── dev/
    ├── prod/
    └── test/
```

### **Characteristics**
- **Environment-first thinking**: Deploy entire environments together
- **Shared policies**: Common settings across all apps in environment
- **Operational simplicity**: Single command deploys everything
- **GitOps-friendly**: Each environment is atomic unit

> **Note (ai-trade Flux migration)**: The ai-trade Flux migration (see
> `docs/plans/flux-move.md`) starts building the GitOps substrate under
> `clusters/homelab/`. This runs ahead of Phase 2 — ai-trade gains Flux
> management while native homelab workloads (minecraft-server in `apps/`,
> etc.) remain manual `kubectl apply`. Once the model is proven, other
> workloads can be folded into Flux under `infrastructure/<name>/` with
> thin Flux Kustomizations in `clusters/homelab/`.

### **Deployment Commands**
```bash
# Deploy entire dev environment (all apps)
kubectl apply -k environments/dev

# Deploy entire prod environment
kubectl apply -k environments/prod

# Deploy just minecraft in dev (if needed)
kubectl apply -k environments/dev/minecraft
```

---

## 🔄 **Migration Strategy**

### **Migration Approach: Gradual**
1. **Keep Phase 1 working** while building Phase 2
2. **Migrate one environment at a time** (dev → test → prod)
3. **Run both systems in parallel** during transition
4. **Validate equivalency** before switching over

### **Migration Steps**
```bash
# Step 1: Create environments structure alongside existing
mkdir -p environments/{dev,prod,test}

# Step 2: Build environment-level configs
# (Reference same base manifests as app-level overlays)

# Step 3: Test equivalency
kubectl kustomize apps/minecraft-server/overlays/dev > old-dev.yaml
kubectl kustomize environments/dev/minecraft > new-dev.yaml
diff old-dev.yaml new-dev.yaml

# Step 4: Switch CI/CD to use new structure
# Update GitHub Actions to use environments/ instead of apps/*/overlays/

# Step 5: Remove old overlay structure
rm -rf apps/*/overlays/
```

### **Rollback Plan**
- **Keep both structures** until migration is validated
- **Git branches** for rollback capability
- **Documentation** of rollback procedures

---

## 📊 **Comparison Matrix**

| Aspect | Phase 1: App-Level | Phase 2: Environment-Level |
|--------|-------------------|---------------------------|
| **Learning Curve** | Low | Medium |
| **Complexity** | Simple | Moderate |
| **Scalability** | Limited | High |
| **Operational Overhead** | High (many commands) | Low (single command) |
| **Configuration Reuse** | Low | High |
| **GitOps Integration** | Moderate | Excellent |
| **Cross-App Dependencies** | Difficult | Easy |
| **Environment Consistency** | Manual | Automatic |

---

## 🎯 **Decision Triggers**

### **When to Refactor to Phase 2**
- [ ] **App Count**: When we have 3+ applications
- [ ] **Pain Points**: Deployment complexity becomes annoying
- [ ] **Shared Resources**: Need cross-app dependencies
- [ ] **Policy Enforcement**: Need environment-wide policies
- [ ] **GitOps**: Ready for sophisticated automation

### **Success Metrics**
- **Deployment Time**: Single command deploys full environment
- **Configuration Consistency**: All apps in environment have consistent policies
- **Operational Simplicity**: Non-technical users can deploy environments
- **Maintainability**: Easy to add new apps to existing environments

---

## 🧠 **Learning Objectives**

### **Phase 1 Skills**
- [ ] Kustomize overlay fundamentals
- [ ] Resource patching techniques
- [ ] Namespace isolation
- [ ] Basic CI/CD integration
- [ ] Debugging overlay issues
- [ ] Understanding cluster-identity vs environment layout

### **Phase 2 Skills**
- [ ] Complex Kustomize hierarchies
- [ ] Environment-wide policy management
- [ ] Cross-app dependency management
- [ ] GitOps application patterns
- [ ] Large-scale refactoring strategies

### **Migration Skills**
- [ ] Architecture migration planning
- [ ] Gradual system evolution
- [ ] Validation strategies
- [ ] Rollback procedures
- [ ] Documentation of architectural decisions

---

## 📚 **Reference Documentation**

### **Kustomize Patterns**
- [Kustomize Overlay Best Practices](https://kubectl.docs.kubernetes.io/guides/config_management/overlays/)
- [Multi-Environment Management](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/multibases.md)

### **GitOps Patterns**
- [ArgoCD Application Sets](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Flux Multi-Environment](https://fluxcd.io/flux/guides/repository-structure/)

### **Repo Structure**
- [Node Labels](../clusters/homelab/node-labels.md) — Node pool placement strategy (control-plane uses `system`)
- [Makefile.cluster](../Makefile.cluster) — SSH-proxied `make flux-*` targets for any device
- [Flux Move Plan](../plans/flux-move.md) — ai-trade Flux migration decision log

---

## 📝 **Implementation Timeline**

### **Phase 1: Foundation** (Week 1-2)
- [ ] Create app-level overlay structure
- [ ] Implement dev/prod/test overlays for minecraft
- [ ] Set up basic CI/CD pipeline
- [ ] Document pain points as they emerge

### **Phase 1.5: Scale Test** (Week 3-4)
- [ ] Add second application (web-portfolio or monitoring)
- [ ] Experience operational complexity
- [ ] Document specific pain points
- [ ] Evaluate readiness for Phase 2

### **Phase 2: Architecture Evolution** (Week 5-6)
- [ ] Design environment-level structure
- [ ] Implement migration strategy
- [ ] Gradual transition with validation
- [ ] Update CI/CD and documentation

---

**Last Updated**: $(date +%Y-%m-%d)
**Current Phase**: Phase 1 - Planning
**Next Review**: After implementing 2+ applications

---

## 💡 **Key Insights**

**Why Start Simple:**
- Builds foundational understanding without complexity
- Allows learning from real pain points vs theoretical ones
- Practices architectural evolution (essential DevOps skill)
- Clear separation: `apps/` (legacy), `infrastructure/<name>/` (GitOps), `clusters/homelab/` (Flux identity)

**Why Refactor Later:**
- Environment-level thinking emerges naturally from operational needs
- Complex patterns make more sense after experiencing simple ones
- Refactoring skills are critical for production systems

**The Journey is the Learning:**
- Experience both patterns deeply
- Understand trade-offs through practice
- Build confidence in architectural decision-making 

## Appendix: Layout Rationale

The repo uses three distinct "zones" for workload manifests:

| Zone | Path | How applied | Example |
|------|------|-------------|---------|
| Legacy | `apps/` | Manual `kubectl apply` | Minecraft server |
| Native GitOps | `infrastructure/<name>/` | Flux Kustomization from `clusters/homelab/<name>.yaml` | Vaultwarden |
| External GitOps | `clusters/homelab/<name>/` (Flux integration only) | Flux Kustomization, points to external repo | ai-trade |

This means:
- **apps/** will shrink over time as services migrate to `infrastructure/<name>/`
- **infrastructure/** contains the actual Kubernetes manifests for native services
- **clusters/homelab/** stays thin — just Flux bootstrap, thin Kustomizations, and SOPS secrets
