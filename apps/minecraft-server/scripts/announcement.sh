#!/bin/bash

# Simple RCON announcement script for Minecraft server using tellraw
# Usage: ./announcement.sh "Your message here"

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="minecraft"
DEPLOYMENT="minecraft-server"

# Function to send tellraw command with proper JSON formatting
send_tellraw() {
    local message="$1"
    local prefix_text="$2"
    local prefix_color="$3"
    local message_color="$4"
    
    echo -e "${BLUE}📢 Sending: ${NC}[$prefix_text] $message"
    
    # Send clean message to players (no log entry)
    kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- \
      rcon-cli tellraw @a "[{\"text\":\"[$prefix_text] \",\"color\":\"$prefix_color\",\"bold\":true},{\"text\":\"$message\",\"color\":\"$message_color\"}]"
    
    # Optional: Log to server console for admin visibility
    kubectl exec deployment/$DEPLOYMENT -n $NAMESPACE -- \
      rcon-cli say "[ADMIN LOG] Sent: [$prefix_text] $message" >/dev/null 2>&1 || true
    
    sleep 1
}

# Check if message provided
if [ -z "$1" ]; then
    echo "Usage: $0 \"Your message here\""
    echo ""
    echo "Examples:"
    echo "  $0 \"Welcome to the server!\""
    echo "  $0 \"Server restart in 5 minutes\""
    echo ""
    echo "Pre-made announcements:"
    echo "  $0 voice-chat    - Announce voice chat feature"
    echo "  $0 welcome       - Send welcome message"
    echo "  $0 restart       - Announce server restart"
    exit 1
fi

# Pre-made announcements with proper colors
case "$1" in
    "voice-chat"|"voice"|"vc")
        echo -e "${GREEN}🎤 Announcing Voice Chat feature...${NC}"
        send_tellraw "🎤 Simple Voice Chat is now available!" "Server" "gold" "green"
        send_tellraw "Press V to open voice settings" "Server" "gold" "aqua"
        send_tellraw "Press G to create/join voice groups" "Server" "gold" "gray"
        send_tellraw "💡 Tip: Use headphones for best experience!" "Tip" "yellow" "yellow"
        ;;
    "welcome")
        echo -e "${GREEN}👋 Sending welcome message...${NC}"
        send_tellraw "Welcome to MAAF Server!" "Welcome" "gold" "green"
        send_tellraw "🎤 Voice chat available - Press V!" "Welcome" "gold" "aqua"
        send_tellraw "Better MC Forge BMC4 with 200+ mods" "Welcome" "gold" "gray"
        ;;
    "restart")
        echo -e "${GREEN}🔄 Announcing server restart...${NC}"
        send_tellraw "⚠️ Server will restart in 5 minutes" "Restart" "red" "red"
        send_tellraw "Please save your progress now!" "Restart" "red" "yellow"
        ;;
    "maintenance")
        echo -e "${GREEN}🔧 Announcing maintenance...${NC}"
        send_tellraw "🔧 Server maintenance starting soon" "Maintenance" "yellow" "yellow"
        send_tellraw "Brief downtime expected" "Maintenance" "yellow" "gray"
        ;;
    "update")
        echo -e "${GREEN}📦 Announcing update...${NC}"
        send_tellraw "📦 Server has been updated!" "Update" "green" "green"
        send_tellraw "New features and improvements available" "Update" "green" "gray"
        ;;
    *)
        # Custom message with [Admin] prefix
        echo -e "${GREEN}📢 Sending custom message...${NC}"
        send_tellraw "$1" "Admin" "gold" "white"
        ;;
esac

echo -e "${GREEN}✅ Announcement sent!${NC}"