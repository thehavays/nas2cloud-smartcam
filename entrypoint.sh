#!/bin/bash

echo "Starting Auth Server in background..."
node /app/server.js &

echo "Starting Sync Script in background..."
/app/sync.sh &

echo "Starting Samba..."
# Execute the original dperson/samba entrypoint in the foreground
# The command line arguments passed in the compose file will be passed as "$@"
exec /usr/bin/samba.sh "$@"
