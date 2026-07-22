# clusters/homelab/secrets — Encrypted Secrets

This directory contains secrets encrypted with [SOPS](https://github.com/getsops/sops)
using age key encryption. Files ending in `.sops.yaml` are encrypted; see the
`.sops.yaml.example` file for the plain-text template.

## Files

| File | Purpose |
|------|---------|
| `aitrade-auth.sops.yaml` | *(live file)* SSH deploy key for the ai-trade GitRepository (write-enabled); encrypted file lives at `../aitrade/aitrade-auth.sops.yaml` |
| `aitrade-auth.sops.yaml.example` | **Example only** — copy to `../aitrade/aitrade-auth.sops.yaml`, fill in real deploy-key values, encrypt |
| `vaultwarden-secrets.sops.yaml` | ADMIN_TOKEN, DOMAIN, and optional SMTP config for Vaultwarden |
| `vaultwarden-secrets.sops.yaml.example` | **Example only** — copy to `vaultwarden-secrets.sops.yaml`, fill in real values, encrypt |
| `operator-oauth.sops.yaml` | OAuth client_id + client_secret for the Tailscale Kubernetes Operator |

## Usage

```bash
# 1. Generate a deploy key pair outside the repo with restricted permissions
(umask 077; ssh-keygen -t ed25519 -C "flux-aitrade@englios" -f ~/.ssh/flux-aitrade)

# 2. Add the public key to GitHub:
#    https://github.com/Englios/ai-trade/settings/keys/new
#    Title: flux-aitrade-image-automation
#    Key:  contents of ~/.ssh/flux-aitrade.pub
#    ✓ Allow write access

# 3. Copy the example to the live location (run from repo root)
cp clusters/homelab/secrets/aitrade-auth.sops.yaml.example \
   clusters/homelab/aitrade/aitrade-auth.sops.yaml

# 4. Replace placeholders with real base64-encoded values (run from repo root):
#    base64 -w0 ~/.ssh/flux-aitrade
#    base64 -w0 ~/.ssh/flux-aitrade.pub
#    ssh-keyscan github.com 2>/dev/null | base64 -w0

# 5. Encrypt with SOPS (run from repo root)
sops --encrypt --in-place clusters/homelab/aitrade/aitrade-auth.sops.yaml

# 6. Verify encryption metadata without printing secret values
sops filestatus clusters/homelab/aitrade/aitrade-auth.sops.yaml
```

## Important

- **Never commit unencrypted secrets.** The `.gitignore` allows `*.sops.yaml`
  files through, but only encrypted ones should exist.
- **Never commit age private keys.** They are excluded by `.gitignore`.
- The age key used for encryption must be the same one deployed as the
  `sops-age` Secret in the `flux-system` namespace. See `docs/howto/sops-secrets.md`.
