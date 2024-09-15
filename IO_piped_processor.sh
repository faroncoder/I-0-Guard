#!/usr/bin/env bash

# Load utility functions
source "$HOMECORE/utils.sh"

check_and_run() {
    if [[ -z "$1" ]]; then
        echo "No command specified."
        return 1
    else
        # Initialize variables
        local CMD="$1"          # Command to execute
        shift                   # Shift to remove the command from arguments
        local ARGS="$@"         # Remaining arguments for the command
        local script_name=$(basename "${BASH_SOURCE[1]}")
        local function_name="${FUNCNAME[1]}"
        local guard_file="$HOMECORE/.environment_warning"
        local disable_file="$HOMECORE/disable_commands.txt"
        local log_file="$HOMECORE/command_log.txt"
        local pid_file="$HOMECORE/.environment_pids"

        # Set resource limits
        ulimit -t 300            # CPU time limit in seconds (5 minutes)
        ulimit -v 1048576        # Virtual memory limit in KB (1 GB)
        ulimit -u 100            # Max number of processes for the user (100 processes)

        # Check if the command is disabled in disable_commands.txt
        if grep -q "^$script_name:$function_name:$CMD$" "$disable_file"; then
            echo "Command '$CMD' is disabled and cannot be executed. Exiting..."
            handle_return 8
            return 8
        fi

        echo "Command '$CMD' is not running. Executing..."
        
        # Log system status before command execution
        echo "[$(date)] System status before executing '$CMD':" >> "$log_file"
        top -b -n 1 | head -n 10 >> "$log_file"  # Log top output (first 10 lines)

        # Execute the command with arguments in the background
        eval "$CMD $ARGS" &> "$log_file" &   # Redirect output to log and run in the background
        local pid=$!  # Get the PID of the last background command
        local start_time=$(date +%s)

        echo "Command '$CMD' started with PID $pid."

        # Record command details in disable_commands.txt to prevent re-execution
        echo "$script_name:$function_name:$CMD" >> "$disable_file"

        # Write to log file for start of command execution
        echo "[$(date)] Command '$CMD' executed from script '$script_name' function '$function_name' with PID $pid." >> "$log_file"

        # Write the command and its PID to the pid file
        echo "$CMD:$pid" >> "$pid_file"

        # Disown the process to detach it from the terminal
        disown $pid
        echo "Command '$CMD' has been disowned."

        # Continuously check if the process is still running
        while kill -0 $pid 2>/dev/null; do
            echo "Command '$CMD' with PID $pid is still running..."
            sleep 15
        done

        # Report job completion
        echo "Command '$CMD' has finished."
        echo "[$(date)] Command '$CMD' completed for script '$script_name' function '$function_name'." >> "$log_file"

        # Log system status after command execution
        echo "[$(date)] System status after executing '$CMD':" >> "$log_file"
        top -b -n 1 | head -n 10 >> "$log_file"

        # Remove command from the guard file once finished
        clear_recursion_guard "$CMD"

        # Remove the command from the disable file
        grep -v "^$script_name:$function_name:$CMD$" "$disable_file" > "$disable_file.tmp" && mv "$disable_file.tmp" "$disable_file"

        # Remove the PID from the pid file
        grep -v "^$CMD:" "$pid_file" > "$pid_file.tmp" && mv "$pid_file.tmp" "$pid_file"

        # Clean up old log files to prevent log files from growing indefinitely
        log_cleanup "$log_file"

        handle_return $?  # Handle the final return status
    fi
}

# Run the check_and_run function with the provided arguments
check_and_run "$@"

# Exit the script with the return status of the last command
exit $?
