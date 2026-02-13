#!/bin/bash
#
# Remote boot Main PC into Linux or Windows from the homelab.
#
# Usage:
#   wol-pc linux      - WOL → LUKS unlock → Pop!_OS ready
#   wol-pc windows    - WOL → LUKS unlock → Pop!_OS → one-shot reboot → Windows
#   wol-pc shutdown   - Gracefully shut down main PC (from Linux)
#   wol-pc status     - Check if main PC is reachable
#   wol-pc --help     - Show this help
#
# Configuration:
#   Copy scripts/wol-pc.conf.example to ~/.config/wol-pc.conf
#   and fill in your values.
#
# Prerequisites:
#   - wakeonlan installed (sudo apt install wakeonlan)
#   - SSH keys configured per your config
#

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
CONFIG_FILE="${HOME}/.config/wol-pc.conf"

MAC=""
IP=""
NET_IF=""
UNLOCK_KEY="$HOME/.ssh/mainpc-unlock"
LINUX_KEY="$HOME/.ssh/main-pc"
UNLOCK_PORT=2222
SSH_PORT=22
SSH_USER=""
BOOT_ENTRY="auto-windows"

WOL_TIMEOUT=60
UNLOCK_TIMEOUT=120
BOOT_TIMEOUT=120

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "${CYAN}[STEP]${NC}  $1"; }

# ── Config Loading ──────────────────────────────────────────────────────────

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi

    if [ -z "$MAC" ] || [ -z "$IP" ] || [ -z "$SSH_USER" ]; then
        error "Missing required config. Copy wol-pc.conf.example to ${CONFIG_FILE} and fill in values."
    fi

    if [ -z "$NET_IF" ]; then
        warn "NET_IF not set, using 'eth0' for shutdown ethtool command"
        NET_IF="eth0"
    fi
}

# ── Helpers ──────────────────────────────────────────────────────────────────

wait_for_port() {
    local host="$1" port="$2" timeout="$3" label="$4"
    local elapsed=0

    step "Waiting for $label ($host:$port) ..."
    while ! nc -z -w1 "$host" "$port" 2>/dev/null; do
        sleep 2
        elapsed=$((elapsed + 2))
        if [ "$elapsed" -ge "$timeout" ]; then
            error "Timed out after ${timeout}s waiting for $label ($host:$port)"
        fi
        printf "."
    done
    echo ""
    info "$label is up (${elapsed}s)"
}

check_prerequisites() {
    command -v wakeonlan >/dev/null 2>&1 || error "wakeonlan not found. Install: sudo apt install wakeonlan"
    command -v nc        >/dev/null 2>&1 || error "nc (netcat) not found. Install: sudo apt install netcat-openbsd"
    [ -f "$UNLOCK_KEY" ]                 || error "Unlock SSH key not found: $UNLOCK_KEY"
    [ -f "$LINUX_KEY" ]                  || error "Linux SSH key not found: $LINUX_KEY"
}

is_linux_up() {
    nc -z -w1 "$IP" "$SSH_PORT" 2>/dev/null
}

is_initramfs_up() {
    nc -z -w1 "$IP" "$UNLOCK_PORT" 2>/dev/null
}

# ── Actions ──────────────────────────────────────────────────────────────────

send_wol() {
    step "Sending WOL magic packet to $MAC ..."
    wakeonlan "$MAC"
}

unlock_luks() {
    step "LUKS unlock via passfifo (dropbear on port $UNLOCK_PORT)"
    echo ""
    echo -e "${YELLOW}Enter LUKS passphrase for main PC:${NC}"
    read -rs PASSPHRASE
    echo ""

    if [ -z "$PASSPHRASE" ]; then
        error "Passphrase cannot be empty"
    fi

    echo -n "$PASSPHRASE" | ssh \
        -i "$UNLOCK_KEY" \
        -p "$UNLOCK_PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        root@"$IP" \
        "cat > /lib/cryptsetup/passfifo"

    info "Passphrase sent — disk should be unlocking"
    unset PASSPHRASE
}

