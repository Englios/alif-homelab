#!/bin/bash

# Enhanced Minecraft SRV Test Script
# Tests DNS records and connectivity for the bore tunnel setup

DOMAIN="play-mc.alifaiman.cloud"
BASE_DOMAIN="alifaiman.cloud"
STANDARD_SRV="_minecraft._tcp.play-mc.alifaiman.cloud"
CUSTOM_SRV="_minecraft.play-mc.alifaiman.cloud"

echo "🔍 Enhanced Minecraft Server Connectivity Test"
echo "=============================================="
echo "Domain: $DOMAIN"
echo "Base Domain: $BASE_DOMAIN"
echo ""

# Function to test connection with timeout and better error handling
test_connection() {
    local host=$1
    local port=$2
    local description=$3
    
    echo "🧪 Testing: $description"
    echo "   Host: $host"
    echo "   Port: $port"
    
    if timeout 10s nc -zv "$host" "$port" 2>/dev/null; then
        echo "   ✅ Connection successful!"
        return 0
    else
        echo "   ❌ Connection failed"
        return 1
    fi
}

# Function to get current bore tunnel port from DNS updater logs
get_current_bore_port() {
    echo "🔍 Checking current bore tunnel port from cluster..."
    if command -v kubectl &> /dev/null; then
        BORE_PORT=$(kubectl logs -n minecraft -l app=minecraft-bore-tunnel --tail=10 2>/dev/null | \
                   grep "listening at" | tail -1 | sed 's/.*:\([0-9]*\).*/\1/' 2>/dev/null)
        if [ -n "$BORE_PORT" ] && [ "$BORE_PORT" != "" ]; then
            echo "   📡 Found active bore tunnel on port: $BORE_PORT"
            return 0
        fi
    fi
    echo "   ⚠️  Could not determine bore tunnel port"
    return 1
}

echo "1. DNS Record Tests"
echo "==================="

# Test A record
echo "📍 Testing A record..."
A_RESULT=$(dig +short A $DOMAIN)
if [ -n "$A_RESULT" ]; then
    echo "✅ A record found: $DOMAIN -> $A_RESULT"
    BORE_SERVER_IP="$A_RESULT"
else
    echo "❌ No A record found for $DOMAIN"
    BORE_SERVER_IP=""
fi
echo ""

# Test standard SRV record
echo "📍 Testing standard SRV record..."
STANDARD_SRV_RESULT=$(dig +short SRV $STANDARD_SRV)
if [ -n "$STANDARD_SRV_RESULT" ]; then
    echo "✅ Standard SRV record found: $STANDARD_SRV_RESULT"
    
    # Parse SRV record (format: priority weight port target)
    STANDARD_PORT=$(echo $STANDARD_SRV_RESULT | awk '{print $3}')
    STANDARD_TARGET=$(echo $STANDARD_SRV_RESULT | awk '{print $4}' | sed 's/\.$//')
    
    echo "   Priority: $(echo $STANDARD_SRV_RESULT | awk '{print $1}')"
    echo "   Weight: $(echo $STANDARD_SRV_RESULT | awk '{print $2}')"
    echo "   Port: $STANDARD_PORT"
    echo "   Target: $STANDARD_TARGET"
else
    echo "❌ No standard SRV record found: $STANDARD_SRV"
    STANDARD_PORT=""
    STANDARD_TARGET=""
fi
echo ""

# Test custom SRV record
echo "📍 Testing custom SRV record..."
CUSTOM_SRV_RESULT=$(dig +short SRV $CUSTOM_SRV)
if [ -n "$CUSTOM_SRV_RESULT" ]; then
    echo "✅ Custom SRV record found: $CUSTOM_SRV_RESULT"
    
    # Parse SRV record
    CUSTOM_PORT=$(echo $CUSTOM_SRV_RESULT | awk '{print $3}')
    CUSTOM_TARGET=$(echo $CUSTOM_SRV_RESULT | awk '{print $4}' | sed 's/\.$//')
    
    echo "   Priority: $(echo $CUSTOM_SRV_RESULT | awk '{print $1}')"
    echo "   Weight: $(echo $CUSTOM_SRV_RESULT | awk '{print $2}')"
    echo "   Port: $CUSTOM_PORT"
    echo "   Target: $CUSTOM_TARGET"
