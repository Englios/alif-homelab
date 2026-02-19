#!/bin/bash
# Setup GPU support on k3s worker node (Pop!_OS)
# Run this on the worker node after joining the cluster

set -e

echo "Setting up GPU support on worker node..."

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script needs to run with sudo:"
    echo "  sudo $0"
    exit 1
fi

echo "=== Step 1: Install NVIDIA Container Toolkit ==="
apt update
apt install -y nvidia-container-toolkit

echo "=== Step 2: Configure containerd for NVIDIA runtime ==="

# Create k3s containerd config template with correct NVIDIA paths
mkdir -p /var/lib/rancher/k3s/agent/etc/containerd/

cat > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl << 'EOF'
version = 3
root = "/var/lib/rancher/k3s/agent/containerd"
state = "/run/k3s/containerd"

[grpc]
  address = "/run/k3s/containerd/containerd.sock"

[plugins.'io.containerd.internal.v1.opt']
  path = "/var/lib/rancher/k3s/agent/containerd"

[plugins.'io.containerd.grpc.v1.cri']
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"

[plugins.'io.containerd.cri.v1.runtime']
  enable_selinux = false
  enable_unprivileged_ports = true
  enable_unprivileged_icmp = true
  device_ownership_from_security_context = false

[plugins.'io.containerd.cri.v1.images']
  snapshotter = "overlayfs"
  disable_snapshot_annotations = true
  use_local_image_pull = true

[plugins.'io.containerd.cri.v1.images'.pinned_images]
  sandbox = "rancher/mirrored-pause:3.6"

[plugins.'io.containerd.cri.v1.runtime'.cni]
  bin_dirs = ["/var/lib/rancher/k3s/data/cni"]
  conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runhcs-wcow-process]
  runtime_type = "io.containerd.runhcs.v1"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.'nvidia']
  runtime_type = "io.containerd.runc.v2"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.'nvidia'.options]
  BinaryName = "/usr/bin/nvidia-container-runtime"
  SystemdCgroup = true
EOF

echo "=== Step 3: Restart k3s-agent ==="
systemctl restart k3s-agent

echo "=== Step 4: Wait for k3s-agent to be ready ==="
sleep 10

echo "=== Step 5: Install NVIDIA device plugin (from control plane) ==="
# Run this from the control plane or use the kubeconfig
echo "Run this on your PC to install the device plugin:"
echo "  kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.5/nvidia-device-plugin.yml"

echo ""
echo "GPU setup complete! Restart k3s-agent: sudo systemctl restart k3s-agent"
echo "Then install the device plugin from your PC."
