#!/bin/sh

# Sync script that runs rclone periodically
# Syncs /data (the mounted samba share) to the 'gdrive' remote

SYNC_INTERVAL=${SYNC_INTERVAL:-3600}          # Default to 1 hour (3600 seconds)
LOCAL_RETENTION_DAYS=${LOCAL_RETENTION_DAYS:-7} # Keep files on local PC for 7 days
REMOTE_RETENTION_DAYS=${REMOTE_RETENTION_DAYS:-30} # Keep files on Google Drive for 30 days
REMOTE_PATH=${REMOTE_PATH:-XiaomiCameraBackup} # Target path on Google Drive
MOTION_DETECTION=${MOTION_DETECTION:-false}    # Enable motion clip extraction
MOTION_CHECK_INTERVAL=${MOTION_CHECK_INTERVAL:-600} # Motion scan every 10 minutes (600 seconds)

echo "Starting rclone sync script."
echo "Sync interval: $SYNC_INTERVAL seconds."
echo "Local retention: $LOCAL_RETENTION_DAYS days."
echo "Remote retention: $REMOTE_RETENTION_DAYS days."
echo "Remote path: $REMOTE_PATH"
echo "Motion detection: $MOTION_DETECTION (interval: ${MOTION_CHECK_INTERVAL}s)"

# ── Motion Detection Loop (runs independently from the main sync loop) ────────
if [ "$MOTION_DETECTION" = "true" ]; then
  echo "[motion] Starting motion detection background loop..."
  (
    while true; do
      echo "[motion] Running motion scan at $(date)..."
      /app/motion_clip.sh
      sleep "$MOTION_CHECK_INTERVAL"
    done
  ) &
fi

# ── Main Sync Loop ─────────────────────────────────────────────────────────────
while true; do
  if [ -f /app/rclone/settings.env ]; then
    source /app/rclone/settings.env
  fi

  echo "[$(date)] Starting sync..."

  # 1. Copy full recordings to Google Drive
  rclone copy /mnt/data "gdrive:${REMOTE_PATH}" \
    --exclude ".deleted/**" \
    --exclude "MotionClips/**" \
    --exclude ".motion_processed.log" \
    --config /app/rclone/rclone.conf --log-level INFO

  # 2. If motion detection is on, sync motion clips to a separate Drive folder
  if [ "$MOTION_DETECTION" = "true" ] && [ -d "/mnt/data/MotionClips" ]; then
    echo "[$(date)] Syncing motion clips..."
    rclone copy /mnt/data/MotionClips "gdrive:${REMOTE_PATH}/MotionClips" \
      --config /app/rclone/rclone.conf --log-level INFO
  fi

  # 3. Cleanup old local files to save PC disk space
  echo "[$(date)] Cleaning up local files older than $LOCAL_RETENTION_DAYS days..."
  find /mnt/data -type f -mtime +$LOCAL_RETENTION_DAYS \
    -not -path "*/MotionClips/*" \
    -not -name ".motion_processed.log" \
    -delete
  rm -rf /mnt/data/.deleted 2>/dev/null || true
  find /mnt/data -type d -empty -delete 2>/dev/null || true

  # 4. Cleanup old Google Drive files to save cloud space
  echo "[$(date)] Cleaning up Google Drive files older than $REMOTE_RETENTION_DAYS days..."
  rclone delete "gdrive:${REMOTE_PATH}" \
    --config /app/rclone/rclone.conf --min-age ${REMOTE_RETENTION_DAYS}d --log-level INFO
  rclone rmdirs "gdrive:${REMOTE_PATH}" \
    --config /app/rclone/rclone.conf --leave-root --log-level INFO

  echo "[$(date)] Sync complete. Sleeping for $SYNC_INTERVAL seconds."
  sleep $SYNC_INTERVAL
done
