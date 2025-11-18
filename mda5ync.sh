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
# Additional refinements requested:
# 1) Log files incorporate date/time in the form YYJJJ-HHMM (2-digit year, 3-digit Julian day, 2-digit hour, 2-digit minute)
# 2) In addition to the main log, create separate diff and copy-fail logs with the same timestamp
# 3) For each subdirectory (and the top-level SRC), count files in that directory and write:
#      "Syncing [file count] files in [directory name]"
#    and send the same message as an ntfy notification (topic: tango-tango-8tst)
# 4) When a directory finishes syncing, write a brief summary and send same via ntfy
# 5) When all is finished, open the main log in nano.
#
# This version: if curl or ntfy are missing the script will attempt to install them
# automatically (without prompting). It uses the available package manager when possible,
# or falls back to pip for the ntfy client. Root privileges (or sudo) are required
# for package installations.
#
# Implementation notes:
# - Uses simple, fast cp for copying.
# - Handles arbitrary filenames (spaces/newlines) via find -print0 and read -d ''.
# - Well-commented and straightforward flow; no other changes made.

set -o errexit
set -o nounset
set -o pipefail

# Helper: detect package manager
detect_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  elif command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v pkg >/dev/null 2>&1; then
    echo "pkg"
  else
    echo ""
  fi
}

# Determine whether to use sudo for installs
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    # We will require sudo or root for package installs; continue if tools already present.
    SUDO=""
  fi
fi

# Install a package with the detected package manager (best-effort, non-interactive).
install_with_pkgmgr() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkg_mgr)

  if [ -z "$mgr" ]; then
    return 1
  fi

  case "$mgr" in
    apt-get)
      # update first to avoid "no candidate" on some systems
      if [ -n "$SUDO" ]; then
        if ! $SUDO apt-get update -y >/dev/null 2>&1; then return 1; fi
      else
        if ! apt-get update -y >/dev/null 2>&1; then return 1; fi
      fi
      if [ -n "$SUDO" ]; then
        if ! $SUDO apt-get install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      else
        if ! apt-get install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      fi
      ;;
    dnf)
      if [ -n "$SUDO" ]; then
        if ! $SUDO dnf install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      else
        if ! dnf install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      fi
      ;;
    yum)
      if [ -n "$SUDO" ]; then
        if ! $SUDO yum install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      else
        if ! yum install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      fi
      ;;
    pacman)
      if [ -n "$SUDO" ]; then
        if ! $SUDO pacman -Syu --noconfirm "$pkg" >/dev/null 2>&1; then return 1; fi
      else
        if ! pacman -Syu --noconfirm "$pkg" >/dev/null 2>&1; then return 1; fi
      fi
      ;;
    apk)
      if [ -n "$SUDO" ]; then
        if ! $SUDO apk add --no-cache "$pkg" >/dev/null 2>&1; then return 1; fi
      else
        if ! apk add --no-cache "$pkg" >/dev/null 2>&1; then return 1; fi
      fi
      ;;
    brew)
      # Homebrew normally runs as non-root; no sudo.
      if ! brew install "$pkg" >/dev/null 2>&1; then return 1; fi
      ;;
    pkg)
      if [ -n "$SUDO" ]; then
        if ! $SUDO pkg install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      else
        if ! pkg install -y "$pkg" >/dev/null 2>&1; then return 1; fi
      fi
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

