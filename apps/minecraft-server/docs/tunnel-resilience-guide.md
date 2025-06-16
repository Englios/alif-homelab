# 🛡️ Tunnel Resilience Guide

## Overview
This guide explains how to prevent bore tunnel connections from going stale and ensure reliable connectivity for your Minecraft server.

## 🚨 The Problem: Stale Tunnels

**What happens when tunnels go stale:**
- bore.pub shows "listening at bore.pub:PORT" in logs
- External connections to that port are refused
- Players can't connect even though DNS is correct
- Manual restart required to fix

**Common causes:**
- Network interruptions
- bore.pub server maintenance
- Long-running connections timing out
- Process crashes without cleanup

## 🛡️ Prevention Strategies

### 1. Enhanced Health Checks (Primary Solution)

**File:** `bore-tunnel.yaml`

**What it does:**
- Monitors bore process health every 60 seconds
- Tests external connectivity to bore.pub
- Automatically restarts tunnel if unhealthy
- Includes Kubernetes readiness/liveness probes

**Key features:**
```bash
# Health check function tests:
- Bore process is running
- Internal Minecraft server connectivity  
- External tunnel accessibility
- Automatic restart on failure
```

**Benefits:**
- ✅ Automatic recovery from stale connections
- ✅ No manual intervention required
- ✅ Kubernetes-native health monitoring
- ✅ Detailed logging for troubleshooting

### 2. Dedicated Tunnel Watchdog (Secondary Protection)

**File:** `tunnel-watchdog.yaml`

**What it does:**
- Independent monitoring service
- Tests tunnel connectivity every 60 seconds
- Restarts bore tunnel deployment after 3 consecutive failures
- Can send alerts (Slack integration ready)

**Key features:**
```bash
# Watchdog monitors:
- External tunnel accessibility
- Consecutive failure counting
- Automatic deployment restart
- Alert notifications (configurable)
```

**Benefits:**
- ✅ Independent monitoring (separate from tunnel process)
- ✅ Can restart entire deployment if needed
- ✅ Alerting capabilities
- ✅ Configurable failure thresholds

### 3. Enhanced DNS Updater (Detection & Alerting)

**File:** `minecraft-dns-updater.yaml`

**What it does:**
- Tests tunnel connectivity before updating DNS
- Tracks consecutive failures
- Provides early warning of tunnel issues
- Only updates DNS for healthy tunnels

**Key features:**
```bash
# Enhanced monitoring:
- Connectivity testing before DNS updates
- Failure counting and alerting
- Health status logging
- Prevents DNS updates for broken tunnels
```

**Benefits:**
- ✅ Prevents DNS pointing to broken tunnels
- ✅ Early warning system
- ✅ Detailed health logging
- ✅ Smart DNS management

### 4. Comprehensive Monitoring Script

**File:** `scripts/monitor-tunnel-health.sh`

**What it does:**
- Complete system health check
- Tests all components (pods, connectivity, DNS)
- Provides troubleshooting recommendations
- Can be run manually or via cron

**Usage:**
```bash
# Run health check
./apps/minecraft-server/scripts/monitor-tunnel-health.sh

# Schedule regular checks (optional)
# Add to crontab: */5 * * * * /path/to/monitor-tunnel-health.sh
```

## 🚀 Deployment

### Quick Deployment
```bash
# Deploy all improvements at once
./apps/minecraft-server/scripts/deploy-tunnel-improvements.sh
```

### Manual Deployment
```bash
# Apply each component individually
kubectl apply -f apps/minecraft-server/bore-tunnel.yaml
kubectl apply -f apps/minecraft-server/tunnel-watchdog.yaml  
kubectl apply -f apps/minecraft-server/minecraft-dns-updater.yaml

# Check status
kubectl get pods -n minecraft
```

## 📊 Monitoring & Alerting

### Real-time Monitoring
```bash
# Watch tunnel watchdog logs
kubectl logs -n minecraft -l app=tunnel-watchdog -f

# Watch bore tunnel logs
kubectl logs -n minecraft -l app=minecraft-bore-tunnel -f

# Watch DNS updater logs
kubectl logs -n minecraft -l app=minecraft-dns-updater -f
```

