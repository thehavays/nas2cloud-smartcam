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

## 1. Start the Environment (Cross-Platform: Linux, macOS, Windows)

Create a `docker-compose.yml` file anywhere on your computer (Ubuntu, macOS, or Windows):

```yaml
services:
  nas2cloud-smartcam:
    image: ghcr.io/thehavays/nas2cloud-smartcam:latest
    container_name: nas2cloud-smartcam
    ports:
      - "445:445"
      - "139:139"
      - "8080:8080"
      - "137:137/udp"
      - "138:138/udp"
    environment:
      - USERID=1000
      - GROUPID=1000
      - TZ=UTC
      - SYNC_INTERVAL=3600          # Sync every 1 hour (in seconds)
      - LOCAL_RETENTION_DAYS=7       # Delete local files older than 7 days
      - REMOTE_PATH=${REMOTE_PATH:-Nas2CloudBackup}     # Target path on Google Drive
      # --- Motion Detection (optional) ---
      - MOTION_DETECTION=true        # Set to 'false' to disable
      - MOTION_SENSITIVITY=0.02      # Scene change threshold (0.01=sensitive, 0.10=lenient)
      - MOTION_CLIP_BUFFER=15        # Seconds added before/after each motion event
      - MOTION_CHECK_INTERVAL=600    # How often to scan for motion (seconds, default: 10 min)
    volumes:
      - ./data:/mnt/data
      - ./rclone:/app/rclone
    command: '-u "camera;camera123" -s "cam_storage;/mnt/data;yes;no;no;camera;camera;camera" -n -p -S -g "ntlm auth = ntlmv1-permitted" -g "server min protocol = NT1" -g "client min protocol = NT1" -g "netbios name = camnas"'
    restart: unless-stopped
```

Then run:
```bash
docker compose up -d
```

> 💡 **Tip:** 
> * **On Linux/Ubuntu:** If you want automatic NetBIOS network broadcast discovery without entering IP addresses manually, you can optionally replace `ports:` with `network_mode: "host"`.
> * **On macOS:** Make sure **macOS File Sharing** (*System Settings > General > Sharing > File Sharing*) is turned OFF to prevent port `445` conflicts.

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
3. Select your device from the list (usually named `camnas` or your host PC/Mac IP address).
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
MOTION_SENSITIVITY=0.02
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
| `0.02` | Balanced *(recommended)* |
| `0.05` | Only large movements (people walking in front of camera) |
| `0.10` | Coarse — only extreme changes |

---

## 🔧 Environment Variables Reference
| Variable | Default | Description |
| :--- | :--- | :--- |
| `SYNC_INTERVAL` | `3600` | Sync frequency in seconds (default: 1 hour). |
| `LOCAL_RETENTION_DAYS` | `7` | Days to keep video files on local PC disk before auto-delete. |
| `REMOTE_RETENTION_DAYS` | `30` | Days to keep video files on Google Drive before auto-delete. |
| `REMOTE_PATH` | `Nas2CloudBackup` | Destination folder path on Google Drive. |
| `MOTION_DETECTION` | `true` | Set to `false` to disable motion clip extraction. |
| `MOTION_SENSITIVITY` | `0.02` | FFmpeg scene change threshold (lower = more sensitive). |
| `MOTION_CLIP_BUFFER` | `15` | Seconds added before/after each detected motion event. |
| `MOTION_CHECK_INTERVAL` | `600` | How often (in seconds) to scan recordings for motion. |
