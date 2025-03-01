#!/bin/bash

RED=`tput setaf 1`                          # code for red console text
GREEN=`tput setaf 2`                        # code for green text
YELLOW=`tput setaf 3`                       # code for yellow text
NC=`tput sgr0`                              # Reset the text color

if [ ! -e /usr/bin/tmux ]; then
    apt install tmux
fi

update_process_list() {
    # Get the list of current processes and store it in the array
    ps -eo pid,ppid,cmd --sort=start_time | tail | grep -Ev "splunk|\[|watch|tmux|tail|ps" > /tmp/new_processes
}

# run watch in the background
watch -n 2 update_process_list &
watch_pid=$!


# Start a new tmux session
tmux new-session -d -s my_session

# Split the tmux window into two panes
tmux split-window -v

# Run the echo script in the top pane
tmux send-keys -t my_session.0 "
    display_proc() {
        while true; do
            clear
            count=0
            # reads the new process file
            while IFS= read -r line; do
                # skips the first line
                if [ \$count -eq 0 ]; then
                    echo \"Line num, PID, PPID, CMD\"
                else
                    echo \"\${count}: \${line}\"
                fi
                ((count++))
            done < \"/tmp/new_processes\"
            sleep 2
        done
    }
" C-m
tmux send-keys -t my_session.0 'display_proc' C-m

