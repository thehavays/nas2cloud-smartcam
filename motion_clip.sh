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

# ── Helper: Get video wall-clock start time as Unix epoch ────────────────────
# Brand-agnostic 3-level fallback chain:
#   Level 1: ffprobe creation_time metadata  (Xiaomi, Reolink, Amcrest…)
#   Level 2: Timestamp parsed from filename  (Reolink: 20250725_143000.mp4)
#   Level 3: File mtime minus duration       (last resort — always works)
get_video_start_epoch() {
  _VIDEO="$1"
  _DURATION="$2"

  # Internal logger: writes to stderr + events file only (NOT stdout)
  # This is critical — the function is called in a $() subshell, so any
  # stdout output would pollute the returned epoch value.
  _log() {
    MSG="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$MSG" >&2
    echo "$MSG" >> "$EVENTS_LOG"
  }

  # Level 1 — embedded MP4 metadata
  _META=$(ffprobe -v error \
    -show_entries format_tags=creation_time \
    -of default=noprint_wrappers=1:nokey=1 \
    "$_VIDEO" 2>/dev/null | head -1)
  if [ -n "$_META" ]; then
    _EPOCH=$(date -d "$_META" +%s 2>/dev/null)
    # Reject epoch=0 (1970-01-01): camera did not set its clock
    if [ -n "$_EPOCH" ] && [ "$_EPOCH" -gt 86400 ]; then
      _log "TIMESRC    Level 1 (metadata)  → $_META"
      echo "$_EPOCH"
      return
    fi
  fi

  # Level 2 — timestamp embedded in filename
  # Matches: 20250725_143000, 20250725143000, 2025-07-25_14-30-00, etc.
  _FNAME=$(basename "$_VIDEO")
  _RAW=$(echo "$_FNAME" | grep -oE '[0-9]{8}[_T-]?[0-9]{6}' | head -1)
  if [ -n "$_RAW" ]; then
    _CLEAN=$(echo "$_RAW" | tr -d '_T-')
    _DATE="${_CLEAN%${_CLEAN#????????}}"
    _TIME="${_CLEAN#????????}"
    _EPOCH=$(date -d "${_DATE:0:4}-${_DATE:4:2}-${_DATE:6:2} ${_TIME:0:2}:${_TIME:2:2}:${_TIME:4:2}" +%s 2>/dev/null)
    if [ -n "$_EPOCH" ] && [ "$_EPOCH" -gt 86400 ]; then
      _log "TIMESRC    Level 2 (filename)   → $_RAW"
      echo "$_EPOCH"
      return
    fi
  fi

  # Level 3 — file mtime minus video duration (approximate recording start)
  _MTIME=$(stat -c %Y "$_VIDEO" 2>/dev/null)
  if [ -n "$_MTIME" ] && [ -n "$_DURATION" ]; then
    _EPOCH=$(awk "BEGIN{printf \"%d\", $_MTIME - $_DURATION}")
    _log "TIMESRC    Level 3 (mtime-dur)  → $(date -d \"@$_EPOCH\" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    echo "$_EPOCH"
    return
  fi

  # Final safety fallback
  _log "TIMESRC    Level 3 (now)        → fallback to current time"
  date +%s
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
# Find all mp4 files in subdirectories (any camera brand) and the snapshot
for VIDEO in "$DATA_DIR"/*/*.mp4 "$SNAPSHOT"; do
  # Skip if it doesn't exist (e.g. glob failed to match)
  [ -f "$VIDEO" ] || continue

  IS_SNAPSHOT=false
  [ "$VIDEO" = "$SNAPSHOT" ] && IS_SNAPSHOT=true

  BASENAME=$(basename "$VIDEO")

  if [ "$IS_SNAPSHOT" = true ] && [ -n "$ACTIVE_FILE" ]; then
    CAM_NAME=$(basename "$(dirname "/mnt/data/$ACTIVE_FILE")")
  else
    CAM_NAME=$(basename "$(dirname "$VIDEO")")
  fi

  # Skip completed files that were already processed
  if [ "$IS_SNAPSHOT" = false ]; then
    grep -qF "$VIDEO" "$PROCESSED_LOG" && continue
  else
    # If this is the snapshot, but the original file it was copied from was
    # already processed as a completed file, skip it to avoid duplicate clips.
    if [ -n "$ACTIVE_FILE" ]; then
      grep -qF "/mnt/data/$ACTIVE_FILE" "$PROCESSED_LOG" && continue
    fi
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

  # Resolve the real wall-clock start time of this video (brand-agnostic)
  if [ "$IS_SNAPSHOT" = true ] && [ -n "$ACTIVE_FILE" ]; then
    # Use the original file path so metadata and filename parsing (Level 1 & 2) work correctly
    VIDEO_START_EPOCH=$(get_video_start_epoch "/mnt/data/$ACTIVE_FILE" "$DURATION")
  else
    VIDEO_START_EPOCH=$(get_video_start_epoch "$VIDEO" "$DURATION")
  fi

  # Derive clip date from the resolved start epoch
  CLIP_DATE=$(date -d "@$VIDEO_START_EPOCH" +%Y-%m-%d 2>/dev/null)
  [ -z "$CLIP_DATE" ] && CLIP_DATE=$(date +%Y-%m-%d)
  mkdir -p "$MOTION_DIR/$CAM_NAME/$CLIP_DATE"

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

    # Real wall-clock time = video start + in-video offset
    EVENT_EPOCH=$(awk "BEGIN{printf \"%d\", $VIDEO_START_EPOCH + ${TS%.*}}")
    TS_LABEL=$(date -d "@$EVENT_EPOCH" +%H-%M-%S 2>/dev/null || printf "%06d" "${TS%.*}")
    OUT_FILE="$MOTION_DIR/$CAM_NAME/$CLIP_DATE/${TS_LABEL}.mp4"

    log "MOTION     t=${TS}s → MotionClips/$CAM_NAME/$CLIP_DATE/${TS_LABEL}.mp4"
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
