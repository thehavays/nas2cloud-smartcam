#!/bin/sh

# Motion Clip Extractor
# Scans NAS recordings for motion events and cuts short clips.
# - Completed files: processed once, then logged and never re-processed.
# - Active file (currently being written): snapshot taken each run, never logged.

DATA_DIR="/mnt/data"
MOTION_DIR="$DATA_DIR/MotionClips"
PROCESSED_LOG="$DATA_DIR/.motion_processed.log"
EVENTS_LOG="$DATA_DIR/motion_events.log"
SENSITIVITY="${MOTION_SENSITIVITY:-0.02}"    # Scene change threshold (0.01=sensitive, 0.10=lenient)
BUFFER="${MOTION_CLIP_BUFFER:-15}"           # Seconds to add before/after motion event
SNAPSHOT="/tmp/active_snapshot.mp4"
TIMESTAMPS_FILE="/tmp/motion_times.txt"

mkdir -p "$MOTION_DIR"
touch "$PROCESSED_LOG"
touch "$EVENTS_LOG"

# Helper: write to both stdout and the persistent events log
log() {
  MSG="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$MSG"
  echo "$MSG" >> "$EVENTS_LOG"
}

# ── Step 1: Snapshot the active (currently written) file ─────────────────────
# Detect which file is locked by Samba (camera is still writing to it)
ACTIVE_FILE=$(smbstatus -L 2>/dev/null | grep -oE '[^ ]+\.mp4' | head -1)

if [ -n "$ACTIVE_FILE" ] && [ -f "/mnt/data/$ACTIVE_FILE" ]; then
  log "SNAPSHOT   $ACTIVE_FILE"
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

  BASENAME=$(basename "$VIDEO")

  # Skip completed files that were already processed
  if [ "$IS_SNAPSHOT" = false ]; then
    grep -qF "$VIDEO" "$PROCESSED_LOG" && continue
  fi

  log "ANALYZING  $BASENAME"

  # ── Step 3: Detect scene changes with FFmpeg (1 fps sampling for speed) ─────
  # Sampling at 1 frame/sec + small scale: ~30x faster than full decode
  # 1-hour video: ~3600 frames instead of ~108,000 → ~30-60 seconds per file
  > "$TIMESTAMPS_FILE"
  ffmpeg -y -i "$VIDEO" \
    -vf "fps=1,scale=320:180,select='gt(scene,$SENSITIVITY)',showinfo" \
    -vsync vfr \
    -an -f null - 2>&1 | \
    grep "pts_time" | \
    sed "s/.*pts_time:\([0-9.]*\).*/\1/" > "$TIMESTAMPS_FILE" || true

  if [ ! -s "$TIMESTAMPS_FILE" ]; then
    log "NO_MOTION  $BASENAME"
    [ "$IS_SNAPSHOT" = false ] && echo "$VIDEO" >> "$PROCESSED_LOG"
    continue
  fi

  # ── Step 4: Merge nearby events and cut clips ─────────────────────────────
  DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null || echo "0")
  # Extract true recording date from video metadata
  CLIP_DATE=$(ffprobe -v error -show_entries format_tags=creation_time -of default=noprint_wrappers=1:nokey=1 "$VIDEO" 2>/dev/null | cut -dT -f1)
  [ -z "$CLIP_DATE" ] && CLIP_DATE=$(date +%Y-%m-%d)
  mkdir -p "$MOTION_DIR/$CLIP_DATE"

  CLIP_COUNT=0
  LAST_CLIP_END="-999"

  while IFS= read -r TS; do
    # Skip if this event falls within the buffer zone of the last clip
    WITHIN=$(awk "BEGIN{print ($TS < $LAST_CLIP_END) ? 1 : 0}")
    [ "$WITHIN" = "1" ] && continue

    START=$(awk "BEGIN {s=$TS-$BUFFER; print (s<0)?0:s}")
    CLIP_DURATION=$(awk "BEGIN {print $BUFFER*2 + 10}")

    # Skip if start exceeds video duration
    EXCEEDS=$(awk "BEGIN{print ($START >= $DURATION) ? 1 : 0}")
    [ "$EXCEEDS" = "1" ] && continue

    TS_LABEL=$(date -u -d "@${TS%.*}" +%H-%M-%S 2>/dev/null || printf "%06d" "${TS%.*}")
    OUT_FILE="$MOTION_DIR/$CLIP_DATE/${TS_LABEL}.mp4"

    log "MOTION     t=${TS}s → MotionClips/$CLIP_DATE/${TS_LABEL}.mp4"
    ffmpeg -y -i "$VIDEO" -ss "$START" -t "$CLIP_DURATION" \
      -c copy -avoid_negative_ts make_zero \
      "$OUT_FILE" -loglevel error 2>/dev/null || true

    LAST_CLIP_END=$(awk "BEGIN{print $START + $CLIP_DURATION}")
    CLIP_COUNT=$((CLIP_COUNT + 1))
  done < "$TIMESTAMPS_FILE"

  log "DONE       $BASENAME ($CLIP_COUNT clip(s))"

  # Mark completed files as processed (never re-process)
  [ "$IS_SNAPSHOT" = false ] && echo "$VIDEO" >> "$PROCESSED_LOG"
done

log "SCAN_COMPLETE ---"
