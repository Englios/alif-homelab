# 🎮 Main PC Integration Runbook

> **Status**: In Progress (Phases 1–5 complete, remote boot operational)  
> **Scope**: WOL + Linux/Windows Dual-Boot + ML Workloads + Gaming  
> **Last Updated**: 2026-02-12

---

## 🧭 High-Level Architecture

```
Steam Deck / Laptop / Phone
            |
        Tailscale
            |
    [ Homelab (always on) ]
            |
       Ethernet (WOL)
            |
        [ Main PC ]
          - Pop!_OS (default, encrypted)
          - Windows (gaming only)
          - GPU k8s worker (ephemeral)
```

---

## 1️⃣ Physical Setup

### Hardware Configuration

✅ **Ethernet cable connected to main PC**

**Connection Options:**
- **Option A**: PC → router/switch (recommended)
- **Option B**: PC → homelab directly (acceptable)

**Notes:**
- Main PC may still use Wi-Fi for normal traffic
- Ethernet is primarily for WOL + standby power

### Validation

When the PC is powered off:

- Ethernet port LEDs should be **on or blinking**
- If LEDs are dark → WOL will not work

---

## 2️⃣ BIOS / Firmware Configuration

### Enable in BIOS/UEFI

| Setting | Status |
|---------|--------|
| Wake on LAN | ✅ Enable |
| Wake from S5 | ✅ Enable |
| Power on by PCI-E / LAN | ✅ Enable |
| NIC power in off state | ✅ Enable |

### Disable

| Setting | Status |
|---------|--------|
| Deep sleep / ErP | ❌ Disable |

---

## 3️⃣ OS-Level WOL Configuration

### On Linux (Pop!_OS)

```bash
# Find the wired interface name (ex: enp6s0)
ip -br link

# Check WOL support + current setting
sudo ethtool enp6s0 | egrep -i "Supports Wake-on|Wake-on"

# Enable WOL (magic packet)
sudo ethtool -s enp6s0 wol g

# Verify
sudo ethtool enp6s0 | egrep -i "Supports Wake-on|Wake-on"
```

**Persist with NetworkManager:**

```bash
# Replace connection name if different
nmcli -f DEVICE,TYPE,STATE,CONNECTION dev
nmcli connection modify "Wired connection 1" 802-3-ethernet.wake-on-lan magic
nmcli connection down "Wired connection 1" && nmcli connection up "Wired connection 1"
sudo ethtool enp6s0 | egrep -i "Supports Wake-on|Wake-on"
```

### On Windows

**Device Manager Configuration:**

1. Open Device Manager → Network Adapter → Properties
2. Power Management tab:
   - ✅ Allow this device to wake the computer
   - ✅ Only allow a magic packet
   - ❌ Uncheck "Allow the computer to turn off this device to save power"

**Disable Fast Startup:**

1. Control Panel → Power Options → Choose what power buttons do
2. Click "Change settings currently unavailable"
3. Uncheck "Turn on fast startup"

---

## 4️⃣ Homelab = WOL Gateway

### Install WOL Tool

```bash
sudo apt install wakeonlan
```

### Test WOL (PC powered off)

```bash
wakeonlan 34:5a:60:62:88:c8
```

> **Main PC MAC (wired / enp6s0):** `34:5a:60:62:88:c8`

**Success Indicator:** PC powers on → WOL configuration is complete

### ⚠️ Critical: Make WOL Survive Shutdown

The NetworkManager `wake-on-lan magic` setting can be reset to `d` (disabled) after a `sudo shutdown now` from SSH. To make WOL truly persistent:

**Option A: systemd.link (recommended)**

Create `/etc/systemd/network/50-wired.link`:

```bash
# On main PC:
sudo tee /etc/systemd/network/50-wired.link << 'EOF'
[Match]
MACAddress=34:5a:60:62:88:c8

[Link]
NamePolicy=kernel database onboard slot path
MACAddressPolicy=persistent
WakeOnLan=magic
EOF
```

