#!/bin/bash

# Simple script to update bore server config from .env

source .env

kubectl create secret generic bore-server-config \
    --from-literal=server-ip="$BORE_SERVER_IP" \
    --from-literal=server-type="$BORE_SERVER_TYPE" \
    -n minecraft \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Updated bore config: $BORE_SERVER_TYPE at $BORE_SERVER_IP"

# Restart services to pick up new config
kubectl rollout restart deployment/minecraft-bore-tunnel -n minecraft
kubectl rollout restart deployment/minecraft-dns-updater -n minecraft

echo "Restarted tunnel and DNS updater" 