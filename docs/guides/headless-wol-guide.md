# Headless WOL Unlock — Build Guide

Remotely boot a headless Linux PC with encrypted disk (LUKS) from a homelab, with optional Windows switch.

---

## What You'll Build

```
[Homelab] --WOL--> [Main PC] --SSH (initramfs)--> [Unlock LUKS] --> [Linux]
                |                                            |
                +-----------------> [bootctl set-oneshot] --> [Windows]
```

---

## Prerequisites

| Item | Description |
|------|-------------|
| **Target PC** | Linux (Pop!_OS/Ubuntu) with LUKS encryption, systemd-boot |
| **Network** | Wired ethernet (WiFi can't do WOL) |
| **Homelab** | Always-on Linux machine to send WOL commands |
| **Tailscale** | For remote access (optional but recommended) |

---

## Step 1: Enable Wake on LAN (Target PC)

### BIOS/UEFI Settings

Enable:

- Wake on LAN
- Wake from S5
- Power on by PCI-E / LAN
- NIC power in off state

Disable:

- ErP / Deep sleep (kills NIC standby power)

### Linux Side

```bash
# Find your wired interface
ip -br link
# e.g., enp6s0

# Check WOL support
sudo ethtool enp6s0 | grep Wake-on

# Enable WOL
sudo ethtool -s enp6s0 wol g

# Persist with NetworkManager
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
```

### Test WOL

From homelab:

```bash
wakeonlan xx:xx:xx:xx:xx:xx  # your MAC address
```

---

## Step 2: Remote LUKS Unlock (Dropbear + Passfifo)

### Install Packages

```bash
sudo apt install dropbear-initramfs cryptsetup-initramfs
```

### Generate SSH Keys (on Homelab)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/pc-unlock -C "headless-unlock"
```

### Add Key to Target PC

```bash
# Copy public key to target PC's initramfs authorized_keys
sudo nano /etc/dropbear/initramfs/authorized_keys
# Paste contents of ~/.ssh/pc-unlock.pub
```

### Configure Dropbear

```bash
echo 'DROPBEAR_OPTIONS="-p 2222 -s -j -k"' | sudo tee /etc/dropbear/initramfs/dropbear.conf
```

### Configure Crypttab

```bash
# Add 'initramfs' flag to your LUKS entry
# sudo blkid to find your LUKS UUID
sudo nano /etc/crypttab
# Example:
# cryptdata UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx none luks,initramfs
```

### Add Network to Initramfs

Edit kernel boot entries in `/boot/efi/loader/entries/`:

```diff
- options   root=... ro quiet splash
+ options   root=... ro quiet splash ip=dhcp
```

### Rebuild Initramfs

```bash
sudo update-initramfs -u
```

### Test Unlock

After WOL, wait for port 2222:

```bash
nc -z 192.168.x.x 2222
```

Unlock:

```bash
echo -n 'your-luks-passphrase' | ssh -i ~/.ssh/pc-unlock -p 2222 root@192.168.x.x \
    "cat > /lib/cryptsetup/passfifo"
```

---

## Step 3: Windows Dual-Boot (Optional)

### Copy Windows Bootloader

```bash
# Find Windows ESP
sudo blkid | grep -i windows

# Mount and copy
sudo mount /dev/nvme0n1p1 /mnt/win-esp
sudo cp -a /mnt/win-esp/EFI/Microsoft /boot/efi/EFI/
sudo umount /mnt/win-esp
```

### One-Shot Boot

```bash
sudo bootctl set-oneshot auto-windows
sudo reboot
```

### Auto-Login + Steam

1. Create dedicated Windows user "steam"
2. `netplwiz` → auto-login for steam user
3. Install Steam → start on login → enable Remote Play

---

## Step 4: Homelab Command Script

### Install

```bash
# Copy script
cp scripts/wol-pc.sh /usr/local/bin/wol-pc
chmod +x /usr/local/bin/wol-pc

# Copy config
cp scripts/wol-pc.conf.example ~/.config/wol-pc.conf
nano ~/.config/wol-pc.conf
```

### Config Example

```bash
MAC="xx:xx:xx:xx:xx:xx"
IP="192.168.1.xx"
NET_IF="enp6s0"
UNLOCK_KEY="$HOME/.ssh/pc-unlock"
LINUX_KEY="$HOME/.ssh/your-key"
SSH_USER="your-username"
```

### Usage

```bash
wol-pc linux            # Wake from off → boot Linux
wol-pc windows          # Wake from off → boot Linux → reboot to Windows  
wol-pc switch_to_windows  # Already on Linux → reboot to Windows
wol-pc shutdown         # Shutdown
wol-pc status          # Check status
```

---

## Tips

- Use Steam Link app on Steam Deck/phone/PC to connect to Windows
- Shutdown Windows via Steam Link's power menu (cleaner than SSH shutdown)
- Set `systemd.link` for robust WOL persistence if needed

---

## Related

- [Overview](./headless-wol-overview.md)
- [Runbook](../plans/headless-wol-runbook.md)
