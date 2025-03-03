#!/bin/bash

update_process_list() {
    # Get the list of current processes and store it in the array
    ps -eo pid,ppid,cmd --sort=start_time | tail | grep -Ev "splunk|\[|watch|tmux|tail|ps" > /var/zds/new_processes
}

# run watch in the background
watch -n 2 update_process_list &
watch_pid=$!

display_proc() {
    trap "exit" SIGINT SIGTERM
    while true; do
        clear

        count=0
        # reads the new process file
        while IFS= read -r line; do
            # skips the first line
            if [ count -eq 0 ]; then
                echo "Line num, PID, PPID, CMD"
            else
                echo "${count}: ${line}"
            fi

            ((count++))
        done < "/tmp/new_processes"
        sleep 2
    done
}

display_proc


