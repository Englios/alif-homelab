# Homelab Kubernetes Setup Guide

## ✅ Completed Setup

### Infrastructure

- [x] **k3s cluster** - Running on Debian homelab server
- [x] **Remote kubectl access** - Configured from WSL
- [x] **SSH access** - Key-based authentication, password disabled
- [x] **Firewall** - UFW enabled with necessary ports open
- [x] **Tailscale VPN** - Secure remote access from anywhere

### Applications

- [x] **Minecraft Server** - Java Edition 1.20.1 + Forge 47.2.0
- [x] **Persistent Storage** - 20GB PVC for world data
- [x] **External Access** - rtun reverse tunnel for friends
- [x] **Resource Management** - CPU/memory limits configured

## 🚀 Current Architecture

```
Internet → rtun tunnel → Homelab → k3s → Minecraft Pod
```

### Network Access

- **Local**: `minecraft-server.minecraft.svc.cluster.local:25565`
- **External**: Via rtun tunnel (ports 35000/tcp, 35001/udp)
- **Remote SSH**: Via Tailscale VPN

## 📁 Repository Structure

```
homelab-k8s/
├── apps/minecraft-server/     # Minecraft deployment manifests
│   ├── namespace.yaml
│   ├── pvc.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── docs/                      # Documentation
├── base/                      # Kustomize base configurations
├── overlays/                  # Environment-specific configs
└── infrastructure/            # Infrastructure components
```

## 🎯 Current Status

### Minecraft Server Specs

- **Version**: Minecraft 1.20.1 + Forge 47.2.0
- **Server Name**: "My Homelab Server"
- **Capacity**: 20 players
- **Resources**: 2-6GB RAM, 1-3 CPU cores
- **Storage**: 20GB persistent volume
- **Access**: LoadBalancer service

### Kubernetes Components

- **Namespace**: `minecraft`
- **Deployment**: `minecraft-server`
- **Service**: LoadBalancer type
- **PVC**: 20GB using local-path storage class

## 🔧 Management Commands

### Server Status

```bash
# Check all resources
kubectl get all -n minecraft

# Check resource usage
kubectl top pods -n minecraft

# View logs
kubectl logs -n minecraft deployment/minecraft-server -f

# Restart server
kubectl rollout restart deployment/minecraft-server -n minecraft
```

### Server Access Commands

```bash
# The rtun tunnel handles external access automatically
# Tunnel runs in separate deployment: kubectl get pods -n minecraft -l app=minecraft-tunnel

# SSH via Tailscale (from anywhere)
ssh homelab-remote  # Using Tailscale IP
```

## 🛡️ Security Features

- [x] **SSH hardening** - Key-based auth only, root login disabled
- [x] **Firewall** - UFW with minimal required ports
- [x] **VPN access** - Tailscale for secure remote management
- [x] **No router exposure** - Using tunnels instead of port forwarding
- [x] **Resource limits** - Kubernetes resource quotas

## 📚 Learning Achievements

This setup demonstrates:

- **Kubernetes fundamentals** - Pods, Services, Deployments, PVCs
- **Container orchestration** - Resource management, persistence
- **Network security** - VPN, tunneling, firewall configuration
- **Infrastructure as Code** - YAML manifests, version control
- **Troubleshooting** - Client/server compatibility, connectivity issues

## 🎮 Gaming Features

- **Modded support** - Forge-enabled for custom modifications
- **Large world** - 29999984 block world size
- **All dimensions** - Overworld, Nether, End enabled
- **Persistent worlds** - Data survives pod restarts
- **External access** - Friends can join from anywhere