# Ensure a command exists, otherwise try to install it automatically (non-interactive).
# For 'curl' we install the package 'curl'. For 'ntfy' we prefer pip (pip3) but fall back
# to a package manager install of 'ntfy' if available.
ensure_command() {
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi

  echo "Command '$cmd' not found. Attempting to install it automatically..."

  # Ensure we have a package manager or pip available; otherwise fail.
  if [ "$cmd" = "curl" ]; then
    # Try package manager install for curl
    if install_with_pkgmgr curl; then
      echo "Installed curl via package manager."
      return 0
    else
      echo "Failed to install curl via package manager. Please install curl manually." >&2
      return 1
    fi
  elif [ "$cmd" = "ntfy" ]; then
    # First try pip3 or pip install --user ntfy
    if command -v pip3 >/dev/null 2>&1; then
      if pip3 install --user ntfy >/dev/null 2>&1; then
        # Ensure local user bin is on PATH
        export PATH="$HOME/.local/bin:$PATH"
        if command -v ntfy >/dev/null 2>&1; then
          echo "Installed ntfy via pip3 (user)."
          return 0
        fi
      fi
    elif command -v pip >/dev/null 2>&1; then
      if pip install --user ntfy >/dev/null 2>&1; then
        export PATH="$HOME/.local/bin:$PATH"
        if command -v ntfy >/dev/null 2>&1; then
          echo "Installed ntfy via pip (user)."
          return 0
        fi
      fi
    else
      # Try to install pip3 via package manager and then use it
      # Common package names: python3-pip or python-pip
      if install_with_pkgmgr python3-pip || install_with_pkgmgr python-pip; then
        # prefer pip3 if available
        if command -v pip3 >/dev/null 2>&1; then
          if pip3 install --user ntfy >/dev/null 2>&1; then
            export PATH="$HOME/.local/bin:$PATH"
            if command -v ntfy >/dev/null 2>&1; then
              echo "Installed ntfy via pip3 (after installing pip)."
              return 0
            fi
          fi
        elif command -v pip >/dev/null 2>&1; then
          if pip install --user ntfy >/dev/null 2>&1; then
            export PATH="$HOME/.local/bin:$PATH"
            if command -v ntfy >/dev/null 2>&1; then
              echo "Installed ntfy via pip (after installing pip)."
              return 0
            fi
          fi
        fi
      fi
    fi

    # If pip-based install didn't work, try package manager for ntfy (best-effort)
    if install_with_pkgmgr ntfy; then
      if command -v ntfy >/dev/null 2>&1; then
        echo "Installed ntfy via package manager."
        return 0
      fi
    fi

    # On some systems ntfy may be available via snap
    if command -v snap >/dev/null 2>&1; then
      if [ -n "$SUDO" ]; then
        if $SUDO snap install ntfy >/dev/null 2>&1; then
          if command -v ntfy >/dev/null 2>&1; then
            echo "Installed ntfy via snap."
            return 0
          fi
        fi
      else
        if snap install ntfy >/dev/null 2>&1; then
          if command -v ntfy >/dev/null 2>&1; then
            echo "Installed ntfy via snap."
            return 0
          fi
        fi
      fi
    fi

    # If the binary exists in typical pip user location, add that to PATH and accept it
    if [ -x "$HOME/.local/bin/ntfy" ]; then
      export PATH="$HOME/.local/bin:$PATH"
      echo "Found ntfy at $HOME/.local/bin/ntfy and added to PATH."
      return 0
    fi

    echo "Failed to install ntfy automatically. Please install ntfy (pip install --user ntfy) or via your package manager." >&2
    return 1
  else
    echo "No automatic install procedure for '$cmd' implemented." >&2
    return 1
  fi
}

# Try to ensure curl and ntfy are present before proceeding.
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

# If pip installed ntfy into ~/.local/bin, ensure PATH includes it for the rest of the script.
export PATH="$HOME/.local/bin:$PATH"

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

# Create timestamp in desired format: 2-digit year, 3-digit Julian day, HHMM
# Example: 25322-1508
ts=$(date +"%y%j-%H%M")

# Log filenames
logfile="mda5ync_${ts}.log"
diff_log="mda5ync-diff_${ts}.log"
copyfail_log="mda5ync-copyfail_${ts}.log"

# Initialize logs with a header line
echo "mda5ync (md5 MediaSync) started at $(date)" > "$logfile"
echo "Diffs for run started at $(date)" > "$diff_log"
echo "Copy failures for run started at $(date)" > "$copyfail_log"

