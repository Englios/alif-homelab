#!/bin/bash

# 🔄 Rolling Update Announcer for Minecraft Server
# Handles announcements for planned restarts, performance updates, and maintenance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

NAMESPACE="minecraft"
DEPLOYMENT="minecraft-server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to send colored tellraw messages
send_tellraw() {
    local message="$1"
    local prefix_text="$2"
    local prefix_color="$3"
    local message_color="$4"
    
    echo -e "${BLUE}📢 Sending: ${NC}[$prefix_text] $message"
    
    kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- \
      rcon-cli tellraw @a "[{\"text\":\"[$prefix_text] \",\"color\":\"$prefix_color\",\"bold\":true},{\"text\":\"$message\",\"color\":\"$message_color\"}]" 2>/dev/null || {
        echo -e "${RED}❌ Failed to send announcement (server might be restarting)${NC}"
        return 1
    }
    
    sleep 1
}

# Function to check if server is ready
is_server_ready() {
    kubectl get pod -n $NAMESPACE -l app=minecraft-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running" || return 1
    kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- rcon-cli list >/dev/null 2>&1 || return 1
    return 0
}

# Function to wait for server to be ready
wait_for_server() {
    echo -e "${YELLOW}⏳ Waiting for server to be ready...${NC}"
    local attempts=0
    local max_attempts=60
    
    while [ $attempts -lt $max_attempts ]; do
        if is_server_ready; then
            echo -e "${GREEN}✅ Server is ready!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 5
        attempts=$((attempts + 1))
    done
    
    echo -e "${RED}❌ Timeout waiting for server${NC}"
    return 1
}

# Function to announce restart countdown
restart_countdown() {
    local countdown_minutes="$1"
    local reason="$2"
    
    echo -e "${PURPLE}🔄 Starting $countdown_minutes minute countdown...${NC}"
    
    # Initial announcement
    send_tellraw "⚠️ Server restart scheduled in $countdown_minutes minutes" "Restart" "red" "red"
    send_tellraw "Reason: $reason" "Restart" "red" "yellow"
    send_tellraw "💾 Please save your progress now!" "Warning" "yellow" "yellow"
    
    # Countdown warnings
    local warnings=(15 10 5 3 2 1)
    
    for warning in "${warnings[@]}"; do
        if [ $warning -lt $countdown_minutes ]; then
            # Calculate sleep time
            local sleep_time=$(( (countdown_minutes - warning) * 60 ))
            echo -e "${YELLOW}⏰ Waiting $((countdown_minutes - warning)) minutes until $warning minute warning...${NC}"
            sleep $sleep_time
            
            # Check if server is still running
            if ! is_server_ready; then
                echo -e "${YELLOW}⚠️  Server not ready, skipping warning${NC}"
                continue
            fi
            
            # Send warning
            case $warning in
                15) send_tellraw "⏰ Server restart in 15 minutes - Save your work!" "Warning" "yellow" "yellow" ;;
                10) send_tellraw "⏰ Server restart in 10 minutes - Finish up!" "Warning" "yellow" "yellow" ;;
                5) send_tellraw "⚠️  FINAL WARNING: Restart in 5 minutes!" "URGENT" "red" "red" ;;
                3) send_tellraw "🔴 3 minutes until restart!" "URGENT" "red" "red" ;;
                2) send_tellraw "🔴 2 minutes until restart!" "URGENT" "red" "red" ;;
                1) send_tellraw "🔴 1 MINUTE UNTIL RESTART!" "URGENT" "red" "red" ;;
            esac
            
            countdown_minutes=$warning
        fi
    done
    
    # Final countdown
    echo -e "${RED}🚨 Final 30-second countdown...${NC}"
    sleep 30
    if is_server_ready; then
        send_tellraw "🔴 RESTARTING NOW! Server will be back in ~2-3 minutes" "RESTART" "dark_red" "red"
    fi
}

