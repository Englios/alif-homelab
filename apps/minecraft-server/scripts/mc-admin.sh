#!/bin/bash

# Quick Minecraft admin commands via RCON
# Usage: ./mc-admin.sh <command>

NAMESPACE="minecraft"
DEPLOYMENT="minecraft-server"

case "$1" in
    "list"|"players")
        echo "📋 Online players:"
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli list
        ;;
    "say")
        if [ -z "$2" ]; then
            echo "Usage: $0 say \"Your message\""
            exit 1
        fi
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli say "$2"
        ;;
    "tell")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 tell PlayerName \"Your message\""
            exit 1
        fi
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli tell "$2" "$3"
        ;;
    "kick")
        if [ -z "$2" ]; then
            echo "Usage: $0 kick PlayerName [reason]"
            exit 1
        fi
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli kick "$2" "${3:-Kicked by admin}"
        ;;
    "tp")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 tp PlayerName TargetPlayer"
            exit 1
        fi
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli tp "$2" "$3"
        ;;
    "time")
        if [ -z "$2" ]; then
            echo "Usage: $0 time <day|night|set XXXX>"
            exit 1
        fi
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli time set "$2"
        ;;
    "weather")
        if [ -z "$2" ]; then
            echo "Usage: $0 weather <clear|rain|thunder>"
            exit 1
        fi
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli weather "$2"
        ;;
    *)
        echo "Available commands:"
        echo "  list           - Show online players"
        echo "  say \"message\"  - Broadcast message"
        echo "  tell player \"msg\" - Private message"
        echo "  kick player    - Kick player"
        echo "  tp p1 p2       - Teleport player to player"
        echo "  time day/night - Change time"
        echo "  weather clear  - Change weather"
        ;;
esac