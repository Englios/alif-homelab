#!/bin/bash

# 🚀 Deploy Tunnel Resilience Improvements
# This script deploys the enhanced bore tunnel with health checks and monitoring

set -e

NAMESPACE="minecraft"
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Deploying Tunnel Resilience Improvements${NC}"
echo "=============================================="

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
    esac
}

# Check if we're in the right directory
if [ ! -f "apps/minecraft-server/bore-tunnel.yaml" ]; then
    echo "❌ Error: Please run this script from the homelab-k8s root directory"
    exit 1
fi

print_status "INFO" "Step 1: Applying enhanced bore tunnel configuration..."
kubectl apply -f apps/minecraft-server/bore-tunnel.yaml

print_status "INFO" "Step 2: Applying tunnel watchdog service..."
kubectl apply -f apps/minecraft-server/tunnel-watchdog.yaml

print_status "INFO" "Step 3: Applying enhanced DNS updater..."
kubectl apply -f apps/minecraft-server/minecraft-dns-updater.yaml

print_status "INFO" "Step 4: Waiting for deployments to be ready..."

# Wait for bore tunnel to be ready
print_status "INFO" "Waiting for bore tunnel to restart..."
kubectl rollout status deployment/minecraft-bore-tunnel -n $NAMESPACE --timeout=120s

# Wait for tunnel watchdog to be ready
print_status "INFO" "Waiting for tunnel watchdog to start..."
kubectl rollout status deployment/tunnel-watchdog -n $NAMESPACE --timeout=120s

# Wait for DNS updater to be ready
print_status "INFO" "Waiting for DNS updater to restart..."
kubectl rollout status deployment/minecraft-dns-updater -n $NAMESPACE --timeout=120s

print_status "SUCCESS" "All deployments are ready!"

echo ""
print_status "INFO" "Step 5: Checking system health..."
sleep 10

# Run health check
if [ -f "apps/minecraft-server/scripts/monitor-tunnel-health.sh" ]; then
    ./apps/minecraft-server/scripts/monitor-tunnel-health.sh
else
    print_status "WARNING" "Health monitor script not found, checking manually..."
    
    # Basic health check
    echo "Pod status:"
    kubectl get pods -n $NAMESPACE
    
    echo ""
    echo "Recent bore tunnel logs:"
    kubectl logs -n $NAMESPACE -l app=minecraft-bore-tunnel --tail=5
fi

echo ""
echo "=============================================="
print_status "SUCCESS" "Tunnel resilience improvements deployed! 🎉"
echo ""
echo "New features:"
echo "• 🔍 Enhanced health checks with automatic restart"
echo "• 🤖 Dedicated tunnel watchdog service"
echo "• 📊 Improved DNS updater with connectivity testing"
echo "• 🛠️  Comprehensive monitoring script"
echo ""
echo "Monitoring commands:"
echo "• Health check: ./apps/minecraft-server/scripts/monitor-tunnel-health.sh"
echo "• Watch logs: kubectl logs -n minecraft -l app=tunnel-watchdog -f"
echo "• Check status: kubectl get pods -n minecraft" 