#!/bin/sh

# Motion Clip Extractor
# Scans NAS recordings for motion events and cuts short clips.
# - Completed files: processed once, then logged and never re-processed.
# - Active file (currently being written): snapshot taken each run, never logged.

DATA_DIR="/mnt/data"
MOTION_DIR="$DATA_DIR/MotionClips"
PROCESSED_LOG="$DATA_DIR/.motion_processed.log"
SENSITIVITY="${MOTION_SENSITIVITY:-0.02}"    # Scene change threshold (0.01=sensitive, 0.10=lenient)
BUFFER="${MOTION_CLIP_BUFFER:-15}"           # Seconds to add before/after motion event
SNAPSHOT="/tmp/active_snapshot.mp4"
TIMESTAMPS_FILE="/tmp/motion_times.txt"

mkdir -p "$MOTION_DIR"
touch "$PROCESSED_LOG"

# ── Step 1: Snapshot the active (currently written) file ─────────────────────
# Detect which file is locked by Samba (camera is still writing to it)
ACTIVE_FILE=$(smbstatus -L 2>/dev/null | grep -oE '[^ ]+\.mp4' | head -1)

if [ -n "$ACTIVE_FILE" ] && [ -f "/mnt/data/$ACTIVE_FILE" ]; then
  echo "[motion] Snapshotting active file: $ACTIVE_FILE"
  # Copy the already-written portion safely without waiting for the file to close
  ffmpeg -y -i "/mnt/data/$ACTIVE_FILE" -c copy "$SNAPSHOT" -loglevel error 2>/dev/null || true
else
  rm -f "$SNAPSHOT"
fi

# ── Step 2: Process all candidate files ──────────────────────────────────────
for VIDEO in "$DATA_DIR"/XiaomiCamera_*/*.mp4 "$SNAPSHOT"; do
  [ -f "$VIDEO" ] || continue

  IS_SNAPSHOT=false
  [ "$VIDEO" = "$SNAPSHOT" ] && IS_SNAPSHOT=true

  # Skip completed files that were already processed
  if [ "$IS_SNAPSHOT" = false ]; then
    grep -qF "$VIDEO" "$PROCESSED_LOG" && continue
  fi

  echo "[motion] Analyzing: $(basename $VIDEO)"

  # ── Step 3: Detect scene changes (motion events) with FFmpeg ─────────────
  > "$TIMESTAMPS_FILE"
  ffmpeg -y -i "$VIDEO" \
    -vf "select='gt(scene,$SENSITIVITY)',showinfo" \
    -vsync vfr \
    -an -f null - 2>&1 | \
    grep "pts_time" | \
    sed "s/.*pts_time:\([0-9.]*\).*/\1/" > "$TIMESTAMPS_FILE" || true

  if [ ! -s "$TIMESTAMPS_FILE" ]; then
    echo "[motion] No motion detected in $(basename $VIDEO)"
    # Mark completed files as processed even if no motion found
    [ "$IS_SNAPSHOT" = false ] && echo "$VIDEO" >> "$PROCESSED_LOG"
    continue
  fi

  # ── Step 4: Merge nearby events and cut clips ─────────────────────────────
  # Get video duration
  DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null || echo "0")
  CLIP_DATE=$(date +%Y-%m-%d)
  mkdir -p "$MOTION_DIR/$CLIP_DATE"

  LAST_CLIP_END="-999"
  while IFS= read -r TS; do
    # Skip if this event is within the buffer zone of the last clip (avoid overlapping clips)
    [ "$(echo "$TS < $LAST_CLIP_END" | awk '{print ($1 < $3)}')" = "1" ] 2>/dev/null && continue || true

    START=$(awk "BEGIN {s=$TS-$BUFFER; print (s<0)?0:s}")
    CLIP_DURATION=$(awk "BEGIN {print $BUFFER*2 + 10}")  # buffer*2 + a little extra

    # Ensure start doesn't exceed video duration
    [ "$(awk "BEGIN{print ($START >= $DURATION)}")" = "1" ] && continue || true

    TS_LABEL=$(date -d "1970-01-01 UTC + ${TS} seconds" +%H-%M-%S 2>/dev/null || date -u -d @${TS%.*} +%H-%M-%S 2>/dev/null || echo "${TS%.*}")
    OUT_FILE="$MOTION_DIR/$CLIP_DATE/${TS_LABEL}.mp4"

    echo "[motion] Cutting clip at ${TS}s → $(basename $OUT_FILE)"
    ffmpeg -y -ss "$START" -i "$VIDEO" -t "$CLIP_DURATION" \
      -c copy -avoid_negative_ts make_zero \
      "$OUT_FILE" -loglevel error 2>/dev/null || true

    LAST_CLIP_END=$(awk "BEGIN{print $START + $CLIP_DURATION}")
  done < "$TIMESTAMPS_FILE"

  echo "[motion] Done: $(basename $VIDEO)"

  # Mark completed files as processed (never re-process)
  [ "$IS_SNAPSHOT" = false ] && echo "$VIDEO" >> "$PROCESSED_LOG"
done

echo "[motion] Scan complete."
