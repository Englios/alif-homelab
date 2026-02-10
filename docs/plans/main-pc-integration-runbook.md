# 🎮 Main PC Integration Runbook

> **Status**: Future Implementation Plan  
> **Scope**: WOL + Linux/Windows Dual-Boot + ML Workloads + Gaming  
> **Last Updated**: 2026-02-10

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
# Check current WOL settings
sudo ethtool -k eth0

# Enable WOL on the interface
sudo ethtool -s eth0 wol g
```

**Persist with NetworkManager:**

Create a dispatcher script or use NetworkManager connection settings to persist WOL across reboots.

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
wakeonlan AA:BB:CC:DD:EE:FF
```

> **Replace** `AA:BB:CC:DD:EE:FF` with your main PC's MAC address

**Success Indicator:** PC powers on → WOL configuration is complete

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
- Windows Boot Manager

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

## 6️⃣ Windows Configuration (Headless Gaming)

### Auto-Login

1. Press `Win + R` → type `netplwiz` → Enter
2. Uncheck "Users must enter a user name and password..."
3. Enter credentials and apply

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
Steam Deck → tap Connect
        ↓
Homelab sends WOL
        ↓
PC boots → Linux
        ↓
Linux triggers one-shot Windows reboot
        ↓
Windows auto-logs in
        ↓
Steam launches
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
- [ ] Ethernet cable connected to main PC
- [ ] Validate WOL LED indicators when PC is off
- [ ] Document MAC address of main PC

### Phase 2: BIOS Configuration
- [ ] Enable Wake on LAN
- [ ] Enable Wake from S5
- [ ] Enable Power on by PCI-E / LAN
- [ ] Enable NIC power in off state
- [ ] Disable Deep sleep / ErP

### Phase 3: OS Configuration
- [ ] Configure WOL on Pop!_OS
- [ ] Configure WOL on Windows
- [ ] Disable Windows Fast Startup
- [ ] Test WOL from homelab

### Phase 4: Bootloader Setup
- [ ] Verify systemd-boot entries
- [ ] Test one-shot Windows boot
- [ ] Document boot commands

### Phase 5: Windows Gaming Setup
- [ ] Configure Windows auto-login
- [ ] Install and configure Steam
- [ ] Enable Remote Play
- [ ] Test Steam Link connectivity

### Phase 6: Kubernetes Integration
- [ ] Join main PC as k8s worker node
- [ ] Configure default cordon state
- [ ] Create drain/uncordon scripts
- [ ] Test pod eviction behavior

### Phase 7: ML Safety
- [ ] Set up object storage (MinIO)
- [ ] Configure training checkpoint logic
- [ ] Test checkpoint resume after reboot
- [ ] Document recovery procedures

### Phase 8: Full Integration Test
- [ ] Test Steam Deck → WOL → Windows flow
- [ ] Test ML training → checkpoint → drain → game → resume flow
- [ ] Document end-to-end timing

---

## 🛠️ Helper Scripts

### WOL Trigger Script (on Homelab)

```bash
#!/bin/bash
# /usr/local/bin/wake-main-pc.sh

MAC_ADDRESS="AA:BB:CC:DD:EE:FF"

if ! command -v wakeonlan &> /dev/null; then
    echo "wakeonlan not installed. Installing..."
    sudo apt update && sudo apt install -y wakeonlan
fi

echo "Sending WOL magic packet to $MAC_ADDRESS..."
wakeonlan "$MAC_ADDRESS"
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
| Physical Ethernet solves WOL cleanly | ⬜ Pending |
| Linux-first workflow preserved | ⬜ Pending |
| Windows isolated to gaming | ⬜ Pending |
| Kubernetes behaves correctly | ⬜ Pending |
| ML jobs are restart-safe | ⬜ Pending |
| Steam Deck experience is smooth | ⬜ Pending |

---

**This is a mature homelab + dev + gaming architecture. Implement when ready!** 🚀🎮💻