# Function to announce server is back
announce_back_online() {
    local update_type="$1"
    echo -e "${GREEN}🎉 Announcing server is back online...${NC}"
    
    case "$update_type" in
        "performance")
            send_tellraw "🚀 Server is back with performance improvements!" "Update" "green" "green"
            send_tellraw "• Better combat performance" "Changelog" "blue" "aqua"
            send_tellraw "• Reduced view distance for smoother gameplay" "Changelog" "blue" "aqua"
            send_tellraw "• Optimized memory usage" "Changelog" "blue" "aqua"
            ;;
        "mods")
            send_tellraw "📦 Server updated with new mods!" "Update" "green" "green"
            send_tellraw "Check your mod list for changes" "Info" "yellow" "yellow"
            ;;
        "maintenance")
            send_tellraw "🔧 Maintenance complete!" "Maintenance" "green" "green"
            send_tellraw "Server running optimally" "Status" "blue" "gray"
            ;;
        *)
            send_tellraw "🎉 Server is back online!" "Online" "green" "green"
            send_tellraw "Thanks for your patience!" "Info" "gold" "yellow"
            ;;
    esac
}

# Main script logic
case "${1:-help}" in
    "performance-update")
        echo -e "${PURPLE}🚀 Performance Update Deployment${NC}"
        echo "This will:"
        echo "  • Announce performance improvements to players"
        echo "  • Start 5-minute countdown"
        echo "  • Apply optimizations"
        echo "  • Announce when server is back"
        echo ""
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            restart_countdown 5 "Performance optimizations"
            
            echo -e "${BLUE}🔄 Applying Kubernetes deployment...${NC}"
            kubectl apply -f "$SCRIPT_DIR/../deployment/deployment.yaml"
            kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=600s
            
            echo -e "${YELLOW}⏳ Waiting for server to fully start...${NC}"
            wait_for_server
            
            sleep 10  # Extra time for server to stabilize
            announce_back_online "performance"
        fi
        ;;
        
    "mod-update")
        echo -e "${PURPLE}📦 Mod Update Deployment${NC}"
        restart_countdown 10 "Mod updates and improvements"
        
        echo -e "${BLUE}🔄 Applying Kubernetes deployment...${NC}"
        kubectl apply -f "$SCRIPT_DIR/../deployment/deployment.yaml"
        kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=600s
        
        wait_for_server
        sleep 10
        announce_back_online "mods"
        ;;
        
    "maintenance")
        minutes="${2:-15}"
        echo -e "${PURPLE}🔧 Maintenance Window${NC}"
        restart_countdown "$minutes" "Scheduled maintenance"
        
        echo -e "${YELLOW}⚠️  Manual maintenance - apply changes now${NC}"
        read -p "Press Enter when maintenance is complete..."
        
        wait_for_server 
        announce_back_online "maintenance"
        ;;
        
    "countdown")
        minutes="${2:-5}"
        reason="${3:-Scheduled restart}"
        restart_countdown "$minutes" "$reason"
        ;;
        
    "back-online")
        update_type="${2:-general}"
        wait_for_server
        announce_back_online "$update_type"
        ;;
        
    "test")
        echo -e "${BLUE}🧪 Testing announcements...${NC}"
        send_tellraw "🧪 Testing announcement system" "Test" "blue" "white"
        send_tellraw "All systems working!" "Test" "blue" "green"
        ;;
        
    "help"|*)
        echo -e "${BLUE}🔄 Rolling Update Announcer${NC}"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  performance-update    - Full performance update with countdown"
        echo "  mod-update           - Mod update with 10-minute countdown"
        echo "  maintenance [min]    - Maintenance window with custom countdown"
        echo "  countdown [min] [reason] - Just countdown, no deployment"
        echo "  back-online [type]   - Announce server is back (performance/mods/maintenance)"
        echo "  test                 - Test announcement system"
        echo ""
        echo "Examples:"
        echo "  $0 performance-update"
        echo "  $0 maintenance 20"
        echo "  $0 countdown 5 'Emergency fix'"
        echo "  $0 back-online performance"
        ;;
esac 