#!/usr/bin/env bash
# scripts/encrypt-vaultwarden-secret.sh
#
# Phase 1, steps 1-7 of the vaultwarden bootstrap draft
# (.slim/deepwork/vaultwarden-bootstrap.md). Generates the
# SOPS-encrypted Secret for Vaultwarden and validates the kustomize
# build.
#
# Prerequisites:
#   - sops and age installed
#   - One of:
#       a) ~/.config/sops/age/keys.txt present (standard SOPS path)
#       b) <repo>/age.key present and matching .sops.yaml
#       c) SOPS_AGE_KEY_FILE env var set to the key file
#   - Working tree is on the feature/vaultwarden-bootstrap branch
#
# After this script:
#   - clusters/homelab/secrets/vaultwarden-secrets.sops.yaml exists,
#     encrypted to the repo's age key
#   - infrastructure/vaultwarden/kustomization.yaml references it
#   - `kubectl kustomize infrastructure/vaultwarden` produces a valid
#     manifest including the encrypted Secret
#
# The DOMAIN field is a placeholder — patch the Secret later when the
# Tailscale hostname is known. See the "Open questions" section of the
# draft.
#
# This script does NOT commit, push, or touch the cluster. It only
# mutates working-tree files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

EXAMPLE="$REPO_ROOT/clusters/homelab/secrets/vaultwarden-secrets.sops.yaml.example"
TARGET="$REPO_ROOT/clusters/homelab/secrets/vaultwarden-secrets.sops.yaml"

# 1. Resolve the age key file
KEY_FILE="${SOPS_AGE_KEY_FILE:-}"
if [[ -z "$KEY_FILE" ]]; then
  for candidate in "$HOME/.config/sops/age/keys.txt" "$REPO_ROOT/age.key"; do
    if [[ -f "$candidate" ]]; then
      KEY_FILE="$candidate"
      break
    fi
  done
fi
if [[ -z "$KEY_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "ERROR: no age key found." >&2
  echo "  Set SOPS_AGE_KEY_FILE, or place the key at one of:" >&2
  echo "    $HOME/.config/sops/age/keys.txt" >&2
  echo "    $REPO_ROOT/age.key" >&2
  exit 1
fi
export SOPS_AGE_KEY_FILE="$KEY_FILE"
echo "Using age key: $KEY_FILE"

# 2. Sanity: the local key matches .sops.yaml
LOCAL_PUB="$(age-keygen -y "$KEY_FILE" 2>/dev/null || true)"
REPO_PUB="$(grep -oE 'age1[0-9a-z]+' .sops.yaml | head -1)"
if [[ -z "$LOCAL_PUB" || -z "$REPO_PUB" || "$LOCAL_PUB" != "$REPO_PUB" ]]; then
  echo "ERROR: age key mismatch." >&2
  echo "  local  : $LOCAL_PUB" >&2
  echo "  .sops.yaml: $REPO_PUB" >&2
  exit 1
fi
echo "Key matches .sops.yaml: $REPO_PUB"

# 3. Refuse to clobber an existing encrypted file
if [[ -f "$TARGET" ]]; then
  echo "ERROR: $TARGET already exists." >&2
  echo "Remove it manually (or use sops to edit in place) and re-run." >&2
  exit 1
fi

# 4. Generate the ADMIN_TOKEN
ADMIN_TOKEN="$(openssl rand -base64 48)"
echo "Generated ADMIN_TOKEN: ${ADMIN_TOKEN:0:8}...${ADMIN_TOKEN: -4}  (full value not echoed again)"

# 5. Use placeholder DOMAIN — patch later
DOMAIN="https://vaultwarden.tail-XXXX.ts.net"
echo "Using placeholder DOMAIN: $DOMAIN"
echo "  -> patch with: sops --set-string 'data[\"DOMAIN\"] <new-b64>' $TARGET"

# 6. Build the Secret from the example, substituting real values
TMP="$(mktemp)"
trap 'shred -u "$TMP" 2>/dev/null || rm -f "$TMP"' EXIT
sed \
  -e "s|^  ADMIN_TOKEN:.*|  ADMIN_TOKEN: \"$(printf '%s' "$ADMIN_TOKEN" | base64 -w0)\"|" \
  -e "s|^  DOMAIN:.*|  DOMAIN: \"$(printf '%s' "$DOMAIN" | base64 -w0)\"|" \
  "$EXAMPLE" > "$TMP"
unset ADMIN_TOKEN

# 7. Encrypt in place
cp "$TMP" "$TARGET"
sops --encrypt --in-place "$TARGET"
echo "Encrypted: $TARGET"

# 8. Verify without printing values
echo
echo "=== sops filestatus ==="
sops filestatus "$TARGET"

# 9. kustomize validation
echo
echo "=== kubectl kustomize (head) ==="
kubectl kustomize infrastructure/vaultwarden --load-restrictor LoadRestrictionsNone \
  | grep -E "^(kind|  name|  namespace):" | head -30

echo
echo "Done. Next:"
echo "  1. Verify the file is encrypted (no base64 placeholders visible)."
echo "  2. git add clusters/homelab/secrets/vaultwarden-secrets.sops.yaml \\"
echo "          infrastructure/vaultwarden/kustomization.yaml"
echo "  3. git commit -m 'feat(vaultwarden): add encrypted secret and wire into kustomization'"
echo "  4. git push origin feature/vaultwarden-bootstrap"
echo "  5. When Tailscale hostname is known, run:"
echo "       sops --set-string 'data[\"DOMAIN\"] <new-b64>' \\"
echo "         clusters/homelab/secrets/vaultwarden-secrets.sops.yaml"
echo "     and commit the result."
