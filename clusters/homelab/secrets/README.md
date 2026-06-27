# clusters/homelab/secrets — Encrypted Secrets

This directory contains secrets encrypted with [SOPS](https://github.com/getsops/sops)
using age key encryption. Files ending in `.sops.yaml` are encrypted; see the
`.sops.yaml.example` file for the plain-text template.

## Files

| File | Purpose |
|------|---------|
| `aitrade-auth.sops.yaml` | SSH deploy key for the ai-trade GitRepository |
| `aitrade-auth.sops.yaml.example` | **Example only** — copy to `aitrade-auth.sops.yaml`, fill in real key, encrypt |
| `vaultwarden-secrets.sops.yaml` | ADMIN_TOKEN, DOMAIN, and optional SMTP config for Vaultwarden |
| `vaultwarden-secrets.sops.yaml.example` | **Example only** — copy to `vaultwarden-secrets.sops.yaml`, fill in real values, encrypt |
| `operator-oauth.sops.yaml` | OAuth client_id + client_secret for the Tailscale Kubernetes Operator |

## Usage

```bash
# 1. Copy the example
cp aitrade-auth.sops.yaml.example aitrade-auth.sops.yaml

# 2. Replace the placeholder deploy key with the real one
#    (generate one at GitHub: Settings → Developer settings → Fine-grained tokens,
#     or use an SSH deploy key)

# 3. Encrypt with SOPS (uses .sops.yaml rules)
sops --encrypt --in-place aitrade-auth.sops.yaml

# 4. Verify encryption metadata without printing secret values
sops filestatus aitrade-auth.sops.yaml
```

## Important

- **Never commit unencrypted secrets.** The `.gitignore` allows `*.sops.yaml`
  files through, but only encrypted ones should exist.
- **Never commit age private keys.** They are excluded by `.gitignore`.
- The age key used for encryption must be the same one deployed as the
  `sops-age` Secret in the `flux-system` namespace. See `docs/howto/sops-secrets.md`.