boot_linux() {
    send_wol

    if is_linux_up; then
        info "Main PC is already up (Linux SSH responding)"
        return
    fi

    wait_for_port "$IP" "$UNLOCK_PORT" "$WOL_TIMEOUT" "dropbear (initramfs)"

    unlock_luks

    wait_for_port "$IP" "$SSH_PORT" "$BOOT_TIMEOUT" "Linux SSH"

    info "Main PC is up and running Pop!_OS"
}

boot_windows() {
    boot_linux

    step "Setting one-shot boot to Windows and rebooting ..."
    ssh -t \
        -i "$LINUX_KEY" \
        -o StrictHostKeyChecking=accept-new \
        -o LogLevel=ERROR \
        "$SSH_USER@$IP" \
        "sudo bootctl set-oneshot $BOOT_ENTRY && sudo reboot"

    info "Main PC is rebooting into Windows"
    info "Steam should auto-launch once Windows boots"
}

switch_windows() {
    if ! is_linux_up; then
        error "Main PC is not running Linux. Use 'wol-pc windows' to wake from off state."
    fi

    step "Already on Linux — switching directly to Windows ..."
    ssh -t \
        -i "$LINUX_KEY" \
        -o StrictHostKeyChecking=accept-new \
        -o LogLevel=ERROR \
        "$SSH_USER@$IP" \
        "sudo bootctl set-oneshot $BOOT_ENTRY && sudo reboot"

    info "Main PC is rebooting into Windows"
    info "Steam should auto-launch once Windows boots"
}

shutdown_pc() {
    if ! is_linux_up; then
        error "Main PC is not reachable on Linux SSH ($IP:$SSH_PORT)"
    fi

    step "Shutting down main PC ..."
    ssh -t \
        -i "$LINUX_KEY" \
        -o StrictHostKeyChecking=accept-new \
        -o LogLevel=ERROR \
        "$SSH_USER@$IP" \
        "sudo ethtool -s $NET_IF wol g && sudo shutdown +0" || true

    info "Shutdown command sent"
}

show_status() {
    echo -e "${CYAN}Main PC Status${NC} ($IP)"
    echo "───────────────────────────"

    if is_linux_up; then
        echo -e "  Linux SSH (port $SSH_PORT):     ${GREEN}UP${NC}"
    else
        echo -e "  Linux SSH (port $SSH_PORT):     ${RED}DOWN${NC}"
    fi

    if is_initramfs_up; then
        echo -e "  Initramfs (port $UNLOCK_PORT): ${YELLOW}WAITING FOR UNLOCK${NC}"
    else
        echo -e "  Initramfs (port $UNLOCK_PORT): ${RED}DOWN${NC}"
    fi
}

usage() {
    cat << EOF
Usage: wol-pc <command> [options]

Commands:
  linux          Boot into Pop!_OS (WOL → LUKS unlock → SSH ready)
  windows        Boot into Windows (from off: WOL → LUKS unlock → reboot)
  switch_to_windows  Switch to Windows (from Linux: direct reboot to Windows)
  shutdown       Gracefully shut down main PC
  status         Check if main PC is reachable
  --help         Show this help

Options:
  --config   Path to config file (default: ~/.config/wol-pc.conf)

Examples:
  wol-pc linux           # Wake and boot into Linux
  wol-pc windows         # Wake from off, boot Linux, then reboot into Windows
  wol-pc switch_to_windows  # Already on Linux — reboot directly into Windows
  wol-pc status          # Quick connectivity check
  wol-pc --config /path/to/custom.conf status

Configuration:
  Copy scripts/wol-pc.conf.example to ~/.config/wol-pc.conf
  and fill in your values (MAC, IP, SSH keys, etc.)
EOF
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    load_config
    check_prerequisites

    case "$1" in
        linux)    boot_linux    ;;
        windows)  boot_windows  ;;
        switch_to_windows) switch_windows ;;
        shutdown) shutdown_pc   ;;
        status)   show_status   ;;
        *)
            error "Unknown command: $1"
            ;;
    esac
}

main "$@"