# Allow user input in the bottom pane
tmux send-keys -t my_session.1 "
while_loop=true
while \$while_loop; do

    echo '################################'
    echo '# \033[32m1 Investigate\033[0m                #'
    echo '# \033[32m2 Eradicate\033[0m                  #'
    echo '# \033[32m3 Investigate and Eradicate\033[0m  #'
    echo '################################'
    echo ''
    read -p '\033[32mEnter choose an option (type '\''\033[31mexit\033[32m'\'' to quit): \033[0m' user_input

    case \$user_input in
        '1')
            clear
            read -p '\033[32mEnter the PID to investigate: \033[0m' pid_input

            ps -co pid,cmd,user,lstart > /tmp/t.txt

            process=()
            while IFS= read -r line; do
                IFS=' ' read -r -a line_array <<< \"\$line\"
                if [[ \${line_array[0]} -eq \$pid_input ]]; then

                    cmd=\"\${line_array[1]}\"
                    ps_user=\"\${line_array[2]}\"
                    location=\$(find / -name \$cmd)
                    time_start=\"\${line_array[3]}\"
                    cmd_line=\$(ps -o cmd,pid | grep \$pid_input | awk '{print \$1}')

                    netstat_line=\$(netstat -peanut | grep \$pid_input)
                    if [[ \$netstat_line -eq \"\" ]]; then
                        listen_state=\"This process is not using network connections\"
                        dip=\"This process is not using network connections\"
                    else
                        listen_state=\$(echo \"\$netstat_line\" | awk '{print \$6}')
                        dip=\$(echo \"\$netstat_line\" | awk '{print \$5}')
                    fi

                    if [[ \$listen_state -eq \"LISTEN\" ]]; then

                        clear
                        echo '\033[32mCommand used: \033[33m\${cmd_line}\033[0m'
                        echo '\033[32mWhere app is located: \033[33m\${location}\033[0m'
                        echo '\033[32mWho ran it: \033[33m\${ps_user}\033[0m'
                        echo '\033[32mStart time: \033[33m\${time_start}\033[0m'
                        if [[ \$listen_state -eq \"ESTABLISHED\" ]]; then
                            echo '\033[32mProcess network status: \033[31m\${listen_state}\033[0m'
                            echo '\033[32mDestination address: \033[31m\${dip}\033[0m'
                            echo ''
                            echo '\033[31mCONNECTION ESTABLISHED\033[32m - Check logs for malicous activity from \033[31m\${dip}\033[0m'
                            echo '\033[32mPlease use the '\''Eradicate'\'' option [enter '\''2'\''] if this is confirmed malicous\033[0m'
                            echo ''
                            echo ''
                        else
                            echo '\033[32mProcess network status: \033[33m\${listen_state}\033[0m'
                            echo '\033[32mDestination address: \033[33m\${dip}\033[0m'
                            echo ''
                            echo '\033[32mPlease use the '\''Eradicate'\'' option [enter '\''2'\''] if this is confirmed malicous\033[0m'
                            echo ''
                            echo ''
                        fi
                fi
            done < \"/tmp/t.txt\"

            rm /tmp/t.txt
            ;;
        '2')
            clear
            read -p '\033[32mEnter the PID to eradicate: \033[0m' pid_input
            clear

            ps_output=\$(ps -co pid,cmd,user,lstart | grep \$pid_input)
            cmd=\$(echo \"\$ps_output\" | awk '{print \$2}')
            location=\$(find / -name \$cmd)

            IFS=' ' read -r -a locations <<< \"\$location\"
            for index in \"\${!locations[@]}\"; do
                echo '\033[32mAll locations of PUP:\033[0m'
                echo \"\$index: \033[33m\${locations[\$index]}\033[0m\"
            done 

            echo ''
            bool=true
            while \$bool; do
                read -p '\033[32mEnter the number of the location to move, enter '\''none'\'', or enter '\''all'\'': \033[0m' location_input
                case \$location_input in
                    'none')
                        echo 'No file locations moved...'
                        \$bool=false
                        ;;
                    'all')
                        for index in \"\${!locations[@]}\"; do
                            echo 'Moving all files to /var/zds/ ...'
                            mv \"\${locations[\$index]}\" \"/var/zds/\${cmd}_\${index}\"
                        done 
                        \$bool=false
                        ;;
                    *)
                        IFS=' ' read -r -a indexes <<< \"\${!locations[@]}\"
                        for element in \"\${indexes[@]}\"; do
                            if [ \"\$element\" == \"\$location_input\" ]; then
                                echo \"Moving \${locations[\$location_input]} to /var/zds ...\"
                                mv \"\${locations[\$index]}\" \"/var/zds/\${cmd}_\${location_input}\"
                                \$bool=false
                            else    
                                echo 'Invalid response...'
                                clear
                            fi
                        done
                        ;;
                esac
            done

            echo '\033[31mKilling PID=\033[33m\${pid_input}\033[31m...\033[0m'
            kill -9 \$pid_input

            ;;
        '3')
            clear
            read -p '\033[32mEnter the PID to investigate: \033[0m' pid_input

            ps -co pid,cmd,user,lstart > /tmp/t.txt

            process=()
            while IFS= read -r line; do
                IFS=' ' read -r -a line_array <<< \"\$line\"
                if [[ \${line_array[0]} -eq \$pid_input ]]; then

                    cmd=\"\${line_array[1]}\"
                    ps_user=\"\${line_array[2]}\"
                    location=\$(find / -name \$cmd)
                    time_start=\"\${line_array[3]}\"
                    cmd_line=\$(ps -o cmd,pid | grep \$pid_input | awk '{print \$1}')

                    netstat_line=\$(netstat -peanut | grep \$pid_input)
                    if [[ \$netstat_line -eq \"\" ]]; then
                        listen_state=\"This process is not using network connections\"
                        dip=\"This process is not using network connections\"
                    else
                        listen_state=\$(echo \"\$netstat_line\" | awk '{print \$6}')
                        dip=\$(echo \"\$netstat_line\" | awk '{print \$5}')
                    fi

                    if [[ \$listen_state -eq \"LISTEN\" ]]; then

                        clear
                        echo '\033[32mCommand used: \033[33m\${cmd_line}\033[0m'
                        echo '\033[32mWhere app is located: \033[33m\${location}\033[0m'
                        echo '\033[32mWho ran it: \033[33m\${ps_user}\033[0m'
                        echo '\033[32mStart time: \033[33m\${time_start}\033[0m'
                        if [[ \$listen_state -eq \"ESTABLISHED\" ]]; then
                            echo '\033[32mProcess network status: \033[31m\${listen_state}\033[0m'
                            echo '\033[32mDestination address: \033[31m\${dip}\033[0m'
                            echo ''
                            echo '\033[31mCONNECTION ESTABLISHED\033[32m - Check logs for malicous activity from \033[31m\${dip}\033[0m'
                            echo ''
                            echo ''
                        else
                            echo '\033[32mProcess network status: \033[33m\${listen_state}\033[0m'
                            echo '\033[32mDestination address: \033[33m\${dip}\033[0m'
                            echo ''
                            echo ''
                        fi
                fi
            done < \"/tmp/t.txt\"

            rm /tmp/t.txt
            
            ps_output=\$(ps -co pid,cmd,user,lstart | grep \$pid_input)
            cmd=\$(echo \"\$ps_output\" | awk '{print \$2}')
            location=\$(find / -name \$cmd)

            IFS=' ' read -r -a locations <<< \"\$location\"
            for index in \"\${!locations[@]}\"; do
                echo '\033[32mAll locations of PUP:\033[0m'
                echo \"\$index: \033[33m\${locations[\$index]}\033
            done
            echo \"\"
            bool=true
            while \$bool; do
                read -p \"\${GREEN}Enter the number of the location to move, enter 'none', or enter 'all': \${NC}\" location_input
                case \$user_input in
                    \"none\")
                        echo \"No file locations moved...\"
                        \$bool=false
                        ;;
                    \"all\")
                        for index in \"\${!locations[@]}\"; do
                            echo \"Moving all files to /var/zds/ ...\"
                            mv \"\${locations[\$index]}\" \"/var/zds/\${cmd}_\${index}\"
                        done 
                        \$bool=false
                        ;;
                    *)
                        IFS=' ' read -r -a indexes <<< \"\${!locations[@]}\"
                        for element in \"\${indexes[@]}\"; do
                            if [ \"\$element\" == \"\$user_input\" ]; then
                                echo \"Moving \${locations[\$user_input]} to /var/zds ...\"
                                mv \"\${locations[\$index]}\" \"/var/zds/\${cmd}_\${user_input}\"
                                \$bool=false
                            else    
                                echo \"Invalid response...\"
                                clear
                            fi
                        done
                        ;;
                esac
            done

            echo \"\${RED}Killing PID=\${YELLOW}\${pid_input}\${RED}...\${NC}\"
            kill -9 \$pid_input

            ;;
        \"exit\")
            while_loop=false
            ;;
        *)
            echo \"\${YELLOW}Invalid response...\${NC}\"
            ;;
    esac

    bool=true
    while \$bool; do
        read -p \"\${GREEN}Press enter to continue...\${NC}\" x
        bool=false
    done
done
exit
" C-m

# Attach to the tmux session
tmux attach -t my_session

echo "${GREEN}Cleaning up...${NC}"
tmux kill-session -t my_session
kill -9 $watch_pid
rm /tmp/new_processes
