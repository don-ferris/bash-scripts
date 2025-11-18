#!/usr/bin/env bash
# mda5ync.sh - compare md5 hashes between SRC and DEST, copying missing files first
# Usage:
#   mda5ync.sh SRC DEST
# If SRC and DEST are not both supplied as command-line arguments, the script will prompt.
#
# Behavior changes:
# - If a file exists in SRC but is missing in DEST, the script will copy the file
#   (creating any necessary destination subdirectories), then re-run the md5 compare
#   and write ONLY the resulting SAME/DIFF entry to the log (no MISSING lines).
# - SRC is validated to exist and to contain at least one file; otherwise the script aborts.
# - DEST (and the entire SRC directory tree under DEST) will be created if missing.
#
# Implementation notes:
# - Uses simple, fast cp for copying.
# - Handles arbitrary filenames (spaces/newlines) via find -print0 and read -d ''.
# - Well-commented and straightforward flow; no other changes made.

set -o errexit
set -o nounset
set -o pipefail

# If two parameters passed, use them; otherwise prompt for both.
if [ "$#" -eq 2 ]; then
  src="$1"
  dst="$2"
else
  read -rp "Enter source directory: " src
  read -rp "Enter destination directory: " dst
fi

# Normalize paths (remove trailing slashes for consistent prefix stripping)
src="${src%/}"
dst="${dst%/}"

# Validate SRC exists and is a directory
if [ ! -d "$src" ]; then
  echo "Error: source directory '$src' does not exist or is not a directory." >&2
  exit 1
fi

# Validate SRC is not empty (it must contain at least one file)
if ! find "$src" -type f -print -quit | grep -q .; then
  echo "Error: source directory '$src' contains no files to compare." >&2
  exit 1
fi

# Ensure DEST exists
mkdir -p "$dst"

# Generate log filenames with date/time format: YY-JJJ-HHMM
# YY = 2-digit year, JJJ = 3-digit Julian date, HH = 2-digit hour (24hr), MM = 2-digit minute
timestamp=$(date +%y)$(date +%j)-$(date +%H)$(date +%M)
LOG_FILE="mda5ync_${timestamp}.log"
DIFF_LOG="mda5ync-diff_${timestamp}.log"
COPYFAIL_LOG="mda5ync-copyfail_${timestamp}.log"

# Initialize log files
echo "Comparison started at $(date)" > "$LOG_FILE"
echo "Comparison started at $(date)" > "$DIFF_LOG"
echo "Comparison started at $(date)" > "$COPYFAIL_LOG"

# Replicate the directory tree from SRC into DEST (creates any needed subdirs up-front).
# This avoids repeating mkdir for each file later and is fast for large trees.
# Use -print0 to handle names with special characters.
find "$src" -type d -print0 | while IFS= read -r -d '' d; do
  # Compute relative directory path from SRC (strip SRC prefix and any leading slash)
  rel="${d#$src}"
  rel="${rel#/}"
  mkdir -p "$dst/$rel"
done

# Get file counts for each directory and log them
echo "Analyzing directory structure..." | tee -a "$LOG_FILE"
find "$src" -type d -print0 | while IFS= read -r -d '' d; do
  # Compute relative directory path from SRC
  rel="${d#$src}"
  rel="${rel#/}"
  
  # Handle the root case
  if [ -z "$rel" ]; then
    dir_name="root"
  else
    dir_name="$rel"
  fi
  
  # Count files in this directory
  file_count=$(find "$d" -maxdepth 1 -type f | wc -l)
  
  if [ "$file_count" -gt 0 ]; then
    echo "Syncing $file_count files in $dir_name" | tee -a "$LOG_FILE"
    
    # Send ntfy notification for directory start
    curl -s -X POST -d "Syncing $file_count files in $dir_name" https://ntfy.sh/tango-tango-8tst >/dev/null 2>&1
  fi
done

# Track counters for each directory
declare -A dir_total dir_same dir_diff dir_copyfail

