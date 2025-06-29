# 🚀 Minecraft Server on Kubernetes

This repository contains the Kubernetes configuration for a performance-tuned, modded Minecraft server (Forge 1.20.1).

## ▶️ Quick Start

To deploy or update the server, apply the Kubernetes manifests from the `deployment` directory:

```bash
kubectl apply -f apps/minecraft-server/deployment/
```

---

## ⚙️ Configuration

### Server Settings

Most server settings (like difficulty, max players, etc.) are managed as environment variables in `apps/minecraft-server/deployment/deployment.yaml`.

### Managing Mods

Server-side mods are managed using CurseForge File IDs.

1.  **To add a mod:** Find its **File ID** from the CurseForge website and add it to the `CURSEFORGE_FILES` list in `deployment.yaml`.
2.  **To remove a mod:** Delete its ID from the list.

The server will automatically download and install the correct mods on restart.

**Current Mods (`CURSEFORGE_FILES`):**
```yaml
# In deployment.yaml
value: "256717,429235,790626,416089,361579" # clumps,ferritecore,modernfix,spark,simple-voice-chat
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