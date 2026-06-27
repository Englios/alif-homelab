# Vaultwarden bootstrap deepwork state

## Goal

Take the suspended Vaultwarden scaffold in `infrastructure/vaultwarden/`
from "in repo, never reconciled" to "running and reachable over Tailscale
with a working backup" — without exposing it to the public internet, and
without re-introducing out-of-band secrets that live only on the homelab
node.

## Final user decisions (pending confirmation)

- Signups disabled, invitations disabled (`SIGNUPS_ALLOWED=false`,
  `INVITATIONS_ALLOWED=false`).
- Single replica with SQLite. No external DB.
- ClusterIP only. No Ingress. Tailscale sidecar / proxy for access.
- Image pinned to `vaultwarden/server:1.36.0-alpine` (current as of writing).
- Backup is two-phase: same-PVC CronJob (suspended, scaffolded) plus a
  future off-cluster target (S3 / NAS / SCP) — Phase 2.
- `ADMIN_TOKEN` and `DOMAIN` live only in
  `clusters/homelab/secrets/vaultwarden-secrets.sops.yaml` — never inline
  in the Deployment.
- `sops-age` Secret already exists in `flux-system` (verified 14h old,
  bootstrap done). Reuse the same Secret for the `vaultwarden`
  Kustomization's `decryption.secretRef`.

## Confirmed current state

- `infrastructure/vaultwarden/` is fully scaffolded:
  - `namespace.yaml`, `pvc.yaml` (10Gi RWO), `deployment.yaml` (single
    replica, envFrom Secret), `service.yaml` (ClusterIP 80 + 3012),
    `networkpolicy.yaml` (allow only pods with
    `app.kubernetes.io/part-of: vaultwarden-access`),
    `backup-cronjob.yaml` (suspended, same-PVC),
    `kustomization.yaml` (intentionally omits the encrypted Secret to keep
    repo kustomize green until the encrypted file exists),
    `patches/deployment-node-selector.yaml` (pods land on
    `homelab.englios.dev/node-pool: system`).
- `clusters/homelab/vaultwarden.yaml` is the thin Flux Kustomization
  (`suspend: true`, `path: ./infrastructure/vaultwarden`,
  `decryption: sops / sops-age`).
- `clusters/homelab/secrets/vaultwarden-secrets.sops.yaml.example` is the
  only existing secret template. Real encrypted file does **not** exist.
- `Secret/sops-age` exists in `flux-system` (14h old). Bootstrap complete.
- Cluster: no `vaultwarden` namespace, no Pods, no PVCs.
- Node labels on the Debian control-plane: status unknown from this
  session — must be verified before resume (see prerequisites).

## Prerequisites checklist (must be true before resuming)

- [ ] Debian control-plane node carries the label
      `homelab.englios.dev/node-pool=system`
      (see `clusters/homelab/node-labels.md`). Without this, the Deployment
      pod will fail to schedule and Flux will keep retrying.
- [ ] `.sops.yaml` at repo root contains the real age public key
      (placeholder replaced). Required so SOPS encryption actually
      succeeds on the new secret.
- [ ] The age private key on the homelab node matches the public key in
      `.sops.yaml`. Verify with:
      `sops --version` and `cat ~/.config/sops/age/keys.txt | grep pub`.
- [ ] `flux get kustomizations -A` shows `flux-system` and `aitrade-flux`
      as `Ready: True`. Bootstrap must be healthy before adding load.

## Execution plan

### Phase 1 — Generate the encrypted Secret (no cluster impact)

1. Copy the example to the live filename:
   `cp clusters/homelab/secrets/vaultwarden-secrets.sops.yaml.example \
      clusters/homelab/secrets/vaultwarden-secrets.sops.yaml`
2. Generate the real `ADMIN_TOKEN` (raw token, not the argon2 hash — simpler
   and the admin panel will accept either):
   `openssl rand -base64 48`
