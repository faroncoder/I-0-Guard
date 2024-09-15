#!/bin/bash



if [[ -z "$HOMECORE" ]]; then
    export HOMECORE="$HOME/.local/faron/lib/core"
fi

TESTHOME="$HOMECORE/.guard_testing/$(mktemp -d)"  # Use a temporary directory for testing




# Set up test environment
echo "Using temporary test environment: $TESTHOME"

# Create dummy scripts and utility functions
echo "Creating utility functions..."
cat << 'EOF' > "$TESTHOME/utils.sh"
#!/bin/bash

clear_recursion_guard() {
    local script_name="\$1"
    local guard_file="\$TESTHOME/.environment_warning"
    if [[ -f "\$guard_file" ]]; then
        grep -v "^\$script_name$" "\$guard_file" > "\$guard_file.tmp" && mv "\$guard_file.tmp" "\$guard_file"
    fi
}

log_cleanup() {
    local log_file="\$1"
    local max_log_size=102400  # Maximum log file size in KB (100 MB)
    if [[ -f "\$log_file" ]] && [[ \$(du -k "\$log_file" | cut -f1) -gt \$max_log_size ]]; then
        mv "\$log_file" "\${log_file}_\$(date +%F_%T).old"
        echo "[\$(date)] Log file rotated due to size limit." >> "\$log_file"
    fi
}
EOF

echo "Creating handle_return script..."
cat << 'EOF' > "$TESTHOME/handle_return.sh"
#!/bin/bash

handle_return() {
    local ret_code="\${1:-\$?}"
    local log_file="\$TESTHOME/command_log.txt"
    case \$ret_code in
        0) severity="INFO"; message="Command executed successfully." ;;
        8) severity="WARN"; message="Command execution refused due to existing entry in disable_commands.txt." ;;
        *) severity="ERROR"; message="Command failed with exit code \$ret_code." ;;
    esac
    echo "[\$(date)] [\$severity] \$message" >> "\$log_file"
    if [[ \$ret_code -eq 8 ]]; then
        echo "[\$(date)] Warning: Command is currently disabled. Cannot proceed." >> "\$log_file"
    elif [[ \$ret_code -ne 0 ]]; then
        echo "[\$(date)] Error occurred. Return code: \$ret_code." >> "\$log_file"
    fi
    return \$ret_code
}
EOF

echo "Creating check_and_run script..."
cat << 'EOF' > "$TESTHOME/check_and_run.sh"
#!/bin/bash

source "\$TESTHOME/utils.sh"
source "\$TESTHOME/handle_return.sh"

check_and_run() {
    if [[ -z "\$1" ]]; then
        echo "No command specified."
        return 1
    else
        local CMD="\$1"
        shift
        local ARGS="\$@"
        local script_name=\$(basename "\${BASH_SOURCE[1]}")
        local function_name="\${FUNCNAME[1]}"
        local guard_file="\$TESTHOME/.environment_warning"
        local disable_file="\$TESTHOME/disable_commands.txt"
        local log_file="\$TESTHOME/command_log.txt"
        local pid_file="\$TESTHOME/.environment_pids"

        ulimit -t 300
        ulimit -v 1048576
        ulimit -u 100

        if grep -q "^\$script_name:\$function_name:\$CMD\$" "\$disable_file"; then
            echo "Command '\$CMD' is disabled and cannot be executed. Exiting..."
            handle_return 8
            return 8
        fi

        echo "Command '\$CMD' is not running. Executing..."
        echo "[\$(date)] System status before executing '\$CMD':" >> "\$log_file"
        top -b -n 1 | head -n 10 >> "\$log_file"

        eval "\$CMD \$ARGS" &
        local pid=\$!
        local start_time=\$(date +%s)

        echo "Command '\$CMD' started with PID \$pid."
        echo "\$script_name:\$function_name:\$CMD" >> "\$disable_file"
        echo "[\$(date)] Command '\$CMD' executed from script '\$script_name' function '\$function_name' with PID \$pid." >> "\$log_file"
        echo "\$CMD:\$pid" >> "\$pid_file"

        disown \$pid
        echo "Command '\$CMD' has been disowned."

        while kill -0 \$pid 2>/dev/null; do
            echo "Command '\$CMD' with PID \$pid is still running..."
            sleep 15
        done

        echo "Command '\$CMD' has finished."
        echo "[\$(date)] Command '\$CMD' completed for script '\$script_name' function '\$function_name'." >> "\$log_file"
        echo "[\$(date)] System status after executing '\$CMD':" >> "\$log_file"
        top -b -n 1 | head -n 10 >> "\$log_file"

        clear_recursion_guard "\$CMD"
        grep -v "^\$script_name:\$function_name:\$CMD\$" "\$disable_file" > "\$disable_file.tmp" && mv "\$disable_file.tmp" "\$disable_file"
        grep -v "^\$CMD:" "\$pid_file" > "\$pid_file.tmp" && mv "\$pid_file.tmp" "\$pid_file"
        log_cleanup "\$log_file"
        handle_return \$?
    fi
}
EOF

echo "Creating guard_loop script..."
cat << 'EOF' > "$TESTHOME/guard_loop.sh"
#!/bin/bash

source "\$TESTHOME/utils.sh"

guard_loop() {
    local guard_file="\$TESTHOME/.environment_warning"
    local disable_file="\$TESTHOME/disable_commands.txt"
    local log_file="\$TESTHOME/command_log.txt"
    local sleep_interval=15

    while true; do
        while IFS= read -r line; do
            local cmd=\$(echo "\$line" | cut -d':' -f3)
            local pid=\$(grep "^\$cmd:" "\$TESTHOME/.environment_pids" | cut -d':' -f2)

            if kill -0 "\$pid" 2>/dev/null; then
                echo "[\$(date)] Command '\$cmd' with PID \$pid is still running." >> "\$log_file"
            else
                echo "[\$(date)] Command '\$cmd' has finished." >> "\$log_file"
                grep -v "^\$cmd" "\$guard_file" > "\$guard_file.tmp" && mv "\$guard_file.tmp" "\$guard_file"
                grep -v "^\$cmd:" "\$TESTHOME/.environment_pids" > "\$TESTHOME/.environment_pids.tmp" && mv "\$TESTHOME/.environment_pids.tmp" "\$TESTHOME/.environment_pids"
            fi
        done < "\$disable_file"
        sleep "\$sleep_interval"
    done
}

guard_loop &
EOF

# Run the test
echo "Starting test..."
bash "$TESTHOME/.guard_testing/check_and_run.sh" "sleep 30"
bash "$TESTHOME/guard_loop.sh" &

# Wait a bit for background jobs
sleep 40

# Check log file for expected output
echo "Checking logs for expected output..."
cat "$TESTHOME/command_log.txt"

echo "Test complete. Cleaning up test environment..."
rm -rf "$TESTHOME"
