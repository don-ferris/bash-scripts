#!/usr/bin/env bash
# mda5ync.sh - compare md5 hashes between SRC and DEST, copying missing files first
# Usage:
#   mda5ync.sh SRC DEST
#
# This variant is simplified for Ubuntu Server and hard-codes apt installs.
# Bugfixes included:
# - reliably iterates all subdirectories (no subshell/pipeline issues)
# - correctly counts files per directory and processes them
# - clearer, robust handling of pip-installed ntfy in ~/.local/bin
#
# Behaviour:
# - copies missing files, then compares md5 and logs SAME/DIFF
# - creates three logs with timestamped names (main, diffs, copy-fails)
# - sends ntfy notifications (topic: tango-tango-8tst) for start/finish of each directory
# - opens main log in nano at the end if available
set -o errexit
set -o nounset
set -o pipefail

# Ensure the script is run as root (required for package installation actions).
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: this script must be run as root." >&2
  exit 1
fi

# apt-only install helper (keeps installs non-interactive)
apt_install() {
  local pkg="$1"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null 2>&1 || return 1
  apt-get install -y -qq "$pkg" >/dev/null 2>&1 || return 1
  return 0
}

# Ensure a command exists, otherwise try to install it automatically via apt-get (or pip3 for ntfy).
ensure_command() {
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  echo "Command '$cmd' not found. Attempting to install it automatically using apt-get..."

  if [ "$cmd" = "curl" ]; then
    if apt_install curl; then
      echo "Installed curl via apt-get."
      return 0
    else
      echo "Failed to install curl via apt-get. Please install curl manually." >&2
      return 1
    fi
  elif [ "$cmd" = "ntfy" ]; then
    # Prefer pip3 global install if available
    if command -v pip3 >/dev/null 2>&1; then
      if pip3 install ntfy >/dev/null 2>&1; then
        if command -v ntfy >/dev/null 2>&1; then
          echo "Installed ntfy via pip3."
          return 0
        fi
      fi
    fi

    # Try pip fallback
    if command -v pip >/dev/null 2>&1; then
      if pip install ntfy >/dev/null 2>&1; then
        if command -v ntfy >/dev/null 2>&1; then
          echo "Installed ntfy via pip."
          return 0
        fi
      fi
    fi

    # Install pip3 via apt-get and retry
    if apt_install python3-pip; then
      if command -v pip3 >/dev/null 2>&1; then
        if pip3 install ntfy >/dev/null 2>&1; then
          if command -v ntfy >/dev/null 2>&1; then
            echo "Installed ntfy via pip3 (after installing python3-pip)."
            return 0
          fi
        fi
      fi
    fi

    # Try apt-get for ntfy (best-effort)
    if apt_install ntfy; then
      if command -v ntfy >/dev/null 2>&1; then
        echo "Installed ntfy via apt-get."
        return 0
      fi
    fi

    echo "Failed to install ntfy automatically. Please install ntfy (pip3 install ntfy) or via apt-get." >&2
    return 1
  else
    echo "No automatic install procedure for '$cmd' implemented." >&2
    return 1
  fi
}

# Ensure curl and ntfy are available
if ! command -v curl >/dev/null 2>&1; then
  if ! ensure_command curl; then
    echo "Error: curl is required but could not be installed automatically." >&2
    exit 1
  fi
fi

if ! command -v ntfy >/dev/null 2>&1; then
  if ! ensure_command ntfy; then
    echo "Error: ntfy is required but could not be installed automatically." >&2
    exit 1
  fi
fi

# Make sure pip-installed user binaries are on PATH (for root this can be ~/.local/bin)
export PATH="$HOME/.local/bin:$PATH"

# Get src/dst
if [ "$#" -eq 2 ]; then
  src="$1"
  dst="$2"
else
  read -rp "Enter source directory: " src
  read -rp "Enter destination directory: " dst
fi

# Normalize paths (remove trailing slashes)
src="${src%/}"
dst="${dst%/}"

# Validate SRC exists and contains at least one file somewhere in the tree
if [ ! -d "$src" ]; then
  echo "Error: source directory '$src' does not exist or is not a directory." >&2
  exit 1
fi

if ! find "$src" -type f -print -quit | grep -q .; then
  echo "Error: source directory '$src' contains no files to compare." >&2
  exit 1
fi

# Ensure DEST exists
mkdir -p "$dst"

