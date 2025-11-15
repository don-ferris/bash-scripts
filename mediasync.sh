#!/bin/bash

################################################################################
# MediaSync.sh - Advanced Media Synchronization Script
# Author: MiniMax Agent
# Description: Comprehensive file synchronization with NTFY notifications,
#              multiple verification methods, and progress tracking
################################################################################

set -euo pipefail

################################################################################
# Global Variables
################################################################################

NTFY_TOPIC="mediasync-$(date +%m%d-%H%M)"
NTFY_SERVER="https://ntfy.sh"
GLOBAL_SYNC_ERRORS=0
SYNC_ERRORS=0
PROGRESS_INTERVAL=10
VERIFY_MODE="diff"
LOG_FILE="/tmp/mediasync_$(date +%Y%m%d_%H%M%S).log"
ERR_LOG_FILE="/tmp/mediasync_errors_$(date +%Y%m%d_%H%M%S).log"
SYNC_LIST_FILE="/tmp/mediasync.list"
TOTAL_FILES=0
PROCESSED_FILES=0
LAST_NOTIFICATION=0

################################################################################
# Logging System
################################################################################

initialize_log_files() {
    touch "$LOG_FILE" "$ERR_LOG_FILE"
    log_message "MediaSync started at $(date)" "INFO"
    log_message "Log file: $LOG_FILE" "INFO"
    log_message "Error log file: $ERR_LOG_FILE" "INFO"
}

log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" "$ERR_LOG_FILE"
    ((SYNC_ERRORS++))
    ((GLOBAL_SYNC_ERRORS++))
}

generate_final_reports() {
    log_message "========== SYNC SUMMARY ==========" "INFO"
    log_message "Total files processed: $PROCESSED_FILES" "INFO"
    log_message "Total errors encountered: $GLOBAL_SYNC_ERRORS" "INFO"
    
    if [[ $GLOBAL_SYNC_ERRORS -gt 0 ]]; then
        log_message "Error details available in: $ERR_LOG_FILE" "INFO"
    fi
    
    log_message "Full log available in: $LOG_FILE" "INFO"
    log_message "=================================" "INFO"
}

################################################################################
# Notification System
################################################################################

generate_ntfy_topic() {
    # Topic is already generated globally at script startup
    log_message "Using NTFY topic: $NTFY_TOPIC" "INFO"
}

send_ntfy_notification() {
    local message="$1"
    local priority="${2:-default}"
    local title="${3:-MediaSync}"
    
    if [[ -z "$NTFY_TOPIC" ]]; then
        log_message "NTFY topic not initialized, skipping notification" "WARN"
        return 1
    fi
    
    curl -s --max-time 10 \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -d "$message" \
        "${NTFY_SERVER}/${NTFY_TOPIC}" > /dev/null 2>&1 || {
        log_message "Failed to send notification: $message" "WARN"
        return 1
    }
    
    return 0
}

