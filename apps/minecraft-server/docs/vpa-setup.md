# 📈 Vertical Pod Autoscaler (VPA) Setup

## Overview
VPA automatically adjusts CPU and memory resources for the Minecraft server based on actual usage patterns.

## 🎯 Benefits for Minecraft Server

### **Automatic Resource Optimization:**
- **Peak hours** (7-11 PM): Scales up for more players
- **Quiet hours** (2-8 AM): Scales down to save resources
- **Combat spikes**: Handles sudden CPU demands during raids/PvP
- **Memory growth**: Manages gradual memory increase from loaded chunks

### **Performance Benefits:**
- ✅ **No resource starvation** during high activity
- ✅ **Cost optimization** during low usage periods  
- ✅ **Reduced manual tuning** 
- ✅ **Better player experience** (no lag from resource constraints)

## 🚀 Installation

### **1. Install VPA (if not already installed)**

```bash
# Check if VPA is installed
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io

# If not installed, install VPA
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler/
./hack/vpa-install.sh
```

### **2. Apply VPA Configuration**

```bash
# Apply the VPA for Minecraft server
kubectl apply -f apps/minecraft-server/deployment/vpa.yaml

# Verify VPA is created
kubectl get vpa -n minecraft
```

### **3. Monitor VPA Recommendations**

```bash
# Check VPA status and recommendations
kubectl describe vpa minecraft-server-vpa -n minecraft

# Watch resource usage
kubectl top pods -n minecraft --containers
```

## 📊 VPA Configuration Details

### **Resource Limits:**
- **Minimum**: 4Gi RAM, 1 CPU core
- **Maximum**: 10Gi RAM, 6 CPU cores (leaves 6GB for system)  
- **Current**: 7Gi RAM, 2-4 CPU cores

### **Scaling Behavior:**
- **Memory**: Aggressive scaling (Minecraft is memory-hungry)
  - Scale up: 50% increase in 1 minute
  - Scale down: 25% decrease over 5 minutes
  
- **CPU**: Conservative scaling
  - Scale up: 100% increase in 30 seconds  
  - Scale down: 50% decrease over 3 minutes

### **Update Mode:**
- **Auto**: VPA will restart pods with new resource limits
- **Initial**: Only set resources on pod creation
- **Off**: Generate recommendations only (no changes)

## 🔍 Monitoring VPA

### **Check VPA Status:**
```bash
# Get VPA recommendations
kubectl get vpa minecraft-server-vpa -n minecraft -o yaml

# Check current vs recommended resources
kubectl describe vpa minecraft-server-vpa -n minecraft | grep -A 10 "Last Recommendation"
```

### **Monitor Resource Usage:**
```bash
# Real-time resource usage
watch kubectl top pods -n minecraft

# Check if resources are being utilized efficiently
kubectl describe pod -n minecraft -l app=minecraft-server | grep -A 5 "Requests\|Limits"
```

### **VPA Events:**
```bash
# Check VPA events and decisions
kubectl get events -n minecraft --field-selector involvedObject.name=minecraft-server-vpa

# Check pod restart events (VPA-triggered)
kubectl get events -n minecraft --field-selector reason=Killing
```

## ⚙️ Tuning VPA

### **Common Adjustments:**

**1. Make VPA Less Aggressive:**
```yaml
# In vpa.yaml, increase stabilization windows
stabilizationWindowSeconds: 600  # Wait 10 minutes instead of 5
```

**2. Change Update Mode:**
```yaml
updatePolicy:
  updateMode: "Initial"  # Only set on pod creation, no restarts
```

**3. Adjust Resource Bounds:**
```yaml
minAllowed:
  memory: "6Gi"     # Higher minimum if always needed
maxAllowed:  
  memory: "16Gi"    # Higher maximum for very busy servers
```

### **Minecraft-Specific Tuning:**

**High Player Count Server:**
- Increase `minAllowed` memory to 6-8Gi
- Set `maxAllowed` memory to 10-12Gi (depending on server capacity)

**Low Player Count Server:**
- Decrease `minAllowed` to 3Gi
- Keep `maxAllowed` at 8-10Gi

**Modded Server (like yours):**
- Higher memory minimums (6Gi+)
- Faster memory scaling (current config is good)

## 🎮 Player Experience

### **What Players Will Notice:**
- **Better performance** during peak hours (no lag spikes)
- **Faster combat** response (adequate CPU allocated)
- **Brief server restart** when VPA scales (30-60 seconds)

### **Managing Restarts:**
VPA restarts can be disruptive. Use the announcement system:

```bash
# Before VPA changes (manual announcement)
./apps/minecraft-server/scripts/rolling-update-announcer.sh countdown 3 "Resource optimization"

# Or switch to "Initial" mode to avoid restarts
kubectl patch vpa minecraft-server-vpa -n minecraft --type='merge' -p='{"spec":{"updatePolicy":{"updateMode":"Initial"}}}'
```

## 📈 Expected Scaling Patterns

### **Daily Usage Pattern:**
```
2-8 AM:   Low usage  → 4Gi RAM, 1-2 CPU
8-12 PM:  Medium     → 6Gi RAM, 2-3 CPU  
12-6 PM:  High       → 7-8Gi RAM, 3-4 CPU
6-11 PM:  Peak       → 8-10Gi RAM, 4-6 CPU (max 10Gi)
11-2 AM:  Declining  → 6-7Gi RAM, 2-3 CPU
```

### **Event-Based Scaling:**
- **Raid events**: CPU spike → Scale up CPU
- **Multiple players exploring**: Memory increase → Scale up RAM
- **AFK periods**: Low usage → Scale down both
- **Restart/maintenance**: Reset to baseline

## 🔧 Troubleshooting

### **VPA Not Scaling:**
```bash
# Check VPA controller logs
kubectl logs -n kube-system -l app=vpa-recommender

# Verify metrics server
kubectl top nodes
```

### **Too Many Restarts:**
```bash
# Switch to recommendation-only mode
kubectl patch vpa minecraft-server-vpa -n minecraft --type='merge' -p='{"spec":{"updatePolicy":{"updateMode":"Off"}}}'

# Check recommendations manually
kubectl describe vpa minecraft-server-vpa -n minecraft
```

### **Resource Limits Hit:**
```bash
# Check if hitting max limits
kubectl describe pod -n minecraft -l app=minecraft-server | grep -A 5 "QoS Class\|Limits"

# Increase max limits if needed
kubectl edit vpa minecraft-server-vpa -n minecraft
```

## 🚀 Advanced Features

### **Prometheus Integration:**
If you have Prometheus, VPA metrics help with monitoring:

```yaml
# Add to prometheus config
- job_name: 'vpa-metrics'
  kubernetes_sd_configs:
  - role: endpoints
    namespaces:
      names: ['minecraft']
```

### **Custom Metrics:**
Use HPA alongside VPA for player-based scaling:

```yaml
# Scale based on player count (requires custom metrics)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: minecraft-player-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: minecraft-server
  minReplicas: 1
  maxReplicas: 1  # Keep at 1 for Minecraft
  metrics:
  - type: Object
    object:
      metric:
        name: minecraft_players_online
      target:
        type: Value
        value: "10"  # Trigger VPA recommendations when >10 players
```

---

## Summary

VPA provides intelligent resource management for your Minecraft server:

- 🎯 **Automatic optimization** based on real usage
- 💰 **Cost efficiency** during low usage periods  
- 🚀 **Performance scaling** for peak times
- 🔍 **Data-driven** resource allocation

Start with the default configuration and tune based on your server's specific patterns! 