This sets WOL at the link level, independent of NetworkManager, and survives any shutdown method.

**Verify after reboot:**
```bash
sudo ethtool enp6s0 | grep Wake-on
# Should show: Wake-on: g
```

**Option B: Add to shutdown command** (belt-and-suspenders)

If using Option A, this is optional. In `wol-pc` script, the shutdown command already includes:
```bash
sudo ethtool -s $NET_IF wol g && sudo shutdown +0
```

This ensures WOL is re-enabled right before shutdown.

---

## 5️⃣ Bootloader Strategy

### Reality Check

Pop!_OS uses **systemd-boot**, which supports one-time OS selection.

### List Available Entries

```bash
bootctl list
```

**Expected output:**
- Pop!_OS
- Windows Boot Manager (after adding an entry)

### Add Windows entry (systemd-boot)

If Windows is installed on a different EFI System Partition (ESP), `bootctl list` may not show Windows until the Windows bootloader is available on the ESP mounted at `/boot/efi`.

**Copy the Microsoft EFI folder to Pop!_OS ESP:**

```bash
# Find the Windows ESP from NVRAM output
sudo efibootmgr -v | grep -i "Windows Boot Manager"

# Example PARTUUID seen in efibootmgr output:
WIN_PARTUUID="ab63e5dc-1de4-407f-b73e-2fd877c362a2"
WIN_DEV="$(sudo blkid -t PARTUUID="$WIN_PARTUUID" -o device)"

sudo mkdir -p /mnt/win-esp
sudo mount -t vfat "$WIN_DEV" /mnt/win-esp
sudo ls -l /mnt/win-esp/EFI/Microsoft/Boot/bootmgfw.efi

sudo cp -a /mnt/win-esp/EFI/Microsoft /boot/efi/EFI/
sudo umount /mnt/win-esp
```

Then refresh systemd-boot and confirm Windows is auto-detected:

```bash
sudo bootctl update
sudo bootctl list
```

### One-Shot Windows Boot

```bash
# Set Windows for next boot only
sudo bootctl set-oneshot auto-windows
sudo reboot
```

**Behavior:**
- Next boot → Windows
- After shutdown → default returns to Linux

---

## 5️⃣.5️⃣ Remote LUKS Unlock (Headless Boot)

Pop!_OS uses full-disk encryption (LUKS2 with argon2id). Without remote unlock, the PC halts at the passphrase prompt after WOL — making headless operation impossible.

### Solution: Dropbear in Initramfs + Passfifo

Install `dropbear-initramfs` on the main PC so that a lightweight SSH server runs during early boot, before the root filesystem is unlocked.

### Setup (on Main PC)

```bash
# Install packages
sudo apt install -y dropbear-initramfs cryptsetup-initramfs

# Generate a dedicated unlock key on the homelab
# (on homelab): ssh-keygen -t ed25519 -f ~/.ssh/mainpc-unlock -C "mainpc-luks-unlock"

# Add the homelab's unlock public key
sudo nano /etc/dropbear/initramfs/authorized_keys
# Paste contents of ~/.ssh/mainpc-unlock.pub

# Configure dropbear to run on port 2222 (avoid conflict with main SSH on 22)
echo 'DROPBEAR_OPTIONS="-p 2222 -s -j -k"' | sudo tee /etc/dropbear/initramfs/dropbear.conf

# Ensure cryptsetup knows to pause for unlock in initramfs
# Edit /etc/crypttab — add 'initramfs' flag:
#   cryptdata UUID=9f576e5b-4b3f-47a7-afa8-6436dca2f1b7 none luks,initramfs

# Add ip=dhcp to kernel options so initramfs gets a network address
# Edit /boot/efi/loader/entries/Pop_OS-current.conf — append 'ip=dhcp' to the options line
# Do the same for Pop_OS-oldkern.conf

# Rebuild initramfs
sudo update-initramfs -u
```

### Unlock Method: Passfifo

