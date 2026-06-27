# Monitoring Stack Migration Plan — GitOps Adoption

## Summary

Bring the `kube-prometheus-stack` monitoring stack (Prometheus, Alertmanager,
Grafana, kube-state-metrics, prometheus-node-exporter, DCGM exporter, Flux
PodMonitor, ServiceMonitors) under Flux v2 GitOps management. The stack was
installed manually 118 days ago via `helm install` and has drifted from the
in-tree manifests in `infrastructure/monitoring/`.

This is the second step of a two-step plan. The first step (Flux PodMonitor
applied directly, see commit `8a967b8`) lights up the Grafana Flux dashboard
immediately. This second step makes the rest of the stack reproducible, drift-
detected, and CRD-upgrade-safe.

## Motivation

- **Single source of truth**: every cluster workload is already managed by Flux
  except monitoring. The monitoring stack is the largest unmanaged surface and
  the most likely to silently rot.
- **Reproducible recovery**: a fresh `k3s` install plus `flux bootstrap`
  should rebuild the entire cluster, including observability.
- **Drift detection**: `HelmRelease.spec.driftDetection.mode: enabled` will
  alert and revert any manual patches to the stack.
- **CRD upgrades**: `helm install` does not upgrade CRDs. `kube-prometheus-stack`
  ships a new `PodMonitor`/`PrometheusRule` CRD on most minor bumps; without
  Flux's `upgrade.crds: CreateReplace`, the chart's own `upgrade` Job fails.
- **Dashboards and recording rules under version control**: prevents click-ops
  drift inside the Grafana UI.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| HelmRelease vs raw manifests | `HelmRelease` | Matches the rest of the stack which is Helm-deployed; chart already manages CRDs, RBAC, defaults. |
| Chart repo | `prometheus-community` (`https://prometheus-community.github.io/helm-charts`) | Canonical source for `kube-prometheus-stack`. |
| Chart `releaseName` | `kube-prometheus-stack` | Match the existing release so helm-controller adopts in place (zero downtime). |
| Chart `version` | `"84.x"` range, pinned to current installed version | Range allows patches, holds majors for manual bump (see Risks). |
| Values source | `HelmRelease.spec.values` inline + SOPS-encrypted `adminPassword` | In-tree values keep the diff visible; SOPS handles the one secret. |
| Resource placement | `infrastructure/monitoring/controllers/` (HelmRelease, HelmRepository, Kustomization) + `infrastructure/monitoring/configs/` (PodMonitors, ServiceMonitors, PrometheusRule, dashboard ConfigMaps) | Two kustomizations; controllers first, configs after, via `dependsOn`. |
| Bootstrap order | Manual `kubectl apply` of `infrastructure/monitoring/controllers/` once, then `infrastructure/monitoring/configs/` | Avoids the chicken-and-egg of needing CRDs to land the PodMonitor. |
| Drift detection | `driftDetection.mode: enabled` on the HelmRelease | Reverts manual `kubectl edit` on rendered resources. |
| CRD handling | `install.crds: Create`, `upgrade.crds: CreateReplace` | Both required for safe upgrades. |
| DCGM exporter | Keep as a separate `Deployment` + `Service` + `ServiceMonitor`, managed by Flux via Kustomization | DCGM is a custom DaemonSet (not part of the chart); easier to manage as plain manifests. |
| Grafana dashboards | `ConfigMap` provider with `grafana_dashboard` label | Loads dashboard JSON from Git; survives stack upgrades. |
| Grafana admin password | SOPS-encrypted Secret referenced from `HelmRelease.spec.valuesFrom` | Already have `sops-age` Secret in `flux-system` (used by `aitrade-flux`). |
| Retention | 10d (current) | Matches current operator-rendered state. Bump later if storage allows. |
| Scrape interval | 30s | Matches current setting. |

## Architecture

```
homelab-k8s (master)
└── infrastructure/
    └── monitoring/
        ├── controllers/                 ← stage 1: applied manually once
        │   ├── helmrepository.yaml     ← prometheus-community repo
        │   ├── helmrelease.yaml         ← kube-prometheus-stack (adopts existing release)
        │   ├── dcgm-exporter.yaml       ← DaemonSet + Service (currently applied manually)
        │   └── kustomization.yaml
        ├── configs/                     ← stage 2: applied manually once, then managed by Flux
        │   ├── podmonitor-flux.yaml     ← already exists (commit 8a967b8)
        │   ├── servicemonitor-dcgm.yaml ← already exists, owned by monitoring/dcgm-exporter
        │   ├── prometheusrule-flux.yaml ← recording/alerting rules for Flux controllers
        │   ├── dashboards/
        │   │   ├── kustomization.yaml
        │   │   ├── flux-overview.json   ← ConfigMap with grafana_dashboard label
        │   │   ├── flux-controllers.json
        │   │   └── cluster-overview.json
        │   └── kustomization.yaml
        └── kustomization.yaml           ← top-level for the Flux Kustomization (dependsOn controllers → configs)
└── clusters/homelab/
    └── monitoring-flux.yaml             ← Flux Kustomization pointing at infrastructure/monitoring
```

