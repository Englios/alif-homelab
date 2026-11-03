---
name: sops-secret-edit
description: Create or change a SOPS/age-encrypted Kubernetes Secret in alif-homelab without ever printing or committing plaintext.
---

# SOPS Secret Edit

Secrets live in `clusters/homelab/secrets/*.sops.yaml` and are encrypted to the age recipient in `.sops.yaml`. Flux decrypts them with `flux-system/sops-age`. The age **private** key exists only on the homelab host (`~/Codes/alif-homelab/age.key`, gitignored).

## Create a new secret (any machine; needs only the public key)

1. Write the plaintext file with `umask 077`, generating values with `openssl rand`. Never echo the values.
2. Encrypt in place from the repo root: `sops --encrypt --in-place clusters/homelab/secrets/<name>.sops.yaml`.
3. Confirm it is encrypted (`grep -c 'ENC\['`; values show `ENC[...]`).
4. Add a `<name>.sops.yaml.example` with placeholders.
5. Reference it from the service kustomization as `../../clusters/homelab/secrets/<name>.sops.yaml`. Do **not** add a `namespace:` override to that kustomization.

## Change an existing value (homelab host; needs the private key)

Work on a temporary copy, never on the homelab clone's tracked file:

```bash
ssh homelab-debian-remote 'cd ~/Codes/alif-homelab; T=$(mktemp -d); cp clusters/homelab/secrets/<f> $T/f;
  SOPS_AGE_KEY_FILE=age.key sops set $T/f "[\"data\"][\"KEY\"]" "\"<base64 value>\"";
  cat $T/f; rm -rf $T' > <f>   # captures the encrypted file only
```

- Files using `data:` need base64 values; files using `stringData:` take plain values.
- Verify the round trip: copy the new file to the host and run `sops -d … > /dev/null`.

## Inspect without revealing

To check a value's shape (scheme, placeholder or not), decrypt on the host and pipe it through a small script that prints only derived facts. Never print secret values into logs, PRs or chat.

## Never

- Commit `age.key`, `*.dec.yaml` or decrypted output.
- Paste secret values into PR bodies, commit messages or plans.
- Re-encrypt a file to a different recipient without updating `.sops.yaml` and the cluster's `sops-age` Secret.