> **Important:** `cryptroot-unlock` does NOT work with LUKS2 + argon2id KDF (it hangs). Use passfifo instead.

```bash
# From the homelab, SSH into dropbear and write the passphrase to passfifo:
echo -n 'your-passphrase' | ssh -i ~/.ssh/mainpc-unlock -p 2222 root@192.168.68.66 \
    "cat > /lib/cryptsetup/passfifo"
```

### Key Details

| Item | Value |
|------|-------|
| Homelab unlock key | `~/.ssh/mainpc-unlock` (ed25519) |
| Dropbear port | `2222` |
| LUKS UUID | `9f576e5b-4b3f-47a7-afa8-6436dca2f1b7` |
| LUKS version | LUKS2 (argon2id PBKDF) |
| Unlock method | passfifo (`/lib/cryptsetup/passfifo`) |
| `cryptroot-unlock` | ❌ Hangs — do not use |

---

## 6️⃣ Windows Configuration (Headless Gaming)

### Auto-Login

1. Press `Win + R` → type `netplwiz` → Enter
2. Uncheck "Users must enter a user name and password..."
3. Enter credentials and apply

**Note:** auto-login is more reliable if the `steam` user has a password (blank password often breaks auto-login). If `netplwiz` is blocked, disable the Windows Hello requirement in Settings → Accounts → Sign-in options.

### Steam Configuration

| Setting | Value |
|---------|-------|
| Start Steam on login | ✅ Enable |
| Enable Remote Play | ✅ Enable |
| Start in Big Picture Mode | ✅ Optional |

**Result:** Windows behaves like a console OS

---

## 7️⃣ Steam Deck / Steam Link Flow

### Complete Gaming Workflow

```
Steam Deck / Laptop / Phone
        ↓
  wol-pc windows       (from homelab or via Tailscale SSH)
        ↓
  WOL magic packet → PC powers on
        ↓
  Dropbear SSH (port 2222) → LUKS passphrase via passfifo
        ↓
  Pop!_OS boots → SSH available (port 22)
        ↓
  bootctl set-oneshot auto-windows → reboot
        ↓
  Windows auto-logs into 'steam' user
        ↓
  Steam launches → Remote Play available
        ↓
  Steam Link connects 🎮
```

### After Gaming

```bash
# In Windows, run:
shutdown /s /t 0
```

**Next WOL:** Boots into Linux again

---

## 8️⃣ Kubernetes & ML Safety

### Mental Model

> **Gaming = node maintenance / failure**

Design for it.

### Default Node State

```bash
# Keep node cordoned by default
kubectl cordon main-pc
```

**Node Status:**
- ✅ Online
- ❌ No new workloads scheduled

### Before Switching to Game Mode

```bash
# Drain node gracefully
kubectl drain main-pc --ignore-daemonsets --delete-emptydir-data
```

**What this does:**
- Sends SIGTERM to pods
- Lets training checkpoint
- Evicts workloads cleanly

### After Gaming (Back in Linux)

```bash
# Make GPU schedulable again
kubectl uncordon main-pc
```

---

## 9️⃣ ML Checkpoint Strategy

### Storage Best Practices

| Approach | Status |
|----------|--------|
| Checkpoints only on node SSD | ❌ Do NOT do this |
| Object storage (S3-compatible) | ✅ Recommended |

### Recommended Setup

- **Storage**: S3-compatible object storage
- **Location**: Hosted on homelab nodes (MinIO, etc.)
- **Training Logic**: Resume if checkpoint exists, restart safely after reboot

### Benefits

- ✅ Reboots are safe
- ✅ Gaming is non-destructive
- ✅ Node loss is boring (not catastrophic)

---

## 🔁 End-to-End Lifecycle

### Normal Day

```
Linux boots
    ↓
Node cordoned by default
```

### Need ML Training

```
uncordon → train → checkpoints saved to object storage
```

### Want to Game

```
cordon → drain → reboot → Windows → Steam Link
```

### Done Gaming

```
shutdown → WOL → Linux → uncordon
```

