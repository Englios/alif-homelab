---
name: flux-change-verification
description: Verify a Kustomize/Flux manifest change before opening a PR and confirm it after merge. Use for any change under clusters/ or infrastructure/.
---

# Flux Change Verification

The repo has no CI that builds manifests. Merging to `master` deploys. Run these checks yourself.

## Before the PR

1. **Build every touched kustomization** (the repo references secrets across directories):
   ```bash
   kubectl kustomize --load-restrictor LoadRestrictionsNone infrastructure/<name>
   kubectl kustomize --load-restrictor LoadRestrictionsNone clusters/homelab
   ```
2. **Check encrypted Secrets come through unchanged.** In the build output, the document containing `sops:` must not have gained a plaintext `namespace:` or any other field. If it has, there is a kustomize `namespace:` override or a patch touching it; remove it.
3. **Server-side dry run** on the cluster, with the encrypted Secret filtered out:
   ```bash
   scp build-without-secret.yaml homelab-debian-remote:/tmp/x.yaml
   ssh homelab-debian-remote 'kubectl apply --dry-run=server -f /tmp/x.yaml; rm /tmp/x.yaml'
   ```
   "namespace not found" is expected for a new namespace; anything else is a real error.
4. **Placement and exposure**:
   - Stateful workloads have a node-pool `nodeSelector`.
   - Tailscale-exposed Services and Ingresses carry `tailscale.com/proxy-class: system`.
   - HTTP apps use a Tailscale `Ingress` (HTTPS); raw TCP uses Service expose.
   - NetworkPolicies allow the `tailscale` namespace via `kubernetes.io/metadata.name`.
5. **Images are pinned** to an exact tag.

## After merge

```bash
ssh homelab-debian-remote 'flux reconcile source git flux-system -n flux-system; flux reconcile kustomization <name> -n flux-system'
ssh homelab-debian-remote 'kubectl get kustomization -n flux-system <name>; kubectl -n <ns> get pods'
ssh homelab-debian-remote 'kubectl -n tailscale get pods -o wide'   # proxies Running on debian
curl -s -o /dev/null -w "%{http_code}\n" <tailnet endpoint>
```

The change is verified only when the Kustomization is Ready, the pods are Running without restarts, the Tailscale proxies run on `debian`, and the endpoint answers from a tailnet device. Report any step you could not run.
