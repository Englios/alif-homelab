#!/bin/bash

# Get the current date
DATE=$(date +%Y%m%d_%H%M%S)

if [ -n "$1" ]; then
  NAME_SUFFIX="$1-$DATE"
else
  NAME_SUFFIX=$DATE
fi

BACKUP_NAME="minecraft-world-backup-$NAME_SUFFIX"

echo "Creating backup: $BACKUP_NAME"

POD_NAME=$(kubectl get pods -n minecraft -l app=minecraft-server -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "Error: Minecraft server pod not found."
    exit 1
fi

kubectl exec -n minecraft $POD_NAME -- tar czf /tmp/$BACKUP_NAME.tar.gz -C /data world
kubectl cp minecraft/$POD_NAME:/tmp/$BACKUP_NAME.tar.gz ./$BACKUP_NAME.tar.gz
kubectl exec -n minecraft $POD_NAME -- rm /tmp/$BACKUP_NAME.tar.gz

echo "Backup created: $BACKUP_NAME.tar.gz"