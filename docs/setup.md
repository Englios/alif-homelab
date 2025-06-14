# Homelab Setup Guide

## k3s Installation

### Manual Installation Process

**Step 1: SSH into homelab server**
```bash
ssh homelab  # Using SSH alias
```

**Step 2: Install k3s with Traefik disabled**
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -
```

**Step 3: Verify installation**
```bash
sudo systemctl status k3s
sudo kubectl get nodes
```

**Step 4: Copy kubeconfig to local machine**
```bash
# On homelab server:
sudo cat /etc/rancher/k3s/k3s.yaml

# Copy content and save to ~/.kube/config on WSL
# Update server IP from 127.0.0.1 to your HOMELAB_IP
```

### Installation Status
- [ ] k3s installed on homelab server
- [ ] kubeconfig copied to WSL
- [ ] kubectl connectivity verified

### Next Steps
- Install ingress controller (nginx-ingress)
- Set up persistent storage
- Deploy first application (Minecraft server) 