# Node Pool Placement Strategy

> **Status**: Labels are recommended for all clusters. The
> `nodeSelector` patches in this repo assume the labels documented
> below are present. Apply labels on the node(s) **before** resuming
> the `flux-system` and `vaultwarden` Kustomizations, or pods will
> fail to schedule.

## Recommended Labels

We use custom labels under the `homelab.englios.dev/` domain to classify
nodes into pools. This avoids relying on the node's hostname (which is
ephemeral and non-semantic in a homelab context) and keeps pool assignment
explicit.

| Label | Value | Purpose |
|-------|-------|---------|
| `homelab.englios.dev/node-pool` | `system` | Flux controllers, Vaultwarden, Keycloak, monitoring core |
| `homelab.englios.dev/node-pool` | `apps` | Normal services (Minecraft, web apps, etc.) |
| `homelab.englios.dev/node-pool` | `trading` | ai-trade isolation (future, when dedicated trading node exists) |
| `homelab.englios.dev/capability` | `gpu` | GPU-accelerated workloads |

## Why Custom Labels Instead of `kubernetes.io/hostname`

1. **Hostnames change**. If you rebuild the node with a different OS or
   rename it, the hostname label shifts. Pool labels are semantic and
   survive renames.
2. **Node count may grow**. A single-node cluster today may become two
   or three nodes. Labels let you target a *class* of node, not a specific
   name.
3. **`nodeSelector` and `affinity` rules are portable**. Manifests that
   say `homelab.englios.dev/node-pool: system` work identically on any
   node bearing that label, without hardcoding hostnames.
4. **Pool labels compose with other scheduling constraints**. You can
   combine `node-pool: system` with `capability: gpu` for workloads that
   need both system isolation and GPU access.

## Applying Labels on the Debian Control-Plane Node

```bash
# Discover the current node name
kubectl get nodes -o name

# Label the Debian control-plane node for both system and apps pool
# (single-node clusters need both). The `system` label is what
# `nodeSelector` patches in this repo match against.
NODE=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
kubectl label node "$NODE" homelab.englios.dev/node-pool=system --overwrite
kubectl label node "$NODE" homelab.englios.dev/node-pool=apps --overwrite

# If the node has a GPU
kubectl label node "$NODE" homelab.englios.dev/capability=gpu --overwrite
```

The Debian node carries both `system` and `apps` so the same node can host
control-plane and user services. When a dedicated trading node is added
later, it can receive the `trading` pool label and the system node can be
relabeled down to just `system`.

## What This Repo Pins to the `system` Pool

| Workload | File | Notes |
|----------|------|-------|
| Flux controllers (6) | `clusters/homelab/flux-system/patches/controller-node-selector.yaml` | Applies after bootstrap |
| Vaultwarden | `infrastructure/vaultwarden/patches/deployment-node-selector.yaml` | Applies via Kustomize patch |

> **Note**: ai-trade workload manifests in the ai-trade repo are not
> affected. They still pin to `kubernetes.io/hostname: debian` and are
> scheduled to migrate to `node-pool: trading` in a follow-up after the
> homelab cutover is complete.
