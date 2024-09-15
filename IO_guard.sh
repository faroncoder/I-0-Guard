#!/bin/bash


source "$HOMECORE/utils.sh"

# This script is intended to be sourced by the user's shell configuration file.
guard_loop() {
    local guard_file="$HOMECORE/.environment_warning"
    local disable_file="$HOMECORE/disable_commands.txt"
    local log_file="$HOMECORE/command_log.txt"
    local sleep_interval=15  # Adjustable sleep interval

    while true; do
        while IFS= read -r line; do
            local cmd=$(echo "$line" | cut -d':' -f3)
            local pid=$(grep "^$cmd:" "$HOMECORE/.environment_pids" | cut -d':' -f2)

            if kill -0 "$pid" 2>/dev/null; then
                echo "[$(date)] Command '$cmd' with PID $pid is still running." >> "$log_file"
            else
                echo "[$(date)] Command '$cmd' has finished." >> "$log_file"
                grep -v "^$cmd" "$guard_file" > "$guard_file.tmp" && mv "$guard_file.tmp" "$guard_file"
                grep -v "^$cmd:" "$HOMECORE/.environment_pids" > "$HOMECORE/.environment_pids.tmp" && mv "$HOMECORE/.environment_pids.tmp" "$HOMECORE/.environment_pids"
            fi
        done < "$disable_file"
        sleep "$sleep_interval"
    done
}

guard_loop &