## Migration Steps (Staged)

### Stage 0 — Already done
- [x] PodMonitor for Flux controllers applied directly to `monitoring` namespace
      (commit `8a967b8`). Dashboard is live.

### Stage 1 — Bring kube-prometheus-stack under Flux

1. **Snapshot current state**
   ```sh
   helm list -n monitoring
   helm get values kube-prometheus-stack -n monitoring > /tmp/kps-values.yaml
   kubectl get svc,deploy,sts,cm,secret -n monitoring -o yaml > /tmp/kps-snapshot.yaml
   ```
   Keep both files in a private location (not the repo) for rollback reference.

2. **Author `infrastructure/monitoring/controllers/helmrepository.yaml`**
   ```yaml
   apiVersion: source.toolkit.fluxcd.io/v1
   kind: HelmRepository
   metadata:
     name: prometheus-community
     namespace: flux-system
   spec:
     type: oci
     url: oci://ghcr.io/prometheus-community/charts
     interval: 24h
   ```

3. **SOPS-encrypt the Grafana admin password**
   ```sh
   kubectl create secret generic grafana-admin \
     --namespace monitoring \
     --from-literal=admin-password='<generated>' \
     --dry-run=client -o yaml > secrets/grafana-admin.yaml
   sops --encrypt --in-place secrets/grafana-admin.yaml
   ```
   Place at `clusters/homelab/secrets/grafana-admin.sops.yaml`. Reference via
   `HelmRelease.spec.valuesFrom`:
   ```yaml
   valuesFrom:
     - kind: Secret
       name: grafana-admin
       valuesKey: admin-password
       targetPath: grafana.adminPassword
   ```

4. **Author `infrastructure/monitoring/controllers/helmrelease.yaml`**
   ```yaml
   apiVersion: helm.toolkit.fluxcd.io/v2
   kind: HelmRelease
   metadata:
     name: kube-prometheus-stack
     namespace: monitoring
   spec:
     releaseName: kube-prometheus-stack      # must match existing release for adoption
     chart:
       spec:
         chart: kube-prometheus-stack
         version: "84.x"
         sourceRef:
           kind: HelmRepository
           name: prometheus-community
           namespace: flux-system
     interval: 30m
     valuesFrom:
       - kind: Secret
         name: grafana-admin
         valuesKey: admin-password
         targetPath: grafana.adminPassword
     values:
       grafana:
         adminUser: admin
         persistence:
           enabled: true
           size: 5Gi
       prometheus:
         prometheusSpec:
           retention: 10d
           retentionSize: 5GB
       # ... (mirrors existing kube-prometheus-stack-values.yaml)
     install:
       crds: Create
       createNamespace: true              # no-op on adoption, idempotent
     upgrade:
       crds: CreateReplace
       cleanupOnFail: false
     driftDetection:
       mode: enabled
       ignore:
         - paths: ["/spec/template/spec/containers/*/resources"]   # HPA may mutate
     rollback:
       cleanupOnFail: false
   ```

