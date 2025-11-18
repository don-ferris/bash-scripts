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

# Replicate the directory tree from SRC into DEST (creates any needed subdirs up-front).
# This avoids repeating mkdir for each file later and is fast for large trees.
# Use -print0 to handle names with special characters.
find "$src" -type d -print0 | while IFS= read -r -d '' d; do
  # Compute relative directory path from SRC (strip SRC prefix and any leading slash)
  rel="${d#$src}"
  rel="${rel#/}"
  mkdir -p "$dst/$rel"
done

# Log file in current directory
logfile="mda5ync.log"
echo "mda5ync (md5 MediaSync) started at $(date)" > "$logfile"

# Walk through files in SRC and compare to DEST. If missing, copy then recompare.
find "$src" -type f -print0 | while IFS= read -r -d '' f; do
  # Relative path of the file under SRC
  rel="${f#$src}"
  rel="${rel#/}"

  # Destination file path
  dest_file="$dst/$rel"

  if [ -f "$dest_file" ]; then
    # Both files exist: compare MD5 sums
    src_hash=$(md5sum "$f" | cut -d' ' -f1)
    dst_hash=$(md5sum "$dest_file" | cut -d' ' -f1)
    if [ "$src_hash" = "$dst_hash" ]; then
      echo "SAME: $rel" >> "$logfile"
    else
      echo "DIFF: $rel" >> "$logfile"
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
        echo "SAME: $rel" >> "$logfile"
      else
        echo "DIFF: $rel" >> "$logfile"
      fi
    else
      # If copy fails, record the failure so the user can inspect the log.
      echo "COPY FAILED: $rel" >> "$logfile"
    fi
  fi
done

echo "Sync finished. Results saved to $logfile"
