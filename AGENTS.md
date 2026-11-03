# Agent Entry Point

Read `.agents/INDEX.md` before exploring the repository.

## Default rules

1. Start with the smallest relevant context listed in `.agents/INDEX.md`.
2. Treat `master` as live: Flux applies it to the cluster within minutes of a merge.
3. New native services go in `infrastructure/<name>/` with a thin Flux Kustomization at `clusters/homelab/<name>.yaml`. `apps/` is legacy.
4. Never commit plaintext secrets. Secrets are SOPS/age-encrypted under `clusters/homelab/secrets/`; follow `.agents/skills/sops-secret-edit/SKILL.md`.
5. Never add a kustomize `namespace:` override to a kustomization that includes a SOPS-encrypted Secret.
6. Verify every manifest change with `.agents/skills/flux-change-verification/SKILL.md` before opening a PR.
7. Make changes on an `agent/*` branch through a pull request. The repo allows squash merges only.
8. Track future work in `.agents/plans/`, not in chat.
9. When review feedback is provided for an existing branch or PR, read `.agents/skills/review-remediation/SKILL.md` and implement the requested changes. Acknowledgement or summarization alone is not completion.

`GEMINI.md` is a tutoring persona for Gemini, not repository rules.

For machine-readable routing, use `.agents/repo-index.yaml`.
