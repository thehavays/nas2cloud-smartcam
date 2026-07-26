# Project Guidelines & Developer Onboarding for Nas2Cloud SmartCam (Server)

This document is a comprehensive guide for AI agents and developers to understand, find, and develop the `nas2cloud-smartcam` server application.

---

## 📖 Project Summary

**Nas2Cloud SmartCam** is a backup and processing pipeline for NAS-capable security cameras (Xiaomi, Reolink, TP-Link Tapo, Eufy, etc.). It acts as a local NVR (Network Video Recorder) that stores video files locally and syncs them to Google Drive for free, bypassing expensive cloud subscriptions.

### How It Works

1. **Local NVR (Samba)**: A Samba SMB share runs in a Docker container. Security cameras discover this share (`CAMNAS`) and stream continuous video recording files (usually in 10-15 minute `.mp4` chunks) directly to it.
2. **Web OAuth Configuration**: A Node.js web interface runs on port `8080` to assist the user with creating a Google Cloud OAuth project and authenticating their Google Drive without terminal commands.
3. **Motion Detection Engine (FFmpeg)**: A background script scans incoming recordings periodically, uses FFmpeg's scene change detection filter to identify motion events, cuts short clips (±15s around each event), and saves them.
4. **Cloud Synchronization (Rclone)**: A background daemon calls Rclone to copy full recordings and motion clips to the user's Google Drive.
5. **Automatic Retention Cleanup**: The daemon periodically deletes local files older than `LOCAL_RETENTION_DAYS` and remote files older than `REMOTE_RETENTION_DAYS`.

---

## 📂 Implementation Paths & Project Structure

The project code is structured as follows:

* **[nas2cloud-smartcam/](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam)**: Root folder of the server repository.
  * **[Dockerfile](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/Dockerfile)**: Docker build configuration. Extends `dperson/samba` (Alpine Linux base) and installs Node.js, npm, curl, unzip, and FFmpeg.
  * **[docker-compose-linux.yml](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/docker-compose-linux.yml)**: Deployment configuration for Linux. Uses `network_mode: "host"` so the camera can auto-discover the `CAMNAS` broadcast on the local network.
  * **[docker-compose-windows.yml](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/docker-compose-windows.yml)**: Deployment configuration for Windows. Exposes explicit port mappings (`8080`, `139`, `445`).
  * **[entrypoint.sh](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/entrypoint.sh)**: Container startup script. Launches the OAuth Web Server and the Sync Script in the background, then boots the Samba daemon in the foreground.
  * **[sync.sh](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/sync.sh)**: Main background sync loop. Runs `rclone` sync cycles, triggers the motion scanner, and executes local and remote file retention cleanups.
  * **[motion_clip.sh](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/motion_clip.sh)**: Motion scanning engine. Performs:
    * Samba lock inspection via `smbstatus` to detect the currently writing "active" video file.
    * FFmpeg scene change analysis (`select='gt(scene,SENSITIVITY)'`).
    * Epoch start-time resolution with a 3-level fallback chain (Metadata -> Filename -> Mtime).
    * Sub-clip cutting using FFmpeg stream copy.
  * **[auth-server/](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/auth-server)**: Web authentication service.
    * **[server.js](file:///home/thehavays/Desktop/projects/workspace-nas2cloud-smartcam/nas2cloud-smartcam/auth-server/server.js)**: Node.js Express server. Pre-configures credentials if `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are passed as environment variables. Writes and manages the `rclone.conf` config.

---

## 🛢️ Volume & Data Directory Mapping

When developing or debugging, look for files in these paths on the host system:

* **`./data/`** (maps to `/mnt/data` in container):
  * **`./data/XiaomiCamera_...`**: Directory containing raw camera video recordings.
  * **`./data/MotionClips/`**: Extracted motion clips, grouped by date folders (e.g., `YYYY-MM-DD/HH-MM-SS.mp4`).
  * **`./data/.motion_processed.log`**: Keeps track of processed full recordings to avoid re-scanning them.
  * **`./data/motion_events.log`**: Main motion analysis event log.
* **`./rclone/`** (maps to `/app/rclone` in container):
  * **`./rclone/rclone.conf`**: Generated rclone config file (holds Google Drive OAuth tokens).
  * **`./rclone/settings.env`**: Sync configurations saved by the web panel.

---

## 🛠️ Development & Operational Workflows

### 1. Rebuilding & Starting the Project

To apply changes to scripts or `server.js`, you must rebuild the image and recreate the container:

```bash
# Stop the active container
docker compose -f docker-compose-linux.yml down

# Rebuild and run in the background
docker compose -f docker-compose-linux.yml up -d --build
```

### 2. Git & GitHub Flow

Refer to the detailed [Git & GitHub Workflow Guidelines](./GIT_WORKFLOW.md) for branch strategy, commit rules, PR workflows, and the GITHUB_TOKEN environment override command.

### 3. Debugging Commands

* **Check camera connection to SMB**:

  ```bash
  docker exec nas2cloud-smartcam smbstatus
  ```

* **Follow live synchronization/motion detection logs**:

  ```bash
  docker logs -f nas2cloud-smartcam
  ```

---

## 🔒 Security & Code Quality Guidelines

### 1. Secrets Management

* **Never commit secrets**: Do not commit `.env`, `./rclone/rclone.conf`, `./rclone/settings.env`, or any client credentials/refresh tokens to the Git repository. These are already added to `.gitignore`, but extra caution must be taken during code modifications.

### 2. Shell Script Best Practices

* **Keep Scripts Executable**: Ensure `sync.sh`, `motion_clip.sh`, and `entrypoint.sh` maintain their executable permissions (`chmod +x`).
* **Subshell Output Hygiene**: When writing utility functions in helper scripts (like `get_video_start_epoch` in `motion_clip.sh` which runs inside a `$()` subshell), redirect internal log outputs to `stderr` (`>&2`) or files to avoid polluting standard output, which would corrupt the returned variable values.

### 3. Verification & Build Integrity

* **Test Build before PR**: Before opening any Pull Request, verify that the project builds and compiles successfully:

  ```bash
  docker compose -f docker-compose-linux.yml up -d --build
  ```

* **Verify Logs**: Check `docker logs nas2cloud-smartcam` to ensure there are no run-time crash loops, syntax errors in the node server, or bash errors in the sync script.