# Initialize counters
dir_total=()
dir_same=()
dir_diff=()
dir_copyfail=()

# Walk through files in SRC and compare to DEST. If missing, copy then recompare.
find "$src" -type f -print0 | while IFS= read -r -d '' f; do
  # Relative path of the file under SRC
  rel="${f#$src}"
  rel="${rel#/}"

  # Destination file path
  dest_file="$dst/$rel"

  # Get the directory for tracking
  dir_path=$(dirname "$rel")
  if [ "$dir_path" = "." ]; then
    track_dir="root"
  else
    track_dir="$dir_path"
  fi
  
  # Initialize directory counters if not set
  if [ -z "${dir_total[$track_dir]+isset}" ]; then
    dir_total[$track_dir]=0
    dir_same[$track_dir]=0
    dir_diff[$track_dir]=0
    dir_copyfail[$track_dir]=0
  fi

  # Increment total file count for this directory
  ((dir_total[$track_dir]++))

  if [ -f "$dest_file" ]; then
    # Both files exist: compare MD5 sums
    src_hash=$(md5sum "$f" | cut -d' ' -f1)
    dst_hash=$(md5sum "$dest_file" | cut -d' ' -f1)
    if [ "$src_hash" = "$dst_hash" ]; then
      echo "SAME: $rel" >> "$LOG_FILE"
      ((dir_same[$track_dir]++))
    else
      echo "DIFF: $rel" >> "$LOG_FILE"
      echo "DIFF: $rel" >> "$DIFF_LOG"
      ((dir_diff[$track_dir]++))
    fi
  else
    # File missing in DEST: copy it (preserving directories already created above),
    # then recompare and write ONLY the SAME/DIFF result to the log.
    # Use a simple, fast cp operation.
    # Ensure destination directory exists (defensive; should already exist from tree replication)
    mkdir -p "$(dirname "$dest_file")"

    if cp -- "$f" "$dest_file"; then
      src_hash=$(md5sum "$f" | cut -d' ' -f1)
      dst_hash=$(md5sum "$dest_file" | cut -d' ' -f1)
      if [ "$src_hash" = "$dst_hash" ]; then
        echo "SAME: $rel" >> "$LOG_FILE"
        ((dir_same[$track_dir]++))
      else
        echo "DIFF: $rel" >> "$LOG_FILE"
        echo "DIFF: $rel" >> "$DIFF_LOG"
        ((dir_diff[$track_dir]++))
      fi
    else
      # If copy fails, record the failure so the user can inspect the log.
      echo "COPY FAILED: $rel" >> "$LOG_FILE"
      echo "COPY FAILED: $rel" >> "$COPYFAIL_LOG"
      ((dir_copyfail[$track_dir]++))
    fi
  fi
done

# Write summary for each directory
echo "" >> "$LOG_FILE"
echo "=== DIRECTORY SUMMARIES ===" >> "$LOG_FILE"

for dir in "${!dir_total[@]}"; do
  total=${dir_total[$dir]}
  same=${dir_same[$dir]}
  diff=${dir_diff[$dir]}
  copyfail=${dir_copyfail[$dir]}
  
  echo "" >> "$LOG_FILE"
  echo "Finished syncing $total files in $dir - $same files were the same, $diff files were different, and $copyfail files failed to copy. See $LOG_FILE, $DIFF_LOG and $COPYFAIL_LOG for details." >> "$LOG_FILE"
  
  # Send ntfy notification with summary
  curl -s -X POST -d "Finished syncing $total files in $dir..." https://ntfy.sh/tango-tango-8tst >/dev/null 2>&1
done

echo "" >> "$LOG_FILE"
echo "Comparison finished. Results saved to $LOG_FILE (diff: $DIFF_LOG, copyfail: $COPYFAIL_LOG)" | tee -a "$LOG_FILE"

# Open the main log file in nano for review
nano "$LOG_FILE"
