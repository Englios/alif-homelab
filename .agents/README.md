# Agent Workspace

This directory holds the token-efficient repository index, plans for future work, and reusable agent skills for the homelab k3s cluster.

It does not hold manifests or secrets.

## Start here

- `../AGENTS.md` — smallest cross-harness entry point
- `INDEX.md` — human-readable task router and context-budget guide
- `repo-index.yaml` — machine-readable routing and ownership map

## Structure

```text
.agents/
  README.md
  INDEX.md
  repo-index.yaml
  plans/
    Object_Storage_Plan.md
    Backup_Plan.md
    Hardware_Upgrade_Plan.md
    Homelab_Provisioning_Plan.md
  skills/
    flux-change-verification/SKILL.md
    sops-secret-edit/SKILL.md
    pr-review-summary/SKILL.md
    review-remediation/SKILL.md
```

## Boundary rules

- `.agents/` defines how automation navigates, plans and changes the repo.
- `docs/` is human-facing documentation (guides, how-tos, runbooks). Plans that are still being decided live in `.agents/plans/`; once executed, the operational result belongs in `docs/runbooks/` or the service README.
- `.slim/deepwork/` is historical working state from earlier agent sessions. Read only when history is needed.
- Secrets, age keys, kubeconfigs and decrypted files must never be committed here.

## Plan format

Each plan states its **status** (`active`, `kiv`, `done`), the decisions already made, open questions, and an ordered checklist with a "done when" for each step. Update the status and checklist in the same PR that does the work.

## Index maintenance

Keep `INDEX.md` and `repo-index.yaml` synchronized whenever services, task routes, plans, skills or ownership rules change.
