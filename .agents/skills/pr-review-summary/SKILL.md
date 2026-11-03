---
name: pr-review-summary
description: Review a pull request or agent branch in alif-homelab and return a short, severity-ranked summary using red, yellow, and blue markers.
---

# PR Review Summary

Use this skill when reviewing a pull request, draft pull request, or agent branch before merge. Merging to `master` deploys to the cluster, so review as if approving a production change.

## Severity markers

- 🔴 **Critical** — blocks merge: plaintext secrets, broken SOPS decryption, public or LAN exposure, data loss (PVC deletion, `prune` removing state), Flux unable to reconcile, or workloads that can't schedule.
- 🟡 **Important** — fix before merge: unpinned images, missing node pinning for stateful services, NetworkPolicy gaps, missing ProxyClass, docs or index out of sync.
- 🔵 **Improvement** — optional: clarity, probes, resource tuning, comments.

## Review order

1. Read `AGENTS.md` and `.agents/INDEX.md`.
2. Identify the PR, or compare the branch against `master`.
3. Check changed paths against the domain boundaries (new services in `infrastructure/`, thin `clusters/homelab/`).
4. Check the hard-won rules in `.agents/INDEX.md`, especially no `namespace:` override next to a SOPS Secret.
5. Run `.agents/skills/flux-change-verification/SKILL.md` steps 1–4.
6. Check index synchronization when services, routes, plans or skills change.
7. Check CI, mergeability and whether the branch is behind `master`.
8. Classify findings by severity.

## Required output

```markdown
## Review summary

🔴 **Critical**
- <merge-blocking issue>

🟡 **Important**
- <issue that should be fixed before merge>

🔵 **Improvement**
- <optional refinement>

**Verdict:** Ready to merge / Fix before merge / Do not merge.
```

Omit empty severity sections.

## Rules

- Put the highest-risk finding first; explain impact, not only the symptom.
- Distinguish verified facts (dry run, build) from assumptions.
- The repo has no CI beyond CodeRabbit; a green check is not evidence the change works.
- Never merge unless the user explicitly requests it.
