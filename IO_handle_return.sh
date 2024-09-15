#!/usr/bin/env bash

#!/usr/bin/env bash

# Function to handle return codes and log results
handle_return() {
    local ret_code="${1:-$?}"   # Get the return code from the first argument, or use the last command's exit status
    local log_file="$HOMECORE/command_log.txt"
    local severity message

    # Determine the severity level and message based on the return code
    case $ret_code in
        0)
            severity="INFO"
            message="Command executed successfully."
            ;;
        8)
            severity="WARN"
            message="Command execution refused due to an existing entry in disable_commands.txt."
            ;;
        *)
            severity="ERROR"
            message="Command failed with exit code $ret_code."
            ;;
    esac

    # Function to log messages
    log_message() {
        echo "[$(date)] [$severity] $1" >> "$log_file"
    }

    # Log the main message
    log_message "$message"

    # Additional logging based on return code
    if [[ $ret_code -eq 8 ]]; then
        log_message "Warning: Command is currently disabled. Cannot proceed."
    elif [[ $ret_code -ne 0 ]]; then
        log_message "Error occurred. Return code: $ret_code."
    fi

    return $ret_code  # Pass the return code back to the calling function
}
