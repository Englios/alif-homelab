# Tailscale + k3s Networking Setup

This document covers configuring k3s cluster access via Tailscale VPN, including both the control plane (kubectl) and worker node connectivity.

## Overview

When accessing a k3s cluster remotely via Tailscale, two components need configuration:

1. **Control Plane Access** - kubectl connecting to the API server
2. **Worker Node Agent** - k3s-agent connecting to the control plane

## Architecture

```
┌─────────────────┐     Tailscale VPN      ┌─────────────────┐
│   Workstation   │◄──────────────────────►│  Control Plane  │
│   (pop-os)      │                        │    (debian)     │
│                 │                        │                 │
│  kubectl ───────┼───► 100.x.x.x:6443 ───►│  k3s server     │
│  k3s-agent ─────┼───► 100.x.x.x:6443 ───►│                 │
└─────────────────┘                        └─────────────────┘
```

## Prerequisites

- Tailscale installed and authenticated on all nodes
- k3s server running on control plane node
- k3s-agent installed on worker nodes

## Part 1: Control Plane TLS Configuration

### Problem

k3s generates TLS certificates with specific SANs (Subject Alternative Names). By default, the Tailscale IP is not included, causing certificate verification failures.

### Solution: Add Tailscale IP to k3s Server Certificates

On the **control plane node**:

```bash
# 1. Create/update k3s config with Tailscale IP
echo 'tls-san: "<TAILSCALE_IP>"' | sudo tee /etc/rancher/k3s/config.yaml

# 2. Delete old API server certificates (k3s will regenerate)
sudo rm -f /var/lib/rancher/k3s/server/tls/serving-kube-apiserver.crt
sudo rm -f /var/lib/rancher/k3s/server/tls/serving-kube-apiserver.key

# 3. Restart k3s to regenerate certificates
sudo systemctl restart k3s

# 4. Verify new certificate includes Tailscale IP
sudo openssl x509 -in /var/lib/rancher/k3s/server/tls/serving-kube-apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

## Part 2: Kubeconfig Configuration

### Update Local Kubeconfig

On your **workstation**, update the kubeconfig to use the Tailscale IP:

```bash
# Update the cluster server URL
kubectl config set-cluster <CLUSTER_NAME> --server=https://<TAILSCALE_IP>:6443

# Update CA certificate (get from control plane)
# SSH to control plane and run:
#   sudo cat /etc/rancher/k3s/k3s.yaml
# Copy the certificate-authority-data value
```

### Manual Kubeconfig Edit

Edit `~/.kube/config` and ensure the cluster section has:

```yaml
clusters:
- cluster:
    certificate-authority-data: <BASE64_CA_CERT>
    server: https://<TAILSCALE_IP>:6443
  name: homelab
```

**Important**: Get the `certificate-authority-data` from `/etc/rancher/k3s/k3s.yaml` on the control plane after regenerating certificates.

## Part 3: Worker Node Agent Configuration

### Problem

The k3s-agent stores the server URL and needs updating when the network topology changes.

### Solution: Update k3s-agent Environment

On **worker nodes**:

```bash
# 1. Check current configuration
cat /etc/systemd/system/k3s-agent.service.env

# 2. Update the server URL to Tailscale IP
sudo sed -i 's|K3S_URL=.*|K3S_URL=https://<TAILSCALE_IP>:6443|' /etc/systemd/system/k3s-agent.service.env

# 3. Reload systemd and restart agent
sudo systemctl daemon-reload
sudo systemctl restart k3s-agent

# 4. Verify connection
sudo systemctl status k3s-agent
```

### Verify Node Status

From your workstation:

```bash
kubectl get nodes
```

All nodes should show `Ready` status.

## Troubleshooting

### Certificate Verification Failed

```
tls: failed to verify certificate: x509: certificate is valid for X, Y, Z, not <TAILSCALE_IP>
```

**Fix**: Regenerate k3s server certificates with `tls-san` config (Part 1).

### Certificate Signed by Unknown Authority

```
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

**Fix**: Update `certificate-authority-data` in kubeconfig from the control plane's `/etc/rancher/k3s/k3s.yaml`.

### Agent Connection Timeout

```
Failed to validate connection to cluster: context deadline exceeded
```

**Fix**: Update `K3S_URL` in `/etc/systemd/system/k3s-agent.service.env` (Part 3).

### Finding Configuration Files

| Component | Config Location |
|-----------|-----------------|
| k3s server config | `/etc/rancher/k3s/config.yaml` |
| k3s server kubeconfig | `/etc/rancher/k3s/k3s.yaml` |
| k3s-agent env | `/etc/systemd/system/k3s-agent.service.env` |
| k3s-agent load balancer | `/var/lib/rancher/k3s/agent/etc/k3s-agent-load-balancer.json` |
| Local kubeconfig | `~/.kube/config` |

## Security Notes

- Never commit actual Tailscale IPs, tokens, or certificates to version control
- Use environment variables or secrets management for sensitive values
- Tailscale provides encrypted, authenticated connections between nodes
- k3s TLS ensures API server communication is encrypted

## Quick Reference

```bash
# Check Tailscale status and IPs
tailscale status

# Test cluster connectivity
kubectl cluster-info
kubectl get nodes

# Check k3s-agent logs
sudo journalctl -u k3s-agent -f

# Check k3s server logs (on control plane)
sudo journalctl -u k3s -f
```