test_notification_delivery() {
    echo ""
    echo "========================================"
    echo "NTFY Notification System Setup"
    echo "========================================"
    echo ""
    echo "Subscribe to notifications:"
    echo "1. Open https://ntfy.sh/app in your browser OR"
    echo "2. Install ntfy app on your phone and subscribe to topic:"
    echo ""
    echo "   Topic: $NTFY_TOPIC"
    echo ""
    echo "Sending test notification..."
    
    send_ntfy_notification "MediaSync notification system is ready! You will receive progress updates here." "high" "MediaSync Test"
    
    echo ""
    read -p "Did you receive the test notification? (y/N): " response
    
    # Convert to lowercase for comparison
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$response" == "y" || "$response" == "yes" ]]; then
        log_message "Notification system verified successfully" "INFO"
        send_ntfy_notification "Notification system verified. Starting sync operations..." "default" "MediaSync"
        return 0
    else
        log_message "Notification test failed or not confirmed" "WARN"
        read -p "Continue without notifications? (y/N): " continue_response
        
        # Convert to lowercase for comparison
        continue_response=$(echo "$continue_response" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$continue_response" == "y" || "$continue_response" == "yes" ]]; then
            return 0
        else
            log_message "User chose to exit due to notification issues" "INFO"
            exit 1
        fi
    fi
}

setup_notification_system() {
    generate_ntfy_topic
    test_notification_delivery
}

################################################################################
# Dependency Management
################################################################################

check_and_install_dependencies() {
    log_message "Checking required dependencies..." "INFO"
    
    local dependencies=("curl" "diff" "find")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    # Check for hashdeep separately as it's optional but recommended
    if ! command -v hashdeep &> /dev/null; then
        missing_deps+=("hashdeep")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "Missing dependencies: ${missing_deps[*]}" "WARN"
        log_message "Installing missing dependencies..." "INFO"
        
        if command -v apt-get &> /dev/null; then
            yes | apt-get update -qq
            yes | apt-get install -y -qq "${missing_deps[@]}" 2>&1 | tee -a "$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yes | yum install -y "${missing_deps[@]}" 2>&1 | tee -a "$LOG_FILE"
        else
            log_error "Package manager not found. Please install manually: ${missing_deps[*]}"
            exit 1
        fi
        
        log_message "Dependencies installed successfully" "INFO"
    else
        log_message "All dependencies satisfied" "INFO"
    fi
}

################################################################################
# Directory Validation
################################################################################

validate_source_directory() {
    local source_dir="$1"
    
    if [[ ! -d "$source_dir" ]]; then
        echo "Error: Source directory does not exist: $source_dir"
        return 1
    fi
    
    if [[ ! -r "$source_dir" ]]; then
        echo "Error: Source directory is not readable: $source_dir"
        return 1
    fi
    
    local file_count=$(find "$source_dir" -type f 2>/dev/null | wc -l)
    if [[ $file_count -eq 0 ]]; then
        echo "Warning: Source directory contains no files: $source_dir"
        read -p "Continue anyway? (yes/no): " response
        [[ "$response" =~ ^[Yy] ]] || return 1
    fi
    
    return 0
}

validate_destination_directory() {
    local dest_dir="$1"
    
    if [[ ! -d "$dest_dir" ]]; then
        echo "Destination directory does not exist: $dest_dir"
        read -p "Create it? (yes/no): " response
        if [[ "$response" =~ ^[Yy] ]]; then
            mkdir -p "$dest_dir" 2>/dev/null || {
                echo "Error: Failed to create destination directory"
                return 1
            }
            echo "Created destination directory: $dest_dir"
        else
            return 1
        fi
    fi
    
    if [[ ! -w "$dest_dir" ]]; then
        echo "Error: Destination directory is not writable: $dest_dir"
        return 1
    fi
    
    return 0
}

write_to_sync_list() {
    local source="$1"
    local dest="$2"
    echo "$source|$dest" >> "$SYNC_LIST_FILE"
    log_message "Added to sync list: $source -> $dest" "INFO"
}

################################################################################
# Source/Destination Collection
################################################################################

collect_source_dest_pairs() {
    echo ""
    echo "========================================"
    echo "Directory Pair Collection"
    echo "========================================"
    echo ""
    
    > "$SYNC_LIST_FILE"  # Clear the sync list file
    
    while true; do
        echo ""
        read -p "Enter source directory (or 'done' to finish): " source_dir
        
        if [[ "$source_dir" == "done" ]]; then
            break
        fi
        
        # Expand tilde to home directory
        source_dir="${source_dir/#\~/$HOME}"
        
        if ! validate_source_directory "$source_dir"; then
            continue
        fi
        
        read -p "Enter destination directory: " dest_dir
        dest_dir="${dest_dir/#\~/$HOME}"
        
        if ! validate_destination_directory "$dest_dir"; then
            continue
        fi
        
        write_to_sync_list "$source_dir" "$dest_dir"
        echo "✓ Pair added successfully"
    done
    
    local pair_count=$(wc -l < "$SYNC_LIST_FILE")
    if [[ $pair_count -eq 0 ]]; then
        log_message "No directory pairs collected. Exiting." "INFO"
        exit 0
    fi
    
    log_message "Collected $pair_count directory pair(s)" "INFO"
}

################################################################################
# Sync Parameters Setup
################################################################################

calculate_total_files() {
    local source_dir="$1"
    log_message "Calculating total files in: $source_dir" "INFO"
    TOTAL_FILES=$(find "$source_dir" -type f 2>/dev/null | wc -l)
    log_message "Total files to process: $TOTAL_FILES" "INFO"
}

get_progress_interval() {
    echo ""
    echo "Progress Notification Settings"
    echo "-------------------------------"
    read -p "Send progress notification every N files (default: 10): " interval
    
    if [[ -n "$interval" && "$interval" =~ ^[0-9]+$ ]]; then
        PROGRESS_INTERVAL=$interval
    else
        PROGRESS_INTERVAL=10
    fi
    
    log_message "Progress notification interval set to: $PROGRESS_INTERVAL files" "INFO"
}

get_verify_mode() {
    echo ""
    echo "Verification Method Selection"
    echo "-----------------------------"
    echo "1. Quick (size comparison)"
    echo "2. Diff (directory tree comparison) [DEFAULT]"
    echo "3. Hashdeep (hash-based verification)"
    echo "4. Checksum (full SHA256 comparison)"
    echo ""
    read -p "Select verification method (1-4, default: 2): " verify_choice
    
    case "$verify_choice" in
        1) VERIFY_MODE="size" ;;
        3) VERIFY_MODE="hashdeep" ;;
        4) VERIFY_MODE="checksum" ;;
        *) VERIFY_MODE="diff" ;;
    esac
    
    log_message "Verification method set to: $VERIFY_MODE" "INFO"
}

