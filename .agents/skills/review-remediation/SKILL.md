---
name: review-remediation
description: Convert review feedback into verified follow-up commits on the current pull-request branch.
version: 1.0.0
status: proposed
---

# Review Remediation

Use this skill whenever the user, a reviewer, or an automated review provides requested changes for an existing branch or pull request.

## Required behavior

Do not merely acknowledge, summarize, or reopen the same pull request. Treat review feedback as an implementation task.

## Workflow

1. Resolve the active repository, branch, and pull request.
2. Fetch the latest branch head and current `master`.
3. Collect all feedback supplied in chat and all GitHub review comments or threads.
4. Convert every actionable finding into a checklist with severity, affected file or contract, intended fix, and verification method.
5. Read the changed files and directly relevant contracts.
6. Apply the fixes on the existing PR branch unless the feedback explicitly requires a separate PR.
7. Update both `.agents/INDEX.md` and `.agents/repo-index.yaml` whenever a route, domain, skill, plan, or ownership rule changes.
8. Run `.agents/skills/flux-change-verification/SKILL.md` for any manifest change.
9. Compare the final branch against `master` and confirm no unrelated files changed.
10. Commit and push the remediation.
11. Update the PR title or body when the scope changed or the description is incomplete.
12. Report a resolution table mapping each review item to its commit, file, and verification result.

## Completion rule

Review remediation is incomplete until the branch head changes and every actionable item is fixed and verified, explicitly rejected with a technical reason, or marked blocked with the exact missing dependency.

A response such as “noted,” “understood,” “will fix,” or a repeated summary does not count as completion.

## Stop conditions

Stop and ask for human intervention only when the requested change conflicts with a higher-priority contract, credentials or permissions are insufficient, the branch cannot be safely updated without rewriting human-owned work, or two review items materially contradict each other.

Do not stop merely because the task spans several files.

## Required final report

```markdown
## Review remediation

| Finding | Resolution | Files | Verification |
|---|---|---|---|
| <finding> | Fixed / Rejected / Blocked | `<path>` | <check performed> |

Branch head: `<sha>`
Remaining blockers: none / <list>
```

If unresolved critical or important findings remain, do not claim the PR is ready to merge.
