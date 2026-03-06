# 🚀 Minecraft Server on Kubernetes

This repository contains the Kubernetes configuration for a performance-tuned Minecraft server using the DeceasedCraft modpack via CurseForge.

## ▶️ Quick Start

To deploy or update the server, apply the Kubernetes manifests from the `deployment` directory:

```bash
kubectl apply -f apps/minecraft-server/deployment/
```

---

## 🌐 External Access

The server is exposed externally using **rtun** (a secure reverse tunnel). This allows friends to connect without needing port forwarding on your home router.

### Tunnel Configuration
- **TCP (Minecraft)**: Port 35000 → `minecraft-server:25565`
- **UDP (Voice Chat)**: Port 35001 → `minecraft-server:24454`

### Managing the Tunnel
```bash
# Check tunnel status
kubectl get pods -n minecraft -l app=minecraft-tunnel

# View tunnel logs
kubectl logs -n minecraft -l app=minecraft-tunnel -f

# Restart tunnel
kubectl rollout restart deployment/minecraft-tunnel -n minecraft
```

---

## ⚙️ Configuration

### Server Settings

Most server settings (like difficulty, max players, etc.) are managed as environment variables in `apps/minecraft-server/deployment/deployment.yaml`.

### Managing Mods

Server-side mods are managed via a ConfigMap that lists mod URLs or CurseForge file IDs.

1.  **To add a mod:** Add its CurseForge file ID or download URL to `config/mod-list.txt`.
2.  **To remove a mod:** Delete its entry from the list.

The server will automatically download and install the correct mods on restart.

**Current Mods (from `config/mod-list.txt`):**
```text
# Mods are loaded from this file
# See deployment.yaml MODS_FILE environment variable for configuration
```

---

## ⚡ Performance

The server has been optimized for a smooth experience with a small group of players.

### Memory Tuning

-   **Java Heap Size:** Set to **6G**. This is a deliberate choice to keep Java's garbage collection (GC) fast and reduce lag spikes.
-   **VPA (Vertical Pod Autoscaler):** The VPA is **disabled** (`updateMode: "Off"`) to prevent it from allocating excessive memory, which harms performance.

### Installed Performance Mods

-   **Spark:** For profiling and diagnosing lag.
-   **FerriteCore:** Reduces memory usage.
-   **Clumps:** Reduces lag from XP orbs.
-   **ModernFix:** A general optimization mod.

---

## 🔧 Troubleshooting

### Investigating Lag with Spark

If you experience lag, use the Spark profiler to find the cause.

1.  **Start Profiler:**
    ```bash
    kubectl exec -n minecraft deployment/minecraft-server -- rcon-cli "spark profiler --timeout 300"
    ```
2.  **Get Report Link:** After 5 minutes, Spark will generate a report. Find the link in the logs:
    ```bash
    kubectl logs -n minecraft deployment/minecraft-server --tail=20
    ```

### Basic Commands

-   **View Server Logs:**
    ```bash
    kubectl logs -f -n minecraft deployment/minecraft-server
    ```
-   **Access Server Console:**
    ```bash
    kubectl exec -it -n minecraft deployment/minecraft-server -- bash
    ```
---

## 🙏 Acknowledgements

This setup relies on the fantastic `itzg/minecraft-server` Docker image. A huge thanks to **itzg** for creating and maintaining this versatile and powerful tool for the Minecraft community.

The secure reverse tunnel is powered by `snsinfu/rtun`, which provides a simple and effective way to expose the server. 