setup_sync_parameters() {
    local source_dir="$1"
    calculate_total_files "$source_dir"
    get_progress_interval
    get_verify_mode
}

################################################################################
# Progress Tracking System
################################################################################

initialize_progress_tracker() {
    PROCESSED_FILES=0
    LAST_NOTIFICATION=0
    log_message "Progress tracker initialized" "INFO"
}

update_progress_count() {
    ((PROCESSED_FILES++))
}

check_progress_milestone() {
    if [[ $TOTAL_FILES -eq 0 ]]; then
        return 1
    fi
    
    local files_since_last=$((PROCESSED_FILES - LAST_NOTIFICATION))
    
    if [[ $files_since_last -ge $PROGRESS_INTERVAL ]]; then
        return 0
    fi
    
    return 1
}

send_progress_notification() {
    if [[ $TOTAL_FILES -eq 0 ]]; then
        return
    fi
    
    local percentage=$((PROCESSED_FILES * 100 / TOTAL_FILES))
    local message="Progress: $PROCESSED_FILES/$TOTAL_FILES files ($percentage%) | Errors: $SYNC_ERRORS"
    
    send_ntfy_notification "$message" "default" "MediaSync Progress"
    LAST_NOTIFICATION=$PROCESSED_FILES
    log_message "$message" "INFO"
}

################################################################################
# File Verification System
################################################################################

verify_by_size() {
    local source_file="$1"
    local dest_file="$2"
    
    if [[ ! -f "$dest_file" ]]; then
        return 1
    fi
    
    local source_size=$(stat -c%s "$source_file" 2>/dev/null || stat -f%z "$source_file" 2>/dev/null)
    local dest_size=$(stat -c%s "$dest_file" 2>/dev/null || stat -f%z "$dest_file" 2>/dev/null)
    
    [[ "$source_size" == "$dest_size" ]]
}

verify_by_diff() {
    local source_dir="$1"
    local dest_dir="$2"
    
    log_message "Running diff verification between $source_dir and $dest_dir" "INFO"
    
    local diff_output=$(diff -r "$source_dir" "$dest_dir" 2>&1)
    
    if [[ -z "$diff_output" ]]; then
        log_message "Diff verification: PASSED" "INFO"
        return 0
    else
        log_message "Diff verification: FAILED" "WARN"
        echo "$diff_output" >> "$ERR_LOG_FILE"
        return 1
    fi
}

verify_by_hashdeep() {
    local source_dir="$1"
    local dest_dir="$2"
    
    if ! command -v hashdeep &> /dev/null; then
        log_error "hashdeep not available, falling back to size verification"
        return 1
    fi
    
    log_message "Running hashdeep verification..." "INFO"
    
    local source_hash_file="/tmp/mediasync_source_hashes_$$.txt"
    local dest_hash_file="/tmp/mediasync_dest_hashes_$$.txt"
    
    hashdeep -r "$source_dir" > "$source_hash_file" 2>&1
    hashdeep -r "$dest_dir" > "$dest_hash_file" 2>&1
    
    if diff "$source_hash_file" "$dest_hash_file" > /dev/null 2>&1; then
        log_message "Hashdeep verification: PASSED" "INFO"
        rm -f "$source_hash_file" "$dest_hash_file"
        return 0
    else
        log_message "Hashdeep verification: FAILED" "WARN"
        rm -f "$source_hash_file" "$dest_hash_file"
        return 1
    fi
}

