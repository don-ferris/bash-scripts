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
