#!/usr/bin/env bash

# Prompt user for source and destination directories
read -rp "Enter source directory: " src
read -rp "Enter destination directory: " dst

# Log file in current directory
logfile="compare.log"
echo "Comparison started at $(date)" > "$logfile"

# Walk through source directory
find "$src" -type f -print0 | while IFS= read -r -d '' f; do
  rel="${f#$src/}"   # relative path
  if [ -f "$dst/$rel" ]; then
    src_hash=$(md5sum "$f" | cut -d' ' -f1)
    dst_hash=$(md5sum "$dst/$rel" | cut -d' ' -f1)
    if [ "$src_hash" = "$dst_hash" ]; then
      echo "SAME: $rel" >> "$logfile"
    else
      echo "DIFF: $rel" >> "$logfile"
    fi
  else
    echo "MISSING in $dst: $rel" >> "$logfile"
  fi
done

echo "Comparison finished. Results saved to $logfile"