verify_by_checksum() {
    local source_file="$1"
    local dest_file="$2"
    
    if [[ ! -f "$dest_file" ]]; then
        return 1
    fi
    
    local source_checksum=$(sha256sum "$source_file" 2>/dev/null | awk '{print $1}')
    local dest_checksum=$(sha256sum "$dest_file" 2>/dev/null | awk '{print $1}')
    
    if [[ "$source_checksum" == "$dest_checksum" ]]; then
        return 0
    else
        log_error "Checksum mismatch: $source_file"
        return 1
    fi
}

file_verification_system() {
    local source="$1"
    local dest="$2"
    local mode="${3:-$VERIFY_MODE}"
    
    case "$mode" in
        size)
            verify_by_size "$source" "$dest"
            ;;
        diff)
            verify_by_diff "$source" "$dest"
            ;;
        hashdeep)
            verify_by_hashdeep "$source" "$dest"
            ;;
        checksum)
            verify_by_checksum "$source" "$dest"
            ;;
        *)
            log_error "Unknown verification mode: $mode"
            return 1
            ;;
    esac
}

################################################################################
# File Synchronization Engine
################################################################################

check_dest_file_exists() {
    local source_file="$1"
    local dest_dir="$2"
    local source_dir="$3"
    
    # Calculate relative path
    local relative_path="${source_file#$source_dir/}"
    local dest_file="$dest_dir/$relative_path"
    
    if [[ -f "$dest_file" ]]; then
        # File exists, verify it
        if [[ "$VERIFY_MODE" == "size" ]]; then
            verify_by_size "$source_file" "$dest_file"
            return $?
        elif [[ "$VERIFY_MODE" == "checksum" ]]; then
            verify_by_checksum "$source_file" "$dest_file"
            return $?
        fi
    fi
    
    return 1
}

copy_file_with_verification() {
    local source_file="$1"
    local dest_file="$2"
    
    # Create destination directory if needed
    local dest_dir=$(dirname "$dest_file")
    mkdir -p "$dest_dir" 2>/dev/null || {
        log_error "Failed to create directory: $dest_dir"
        return 1
    }
    
    # Copy the file
    if cp -p "$source_file" "$dest_file" 2>/dev/null; then
        # Verify copy based on mode
        if [[ "$VERIFY_MODE" == "checksum" ]]; then
            if verify_by_checksum "$source_file" "$dest_file"; then
                return 0
            else
                log_error "Copy verification failed: $source_file"
                return 1
            fi
        elif [[ "$VERIFY_MODE" == "size" ]]; then
            if verify_by_size "$source_file" "$dest_file"; then
                return 0
            else
                log_error "Size verification failed: $source_file"
                return 1
            fi
        else
            # For diff and hashdeep, we verify at the end
            return 0
        fi
    else
        log_error "Failed to copy: $source_file"
        return 1
    fi
}

process_single_file() {
    local source_file="$1"
    local source_dir="$2"
    local dest_dir="$3"
    
    # Calculate relative path and destination file
    local relative_path="${source_file#$source_dir/}"
    local dest_file="$dest_dir/$relative_path"
    
    # Check if file already exists and is valid
    if check_dest_file_exists "$source_file" "$dest_dir" "$source_dir"; then
        # File exists and is valid, skip
        update_progress_count
        return 0
    fi
    
    # Copy the file
    if copy_file_with_verification "$source_file" "$dest_file"; then
        update_progress_count
        
        # Check if we should send progress notification
        if check_progress_milestone; then
            send_progress_notification
        fi
        return 0
    else
        update_progress_count
        return 1
    fi
}

find_all_source_files() {
    local source_dir="$1"
    find "$source_dir" -type f 2>/dev/null
}