else
    echo "❌ No custom SRV record found: $CUSTOM_SRV"
    CUSTOM_PORT=""
    CUSTOM_TARGET=""
fi
echo ""

echo "2. Connectivity Tests"
echo "===================="

# Get current bore port from cluster
get_current_bore_port
CLUSTER_BORE_PORT="$BORE_PORT"

# Test connections in order of preference
CONNECTION_SUCCESS=false

# Test standard SRV record connection
if [ -n "$STANDARD_PORT" ] && [ -n "$STANDARD_TARGET" ]; then
    if test_connection "$STANDARD_TARGET" "$STANDARD_PORT" "Standard SRV record ($STANDARD_SRV)"; then
        CONNECTION_SUCCESS=true
        WORKING_METHOD="Standard SRV record"
        WORKING_PORT="$STANDARD_PORT"
    fi
    echo ""
fi

# Test custom SRV record connection  
if [ -n "$CUSTOM_PORT" ] && [ -n "$CUSTOM_TARGET" ]; then
    if test_connection "$CUSTOM_TARGET" "$CUSTOM_PORT" "Custom SRV record ($CUSTOM_SRV)"; then
        CONNECTION_SUCCESS=true
        WORKING_METHOD="Custom SRV record"
        WORKING_PORT="$CUSTOM_PORT"
    fi
    echo ""
fi

# Test direct bore server connection with cluster port
if [ -n "$BORE_SERVER_IP" ] && [ -n "$CLUSTER_BORE_PORT" ]; then
    if test_connection "$BORE_SERVER_IP" "$CLUSTER_BORE_PORT" "Direct bore server (cluster port)"; then
        CONNECTION_SUCCESS=true
        WORKING_METHOD="Direct bore server"
        WORKING_PORT="$CLUSTER_BORE_PORT"
    fi
    echo ""
fi

# Test direct domain connection on port 25565 (fallback)
if test_connection "$DOMAIN" "25565" "Direct domain on default port"; then
    CONNECTION_SUCCESS=true
    WORKING_METHOD="Direct domain (port 25565)"
    WORKING_PORT="25565"
fi
echo ""

echo "3. Summary & Recommendations"
echo "============================"

if [ "$CONNECTION_SUCCESS" = true ]; then
    echo "✅ SUCCESS: Server is accessible!"
    echo ""
    echo "🎮 Player Connection Options:"
    echo "   Recommended: $DOMAIN (no port needed)"
    echo "   Working method: $WORKING_METHOD"
    echo "   Working port: $WORKING_PORT"
    
    if [ -n "$STANDARD_SRV_RESULT" ]; then
        echo ""
        echo "✅ Standard SRV record is working - players can connect with just the domain!"
    elif [ -n "$CUSTOM_SRV_RESULT" ]; then
        echo ""
        echo "⚠️  Only custom SRV record found - some clients may need manual port"
    else
        echo ""
        echo "⚠️  No SRV records found - players need to specify port manually: $DOMAIN:$WORKING_PORT"
    fi
else
    echo "❌ FAILURE: Server is not accessible!"
    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "1. Check if bore tunnel is running: kubectl logs -n minecraft -l app=minecraft-bore-tunnel"
    echo "2. Check DNS updater status: kubectl logs -n minecraft -l app=minecraft-dns-updater"
    echo "3. Verify Minecraft server is ready: kubectl logs -n minecraft -l app=minecraft-server"
    echo "4. Check pod status: kubectl get pods -n minecraft"
    
    if [ -n "$CLUSTER_BORE_PORT" ]; then
        echo ""
        echo "🔍 Debug info:"
        echo "   Cluster bore port: $CLUSTER_BORE_PORT"
        echo "   DNS A record: $A_RESULT"
        echo "   Try manual connection: $DOMAIN:$CLUSTER_BORE_PORT"
    fi
fi

echo ""
echo "🔍 DNS Propagation Note:"
echo "   DNS changes can take 5-15 minutes to propagate"
echo "   TTL is set to 300 seconds (5 minutes)" 