### Health Checks
```bash
# Comprehensive health check
./apps/minecraft-server/scripts/monitor-tunnel-health.sh

# Quick status check
kubectl get pods -n minecraft

# Test current connectivity
CURRENT_PORT=$(kubectl logs -n minecraft -l app=minecraft-bore-tunnel --tail=10 | grep -o 'bore\.pub:[0-9]*' | tail -1 | cut -d':' -f2)
nc -zv bore.pub $CURRENT_PORT
```

### Setting Up Alerts (Optional)

**Slack Integration:**
```bash
# Create secret with Slack webhook
kubectl create secret generic alerting-secrets \
  --from-literal=slack-webhook="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  -n minecraft

# Tunnel watchdog will automatically use it
```

**Email Alerts (via cron):**
```bash
# Add to crontab for regular monitoring
*/10 * * * * /path/to/monitor-tunnel-health.sh | grep -q "System appears healthy" || echo "Minecraft tunnel unhealthy" | mail -s "Server Alert" admin@example.com
```

## 🔧 Troubleshooting

### Common Issues

**1. Tunnel shows as connected but not accessible:**
```bash
# Check if tunnel process is actually running
kubectl exec -n minecraft -l app=minecraft-bore-tunnel -- pgrep -f "bore local"

# Test internal connectivity
kubectl exec -n minecraft -l app=minecraft-bore-tunnel -- nc -z minecraft-server.minecraft.svc.cluster.local 25565

# Restart tunnel
kubectl rollout restart deployment/minecraft-bore-tunnel -n minecraft
```

**2. Watchdog not restarting tunnel:**
```bash
# Check watchdog logs
kubectl logs -n minecraft -l app=tunnel-watchdog --tail=20

# Check RBAC permissions
kubectl auth can-i patch deployments --as=system:serviceaccount:minecraft:tunnel-watchdog -n minecraft
```

**3. DNS not updating:**
```bash
# Check DNS updater logs
kubectl logs -n minecraft -l app=minecraft-dns-updater --tail=20

# Verify Cloudflare API credentials
kubectl get secret cloudflare-dns-secret -n minecraft -o yaml
```

### Emergency Recovery
```bash
# Nuclear option - restart everything
kubectl rollout restart deployment/minecraft-bore-tunnel -n minecraft
kubectl rollout restart deployment/tunnel-watchdog -n minecraft
kubectl rollout restart deployment/minecraft-dns-updater -n minecraft

# Wait for everything to be ready
kubectl wait --for=condition=ready pod -l app=minecraft-bore-tunnel -n minecraft --timeout=120s
kubectl wait --for=condition=ready pod -l app=tunnel-watchdog -n minecraft --timeout=120s
kubectl wait --for=condition=ready pod -l app=minecraft-dns-updater -n minecraft --timeout=120s
```

## 📈 Performance Impact

### Resource Usage
- **Enhanced bore tunnel:** +10MB memory, +50m CPU
- **Tunnel watchdog:** 64MB memory, 100m CPU  
- **Enhanced DNS updater:** No significant change

### Network Impact
- **Health checks:** ~1KB/minute per check
- **Tunnel restarts:** ~30 seconds downtime
- **DNS propagation:** 30-300 seconds (TTL dependent)

## 🎯 Best Practices

1. **Monitor regularly:** Run health checks at least every 10 minutes
2. **Set up alerts:** Get notified when issues occur
3. **Test recovery:** Periodically test tunnel restart procedures
4. **Keep logs:** Retain logs for troubleshooting patterns
5. **Document incidents:** Track when and why tunnels go stale

## 🔮 Future Improvements

**Potential enhancements:**
- Prometheus metrics integration
- Grafana dashboards
- Multiple tunnel redundancy
- Automatic failover to backup tunnels
- Integration with external monitoring systems

---

## Summary

With these improvements, your bore tunnel should be much more resilient:

- **🔍 Proactive monitoring** detects issues before they affect players
- **🤖 Automatic recovery** fixes problems without manual intervention  
- **📊 Comprehensive logging** helps troubleshoot any remaining issues
- **🛠️ Easy management** through scripts and monitoring tools

The combination of health checks, watchdog monitoring, and enhanced DNS management should eliminate most stale tunnel issues! 