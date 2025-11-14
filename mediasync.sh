#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MediaSync"
LIST_FILE="/tmp/mediasync.list"
COUNT_FILE="/tmp/mediasync_counts.list"
INIT_MARKER="/tmp/mediasync.init"
LOG_DIR="/tmp"
SUMMARY_LOG="$LOG_DIR/mediasync_summary.log"
PROGRESS_INTERVAL=10

# VERIFY_MODE options:
#   file_size  - Fastest. Compares file sizes only. May miss subtle corruption.
#   diff       - Medium. Uses 'diff -qr' to compare directory trees. Faster than checksums, more thorough than size.
#   hashdeep   - Medium-slow. Computes hashes across directories. Stronger than diff, faster than full checksum.
#   checksum   - Slowest. Per-file SHA256 comparison. Reads every byte. Most thorough.
VERIFY_MODE="file_size"

NTFY_TOPIC="${NTFY_TOPIC:-mediasync}"  # set your ntfy topic here

log() { printf "[%s] %s\n" "$APP_NAME" "$*"; }

require_cmd() {
  local cmd="$1" pkg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "Missing required tool: $cmd. Attempting to install $pkg..."
    if command -v apt >/dev/null 2>&1; then
      sudo apt update && sudo apt install -y "$pkg" || {
        log "ERROR: Could not install $pkg. Please install manually: sudo apt install $pkg"
        exit 1
      }
    else
      log "ERROR: No package manager found. Please install $pkg manually."
      exit 1
    fi
  fi
}

notify() {
  local message="$1"
  require_cmd ntfy ntfy
  ntfy publish "$NTFY_TOPIC" "$message"
}

init_routine() {
  log "Init routine starting..."
  require_cmd rsync rsync
  require_cmd ntfy ntfy

  read -rp "Init: Enter a small source directory for dry-run: " test_src
  read -rp "Init: Enter a destination directory for dry-run: " test_dst
  [[ -z "$test_src" || -z "$test_dst" ]] && { log "Init aborted."; exit 1; }
  [[ -d "$test_src" ]] || { log "Source does not exist."; exit 1; }
  mkdir -p "$test_dst"

  local log_file="$LOG_DIR/mediasync_init.log"
  rsync -aP --dry-run --max-size=50M "$test_src"/ "$test_dst"/ | tee "$log_file" >/dev/null

  read -rp "Press any key to display the log file..." -n1 -s
  less "$log_file"
  read -rp "Did the log look good? (y/n): " ok_log
  [[ "${ok_log,,}" != "y" ]] && { log "Init aborted."; exit 1; }

  notify "MediaSync test notification: init routine"
  read -rp "Did you receive the notification? (y/n): " ok_notif
  [[ "${ok_notif,,}" != "y" ]] && { log "Init aborted."; exit 1; }

  : > "$INIT_MARKER"
  log "Init complete."
}

build_list() {
  : > "$LIST_FILE"
  log "Enter source/destination pairs. Press Enter on empty source to finish."
  while true; do
    read -rp "Source directory: " src
    [[ -z "$src" ]] && break
    [[ -d "$src" ]] || { log "Source does not exist."; continue; }
    read -rp "Destination directory: " dst
    [[ -z "$dst" ]] && { log "Destination cannot be empty."; continue; }
    mkdir -p "$dst"
    printf "%s\t%s\n" "$src" "$dst" >> "$LIST_FILE"
    log "Added pair: $src -> $dst"
  done
}

prepare_counts() {
  local total=0
  : > "$COUNT_FILE"
  while IFS=$'\t' read -r src dst; do
    local c
    c=$(find "$src" -type f | wc -l)
    printf "%s\t%s\t%s\n" "$c" "$src" "$dst" >> "$COUNT_FILE"
    total=$((total + c))
  done < "$LIST_FILE"
  echo "$total"
}

copy_pair() {
  local src="$1" dst="$2"
  if ! rsync -aP "$src"/ "$dst"/; then
    log "ERROR: rsync failed for $src -> $dst"
    return 1
  fi
}

verify_pair_size() {
  local src="$1" dst="$2" log_file="$3"
  find "$src" -type f -print0 | while IFS= read -r -d '' sfile; do
    local rel="${sfile#$src/}" dfile="$dst/$rel"
    if [[ -f "$dfile" ]]; then
      local ssize dsize
      ssize=$(stat -c %s "$sfile")
      dsize=$(stat -c %s "$dfile")
      if [[ "$ssize" -eq "$dsize" ]]; then
        echo "OK size=$ssize $sfile -> $dfile" >> "$log_file"
      else
        echo "MISMATCH src_size=$ssize dst_size=$dsize $sfile -> $dfile" >> "$log_file"
      fi
    else
      echo "MISSING $sfile (no dest file at $dfile)" >> "$log_file"
    fi
  done
}