5. **Author `infrastructure/monitoring/controllers/kustomization.yaml`**
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - helmrepository.yaml
     - helmrelease.yaml
     - dcgm-exporter.yaml
   ```

6. **Apply once manually** (the bootstrap step — Flux CRDs already exist)
   ```sh
   kubectl apply -k infrastructure/monitoring/controllers/
   ```
   helm-controller will detect the existing release secret and adopt it.
   `flux get helmreleases -A` should show `Ready: True` within ~60s.

### Stage 2 — Wire Flux Kustomization for the configs layer

7. **Author `infrastructure/monitoring/configs/prometheusrule-flux.yaml`**
   Recording rules and alerts for Flux controller health (source-controller
   failures, kustomize-controller reconcile errors, etc). Modeled on the
   `fluxcd/flux2-monitoring-example` rules.

8. **Author `infrastructure/monitoring/configs/dashboards/*.json`**
   Drop in dashboard JSON from `fluxcd/flux2-monitoring-config`:
   - `flux-overview.json`
   - `flux-controllers.json`
   - `cluster-overview.json` (optional, useful as a general landing page)
   Wrap each in a `ConfigMap` with label `grafana_dashboard: "1"`.

9. **Author `infrastructure/monitoring/configs/kustomization.yaml`**
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   namespace: monitoring
   resources:
     - podmonitor-flux.yaml
     - servicemonitor-dcgm.yaml
     - prometheusrule-flux.yaml
     - dashboards/kustomization.yaml
   ```

10. **Apply once manually**
    ```sh
    kubectl apply -k infrastructure/monitoring/configs/
    ```

### Stage 3 — Flux-owned reconciliation

11. **Author `infrastructure/monitoring/kustomization.yaml`** (top-level, with
    `dependsOn` between controllers and configs):
    ```yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
      - path: controllers
      - path: configs
        dependsOn:
          - controllers
    ```

12. **Author `clusters/homelab/monitoring-flux.yaml`** (Flux Kustomization):
    ```yaml
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: monitoring
      namespace: flux-system
    spec:
      suspend: false
      interval: 30m
      path: ./infrastructure/monitoring
      prune: true
      wait: true
      timeout: 5m
      sourceRef:
        kind: GitRepository
        name: flux-system
      decryption:
        provider: sops
        secretRef:
          name: sops-age
    ```

13. **Wire into `clusters/homelab/kustomization.yaml`**:
    ```yaml
    resources:
      - flux-system
      - aitrade-flux.yaml
      - vaultwarden.yaml
      - monitoring-flux.yaml       # ← add
    ```

14. **Commit, push, observe.** `flux get kustomizations -A` should show
    `monitoring` reach `Ready: True`. Subsequent `git push`es will keep the
    stack reconciled.

### Stage 4 — Cleanup

15. **Delete the manual Helm release name conflict** (should be a no-op, but
    verify no stragglers in `monitoring` namespace that aren't in the repo).
16. **Remove the `kube-prometheus-stack-values.yaml` standalone file** from
    `infrastructure/monitoring/` — its content is now in `helmrelease.yaml`.

## Files Changed / Added

| File | Action |
|------|--------|
| `infrastructure/monitoring/podmonitor-flux.yaml` | Already added (commit `8a967b8`) |
| `infrastructure/monitoring/kustomization.yaml` | Already added (commit `8a967b8`) — will be replaced by the top-level one in Stage 3 |
| `infrastructure/monitoring/controllers/helmrepository.yaml` | New |
| `infrastructure/monitoring/controllers/helmrelease.yaml` | New |
| `infrastructure/monitoring/controllers/kustomization.yaml` | New |
| `infrastructure/monitoring/configs/prometheusrule-flux.yaml` | New |
| `infrastructure/monitoring/configs/dashboards/*.json` + `kustomization.yaml` | New |
| `infrastructure/monitoring/configs/kustomization.yaml` | New |
| `infrastructure/monitoring/kustomization.yaml` | Refactored to two-path with `dependsOn` |
| `infrastructure/monitoring/kube-prometheus-stack-values.yaml` | Deleted (content moved into `helmrelease.yaml`) |
| `clusters/homelab/secrets/grafana-admin.sops.yaml` | New (SOPS-encrypted) |
| `clusters/homelab/monitoring-flux.yaml` | New |
| `clusters/homelab/kustomization.yaml` | Updated (add `monitoring-flux.yaml` to `resources`) |
| `docs/README.md` | Updated (link to this plan) |

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| HelmRelease fails to adopt existing release | Stack goes down briefly | `releaseName` must match existing release; verify with `helm list -n monitoring` first. Have snapshot ready. |
| CRD upgrade breaks PodMonitor validation | PodMonitor rejected, dashboard goes dark | `upgrade.crds: CreateReplace`; run a dry-run with `helm template` before applying. |
| Major chart bump with immutable field changes | Reconciliation stuck | Pin `version` to current major; manually delete conflicting resource on bump (see `fluxcd/flux2#3304`). |
| DCGM exporter is a custom DaemonSet — chart doesn't manage it | Manifests drift | Keep `dcgm-exporter.yaml` + `servicemonitor-dcgm.yaml` in the `controllers/` kustomization; Flux owns them. |
| `dependsOn` not respected across kustomizations | Configs land before CRDs | Stage 2 uses manual `kubectl apply`; Stage 3 kustomization has explicit `dependsOn`. |
| Grafana admin password leak in Git | Unauthorized Grafana access | SOPS-encrypt the Secret; never inline the password in `helmrelease.yaml`. |
| HelmRepository unreachable at first reconcile | Stack stalls | Repo is public OCI (`oci://ghcr.io/prometheus-community/charts`); fallback is a manual `helm repo add`. |
| Stack drift from manual `kubectl edit` | Out-of-band changes stick | `driftDetection.mode: enabled` reverts; document for the team. |
| Long-running scrape gap during CRD upgrade | Dashboard shows stale data | Default scrape interval is 30s; gap is < 2 minutes in normal upgrades. |
| `image-automation.yaml` or other `clusters/homelab/aitrade/*` files reference monitoring | Coupled Kustomizations | Verify `flux get kustomizations -A` shows no `dependsOn` between `monitoring` and other workloads before proceeding. |

## Rollback

- Delete the Flux Kustomization: `kubectl delete kustomization monitoring -n flux-system`
- The HelmRelease is left in place — it can be released with
  `helm uninstall kube-prometheus-stack -n monitoring`
- Restore the manual install from `/tmp/kps-snapshot.yaml` if the migration
  has to be reverted before completion.
