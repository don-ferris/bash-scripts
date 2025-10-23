#!/usr/bin/env bash
# fixnano
#
# installs a modified /etc/nanorc to enable mouse support and common keybindings in nano.
set -euo pipefail

REMOTE_URL="https://raw.githubusercontent.com/don-ferris/bash-scripts/main/etc-nanorc"

# Determine script directory (works when invoked from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LOCAL_ETC="$SCRIPT_DIR/etc-nanorc"

# Temporary staging file
TMPFILE="$(mktemp /tmp/etc-nanorc.XXXXXX)"

cleanup() {
  rm -f "$TMPFILE" 2>/dev/null || true
}
trap cleanup EXIT

echo "fixnano: looking for local etc-nanorc..."

if [ -f "$LOCAL_ETC" ] && [ -s "$LOCAL_ETC" ]; then
  echo "fixnano: found local etc-nanorc at: $LOCAL_ETC"
  cp -- "$LOCAL_ETC" "$TMPFILE"
else
  echo "fixnano: local etc-nanorc not found; downloading from $REMOTE_URL"
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL -- "$REMOTE_URL" -o "$TMPFILE"; then
      echo "fixnano: error: download failed (curl)."
      exit 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$TMPFILE" -- "$REMOTE_URL"; then
      echo "fixnano: error: download failed (wget)."
      exit 1
    fi
  else
    echo "fixnano: error: neither curl nor wget available to download etc-nanorc."
    exit 1
  fi
fi

# Basic validation: ensure file is non-empty and contains some expected token (optional)
if [ ! -s "$TMPFILE" ]; then
  echo "fixnano: error: etc-nanorc is empty or missing after staging."
  exit 1
fi

# Confirm /etc exists and we can write to /etc/nanorc (use sudo if necessary)
TARGET="/etc/nanorc"

echo "fixnano: preparing to install $TARGET"

if [ -f "$TARGET" ]; then
  TIMESTAMP="$(date +%Y%m%d%H%M%S)"
  BACKUP="${TARGET}.bak.${TIMESTAMP}"
  echo "fixnano: backing up existing $TARGET -> $BACKUP"
  if [ "$(id -u)" -eq 0 ]; then
    cp -- "$TARGET" "$BACKUP"
  else
    sudo cp -- "$TARGET" "$BACKUP"
  fi
fi

# Install the new file
if [ "$(id -u)" -eq 0 ]; then
  cp -- "$TMPFILE" "$TARGET"
  chmod 644 "$TARGET"
else
  sudo cp -- "$TMPFILE" "$TARGET"
  sudo chmod 644 "$TARGET"
fi

echo "fixnano: installed etc-nanorc to $TARGET"

# Optional: report a brief snippet to show success
echo "fixnano: first lines of installed /etc/nanorc:"
if [ "$(id -u)" -eq 0 ]; then
  head -n 6 "$TARGET" || true
else
  sudo head -n 6 "$TARGET" || true
fi

echo "fixnano: done."
exit 0