3. Base64-encode the value:
   `printf '%s' "<the-token>" | base64 -w0`
4. Set `DOMAIN` to the eventual Tailscale URL
   (e.g. `https://vaultwarden.tail-xyz.ts.net`), base64-encoded.
5. Encrypt in place:
   `sops --encrypt --in-place \
      clusters/homelab/secrets/vaultwarden-secrets.sops.yaml`
6. Verify without printing values:
   `sops filestatus clusters/homelab/secrets/vaultwarden-secrets.sops.yaml`
7. Wire it into the kustomization — replace the bottom TODO block in
   `infrastructure/vaultwarden/kustomization.yaml` by adding
   `- ../../clusters/homelab/secrets/vaultwarden-secrets.sops.yaml`
   to `resources`.
8. Repo validation:
   `kubectl kustomize infrastructure/vaultwarden \
      --load-restrictor LoadRestrictionsNone | head -40`
   Must show the `Secret/vaultwarden-secrets` resource with encrypted
   `data:` blocks (not the placeholders).

### Phase 2 — Bootstrap commit (no cluster change yet)

9. Commit Phase 1 changes. Message:
   `feat(vaultwarden): add encrypted secret and wire into kustomization`.
10. Push. Confirm `flux get kustomizations -A` is still `Ready: True` and
    the `vaultwarden` Kustomization remains `suspend: true` — no
    resources should land yet.

### Phase 3 — First reconciliation (still suspended)

11. Manually reconcile once to dry-run and surface CRD / schema issues:
    `flux reconcile kustomization vaultwarden --with-source`
12. Inspect: `kubectl describe kustomization vaultwarden -n flux-system`.
    Expect `Status: False` with `Reason: DependencyNotReady` or similar
    (because `suspend: true`).
13. If `kustomize-controller` reports a kustomize error in the events,
    fix the manifest. Repeat until clean.

### Phase 4 — Resume and verify

14. Resume the Kustomization:
    `flux resume kustomization vaultwarden`
15. Watch the first reconciliation:
    `flux logs --follow --tail=20 --name=kustomize-controller`
16. Verify resources land:
    - `kubectl get ns vaultwarden` → `Active`
    - `kubectl get pvc -n vaultwarden` → `Bound`
    - `kubectl get pods -n vaultwarden -l app.kubernetes.io/name=vaultwarden`
      → `Running` after ~30s
    - `kubectl logs deploy/vaultwarden -n vaultwarden | head -20`
      → no crash, `Rocket has launched` line
17. Smoke test from inside the cluster:
    `kubectl run -n vaultwarden --rm -it --restart=Never --image=curlimages/curl \
       -- curl -sf http://vaultwarden.vaultwarden.svc.cluster.local/alive`
    Expect HTTP 200. (Note: this `curl` pod needs the
    `app.kubernetes.io/part-of: vaultwarden-access` label or the
    NetworkPolicy will block it.)
18. From a Tailscale-attached device, hit `https://<DOMAIN>/alive` and
    confirm 200.
19. **Do not** create the first user account until signups are verified
    disabled. Test signup path first; it should return a clear "signups
    disabled" page.

### Phase 5 — Backups

20. Decide on the external backup target (S3 bucket, NAS via SSH, or
    SCP to another host). The same-PVC CronJob is intentionally
    insufficient — see Risks.
21. Implement and test a manual backup: `kubectl create job
    --from=cronjob/vaultwarden-local-backup -n vaultwarden manual-backup`
22. Resume the local CronJob only after the external target is wired in
    and verified.

## Open questions

- Tailscale exposure mechanism: sidecar on the Vaultwarden Pod, an
  in-cluster proxy, or Tailscale Kubernetes Operator? Pick one before
  Phase 4.
- `DOMAIN` for the SOPS Secret — must match the access mechanism chosen
  above. Tailscale MagicDNS, custom hostname, etc.
- Backup target: S3-compatible bucket? NAS at home? Off-site SCP? Affects
  whether Phase 5 needs a new Secret (`aws-credentials`, `nas-ssh-key`).
