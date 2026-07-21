#!/bin/sh

# Sync script that runs rclone periodically
# Syncs /data (the mounted samba share) to the 'gdrive' remote

SYNC_INTERVAL=${SYNC_INTERVAL:-3600} # Default to 1 hour (3600 seconds)

echo "Starting rclone sync script. Sync interval: $SYNC_INTERVAL seconds."

while true; do
  echo "[$(date)] Starting sync..."
  # We use 'copy' instead of 'sync' to avoid deleting files on Google Drive if they are deleted from the NAS.
  # If you want to strictly mirror (and delete from Drive if deleted from NAS), change 'copy' to 'sync'.
  rclone copy /mnt/data gdrive:XiaomiCameraBackup --config /app/rclone/rclone.conf --log-level INFO
  echo "[$(date)] Sync complete. Sleeping for $SYNC_INTERVAL seconds."
  sleep $SYNC_INTERVAL
done
