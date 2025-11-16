#!/bin/bash

# Usage: ./mediasync.sh SRC DEST
SRC="$1"
DEST="$2"
LOG_FILE="/tmp/mediasync_1115.log"
NTFY_TOPIC="mediasync-1115"

if [[ -z "$SRC" || -z "$DEST" ]]; then
    echo "Usage: $0 SRC DEST"
    exit 1
fi

# Send start notification
ntfy send "$NTFY_TOPIC" "MediaSync [$SRC] >> [$DEST] - starting now."

# Find all files in SRC recursively and count
TOTAL_COUNT=$(find "$SRC" -type f | wc -l)
NTFY_INTERVAL=$(( (TOTAL_COUNT + 9) / 10 )) # Divide by 10 and round up

PROC_COUNT=0
TOTAL_PROC_COUNT=0
ERR_COUNT=0

find "$SRC" -type f | while read -r SRC_FILE; do
    REL_PATH="${SRC_FILE#$SRC/}"
    DEST_FILE="$DEST/$REL_PATH"
    DEST_DIR="$(dirname "$DEST_FILE")"

    if [[ -f "$DEST_FILE" ]]; then
        if diff -q "$SRC_FILE" "$DEST_FILE" > /dev/null; then
            echo "$SRC/$REL_PATH and $DEST/$REL_PATH are identical" >> "$LOG_FILE"
            ((PROC_COUNT++))
            ((TOTAL_PROC_COUNT++))
            if (( PROC_COUNT == NTFY_INTERVAL )); then
                ntfy send "$NTFY_TOPIC" \
                    "MediaSync [$SRC] >> [$DEST] - [$TOTAL_PROC_COUNT] of [$TOTAL_COUNT] files processed with [$ERR_COUNT] errors."
                PROC_COUNT=0
            fi
            continue
        fi
    fi

    mkdir -p "$DEST_DIR"
    cp "$SRC_FILE" "$DEST_FILE"

    if [[ -f "$DEST_FILE" ]] && diff -q "$SRC_FILE" "$DEST_FILE" > /dev/null; then
        echo "$SRC/$REL_PATH and $DEST/$REL_PATH are identical" >> "$LOG_FILE"
    else
        echo "ERROR copying $SRC_FILE to $DEST_FILE" >> "$LOG_FILE"
        ((ERR_COUNT++))
    fi

    ((PROC_COUNT++))
    ((TOTAL_PROC_COUNT++))
    if (( PROC_COUNT == NTFY_INTERVAL )); then
        ntfy send "$NTFY_TOPIC" \
            "MediaSync [$SRC] >> [$DEST] - [$TOTAL_PROC_COUNT] of [$TOTAL_COUNT] files processed with [$ERR_COUNT] errors."
        PROC_COUNT=0
    fi
done

# Final notification
ntfy send "$NTFY_TOPIC" \
    "MediaSync [$SRC] >> [$DEST] - COMPLETE - [$TOTAL_PROC_COUNT] of [$TOTAL_COUNT] files processed. There were [$ERR_COUNT] errors."