---

## ✅ Implementation Checklist

### Phase 1: Hardware Setup
- [x] Ethernet cable connected to main PC
- [x] Validate WOL LED indicators when PC is off
- [x] Document MAC address of main PC (`34:5a:60:62:88:c8`)

### Phase 2: BIOS Configuration
- [x] Enable Wake on LAN
- [x] Enable Wake from S5
- [x] Enable Power on by PCI-E / LAN
- [x] Enable NIC power in off state
- [x] Disable Deep sleep / ErP

### Phase 3: OS Configuration
- [x] Configure WOL on Pop!_OS (enp6s0)
- [x] Create systemd.link for persistent WOL (`/etc/systemd/network/50-wired.link`)
- [x] Configure WOL on Windows
- [x] Disable Windows Fast Startup
- [x] Test WOL from homelab (suspend + shutdown/S5)

### Phase 4: Bootloader Setup
- [x] Verify systemd-boot entries
- [x] Test one-shot Windows boot (auto-windows)
- [x] Document boot commands
- [x] Copy Windows ESP (`EFI/Microsoft`) to Pop!_OS ESP

### Phase 4.5: Remote LUKS Unlock
- [x] Install dropbear-initramfs + cryptsetup-initramfs
- [x] Configure dropbear on port 2222
- [x] Add homelab unlock key to authorized_keys
- [x] Add `initramfs` flag to /etc/crypttab
- [x] Add `ip=dhcp` to kernel options (Pop_OS-current + oldkern)
- [x] Rebuild initramfs
- [x] Test passfifo unlock from homelab

### Phase 5: Windows Gaming Setup
- [x] Configure Windows auto-login (steam user)
- [x] Install and configure Steam
- [x] Enable Remote Play
- [x] Test Steam Link connectivity

### Phase 5.5: Homelab Remote Boot Command
- [x] Create `wol-pc` script (`scripts/wol-pc.sh`)
- [x] Create config template (`scripts/wol-pc.conf.example`)
- [x] Copy script to homelab PATH
- [x] Create `~/.config/wol-pc.conf` with your values
- [x] Test `wol-pc status`
- [x] Test `wol-pc linux` end-to-end (WOL → LUKS → SSH)
- [x] Test `wol-pc windows` end-to-end (WOL → LUKS → Windows reboot)
- [x] Test Steam Link connectivity (works!)
- [x] Create systemd.link for robust WOL persistence
- [x] Test `wol-pc shutdown` → verify WOL still works after boot

### Phase 6: Kubernetes Integration
- [x] Join main PC as k8s worker node
- [x] Configure default cordon state
- [x] Create drain/uncordon scripts
- [ ] Test pod eviction behavior

### Phase 7: ML Safety
- [ ] Set up object storage (MinIO)
- [ ] Configure training checkpoint logic
- [ ] Test checkpoint resume after reboot
- [ ] Document recovery procedures

### Phase 8: Full Integration Test
- [x] Test Steam Deck → WOL → Windows flow
- [ ] Test ML training → checkpoint → drain → game → resume flow
- [ ] Document end-to-end timing

---

## 🛠️ Helper Scripts

### `wol-pc` — Unified Remote Boot Command (on Homelab)

Located at [`scripts/wol-pc.sh`](../../scripts/wol-pc.sh). Handles the full lifecycle from the homelab.

**Install:**

```bash
# Copy script to PATH
sudo cp scripts/wol-pc.sh /usr/local/bin/wol-pc
sudo chmod +x /usr/local/bin/wol-pc

# Copy config template and fill in your values
cp scripts/wol-pc.conf.example ~/.config/wol-pc.conf
nano ~/.config/wol-pc.conf
```

**Config file** (`~/.config/wol-pc.conf`):

```bash
MAC="34:5a:60:62:88:c8"
IP="192.168.68.66"
NET_IF="enp6s0"
UNLOCK_KEY="$HOME/.ssh/mainpc-unlock"
LINUX_KEY="$HOME/.ssh/main-pc"
UNLOCK_PORT=2222
SSH_PORT=22
SSH_USER="alif-pc"
BOOT_ENTRY="auto-windows"
```