- Whether to enable SMTP now or defer. SMTP lives in the same Secret
  template, so it's reversible.

## Safety notes

- Do not commit the unencrypted Secret. `.gitignore` allows
  `*.sops.yaml` but not `.sops.yaml` without that suffix — the file
  must be encrypted on disk.
- Do not paste the real `ADMIN_TOKEN` into chat, logs, or PR
  descriptions.
- Do not skip the `kubectl kustomize` validation in Phase 1 — the whole
  bootstrap hinges on the encrypted file being picked up by the
  kustomization.
- The Vaultwarden `networkpolicy.yaml` blocks all ingress by default.
  Anything that needs to talk to Vaultwarden (Tailscale sidecar, the
  smoke-test `curl` pod) must carry
  `app.kubernetes.io/part-of: vaultwarden-access`.
- `Strategy: Recreate` on the Deployment means downtime on rolling
  updates. Acceptable for a single-replica SQLite workload; not
  accidental.

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Node missing `system` label | Pod unschedulable, Flux loops | Verify labels before resume; document in node-labels.md. |
| `.sops.yaml` placeholder age key | Encryption "succeeds" with a useless key; cluster decryption fails | Confirm `.sops.yaml` was updated post-bootstrap (the deepwork state file says this was already done — re-verify). |
| Encrypted Secret data field has wrong type (string vs base64) | Vaultwarden reads garbage env vars | The `data:` block (not `stringData:`) requires base64 — the example uses `data:`; the Deployment uses `envFrom.secretRef`, which expects base64. Don't change one without the other. |
| NetworkPolicy blocks the Tailscale sidecar | Vaultwarden reachable in cluster only, not from tailnet | Sidecar must carry `app.kubernetes.io/part-of: vaultwarden-access`. Document in the Tailscale mechanism chosen. |
| SQLite + Recreate strategy + node loss | Data loss | External backup (Phase 2 of backups) is non-optional for a real password store. |
| Local CronJob succeeds but external backup silently fails | Silent data loss | Phase 5 must include alerting or verification — at minimum a Slack/email ping from the backup job. |
| Vaultwarden becomes the SOPS age-key store | Circular dependency on rebuild | SOPS age key is primary; Vaultwarden is convenience. Offline paper/USB backup of age key remains required. |
| Tailscale DNS not yet configured when first resume happens | Web vault unreachable from tailnet | Smoke test (step 17) is in-cluster, not over tailnet — that is enough to know the Pod is healthy. Tailscale routing is a separate concern. |

## Files that will change

| File | Action | Phase |
|------|--------|-------|
| `clusters/homelab/secrets/vaultwarden-secrets.sops.yaml` | New (encrypted) | 1 |
| `infrastructure/vaultwarden/kustomization.yaml` | Uncomment / add the encrypted Secret to `resources` | 1 |
| `infrastructure/vaultwarden/networkpolicy.yaml` | Possibly add a named NetworkPolicy for the Tailscale sidecar | 1 or 4 |
| `docs/runbooks/vaultwarden.md` | Add actual cutover / rollback steps after the live run | 5 |
| `infrastructure/vaultwarden/README.md` | Update Status section (suspended → running) | 5 |
| `docs/plans/flux-move.md` (or a successor) | Reference this bootstrap in the agenda "Bring up Vaultwarden" item | 5 |

## What I will not do without explicit confirmation

- Run `sops --encrypt` against a real Secret (need the user's real
  `ADMIN_TOKEN` and `DOMAIN` to encrypt).
- Run `flux resume kustomization vaultwarden` against the live cluster.
- Run any `kubectl create` / `kubectl apply` against the cluster from
  this session.
- Commit any encrypted Secret with a public key (encryption must use the
  homelab age key).
- Touch `clusters/homelab/secrets/sops-age.sops.yaml` (age private key
  redaction risk).