# Timestamp and logs
ts=$(date +"%y%j-%H%M")
logfile="mda5ync_${ts}.log"
diff_log="mda5ync-diff_${ts}.log"
copyfail_log="mda5ync-copyfail_${ts}.log"

echo "mda5ync (md5 MediaSync) started at $(date)" > "$logfile"
echo "Diffs for run started at $(date)" > "$diff_log"
echo "Copy failures for run started at $(date)" > "$copyfail_log"

# Helper to send notifications
send_ntfy() {
  local message="$1"
  if command -v ntfy >/dev/null 2>&1; then
    if ! ntfy publish -t "mda5ync" -p tango-tango-8tst "$message" >/dev/null 2>&1; then
      if command -v curl >/dev/null 2>&1; then
        if ! curl -sS -X POST -H "Title: mda5ync" -d "$message" "https://ntfy.sh/tango-tango-8tst" >/dev/null 2>&1; then
          echo "WARNING: ntfy send failed for message: $message" >> "$logfile"
        fi
      else
        echo "WARNING: neither ntfy CLI nor curl available to send ntfy message: $message" >> "$logfile"
      fi
    fi
  else
    if command -v curl >/dev/null 2>&1; then
      if ! curl -sS -X POST -H "Title: mda5ync" -d "$message" "https://ntfy.sh/tango-tango-8tst" >/dev/null 2>&1; then
        echo "WARNING: ntfy send failed for message: $message" >> "$logfile"
      fi
    else
      echo "WARNING: curl not found; cannot send ntfy message: $message" >> "$logfile"
    fi
  fi
}

# Collect all directories into an array to avoid subshell/pipeline side-effects
readarray -d '' -t dirs < <(find "$src" -type d -print0)

# Replicate directory tree in destination
for d in "${dirs[@]}"; do
  rel="${d#$src}"
  rel="${rel#/}"
  mkdir -p "$dst/$rel"
done

# Process each directory
for dir in "${dirs[@]}"; do
  rel_dir="${dir#$src}"
  rel_dir="${rel_dir#/}"
  [ -z "$rel_dir" ] && display_dir="." || display_dir="$rel_dir"

  # Gather files directly in this directory (non-recursive)
  readarray -d '' -t files < <(find "$dir" -maxdepth 1 -type f -print0)
  file_count=${#files[@]}

  start_msg="Syncing ${file_count} files in ${display_dir}"
  echo "$start_msg" >> "$logfile"
  send_ntfy "$start_msg"

  same_count=0
  diff_count=0
  copyfail_count=0

  for f in "${files[@]}"; do
    # Relative path of the file under SRC
    rel="${f#$src}"
    rel="${rel#/}"

    dest_file="$dst/$rel"

    if [ -f "$dest_file" ]; then
      src_hash=$(md5sum "$f" | cut -d' ' -f1)
      dst_hash=$(md5sum "$dest_file" | cut -d' ' -f1)
      if [ "$src_hash" = "$dst_hash" ]; then
        echo "SAME: $rel" >> "$logfile"
        same_count=$((same_count + 1))
      else
        echo "DIFF: $rel" >> "$logfile"
        echo "DIFF: $rel" >> "$diff_log"
        diff_count=$((diff_count + 1))
      fi
    else
      mkdir -p "$(dirname "$dest_file")"
      if cp -- "$f" "$dest_file"; then
        src_hash=$(md5sum "$f" | cut -d' ' -f1)
        dst_hash=$(md5sum "$dest_file" | cut -d' ' -f1)
        if [ "$src_hash" = "$dst_hash" ]; then
          echo "SAME: $rel" >> "$logfile"
          same_count=$((same_count + 1))
        else
          echo "DIFF: $rel" >> "$logfile"
          echo "DIFF: $rel" >> "$diff_log"
          diff_count=$((diff_count + 1))
        fi
      else
        echo "COPY FAILED: $rel" >> "$logfile"
        echo "COPY FAILED: $rel" >> "$copyfail_log"
        copyfail_count=$((copyfail_count + 1))
      fi
    fi
  done

  summary_msg="Finished syncing ${file_count} files in ${display_dir} - ${same_count} files were the same, ${diff_count} files were different, and ${copyfail_count} files failed to copy. See ${logfile}"
  echo "$summary_msg" >> "$logfile"
  send_ntfy "$summary_msg"
done

echo "Sync finished. Results saved to $logfile"

# Open the main log in nano if available
if command -v nano >/dev/null 2>&1; then
  nano "$logfile"
else
  echo "Note: nano not found. Main log is at $logfile"
fi
