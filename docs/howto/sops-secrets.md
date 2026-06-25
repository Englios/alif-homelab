# SOPS / Age Secrets Management

This guide covers how to manage encrypted secrets using
[SOPS](https://github.com/getsops/sops) with
[age](https://github.com/FiloSottile/age) encryption for this repository.

## Overview

Secrets in `clusters/homelab/secrets/` are encrypted with SOPS using an age
key pair. Flux decrypts them at reconciliation time using the `sops-age`
Secret in the `flux-system` namespace.

The `.sops.yaml` at the repo root configures which encryption key to use
for which file paths.

## Age Key Generation

### 1. Generate a key pair

```bash
# Generate a new age key (writes to age.key in the current directory)
age-keygen -o age.key

# Display the public key
age-keygen -y age.key
# Example output: age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

### 2. Update `.sops.yaml`

Copy the public key into `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: clusters/homelab/secrets/.*\.sops\.yaml
    age: >-
      age1abc123def456ghi789jkl012mno345pqr678stu901vwx234yz
```

### 3. Back up the private key

See [Backup and Recovery](#backup-and-recovery) below.

### 4. (Optional) Add additional recipients

You can add multiple age public keys to allow decryption by multiple
parties:

```yaml
creation_rules:
  - path_regex: clusters/homelab/secrets/.*\.sops\.yaml
    age: >-
      age1abc123..., age1def456...
```

Use `sops --updatekeys` to re-encrypt existing files with the new
recipients (see below).

## Encrypting Secrets

### Encrypt a new secret

```bash
# Copy the example template
cp clusters/homelab/secrets/aitrade-auth.sops.yaml.example \
   clusters/homelab/secrets/aitrade-auth.sops.yaml

# Edit the file with real values (plain text)
vim clusters/homelab/secrets/aitrade-auth.sops.yaml

# Encrypt in-place
sops --encrypt --in-place clusters/homelab/secrets/aitrade-auth.sops.yaml

# Commit the encrypted file
git add clusters/homelab/secrets/aitrade-auth.sops.yaml
git commit -m "chore(secrets): add aitrade-auth deploy key"
```

### Encrypt an existing plain file

```bash
sops --encrypt --in-place clusters/homelab/secrets/<file>.yaml
```

## Decrypting Secrets

### View a decrypted secret (stdout)

```bash
sops --decrypt clusters/homelab/secrets/aitrade-auth.sops.yaml
```

### Decrypt to a temporary file (AVOID — use stdout instead)

If you must write to disk, use a temp file and shred it immediately:

```bash
tmpfile=$(mktemp /tmp/sops-decrypt-XXXXXXXXXX)
sops --decrypt clusters/homelab/secrets/aitrade-auth.sops.yaml > "$tmpfile"
# ... use the file ...
shred -u "$tmpfile"
```

## Updating Keys / Recipients

If you add or remove age recipients in `.sops.yaml`, re-encrypt all
affected files:

```bash
sops updatekeys --yes clusters/homelab/secrets/aitrade-auth.sops.yaml
```

This re-encrypts the file with the current set of recipients from
`.sops.yaml` without needing the plaintext.

## Deploying the Age Key to the Cluster

Flux needs the age private key to decrypt secrets at reconciliation time.
Create the `sops-age` Secret:

```bash
kubectl -n flux-system create secret generic sops-age \
  --from-file=age.agekey=<path-to-age-private-key>
```

Verify that the Kubernetes Secret exists without printing the private key:

```bash
kubectl -n flux-system get secret sops-age -o jsonpath='{.metadata.name}{"\n"}'
```

> **Security**: The age private key in the cluster is a runtime secret.
> It should be rotated periodically and after any personnel changes.

## Printing Secrets to Paper (Break-Glass Backup)

> ⚠️ **No K8s Job for secret printing.** The following procedure uses
> SSH and `lp` directly.

```bash
# On a trusted machine with access to the age key and a printer:
#
# 1. Decrypt the secret to a temp file
tmpfile=$(mktemp /tmp/sops-print-XXXXXXXXXX)
sops --decrypt clusters/homelab/secrets/aitrade-auth.sops.yaml > "$tmpfile"

# 2. Print to local or network printer
lp -d <printer-name> "$tmpfile"

# 3. Shred the temp file immediately
shred -u "$tmpfile"

# 4. Store the printout in a sealed envelope in a secure location
#    (e.g., fireproof safe, safety deposit box).
```

For the age private key itself:

```bash
# Print the age key on the homelab node without storing it in Kubernetes.
# The temp file is created with restrictive permissions, printed, then shredded.
ssh debian 'umask 077; tmp=$(mktemp); cat > "$tmp"; lp -d <printer-name> "$tmp"; shred -u "$tmp"' < age.key
```

## Backup and Recovery

### Immediate (Primary) Store: Vaultwarden

The age private key should be stored in Vaultwarden as a secure note.

### Offline Break-Glass Backup

Two hardened offline backups should exist:

1. **Paper backup**: The age private key printed to paper (see above).
   Store in a fireproof safe.
2. **USB backup**: Encrypted age key on a USB drive stored in a
   separate physical location.
   ```bash
   # Encrypt the key with a strong passphrase for USB storage
   gpg --symmetric --cipher-algo AES256 age.key
   # Store age.key.gpg on a USB drive
   ```

### Recovery Procedure

If the `sops-age` Secret is lost and you need to re-create it:

1. Retrieve the age key from Vaultwarden, paper backup, or USB.
2. Re-create the Kubernetes Secret:
   ```bash
   kubectl -n flux-system delete secret sops-age
   kubectl -n flux-system create secret generic sops-age \
     --from-file=age.agekey=<path-to-recovered-age-key>
   ```
3. Flux will automatically re-reconcile and decrypt secrets.

## Important Warnings

- **Never commit unencrypted secrets.** The `.sops.yaml` and encrypted
  `*.sops.yaml` files are designed to keep secrets out of Git.
- **Never commit age private keys.** They are excluded by `.gitignore`
  patterns (`*.agekey`, `age.key`).
- **Never use a K8s Job to print secrets.** Use SSH + `lp` with temp-file
  shred as shown above.
- **Rotate keys** if a team member leaves or a key is compromised.
- **Test recovery** at least once after initial setup.