**Usage:**

```bash
wol-pc linux      # WOL → LUKS unlock → Pop!_OS ready
wol-pc windows    # WOL → LUKS unlock → Pop!_OS → one-shot reboot → Windows
wol-pc shutdown   # Gracefully shut down main PC
wol-pc status     # Check if main PC is reachable
wol-pc --help    # Show full help
```

### Game Mode Transition Script (on Main PC)

```bash
#!/bin/bash
# /usr/local/bin/enter-game-mode.sh

# Cordon and drain the node
echo "Cordoning node..."
kubectl cordon $(hostname)

echo "Draining node..."
kubectl drain $(hostname) --ignore-daemonsets --delete-emptydir-data --force

# Set one-shot Windows boot
echo "Setting one-shot Windows boot..."
sudo bootctl set-oneshot auto-windows

# Reboot
echo "Rebooting in 5 seconds..."
sleep 5
sudo reboot
```

### Post-Gaming Recovery Script (on Main PC)

```bash
#!/bin/bash
# /usr/local/bin/exit-game-mode.sh

# Uncordon the node
echo "Uncordoning node..."
kubectl uncordon $(hostname)

echo "Node is now schedulable for ML workloads"
kubectl get nodes
```

---

## 🚨 Troubleshooting

### LUKS Unlock Fails

1. Verify dropbear is listening: `nc -z 192.168.68.66 2222`
2. Check that `ip=dhcp` is in kernel options (no IP = no network in initramfs)
3. Ensure `initramfs` flag is in `/etc/crypttab`
4. Do NOT use `cryptroot-unlock` — it hangs with LUKS2 + argon2id
5. Use passfifo method: `echo -n 'pass' | ssh -p 2222 root@IP "cat > /lib/cryptsetup/passfifo"`
6. After initramfs changes, always `sudo update-initramfs -u`

### WOL Not Working

1. Check Ethernet LEDs when PC is off
2. Verify MAC address is correct
3. Test with `ethtool` on Linux side
4. Check BIOS settings for WOL options

### Windows Doesn't Auto-Login

1. Verify netplwiz settings
2. Check for Windows Hello conflicts
3. Ensure password is not blank

### Steam Link Won't Connect

1. Verify Windows firewall rules
2. Check Steam Remote Play settings
3. Test on same network first
4. Verify Tailscale connectivity

### Pods Not Evicting

1. Check for pods with local storage
2. Use `--force` flag if necessary
3. Verify PDBs (Pod Disruption Budgets) aren't blocking
4. Check for finalizers

### Checkpoints Not Resuming

1. Verify object storage connectivity
2. Check checkpoint file permissions
3. Validate training script resume logic
4. Test manual checkpoint save/load

---

## 📚 Related Documentation

- [Overview](./overview.md) - Project overview and current status
- [Next Steps](./next-steps.md) - Roadmap and implementation priorities
- [Setup](./setup.md) - Current system configuration
- [Tailscale K3s Networking](./tailscale-k3s-networking.md) - VPN setup

---

## 🎯 Success Criteria

| Criteria | Status |
|----------|--------|
| Physical Ethernet solves WOL cleanly | ✅ Done |
| WOL persists after shutdown (systemd.link) | ✅ Done |
| Linux-first workflow preserved | ✅ Done |
| Remote headless boot (LUKS unlock) | ✅ Done |
| Windows isolated to gaming | ✅ Done (one-shot boot) |
| `wol-pc` command works from homelab | ✅ Done |
| Steam Link connectivity works | ✅ Done |
| Kubernetes behaves correctly | ✅ Done (joined as worker) |
| ML jobs are restart-safe | ⬜ Pending |
| Steam Deck experience is smooth | ✅ Done |

---

**This is a mature homelab + dev + gaming architecture. Implement when ready!** 🚀🎮💻