# Helper: send ntfy notification using ntfy client (preferred) or ntfy.sh via curl.
# Topic: tango-tango-8tst
send_ntfy() {
  local message="$1"
  # Prefer ntfy CLI if available
  if command -v ntfy >/dev/null 2>&1; then
    # Use ntfy CLI; best-effort
    if ! ntfy publish -t "mda5ync" -p tango-tango-8tst "$message" >/dev/null 2>&1; then
      # Fall back to curl if ntfy CLI publish fails
      if command -v curl >/dev/null 2>&1; then
        if ! curl -sS -X POST -H "Title: mda5ync" -d "$message" "https://ntfy.sh/tango-tango-8tst" >/dev/null 2>&1; then
          echo "WARNING: ntfy send failed for message: $message" >> "$logfile"
        fi
      else
        echo "WARNING: neither ntfy CLI nor curl available to send ntfy message: $message" >> "$logfile"
      fi
    fi
  else
    # Fallback to curl to post to ntfy.sh
    if command -v curl >/dev/null 2>&1; then
      if ! curl -sS -X POST -H "Title: mda5ync" -d "$message" "https://ntfy.sh/tango-tango-8tst" >/dev/null 2>&1; then
        echo "WARNING: ntfy send failed for message: $message" >> "$logfile"
      fi
    else
      echo "WARNING: curl not found; cannot send ntfy message: $message" >> "$logfile"
    fi
  fi
}

# Replicate the directory tree from SRC into DEST (creates any needed subdirs up-front).
# This avoids repeating mkdir for each file later and is fast for large trees.
# Use -print0 to handle names with special characters.
find "$src" -type d -print0 | while IFS= read -r -d '' d; do
  # Compute relative directory path from SRC (strip SRC prefix and any leading slash)
  rel="${d#$src}"
  rel="${rel#/}"
  mkdir -p "$dst/$rel"
done

# Walk through each directory under SRC (including the root SRC dir itself) and process files
find "$src" -type d -print0 | while IFS= read -r -d '' dir; do
  # Compute relative directory name for display (use '.' for top-level if empty)
  rel_dir="${dir#$src}"
  rel_dir="${rel_dir#/}"
  [ -z "$rel_dir" ] && display_dir="." || display_dir="$rel_dir"

  # Count files directly in this directory (non-recursive)
  file_count=0
  while IFS= read -r -d '' _f; do
    file_count=$((file_count + 1))
  done < <(find "$dir" -maxdepth 1 -type f -print0)

  # Log and notify the start of syncing for this directory
  start_msg="Syncing ${file_count} files in ${display_dir}"
  echo "$start_msg" >> "$logfile"
  send_ntfy "$start_msg"

  # Initialize counters for this directory
  same_count=0
  diff_count=0
  copyfail_count=0

  # Process files in this directory (non-recursive)
  while IFS= read -r -d '' f; do
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
        same_count=$((same_count + 1))
      else
        echo "DIFF: $rel" >> "$logfile"
        echo "DIFF: $rel" >> "$diff_log"
        diff_count=$((diff_count + 1))
      fi
    else
      # File missing in DEST: copy it (preserving directories already created above),
      # then recompare and write ONLY the SAME/DIFF result to the log.
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
        # If copy fails, record the failure so the user can inspect the log.
        echo "COPY FAILED: $rel" >> "$logfile"
        echo "COPY FAILED: $rel" >> "$copyfail_log"
        copyfail_count=$((copyfail_count + 1))
      fi
    fi
  done < <(find "$dir" -maxdepth 1 -type f -print0)

  # Directory summary message
  summary_msg="Finished syncing ${file_count} files in ${display_dir} - ${same_count} files were the same, ${diff_count} files were different, and ${copyfail_count} files failed to copy. See ${logfile}"
  echo "$summary_msg" >> "$logfile"
  send_ntfy "$summary_msg"

done

echo "Sync finished. Results saved to $logfile"

# Open the main log in nano (user requested). This will block until the user exits nano.
if command -v nano >/dev/null 2>&1; then
  nano "$logfile"
else
  echo "Note: nano not found. Main log is at $logfile"
fi
