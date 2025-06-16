#!/bin/bash

# 🔍 Minecraft Tunnel Health Monitor
# This script checks the health of the bore tunnel and provides detailed diagnostics

set -e

NAMESPACE="minecraft"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Minecraft Tunnel Health Monitor${NC}"
echo "================================================"

# Function to print colored status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_status "ERROR" "kubectl not found. Please install kubectl."
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    print_status "ERROR" "Namespace '$NAMESPACE' not found."
    exit 1
fi

echo -e "\n${BLUE}1. Checking Pod Status${NC}"
echo "------------------------"

# Check bore tunnel pod
BORE_POD=$(kubectl get pods -n $NAMESPACE -l app=minecraft-bore-tunnel -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$BORE_POD" ]; then
    print_status "ERROR" "Bore tunnel pod not found"
    exit 1
else
    BORE_STATUS=$(kubectl get pod $BORE_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$BORE_STATUS" = "Running" ]; then
        print_status "SUCCESS" "Bore tunnel pod is running: $BORE_POD"
    else
        print_status "ERROR" "Bore tunnel pod is not running: $BORE_STATUS"
    fi
fi

# Check Minecraft server pod
MC_POD=$(kubectl get pods -n $NAMESPACE -l app=minecraft-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$MC_POD" ]; then
    print_status "ERROR" "Minecraft server pod not found"
else
    MC_STATUS=$(kubectl get pod $MC_POD -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$MC_STATUS" = "Running" ]; then
        print_status "SUCCESS" "Minecraft server pod is running: $MC_POD"
    else
        print_status "ERROR" "Minecraft server pod is not running: $MC_STATUS"
    fi
fi

echo -e "\n${BLUE}2. Checking Tunnel Connection${NC}"
echo "--------------------------------"

# Get current port from logs
CURRENT_PORT=$(kubectl logs -n $NAMESPACE -l app=minecraft-bore-tunnel --tail=20 | \
    grep "listening at bore.pub:" | \
    tail -1 | \
    sed 's/.*bore.pub:\([0-9]*\).*/\1/' || echo "")

if [ -z "$CURRENT_PORT" ]; then
    print_status "ERROR" "No active tunnel port found in logs"
    echo "Recent bore tunnel logs:"
    kubectl logs -n $NAMESPACE -l app=minecraft-bore-tunnel --tail=10
else
    print_status "INFO" "Current tunnel port: $CURRENT_PORT"
    
    # Test external connectivity
    if timeout 10s nc -z bore.pub "$CURRENT_PORT" 2>/dev/null; then
        print_status "SUCCESS" "Tunnel is accessible externally on port $CURRENT_PORT"
    else
        print_status "ERROR" "Tunnel is NOT accessible externally on port $CURRENT_PORT"
    fi
fi

echo -e "\n${BLUE}3. Checking Internal Connectivity${NC}"
echo "------------------------------------"

# Test internal Minecraft server connectivity
if kubectl exec -n $NAMESPACE $BORE_POD -- nc -z minecraft-server.minecraft.svc.cluster.local 25565 2>/dev/null; then
    print_status "SUCCESS" "Internal Minecraft server is accessible"
else
    print_status "ERROR" "Internal Minecraft server is NOT accessible"
fi

echo -e "\n${BLUE}4. Checking DNS Records${NC}"
echo "-------------------------"

# Check SRV record
SRV_RESULT=$(dig +short SRV _minecraft._tcp.minecraft.alifaiman.cloud 2>/dev/null || echo "")
if [ -n "$SRV_RESULT" ]; then
    DNS_PORT=$(echo "$SRV_RESULT" | awk '{print $3}')
    print_status "INFO" "DNS SRV record points to port: $DNS_PORT"
    
    if [ "$DNS_PORT" = "$CURRENT_PORT" ]; then
        print_status "SUCCESS" "DNS record matches current tunnel port"
    else
        print_status "WARNING" "DNS record ($DNS_PORT) doesn't match current tunnel port ($CURRENT_PORT)"
        print_status "INFO" "DNS updater should fix this within 30 seconds"
    fi
else
    print_status "ERROR" "No SRV record found for minecraft.alifaiman.cloud"
fi

echo -e "\n${BLUE}5. Resource Usage${NC}"
echo "-------------------"

# Check resource usage
kubectl top pods -n $NAMESPACE 2>/dev/null || print_status "WARNING" "Metrics server not available"

echo -e "\n${BLUE}6. Recent Events${NC}"
echo "------------------"

# Show recent events
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' --field-selector involvedObject.kind=Pod | tail -5

echo -e "\n${BLUE}7. Recommendations${NC}"
echo "---------------------"

if [ -n "$CURRENT_PORT" ] && timeout 10s nc -z bore.pub "$CURRENT_PORT" 2>/dev/null; then
    print_status "SUCCESS" "System appears healthy! 🎮"
    echo "Players can connect to: minecraft.alifaiman.cloud"
else
    print_status "ERROR" "System needs attention! 🔧"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Restart bore tunnel: kubectl rollout restart deployment/minecraft-bore-tunnel -n $NAMESPACE"
    echo "2. Check logs: kubectl logs -n $NAMESPACE -l app=minecraft-bore-tunnel -f"
    echo "3. Test connectivity: nc -zv bore.pub [PORT]"
fi

echo ""
echo "================================================"
echo -e "${BLUE}Monitor completed at $(date)${NC}" 