#!/bin/bash
#
# Setup kubectl access to homelab k3s cluster via Tailscale
#
# Prerequisites:
#   - Tailscale installed and authenticated
#   - SSH access to homelab (ssh homelab-debian-remote)
#   - kubectl installed locally
#
# Usage:
#   ./setup-kubectl.sh
#   ./setup-kubectl.sh --context-name my-homelab
#

set -e

# Configuration - modify these for your setup
SSH_HOST="${SSH_HOST:-homelab-debian-remote}"
TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-debian}"
CONTEXT_NAME="${1:-homelab-context}"
CLUSTER_NAME="${CLUSTER_NAME:-homelab}"
USER_NAME="${USER_NAME:-alif-homelab}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    command -v kubectl >/dev/null 2>&1 || error "kubectl not found. Please install kubectl first."
    command -v tailscale >/dev/null 2>&1 || error "tailscale not found. Please install Tailscale first."
    command -v ssh >/dev/null 2>&1 || error "ssh not found."
    command -v jq >/dev/null 2>&1 || warn "jq not found. Some features may not work."
    
    # Check Tailscale is connected
    if ! tailscale status >/dev/null 2>&1; then
        error "Tailscale is not running or not authenticated. Run 'tailscale up' first."
    fi
    
    info "Prerequisites OK"
}

# Get Tailscale IP for the homelab server
get_tailscale_ip() {
    info "Getting Tailscale IP for ${TAILSCALE_HOSTNAME}..."
    
    TAILSCALE_IP=$(tailscale status | grep -w "${TAILSCALE_HOSTNAME}" | awk '{print $1}')
    
    if [ -z "$TAILSCALE_IP" ]; then
        error "Could not find Tailscale IP for '${TAILSCALE_HOSTNAME}'. Check 'tailscale status'."
    fi
    
    info "Found Tailscale IP: ${TAILSCALE_IP}"
}

# Test SSH connectivity
test_ssh() {
    info "Testing SSH connection to ${SSH_HOST}..."
    
    if ! ssh -o ConnectTimeout=10 "${SSH_HOST}" "echo 'SSH OK'" >/dev/null 2>&1; then
        error "Cannot SSH to ${SSH_HOST}. Check your SSH config."
    fi
    
    info "SSH connection OK"
}

# Fetch kubeconfig from server
fetch_kubeconfig() {
    info "Fetching kubeconfig from ${SSH_HOST}..."
    
    # Get the k3s kubeconfig (requires sudo on remote)
    REMOTE_CONFIG=$(ssh "${SSH_HOST}" "sudo cat /etc/rancher/k3s/k3s.yaml 2>/dev/null" || true)
    
    if [ -z "$REMOTE_CONFIG" ]; then
        error "Could not fetch kubeconfig. You may need to enter sudo password on remote."
        echo "Try running: ssh ${SSH_HOST} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
        exit 1
    fi
    
    # Extract CA certificate
    CA_DATA=$(echo "$REMOTE_CONFIG" | grep 'certificate-authority-data:' | awk '{print $2}')
    CLIENT_CERT=$(echo "$REMOTE_CONFIG" | grep 'client-certificate-data:' | awk '{print $2}')
    CLIENT_KEY=$(echo "$REMOTE_CONFIG" | grep 'client-key-data:' | awk '{print $2}')
    
    if [ -z "$CA_DATA" ] || [ -z "$CLIENT_CERT" ] || [ -z "$CLIENT_KEY" ]; then
        error "Could not extract certificate data from remote kubeconfig"
    fi
    
    info "Certificates fetched successfully"
}

# Configure local kubectl
configure_kubectl() {
    info "Configuring local kubectl..."
    
    # Backup existing config
    if [ -f ~/.kube/config ]; then
        cp ~/.kube/config ~/.kube/config.backup.$(date +%Y%m%d%H%M%S)
        info "Backed up existing kubeconfig"
    fi
    
    # Ensure .kube directory exists
    mkdir -p ~/.kube
    
    # Set cluster
    kubectl config set-cluster "${CLUSTER_NAME}" \
        --server="https://${TAILSCALE_IP}:6443" \
        --certificate-authority-data="${CA_DATA}" \
        --embed-certs=true
    
    # Set credentials
    kubectl config set-credentials "${USER_NAME}" \
        --client-certificate-data="${CLIENT_CERT}" \
        --client-key-data="${CLIENT_KEY}" \
        --embed-certs=true
    
    # Set context
    kubectl config set-context "${CONTEXT_NAME}" \
        --cluster="${CLUSTER_NAME}" \
        --user="${USER_NAME}"
    
    info "kubectl configured"
}

# Test the connection
test_connection() {
    info "Testing cluster connection..."
    
    if kubectl --context="${CONTEXT_NAME}" cluster-info >/dev/null 2>&1; then
        info "Cluster connection successful!"
        echo ""
        kubectl --context="${CONTEXT_NAME}" get nodes
    else
        error "Could not connect to cluster. Check the configuration."
    fi
}

# Prompt to set as current context
set_current_context() {
    echo ""
    read -p "Set ${CONTEXT_NAME} as current context? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        kubectl config use-context "${CONTEXT_NAME}"
        info "Current context set to ${CONTEXT_NAME}"
    fi
}

# Main
main() {
    echo "======================================"
    echo "  Homelab kubectl Setup Script"
    echo "======================================"
    echo ""
    
    check_prerequisites
    get_tailscale_ip
    test_ssh
    fetch_kubeconfig
    configure_kubectl
    test_connection
    set_current_context
    
    echo ""
    info "Setup complete! You can now use: kubectl --context=${CONTEXT_NAME} <command>"
}

main "$@"
