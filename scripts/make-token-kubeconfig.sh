#!/bin/bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  make-token-kubeconfig.sh --server <url> --ca-data <base64> --token <token> --user <name> [options]

Required:
  --server     Kubernetes API server URL
  --ca-data    Base64-encoded certificate-authority-data
  --token      Bearer token for the service account or short-lived identity
  --user       Username to place in kubeconfig

Optional:
  --cluster    Cluster name (default: homelab)
  --context    Context name (default: <cluster>-<user>)
  --output     Output path (default: ./<context>.kubeconfig)

Notes:
  - Do not use this script to hand long-lived service account tokens to humans.
  - Prefer per-user client certificates now, and OIDC groups later, for people.
EOF
}

CLUSTER_NAME="homelab"
CONTEXT_NAME=""
OUTPUT_PATH=""
SERVER_URL=""
CA_DATA=""
TOKEN=""
USER_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --server)
            SERVER_URL="$2"
            shift 2
            ;;
        --ca-data)
            CA_DATA="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --user)
            USER_NAME="$2"
            shift 2
            ;;
        --cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --context)
            CONTEXT_NAME="$2"
            shift 2
            ;;
        --output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$SERVER_URL" || -z "$CA_DATA" || -z "$TOKEN" || -z "$USER_NAME" ]]; then
    usage >&2
    exit 1
fi

if [[ -z "$CONTEXT_NAME" ]]; then
    CONTEXT_NAME="${CLUSTER_NAME}-${USER_NAME}"
fi

if [[ -z "$OUTPUT_PATH" ]]; then
    OUTPUT_PATH="./${CONTEXT_NAME}.kubeconfig"
fi

CA_FILE=$(mktemp)
cleanup() {
    rm -f "$CA_FILE"
}
trap cleanup EXIT

printf '%s' "$CA_DATA" | base64 -d > "$CA_FILE"

kubectl config --kubeconfig="$OUTPUT_PATH" set-cluster "$CLUSTER_NAME" \
    --server="$SERVER_URL" \
    --certificate-authority="$CA_FILE" \
    --embed-certs=true >/dev/null

kubectl config --kubeconfig="$OUTPUT_PATH" set-credentials "$USER_NAME" \
    --token="$TOKEN" >/dev/null

kubectl config --kubeconfig="$OUTPUT_PATH" set-context "$CONTEXT_NAME" \
    --cluster="$CLUSTER_NAME" \
    --user="$USER_NAME" >/dev/null

kubectl config --kubeconfig="$OUTPUT_PATH" use-context "$CONTEXT_NAME" >/dev/null

printf 'Wrote kubeconfig to %s\n' "$OUTPUT_PATH"