verify_pair_diff() {
  local src="$1" dst="$2" log_file="$3"
  require_cmd diff diffutils
  diff -qr "$src" "$dst" > "$log_file" || true
}

verify_pair_hashdeep() {
  local src="$1" dst="$2" log_file="$3"
  require_cmd hashdeep hashdeep
  local src_hash="/tmp/mediasync_src_${RANDOM}.hash"
  hashdeep -r "$src" > "$src_hash"
  hashdeep -r -a -k "$src_hash" "$dst" > "$log_file"
  rm -f "$src_hash"
}

verify_pair_checksum() {
  local src="$1" dst="$2" log_file="$3"
  require_cmd sha256sum coreutils
  find "$src" -type f -print0 | while IFS= read -r -d '' sfile; do
    local rel="${sfile#$src/}" dfile="$dst/$rel"
    if [[ -f "$dfile" ]]; then
      local sh_src sh_dst
      sh_src=$(sha256sum "$sfile" | awk '{print $1}')
      sh_dst=$(sha256sum "$dfile" | awk '{print $1}')
      if [[ "$sh_src" == "$sh_dst" ]]; then
        echo "OK sha256=$sh_src $sfile -> $dfile" >> "$log_file"
      else
        echo "MISMATCH src_sha256=$sh_src dst_sha256=$sh_dst $sfile -> $dfile" >> "$log_file"
      fi
    else
      echo "MISSING $sfile (no dest file at $dfile)" >> "$log_file"
    fi
  done
}

verify_pair() {
  local src="$1" dst="$2" log_file="$3"
  case "$VERIFY_MODE" in
    file_size) verify_pair_size "$src" "$dst" "$log_file" ;;
    diff)      verify_pair_diff "$src" "$dst" "$log_file" ;;
    hashdeep)  verify_pair_hashdeep "$src" "$dst" "$log_file" ;;
    checksum)  verify_pair_checksum "$src" "$dst" "$log_file" ;;
    *) log "Unknown VERIFY_MODE: $VERIFY_MODE"; exit 1 ;;
  esac
}

main() {
  [[ -f "$INIT_MARKER" ]] || init_routine
  require_cmd rsync rsync
  require_cmd ntfy ntfy

  build_list
  [[ -s "$LIST_FILE" ]] || { log "No pairs provided."; exit 0; }

  local total files_done next_threshold
  total=$(prepare_counts)
  files_done=0
  next_threshold=$PROGRESS_INTERVAL

  : > "$SUMMARY_LOG"
  notify "$APP_NAME started: total files $total"

  local pair_index=0
  while IFS=$'\t' read -r pair_files src dst; do
    pair_index=$((pair_index + 1))

    # Copy with error handling
    if ! copy_pair "$src" "$dst"; then
      notify "$APP_NAME: ERROR during copy for pair $pair_index ($src -> $dst). Skipping verification for this pair."
      {
        echo "Pair $pair_index: $src -> $dst"
        echo "COPY ERROR: rsync failed; verification skipped for this pair."
        echo "----"
      } >> "$SUMMARY_LOG"
      # Continue to next pair (to abort instead, replace 'continue' with 'exit 1')
      continue
    fi

    # Verification per pair
    local log_file="$LOG_DIR/mediasync_pair${pair_index}.log"
    : > "$log_file"
    verify_pair "$src" "$dst" "$log_file"
    notify "$APP_NAME: verification for pair $pair_index written to $log_file"

    # Append to summary
    {
      echo "Pair $pair_index: $src -> $dst"
      cat "$log_file"
      echo "----"
    } >> "$SUMMARY_LOG"

    # Progress accounting
    files_done=$((files_done + pair_files))
    if [[ "$total" -gt 0 ]]; then
      local percent=$(( (files_done * 100) / total ))
      if [[ "$percent" -ge "$next_threshold" ]]; then
        notify "$APP_NAME is ${percent}% complete — ${files_done} of ${total} files copied and verified."
        next_threshold=$((next_threshold + PROGRESS_INTERVAL))
      fi
    fi
  done < "$COUNT_FILE"

  notify "$APP_NAME: All copies and verifications completed. Summary log at $SUMMARY_LOG"
  log "Done."
}

main "$@"
