#!/bin/bash




# Function: clear_recursion_guard
clear_recursion_guard() {
    local script_name="$1"
    local guard_file="$HOMECORE/.environment_warning"
    
    # Ensure the file exists before trying to modify it
    if [[ -f "$guard_file" ]]; then
        grep -v "^$script_name$" "$guard_file" > "$guard_file.tmp"
        if mv "$guard_file.tmp" "$guard_file"; then
            echo "[$(date)] Successfully removed entry '$script_name' from guard file." >> "$HOMECORE/command_log.txt"
        else
            echo "[$(date)] Error: Failed to update guard file after removing entry '$script_name'." >> "$HOMECORE/command_log.txt"
        fi
    fi
}

# Function: log_cleanup
log_cleanup() {
    local log_file="$1"
    local max_log_size=102400  # Maximum log file size in KB (100 MB)

    # Check if the log file exists and its size exceeds the limit
    if [[ -f "$log_file" ]] && [[ $(du -k "$log_file" | cut -f1) -gt $max_log_size ]]; then
        mv "$log_file" "${log_file}_$(date +%F_%T).old"  # Rename the old log file
        echo "[$(date)] Log file rotated due to size limit." >> "$log_file"
        echo "[$(date)] Notification: Log file '$log_file' was rotated." >> "$HOMECORE/command_log.txt"
    fi
}
