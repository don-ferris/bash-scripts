#!/bin/bash

# Usage: ./mediasync.sh SRC DEST
SRC="$1"
DEST="$2"
LOG_FILE="/tmp/mediasync_1115.log"

if [[ -z "$SRC" || -z "$DEST" ]]; then
    echo "Usage: $0 SRC DEST"
    exit 1
fi

# Find all files in SRC recursively
find "$SRC" -type f | while read -r SRC_FILE; do
    # Remove SRC prefix, get relative path
    REL_PATH="${SRC_FILE#$SRC/}"
    DEST_FILE="$DEST/$REL_PATH"
    DEST_DIR="$(dirname "$DEST_FILE")"

    if [[ -f "$DEST_FILE" ]]; then
        # File exists in DEST, compare with diff
        if diff -q "$SRC_FILE" "$DEST_FILE" > /dev/null; then
            echo "$SRC/$REL_PATH and $DEST/$REL_PATH are identical" >> "$LOG_FILE"
            continue
        fi
    fi

    # File does not exist or is not identical, copy SRC_FILE to DEST
    mkdir -p "$DEST_DIR"
    cp "$SRC_FILE" "$DEST_FILE"
    
    # Post-copy check
    if [[ -f "$DEST_FILE" ]] && diff -q "$SRC_FILE" "$DEST_FILE" > /dev/null; then
        echo "$SRC/$REL_PATH and $DEST/$REL_PATH are identical" >> "$LOG_FILE"
    else
        echo "ERROR copying $SRC_FILE to $DEST_FILE" >> "$LOG_FILE"
    fi
done
