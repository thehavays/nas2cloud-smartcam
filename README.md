# Nas2Cloud SmartCam

Welcome to the **Nas2Cloud SmartCam** project! This tool allows any NAS-capable security camera (Xiaomi, TP-Link Tapo, Reolink, Eufy, Amcrest, etc.) to backup its recordings completely for free to your personal Google Drive, avoiding expensive cloud subscriptions.

To make setup as easy as possible, a web interface is included to handle Google Drive authentication for you. No complex terminal commands required!

---

## 🌟 How It Works

* **Full Continuous Recording:** Instead of relying on 10-second cloud clips, this system acts as a local NVR to backup **full, continuous video recordings**.
* **Buffer & Loop Recording:** Your camera records to its local MicroSD card first, then streams files to your PC's Docker NAS in real-time. Even when the SD card overwrites old files, your PC and Google Drive backups remain safe.
* **Auto Cleanup:** Keeps your local PC storage and Google Drive clean by automatically purging files older than your configured retention policy.
* **Motion Clip Extraction *(optional)*:** Scans completed and in-progress recordings with FFmpeg and automatically cuts short clips (±15s around each motion event) — turning your basic camera into a smart cloud camera.

---

## 1. Start the Environment (Cross-Platform: Linux, Windows, macOS)

Depending on your Operating System, use the appropriate configuration file:

### macOS (Native File Sharing + Cloud Sync & Motion Detection)
Because Docker Desktop on macOS runs inside a LinuxKit virtual machine behind NAT, camera apps (such as Xiaomi / Mi Home) cannot discover Docker's Samba broadcast directly over Wi-Fi. The recommended and tested solution is to use macOS native **File Sharing** for camera ingestion, while `nas2cloud` handles motion detection, clip cutting, and Google Drive synchronization:

1. **Enable macOS Native File Sharing**:
   - Go to **System Settings > General > Sharing** and turn on **File Sharing**.
   - Click the **(i)** info icon, add a dedicated storage folder (e.g. `cam_storage` on your Desktop or external drive).
   - Click **Options...**, enable **Share files and folders using SMB**, and check your user account under **Windows File Sharing** (NTLM authentication).
2. **Configure and Run the Container**:
   - Create or edit `.env` in the repository root and set `DATA_PATH` to your shared folder:
     ```env
     DATA_PATH=/Users/yourusername/Desktop/cam_storage
     ```
   - Start the container using [docker-compose-mac.yml](docker-compose-mac.yml):
     ```bash
     docker compose -f docker-compose-mac.yml up -d
     ```
3. **Connect Your Camera**:
   - In your camera app (e.g. Mi Home -> Camera Settings -> Storage Management -> NAS Network Storage), your Mac will appear automatically in the discovery list.
   - Enter your Mac username and password, select the shared folder, and the camera will begin streaming video directly.

> 💡 **Tip for macOS:**
> * **Preventing Sleep:** If using your Mac as an always-on NVR server, configure your Mac not to sleep when the display is off (under **System Settings > Displays / Lock Screen** or by running `caffeinate -d` in a background terminal).

### Windows (requires explicit port exposure)
Use [docker-compose-windows.yml](docker-compose-windows.yml) and run:
```bash
docker compose -f docker-compose-windows.yml up -d
```

> 💡 **Tip for Windows:**
> * Make sure port `445` is not being used by the native Windows "Server" (SMB) service.
> * You can customize the storage directory by setting `DATA_PATH` in `.env` (e.g. `DATA_PATH=D:\cam_storage`).

### Linux (uses host networking for automatic discovery)
Use [docker-compose-linux.yml](docker-compose-linux.yml) and run:
```bash
docker compose -f docker-compose-linux.yml up -d
```

> 💡 **Tip for Linux:**
> * You can customize the storage directory by setting `DATA_PATH` in `.env` (e.g. `DATA_PATH=/mnt/storage`).

---

## 2. Authenticate with Google Drive via Web UI

