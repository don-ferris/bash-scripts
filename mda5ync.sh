#!/usr/bin/env bash
# mda5ync.sh - compare md5 hashes between SRC and DEST, copying missing files first

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

# Normalize paths
src="${src%/}"
dst="${dst%/}"

# Validate SRC exists and is a directory
if [ ! -d "$src" ]; then
  echo "Error: source directory '$src' does not exist or is not a directory." >&2
  exit 1
fi

# Validate SRC is not empty
if ! find "$src" -type f -print -quit | grep -q .; then
  echo "Error: source directory '$src' contains no files to compare." >&2
  exit 1
fi

# Ensure DEST exists
mkdir -p "$dst"

# Generate log filenames
timestamp=$(date +%y-%j-%H%M)
LOG_FILE="mda5ync_${timestamp}.log"
DIFF_LOG="mda5ync-diff_${timestamp}.log"
COPYFAIL_LOG="mda5ync-copyfail_${timestamp}.log"

# Initialize log files
echo "Comparison started at $(date)" > "$LOG_FILE"
echo "Comparison started at $(date)" > "$DIFF_LOG"
echo "Comparison started at $(date)" > "$COPYFAIL_LOG"

# Track counters for each directory
declare -A dir_total dir_same dir_diff dir_copyfail

# Create directory structure first
echo "Creating directory structure..." | tee -a "$LOG_FILE"
find "$src" -type d | while IFS= read -r d; do
  rel="${d#$src}"
  rel="${rel#/}"
  mkdir -p "$dst/$rel"
done

# Build list of directories with files and initialize counters
echo "Analyzing directory structure..." | tee -a "$LOG_FILE"
directories_with_files=()

while IFS= read -r d; do
  rel="${d#$src}"
  rel="${rel#/}"
  
  if [ -z "$rel" ]; then
    dir_name="root"
  else
    dir_name="$rel"
  fi
  
  file_count=$(find "$d" -maxdepth 1 -type f | wc -l)
  
  if [ "$file_count" -gt 0 ]; then
    echo "Starting sync of $file_count files in $dir_name" | tee -a "$LOG_FILE"
    curl -s -X POST -d "Starting sync of $file_count files in $dir_name" https://ntfy.sh/tango-tango-8tst >/dev/null 2>&1
    
    # Store directory for tracking
    directories_with_files+=("$dir_name")
    dir_total["$dir_name"]=0
    dir_same["$dir_name"]=0
    dir_diff["$dir_name"]=0
    dir_copyfail["$dir_name"]=0
  fi
done < <(find "$src" -type d)

# Process files - using a temporary file to avoid subshell for main processing
echo "Processing files..." | tee -a "$LOG_FILE"
temp_file_list=$(mktemp)
find "$src" -type f > "$temp_file_list"

while IFS= read -r f; do
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
  
  # Skip if this directory wasn't initialized (shouldn't happen, but defensive)
  if [ -z "${dir_total[$track_dir]+isset}" ]; then
    continue
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
    # File missing in DEST: copy it
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
      echo "COPY FAILED: $rel" >> "$LOG_FILE"
      echo "COPY FAILED: $rel" >> "$COPYFAIL_LOG"
      ((dir_copyfail[$track_dir]++))
    fi
  fi
done < "$temp_file_list"

rm -f "$temp_file_list"

# Write summary for each directory
echo "" >> "$LOG_FILE"
echo "=== DIRECTORY SUMMARIES ===" >> "$LOG_FILE"

for dir in "${directories_with_files[@]}"; do
  total=${dir_total[$dir]}
  same=${dir_same[$dir]}
  diff=${dir_diff[$dir]}
  copyfail=${dir_copyfail[$dir]}
  
  echo "" >> "$LOG_FILE"
  echo "Finished syncing $total files in $dir - $same files were the same, $diff files were different, and $copyfail files failed to copy." >> "$LOG_FILE"
  
  curl -s -X POST -d "Finished syncing $total files in $dir - $same files were the same, $diff files were different, and $copyfail files failed to copy" https://ntfy.sh/tango-tango-8tst >/dev/null 2>&1
done

echo "" >> "$LOG_FILE"
echo "Comparison finished. Results saved to $LOG_FILE (diff: $DIFF_LOG, copyfail: $COPYFAIL_LOG)" | tee -a "$LOG_FILE"

# Open the main log file in nano for review
nano "$LOG_FILE"
