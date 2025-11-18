#!/usr/bin/env bash
# mda5ync.sh - compare md5 hashes between SRC and DEST, copying missing files first
# Usage:
#   mda5ync.sh SRC DEST
#
# Simplified for Ubuntu Server per request:
# - ALL_CAPS variable names
# - prints "Processing $SRC_FILE" for every source file on stdout
# - uses curl only for ntfy (no checks/installation code for curl)
# - no package-manager/install code at all
#
# Behavior:
# - copies missing files, then compares md5 and logs SAME/DIFF
# - creates three logs with timestamped names (main, diffs, copy-fails)
# - sends ntfy notifications (topic: tango-tango-8tst) via curl for start/finish of each directory
# - opens main log in nano at the end if available

set -o errexit
set -o nounset
set -o pipefail

# Ensure the script is run as root (keeps previous behavior)
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: this script must be run as root." >&2
  exit 1
fi

# Get SRC/DST
if [ "$#" -eq 2 ]; then
  SRC="$1"
  DST="$2"
else
  read -rp "Enter source directory: " SRC
  read -rp "Enter destination directory: " DST
fi

# Normalize paths (remove trailing slashes)
SRC="${SRC%/}"
DST="${DST%/}"

# Validate SRC exists and contains at least one file somewhere in the tree
if [ ! -d "$SRC" ]; then
  echo "Error: source directory '$SRC' does not exist or is not a directory." >&2
  exit 1
fi

if ! find "$SRC" -type f -print -quit | grep -q .; then
  echo "Error: source directory '$SRC' contains no files to compare." >&2
  exit 1
fi

# Ensure DST exists
mkdir -p "$DST"

# Timestamp and logs (TS is the timestamp variable)
TS=$(date +"%y%j-%H%M")
LOGFILE="mda5ync_${TS}.log"
DIFF_LOG="mda5ync-diff_${TS}.log"
COPYFAIL_LOG="mda5ync-copyfail_${TS}.log"

echo "mda5ync (md5 MediaSync) started at $(date)" > "$LOGFILE"
echo "Diffs for run started at $(date)" > "$DIFF_LOG"
echo "Copy failures for run started at $(date)" > "$COPYFAIL_LOG"

# Helper to send notifications via curl only (no checks/install)
# Topic: tango-tango-8tst
send_ntfy() {
  local MESSAGE="$1"
  # Use curl to post to ntfy.sh; best-effort and log failures
  if ! curl -sS -X POST -H "Title: mda5ync" -d "$MESSAGE" "https://ntfy.sh/tango-tango-8tst" >/dev/null 2>&1; then
    echo "WARNING: ntfy send failed for message: $MESSAGE" >> "$LOGFILE"
  fi
}

# Collect all directories into an array (handles names with newlines/spaces)
readarray -d '' -t DIRS < <(find "$SRC" -type d -print0)

# Replicate directory tree in destination
for DIR in "${DIRS[@]}"; do
  REL="${DIR#$SRC}"
  REL="${REL#/}"
  mkdir -p "$DST/$REL"
done

# Process each directory
for DIR in "${DIRS[@]}"; do
  REL_DIR="${DIR#$SRC}"
  REL_DIR="${REL_DIR#/}"
  [ -z "$REL_DIR" ] && DISPLAY_DIR="." || DISPLAY_DIR="$REL_DIR"

  # Gather files directly in this directory (non-recursive)
  readarray -d '' -t FILES < <(find "$DIR" -maxdepth 1 -type f -print0)
  FILE_COUNT=${#FILES[@]}

  START_MSG="Syncing ${FILE_COUNT} files in ${DISPLAY_DIR}"
  echo "$START_MSG" >> "$LOGFILE"
  send_ntfy "$START_MSG"

  SAME_COUNT=0
  DIFF_COUNT=0
  COPYFAIL_COUNT=0

  for SRC_FILE in "${FILES[@]}"; do
    # Echo to stdout so user sees progress
    printf 'Processing %s\n' "$SRC_FILE"

    # Relative path of the file under SRC
    REL="${SRC_FILE#$SRC}"
    REL="${REL#/}"

    DEST_FILE="$DST/$REL"

    if [ -f "$DEST_FILE" ]; then
      SRC_HASH=$(md5sum "$SRC_FILE" | cut -d' ' -f1)
      DST_HASH=$(md5sum "$DEST_FILE" | cut -d' ' -f1)
      if [ "$SRC_HASH" = "$DST_HASH" ]; then
        echo "SAME: $REL" >> "$LOGFILE"
        SAME_COUNT=$((SAME_COUNT + 1))
      else
        echo "DIFF: $REL" >> "$LOGFILE"
        echo "DIFF: $REL" >> "$DIFF_LOG"
        DIFF_COUNT=$((DIFF_COUNT + 1))
      fi
    else
      mkdir -p "$(dirname "$DEST_FILE")"
      if cp -- "$SRC_FILE" "$DEST_FILE"; then
        SRC_HASH=$(md5sum "$SRC_FILE" | cut -d' ' -f1)
        DST_HASH=$(md5sum "$DEST_FILE" | cut -d' ' -f1)
        if [ "$SRC_HASH" = "$DST_HASH" ]; then
          echo "SAME: $REL" >> "$LOGFILE"
          SAME_COUNT=$((SAME_COUNT + 1))
        else
          echo "DIFF: $REL" >> "$LOGFILE"
          echo "DIFF: $REL" >> "$DIFF_LOG"
          DIFF_COUNT=$((DIFF_COUNT + 1))
        fi
      else
        echo "COPY FAILED: $REL" >> "$LOGFILE"
        echo "COPY FAILED: $REL" >> "$COPYFAIL_LOG"
        COPYFAIL_COUNT=$((COPYFAIL_COUNT + 1))
      fi
    fi
  done

  SUMMARY_MSG="Finished syncing ${FILE_COUNT} files in ${DISPLAY_DIR} - ${SAME_COUNT} files were the same, ${DIFF_COUNT} files were different, and ${COPYFAIL_COUNT} files failed to copy. See ${LOGFILE}"
  echo "$SUMMARY_MSG" >> "$LOGFILE"
  send_ntfy "$SUMMARY_MSG"
done

echo "Sync finished. Results saved to $LOGFILE"

# Open the main log in nano if available
if command -v nano >/dev/null 2>&1; then
  nano "$LOGFILE"
else
  echo "Note: nano not found. Main log is at $LOGFILE"
fi
