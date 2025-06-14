# 🏠 Homelab Kubernetes Setup

A self-hosted Kubernetes environment for learning and running applications.

## 🖥️ Infrastructure
- **Host**: Old gaming laptop (i7-7700HQ, 12GB RAM, GTX 1060)
- **OS**: Debian 12
- **Network**: Home network (IP configured in .env)
- **K8s**: k3s (lightweight Kubernetes)

## 📋 Current Status
- [x] SSH setup with key-based authentication
- [x] CLI tools installed (kubectl, helm, k3sup)
- [ ] k3s installation (in progress)
- [ ] Minecraft server deployment

## 🎯 Planned Applications
- Minecraft server (modded, ~10 players, large world)
- Personal website (future)
- VS Code server (future)
- Monitoring stack (future)

## 📁 Repository Structure
```
homelab-k8s/
├── apps/           # Application manifests
├── infrastructure/ # Core infrastructure components  
├── base/          # Base configurations
├── overlays/      # Environment-specific configs
└── docs/          # Documentation
```

## 🚀 Getting Started

1. **Configure environment variables:**
   ```bash
   cp env.example .env
   # Edit .env with your actual values
   ```

2. **Follow setup guide:**
   See [setup documentation](./docs/setup.md) for detailed installation steps. 