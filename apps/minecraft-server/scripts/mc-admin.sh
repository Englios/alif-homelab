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
        
        # Use tellraw for the player-facing message
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli tellraw @a "[{\"text\":\"[ADMIN] \",\"color\":\"red\"},{\"text\":\"$2\"}]" > /dev/null

        # Use /say for the server-side log entry. We will briefly disable
        # command block output to prevent players from seeing this second message.
        # This is more reliable than trying to manually write to the log file.
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli gamerule commandBlockOutput false > /dev/null
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli say "[ADMIN] $2" > /dev/null
        kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli gamerule commandBlockOutput true > /dev/null
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
    "spawn")
        spawn_help() {
            echo "Usage: $0 spawn <mob> [options]"
            echo
            echo "Options:"
            echo "  -p, --player <name>      Target a player's location."
            echo "  -c, --coords <x> <y> <z> Target specific coordinates."
            echo "  -q, --quantity <#>       Number of mobs to spawn (default: 1)."
            echo
            echo "Examples:"
            echo "  $0 spawn minecraft:sheep --player Notch --quantity 10"
            echo "  $0 spawn minecraft:creeper -c 100 64 -150"
        }

        shift # Move past the "spawn" command
        
        # If no arguments are given to spawn, show help.
        if [ "$#" -eq 0 ]; then
            spawn_help
            exit 0
        fi
        
        # Default values
        mob_type=""
        player_name=""
        coords=""
        quantity=1

        # Parse arguments
        while (( "$#" )); do
          case "$1" in
            -p|--player)
              player_name="$2"
              shift 2
              ;;
            -c|--coords)
              if [ "$#" -lt 4 ]; then echo "Error: --coords requires x y z values." >&2; exit 1; fi
              coords="$2 $3 $4"
              shift 4
              ;;
            -q|--quantity)
              quantity="$2"
              shift 2
              ;;
            *)
              if [ -z "$mob_type" ]; then
                mob_type="$1"
                shift
              else
                echo "Error: Unknown argument $1" >&2
                exit 1
              fi
              ;;
          esac
        done

        # --- Validation ---
        if [ -z "$mob_type" ]; then
          echo "Error: Mob type is a required argument." >&2
          spawn_help
          exit 1
        fi
        if [ -n "$player_name" ] && [ -n "$coords" ]; then
          echo "Error: Cannot use --player and --coords at the same time." >&2
          exit 1
        fi
        
        # If no target is specified, use default coordinates
        if [ -z "$player_name" ] && [ -z "$coords" ]; then
          echo "No target specified, using default coordinates."
          coords="0 64 0"
        fi

        # --- Execution ---
        if [ -n "$player_name" ]; then
            log_message="Attempting to spawn $quantity of $mob_type at player $player_name..."
            echo "$log_message"
            # Log the attempt to the server's log file for visibility in `kubectl logs`
            safe_log=$(echo "$log_message" | sed "s/'/'\\\\''/g")
            log_entry="[mc-admin-script/INFO]: ${safe_log}"
            kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- sh -c "echo '${log_entry}' >> /data/logs/latest.log"

            for (( i=1; i<=$quantity; i++ )); do
                # We've removed '> /dev/null' to see the server's response for debugging
                # We quote the tildes '~' to prevent the local shell from expanding them to the user's home directory.
                kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli execute at "$player_name" run summon "$mob_type" '~' '~' '~'
            done
            echo "Spawn command sent."
        else
            log_message="Attempting to spawn $quantity of $mob_type at coordinates $coords..."
            echo "$log_message"
            # Log the attempt to the server's log file
            safe_log=$(echo "$log_message" | sed "s/'/'\\\\''/g")
            log_entry="[mc-admin-script/INFO]: ${safe_log}"
            kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- sh -c "echo '${log_entry}' >> /data/logs/latest.log"

            for (( i=1; i<=$quantity; i++ )); do
                # We've removed '> /dev/null' to see the server's response for debugging
                # We quote the tildes '~' to prevent the local shell from expanding them to the user's home directory.
                kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli summon "$mob_type" $coords
            done
            echo "Spawn command sent."
        fi
        ;;
    *)
        echo "Available commands:"
        echo "  list           - Show online players"
        echo "  say \"message\"  - Broadcast a message as [ADMIN]"
        echo "  tell player \"msg\" - Private message"
        echo "  kick player    - Kick player"
        echo "  tp p1 p2       - Teleport player to player"
        echo "  time day/night - Change time"
        echo "  weather clear  - Change weather"
        echo "  spawn          - Show options for spawning mobs"
        ;;
esac