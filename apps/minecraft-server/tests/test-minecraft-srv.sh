#!/bin/bash

DOMAIN="minecraft.alifaiman.cloud"

echo "Testing Minecraft SRV record lookup for: $DOMAIN"
echo "================================================"

# Test standard Minecraft SRV record
echo "1. Looking up standard Minecraft SRV record..."
SRV_RESULT=$(dig +short SRV _minecraft._tcp.$DOMAIN)

if [ -n "$SRV_RESULT" ]; then
    echo "✅ SRV record found: $SRV_RESULT"
    
    # Parse the SRV record (format: priority weight port target)
    PORT=$(echo $SRV_RESULT | awk '{print $3}')
    TARGET=$(echo $SRV_RESULT | awk '{print $4}' | sed 's/\.$//')
    
    echo "   Target: $TARGET"
    echo "   Port: $PORT"
    echo ""
    
    echo "2. Testing connection to resolved target..."
    echo "   Connecting to: $TARGET:$PORT"
    
    # Test the connection
    timeout 5 nc -zv $TARGET $PORT 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✅ Connection successful!"
        echo ""
        echo "🎮 Minecraft clients should be able to connect to:"
        echo "   $DOMAIN (without port)"
    else
        echo "❌ Connection failed"
        echo ""
        echo "🎮 Clients would need to use:"
        echo "   $DOMAIN:$PORT"
    fi
else
    echo "❌ No SRV record found"
    echo ""
    echo "🎮 Clients would need to specify port manually"
fi

echo ""
echo "3. Testing fallback (direct connection to domain:25565)..."
timeout 5 nc -zv $DOMAIN 25565 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Direct connection to port 25565 works"
else
    echo "❌ Direct connection to port 25565 failed"
fi 