execute_file_sync() {
    local source_dir="$1"
    local dest_dir="$2"
    
    log_message "Starting file sync: $source_dir -> $dest_dir" "INFO"
    send_ntfy_notification "Starting sync: $source_dir -> $dest_dir" "default" "MediaSync"
    
    initialize_progress_tracker
    SYNC_ERRORS=0
    
    # Process all files
    while IFS= read -r source_file; do
        process_single_file "$source_file" "$source_dir" "$dest_dir"
    done < <(find_all_source_files "$source_dir")
    
    # Final progress notification
    send_progress_notification
    
    # Run final verification if using diff or hashdeep
    if [[ "$VERIFY_MODE" == "diff" ]]; then
        file_verification_system "$source_dir" "$dest_dir" "diff"
    elif [[ "$VERIFY_MODE" == "hashdeep" ]]; then
        file_verification_system "$source_dir" "$dest_dir" "hashdeep"
    fi
    
    log_message "Completed sync: $source_dir -> $dest_dir" "INFO"
    log_message "Files processed: $PROCESSED_FILES, Errors: $SYNC_ERRORS" "INFO"
    
    send_ntfy_notification "Sync completed: $PROCESSED_FILES files, $SYNC_ERRORS errors" "high" "MediaSync"
}

################################################################################
# Sync Processing
################################################################################

parse_sync_list() {
    if [[ ! -f "$SYNC_LIST_FILE" ]]; then
        log_error "Sync list file not found: $SYNC_LIST_FILE"
        return 1
    fi
    
    cat "$SYNC_LIST_FILE"
}

process_directory_pair() {
    local source_dir="$1"
    local dest_dir="$2"
    
    log_message "======================================" "INFO"
    log_message "Processing pair: $source_dir -> $dest_dir" "INFO"
    log_message "======================================" "INFO"
    
    setup_sync_parameters "$source_dir"
    execute_file_sync "$source_dir" "$dest_dir"
}

process_sync_operations() {
    local pair_num=1
    
    while IFS='|' read -r source_dir dest_dir; do
        echo ""
        echo "========================================"
        echo "Processing Pair $pair_num"
        echo "========================================"
        process_directory_pair "$source_dir" "$dest_dir"
        ((pair_num++))
    done < <(parse_sync_list)
}

################################################################################
# Cleanup and Reporting
################################################################################

aggregate_global_errors() {
    log_message "Total global errors: $GLOBAL_SYNC_ERRORS" "INFO"
}

send_final_notification() {
    local status="SUCCESS"
    local priority="high"
    
    if [[ $GLOBAL_SYNC_ERRORS -gt 0 ]]; then
        status="COMPLETED WITH ERRORS"
        priority="urgent"
    fi
    
    local message="MediaSync $status
Total errors: $GLOBAL_SYNC_ERRORS
Log file: $LOG_FILE"
    
    send_ntfy_notification "$message" "$priority" "MediaSync Complete"
}

cleanup_temporary_files() {
    log_message "Cleaning up temporary files..." "INFO"
    
    if [[ -f "$SYNC_LIST_FILE" ]]; then
        rm -f "$SYNC_LIST_FILE"
    fi
    
    # Clean up any hash files that might be left over
    rm -f /tmp/mediasync_source_hashes_$$.txt
    rm -f /tmp/mediasync_dest_hashes_$$.txt
    
    log_message "Cleanup completed" "INFO"
}

cleanup_and_report() {
    aggregate_global_errors
    generate_final_reports
    send_final_notification
    cleanup_temporary_files
    
    echo ""
    echo "========================================"
    echo "MediaSync Completed"
    echo "========================================"
    echo "Log file: $LOG_FILE"
    
    if [[ $GLOBAL_SYNC_ERRORS -gt 0 ]]; then
        echo "Error log: $ERR_LOG_FILE"
        echo "Status: COMPLETED WITH $GLOBAL_SYNC_ERRORS ERRORS"
    else
        echo "Status: SUCCESS"
    fi
    echo "========================================"
}

################################################################################
# Root Check
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root"
        echo "Please run with: sudo $0"
        exit 1
    fi
}

################################################################################
# Main Function
################################################################################

main() {
    # Check if running as root
    check_root
    
    echo "========================================"
    echo "MediaSync - Media Synchronization Tool"
    echo "========================================"
    echo ""
    
    # Initialize logging
    initialize_log_files
    
    # Check and install dependencies
    check_and_install_dependencies
    
    # Setup notification system
    setup_notification_system
    
    # Collect source/destination pairs
    collect_source_dest_pairs
    
    # Process all sync operations
    process_sync_operations
    
    # Cleanup and final reporting
    cleanup_and_report
}

################################################################################
# Script Entry Point
################################################################################

# Trap errors and cleanup
trap cleanup_temporary_files EXIT

# Run main function
main "$@"
