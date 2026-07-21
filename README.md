# Xiaomi Camera to Google Drive Sync

Welcome to the Xiaomi Camera to Google Drive Sync project! This tool allows your Xiaomi security camera (which usually requires a paid cloud subscription or a dedicated NAS) to backup its videos completely for free to your personal Google Drive. 

To make setup as easy as possible, we have built a beautiful web interface to handle Google Drive authentication for you. No terminal commands required!

## 1. Start the Environment

### Option A: Use Pre-built Image (Recommended)
You do not need to download this repository! Just create a `docker-compose.yml` file anywhere on your computer with the following contents:

```yaml
services:
  xiaomi-sync:
    image: ghcr.io/thehavays/xiaomi-camera-drive-sync:latest
    container_name: xiaomi-sync
    environment:
      - USERID=1000
      - GROUPID=1000
      - TZ=UTC
    network_mode: "host"
    volumes:
      - ./data:/mnt/data
    command: '-u "camera;camera123" -s "xiaomi_nas;/mnt/data;yes;no;no;camera;camera;camera" -n -p -S -g "ntlm auth = ntlmv1-permitted" -g "server min protocol = NT1" -g "client min protocol = NT1" -g "netbios name = xiaominas"'
    restart: unless-stopped
```
Then, in the same folder as the file, run:
```bash
docker compose up -d
```

### Option B: Build from Source (Local Development)
If you want to modify the code yourself, clone this repository, open a terminal in the folder, and run:
```bash
docker compose up -d --build
```

*(This will start the Samba NAS, the Sync script, and our Auth Server!)*

## 2. Authenticate with Google Drive via Web UI

1. Open your web browser and go to: **[http://127.0.0.1:8080](http://127.0.0.1:8080)**
2. The left side of the page provides instructions on how to generate your own Google Cloud **Client ID** and **Client Secret**. (This takes about 3 minutes and ensures you never hit Google's rate limits).
3. Paste those keys into the form on the right and click **Connect Google Drive**.
4. You will be redirected to the Google login screen. Log in and click "Allow".
5. It will redirect you back to a Success page. 
6. **Important:** Restart the container so it picks up the new credentials:
   ```bash
   docker compose restart xiaomi-sync
   ```

## 3. Connect the Camera

1. Open your **Mi Home app**.
2. Go to your camera settings -> **Storage Management** -> **NAS network storage**.
3. It will scan your local network and should find a device (likely named `xiaominas` or your host PC's IP address).
4. Tap it and enter the credentials we set up:
   - **Username:** `camera`
   - **Password:** `camera123`
5. It should connect successfully and show the `xiaomi_nas` folder. Select it.

The camera will now automatically save recordings to the Docker NAS. Periodically (every hour by default), the `rclone-sync` container will wake up and securely copy these files up to a folder named `XiaomiCameraBackup` in your Google Drive!