1. Open your web browser and go to: **[http://127.0.0.1:8080](http://127.0.0.1:8080)**
2. Follow the step-by-step instructions on the page to create your Google Cloud **Client ID** and **Client Secret** (takes ~3 minutes).
3. Enter your keys into the web form and click **Connect Google Drive**.
4. Authorize with your Google Account when prompted.
5. After seeing the success screen, **restart the container** to apply the new credentials:
   ```bash
   docker compose restart nas2cloud-smartcam
   ```

---

## 3. Connect Your Camera (NAS/SMB Storage)

The setup process varies depending on your camera brand, but generally requires pointing it to the newly created SMB network share.

### Example: Xiaomi Cameras (Mi Home)
1. Open the **Mi Home app**.
2. Navigate to your camera: **Settings (⋮)** -> **Storage Management** -> **NAS network storage**.
3. Select your device from the list (usually named `camnas` or your host PC IP address).
   * *If `camnas` is not discovered automatically, enter your host IP address manually (e.g., `192.168.1.50`).*
4. Enter the SMB credentials:
   * **Username:** `camera`
   * **Password:** `camera123`
5. Select the **`cam_storage`** folder and ensure:
   * **Transmission status:** `Transmission is normal`
   * **Transfer time:** `Immediately`

The camera will now automatically stream recordings to your local Docker NAS, and the sync engine will periodically upload them to the `Nas2CloudBackup` folder in your Google Drive! 🚀

---

## 🔍 Verification & Troubleshooting

### Check Active Camera Connection
To verify if your Xiaomi camera is actively connected and transferring files:
```bash
docker exec nas2cloud-smartcam smbstatus
```

### Check Google Drive Sync Logs
To view real-time sync activity and upload progress:
```bash
docker logs -f nas2cloud-smartcam
```

---

## 🎯 Motion Detection (Optional)

Enable automatic motion clip extraction to get short clips around motion events — without paying for expensive cloud subscriptions.

Set `MOTION_DETECTION=true` in your environment or `.env` file:
```env
MOTION_DETECTION=true
MOTION_SENSITIVITY=0.04
MOTION_CLIP_BUFFER=15
MOTION_CHECK_INTERVAL=600
```

### How It Works
1. Every **10 minutes** (configurable), `motion_clip.sh` runs inside the container.
2. It detects scene changes in **completed** recordings (processed once, then skipped forever) and the **active** recording (always re-checked with a fresh snapshot).
3. A short clip of **±15 seconds** around each motion event is cut and saved to `./data/MotionClips/YYYY-MM-DD/`.
4. On the next hourly sync, clips are uploaded to **`gdrive:Nas2CloudBackup/MotionClips/`**.

### Maximum Latency
Because the active file is snapshotted every 10 minutes, you'll see motion clips in Drive **within ~10 minutes** of the event.

### Tuning Sensitivity
| `MOTION_SENSITIVITY` | Behaviour |
| :--- | :--- |
| `0.01` | Very sensitive — flags minor lighting changes |
| `0.04` | Balanced *(recommended)* |
| `0.05` | Only large movements (people walking in front of camera) |
| `0.10` | Coarse — only extreme changes |

---

## 🔧 Environment Variables Reference
| Variable | Default | Description |
| :--- | :--- | :--- |
| `DATA_PATH` | `./data` | Host directory path where camera recordings are saved and read from. |
| `TZ` | Host time (`/etc/localtime`) | Timezone identifier (e.g. `Europe/Istanbul`, `America/New_York`, `UTC`). |
| `SYNC_INTERVAL` | `3600` | Sync frequency in seconds (default: 1 hour). |
| `LOCAL_RETENTION_DAYS` | `7` | Days to keep video files on local PC disk before auto-delete. |
| `REMOTE_RETENTION_DAYS` | `30` | Days to keep video files on Google Drive before auto-delete. |
| `REMOTE_PATH` | `Nas2CloudBackup` | Destination folder path on Google Drive. |
| `MOTION_DETECTION` | `true` | Set to `false` to disable motion clip extraction. |
| `MOTION_SENSITIVITY` | `0.04` | FFmpeg scene change threshold (lower = more sensitive). |
| `MOTION_CLIP_BUFFER` | `15` | Seconds added before/after each detected motion event. |
| `MOTION_CHECK_INTERVAL` | `600` | How often (in seconds) to scan recordings for motion. |
