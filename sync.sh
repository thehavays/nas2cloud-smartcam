#!/bin/sh

# Sync script that runs rclone periodically
# Syncs /data (the mounted samba share) to the 'gdrive' remote

SYNC_INTERVAL=${SYNC_INTERVAL:-3600} # Default to 1 hour (3600 seconds)
LOCAL_RETENTION_DAYS=${LOCAL_RETENTION_DAYS:-7} # Keep files on local PC for 7 days
REMOTE_RETENTION_DAYS=${REMOTE_RETENTION_DAYS:-30} # Keep files on Google Drive for 30 days

echo "Starting rclone sync script."
echo "Sync interval: $SYNC_INTERVAL seconds."
echo "Local retention: $LOCAL_RETENTION_DAYS days."
echo "Remote retention: $REMOTE_RETENTION_DAYS days."

while true; do
  if [ -f /app/rclone/settings.env ]; then
    source /app/rclone/settings.env
  fi

  echo "[$(date)] Starting sync..."
  
  # 1. Copy new files to Google Drive
  rclone copy /mnt/data gdrive:XiaomiCameraBackup --config /app/rclone/rclone.conf --log-level INFO
  
  # 2. Cleanup old local files to save PC disk space
  echo "[$(date)] Cleaning up local files older than $LOCAL_RETENTION_DAYS days..."
  find /mnt/data -type f -mtime +$LOCAL_RETENTION_DAYS -delete
  find /mnt/data -type d -empty -delete 2>/dev/null || true

  # 3. Cleanup old Google Drive files to save cloud space
  echo "[$(date)] Cleaning up Google Drive files older than $REMOTE_RETENTION_DAYS days..."
  rclone delete gdrive:XiaomiCameraBackup --config /app/rclone/rclone.conf --min-age ${REMOTE_RETENTION_DAYS}d --log-level INFO
  rclone rmdirs gdrive:XiaomiCameraBackup --config /app/rclone/rclone.conf --leave-root --log-level INFO

  echo "[$(date)] Sync complete. Sleeping for $SYNC_INTERVAL seconds."
  sleep $SYNC_INTERVAL
done
