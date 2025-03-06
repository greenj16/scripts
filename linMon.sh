#!/bin/bash

RED=`tput setaf 1`                          # code for red console text
GREEN=`tput setaf 2`                        # code for green text
YELLOW=`tput setaf 3`                       # code for yellow text
NC=`tput sgr0`                              # Reset the text color

if [ ! -e /usr/bin/tmux ]; then
    apt install tmux
fi

update_process_list() {
    trap "exit" SIGINT SIGTERM
    # Get the list of current processes and store it in the array
    while true; do
        ps -eo pid,ppid,cmd,user --sort=start_time | tail | grep -Ev "splunk|\[|watch|tmux|tail|ps|sleepl" > /var/zds/new_processes
        sleep 2
    done
}

# run watch in the background
update_process_list &
loop_pid=$!

cat << 'EOF' > /var/zds/temp_function.sh
#!/bin/bash

RED=`tput setaf 1`                          # code for red console text
GREEN=`tput setaf 2`                        # code for green text
YELLOW=`tput setaf 3`                       # code for yellow text
NC=`tput sgr0`                              # Reset the text color
# Continuously prompt the user for input
while_loop=true
while $while_loop; do
    clear
    echo "################################"
    echo "# ${GREEN}1 Investigate${NC}                #"
    echo "# ${GREEN}2 Eradicate${NC}                  #"
    echo "# ${GREEN}3 Investigate and Eradicate${NC}  #"
    echo "################################"
    echo ""
    read -p "${GREEN}Enter choose an option (type '${RED}exit${GREEN}' to quit): ${NC}" user_input


    case $user_input in
        "1")
            clear
            read -p "${GREEN}Enter the PID to investigate: ${NC}" pid_input

            cmd="$(ps -co cmd -p ${pid_input} | grep -Ev 'CMD')"
            ps_user="$(ps -o user -p ${pid_input} | grep -Ev 'USER')"
            time_start="$(ps -o lstart -p ${pid_input} | grep -Ev 'STARTED' | awk '{print $4}')"
            cmd_line="$(ps -o cmd -p ${pid_input} | grep -Ev 'CMD')"
            location=$(find / -name $cmd)

            netstat_line=$(netstat -peanut | grep -w $pid_input)
            if [[ $netstat_line -eq "" ]]; then
                listen_state="This process is not using network connections"
                dip="This process is not using network connections"
            else
                listen_state=$(echo "$netstat_line" | awk '{print $6}')
                dip=$(echo "$netstat_line" | awk '{print $5}')
            fi

            if echo "$listen_state" | grep -q "ESTABLISHED"; then

                clear
                echo "${GREEN}Command used: ${YELLOW}${cmd_line}${NC}"
                echo "${GREEN}Where app is located: ${NC}"
                echo "${YELLOW}${location}${NC}"
                echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                echo "${GREEN}Process network status: ${NC}"
                echo "${RED}${listen_state}${NC}"
                echo "${GREEN}Destination address: ${NC}"
                echo "${RED}${dip}${NC}"
                echo ""
                echo "${RED}CONNECTION ESTABLISHED${GREEN} - Check logs for malicous activity from ${RED}${dip}${NC}"
                echo "${GREEN}Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous${NC}"
                echo ""
                echo ""

            elif echo "$listen_state" | grep -q "LISTEN" && ! echo "$listen_state" | grep -q "ESTABLISHED"; then

                clear
                echo "${GREEN}Command used: ${YELLOW}${cmd_line}${NC}"
                echo "${GREEN}Where app is located: ${NC}"
                echo "${YELLOW}${location}${NC}"
                echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                echo "${GREEN}Process network status: ${NC}"
                echo "${YELLOW}${listen_state}${NC}"
                echo "${GREEN}Destination address(es): ${NC}"
                echo "${YELLOW}${dip}${NC}"
                echo ""
                echo "Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous"
                echo ""
                echo ""

            else
                clear
                echo "${GREEN}Command used: ${YELLOW}${cmd_line}${NC}"
                echo "${GREEN}Where app is located: ${NC}"
                echo "${YELLOW}${location}${NC}"
                echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                echo "${GREEN}Process network status: ${NC}"
                echo "${GREEN}${listen_state}${NC}"
                echo "${GREEN}Destination address: ${NC}"
                echo "${GREEN}${dip}${NC}"
                echo ""
                echo "Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous"
                echo ""
                echo ""
            fi
            ;;
        "2")
            clear
            read -p "${GREEN}Enter the PID to eradicate: ${NC}" pid_input
            clear

            ps_output=$(ps -co pid,cmd,user,lstart | grep $pid_input)
            cmd=$(echo "$ps_output" | awk '{print $2}')
            location=$(find / -name $cmd)

            IFS=' ' read -r -a locations <<< "$location" 

            echo ""
            bool=true
            while $bool; do
                for index in "${!locations[@]}"; do
                    echo "${GREEN}All locations of PUP:${NC}"
                    echo "${index}: ${YELLOW}${locations[$index]}${NC}"
                done 
                echo "${GREEN}Which file(s) do you want to move?${NC}"
                read -p "${GREEN}Options: line number, 'all', 'none', 'manual' or enter to exit: ${NC}" user_input
                case $user_input in
                    "none")
                        echo "No file locations moved..."
                        bool=false
                        ;;
                    "all")
                        for index in "${!locations[@]}"; do
                            echo "Moving ${locations[$index]} to /var/zds/ ..."
                            mv "${locations[$index]}" "/var/zds/${cmd}_${index}"
                        done 
                        bool=false
                        ;;
                    "manual")
                        clear
                        read -p "${GREEN}Enter the file path you want to move: ${NC}" file_path
                        current_time=$(date +"%H:%M:%S")
                        echo "Moving ${file_path} to /var/zds/ ..."
                        mv "${file_path}" "/var/zds/${current_time}"
                        bool=false
                        ;;
                    "")
                        bool=false
                        ;;
                    *)
                        IFS=' ' read -r -a indexes <<< "${!locations[@]}"
                        for element in "${indexes[@]}"; do
                            if [ "$element" == "$user_input" ]; then
                                echo "Moving ${locations[$user_input]} to /var/zds ..."
                                mv "${locations[$index]}" "/var/zds/${cmd}_${user_input}"
                                bool=false
                            else    
                                echo "Invalid response..."
                                clear
                            fi
                        done
                        ;;
                esac
            done

            bool=true
            while $bool; do
                clear
                read -p "${GREEN}Kill the process? y or n ${NC}" answer
                case $answer in
                    "yes"|"y"|"Y")
                        echo "${RED}Killing PID=${YELLOW}${pid_input}${RED}...${NC}"
                        kill -9 $pid_input
                        bool=false
                        ;;
                    "no"|"n"|"N")
                        bool=false
                        ;;
                    *)
                        ;;
                esac
            done

            ;;
        "3")
            clear
            read -p "${GREEN}Enter the PID to investigate: ${NC}" pid_input

            cmd="$(ps -co cmd -p ${pid_input} | grep -Ev 'CMD')"
            ps_user="$(ps -o user -p ${pid_input} | grep -Ev 'USER')"
            time_start="$(ps -o lstart -p ${pid_input} | grep -Ev 'STARTED' | awk '{print $4}')"
            cmd_line="$(ps -o cmd -p ${pid_input} | grep -Ev 'CMD')"
            location=$(find / -name $cmd)

            netstat_line=$(netstat -peanut | grep -w $pid_input)
            if [[ $netstat_line -eq "" ]]; then
                listen_state="This process is not using network connections"
                dip="This process is not using network connections"
            else
                listen_state=$(echo "$netstat_line" | awk '{print $6}')
                dip=$(echo "$netstat_line" | awk '{print $5}')
            fi

            if echo "$listen_state" | grep -q "ESTABLISHED"; then

                clear
                echo "${GREEN}Command used: ${YELLOW}${cmd_line}${NC}"
                echo "${GREEN}Where app is located: ${NC}"
                echo "${YELLOW}${location}${NC}"
                echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                echo "${GREEN}Process network status: ${NC}"
                echo "${RED}${listen_state}${NC}"
                echo "${GREEN}Destination address: ${NC}"
                echo "${RED}${dip}${NC}"
                echo ""
                echo "${RED}CONNECTION ESTABLISHED${GREEN} - Check logs for malicous activity from ${RED}${dip}${NC}"
                echo "${GREEN}Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous${NC}"
                echo ""
                echo ""

            elif echo "$listen_state" | grep -q "LISTEN" && ! echo "$listen_state" | grep -q "ESTABLISHED"; then

                clear
                echo "${GREEN}Command used: ${YELLOW}${cmd_line}${NC}"
                echo "${GREEN}Where app is located: ${NC}"
                echo "${YELLOW}${location}${NC}"
                echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                echo "${GREEN}Process network status: ${NC}"
                echo "${YELLOW}${listen_state}${NC}"
                echo "${GREEN}Destination address(es): ${NC}"
                echo "${YELLOW}${dip}${NC}"
                echo ""
                echo "Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous"
                echo ""
                echo ""

            else
                clear
                echo "${GREEN}Command used: ${YELLOW}${cmd_line}${NC}"
                echo "${GREEN}Where app is located: ${NC}"
                echo "${YELLOW}${location}${NC}"
                echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                echo "${GREEN}Process network status: ${NC}"
                echo "${GREEN}${listen_state}${NC}"
                echo "${GREEN}Destination address: ${NC}"
                echo "${GREEN}${dip}${NC}"
                echo ""
                echo "Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous"
                echo ""
                echo ""
            fi

            
            ps_output=$(ps -co pid,cmd,user,lstart | grep $pid_input)
            cmd="$(ps -co cmd -p ${pid_input} | grep -Ev 'CMD')"
            location=$(find / -name $cmd)

            IFS=' ' read -r -a locations <<< "$location"

            echo ""
            bool=true
            while $bool; do
                for index in "${!locations[@]}"; do
                    echo "${GREEN}All locations of PUP:${NC}"
                    echo "${index}: ${YELLOW}${locations[$index]}${NC}"
                done 
                echo "${GREEN}Which file(s) do you want to move?${NC}"
                read -p "${GREEN}Options: line number, 'all', 'none', 'manual' or enter to exit: ${NC}" user_input
                case $user_input in
                    "none")
                        echo "No file locations moved..."
                        bool=false
                        ;;
                    "all")
                        for index in "${!locations[@]}"; do
                            echo "Moving ${locations[$index]} to /var/zds/ ..."
                            mv "${locations[$index]}" "/var/zds/${cmd}_${index}"
                        done 
                        bool=false
                        ;;
                    "manual")
                        clear
                        read -p "${GREEN}Enter the file path you want to move: ${NC}" file_path
                        current_time=$(date +"%H:%M:%S")
                        echo "Moving ${file_path} to /var/zds/ ..."
                        mv "${file_path}" "/var/zds/${current_time}"
                        bool=false
                        ;;
                    "")
                        bool=false
                        ;;
                    *)
                        IFS=' ' read -r -a indexes <<< "${!locations[@]}"
                        for element in "${indexes[@]}"; do
                            if [ "$element" == "$user_input" ]; then
                                echo "Moving ${locations[$user_input]} to /var/zds ..."
                                mv "${locations[$index]}" "/var/zds/${cmd}_${user_input}"
                                bool=false
                            else    
                                echo "Invalid response..."
                                clear
                            fi
                        done
                        ;;
                esac
            done

            bool=true
            while $bool; do
                clear
                read -p "${GREEN}Kill the process? y or n ${NC}" answer
                case $answer in
                    "yes"|"y"|"Y")
                        echo "${RED}Killing PID=${YELLOW}${pid_input}${RED}...${NC}"
                        kill -9 $pid_input
                        bool=false
                        ;;
                    "no"|"n"|"N")
                        bool=false
                        ;;
                    *)
                        ;;
                esac
            done

            ;;
        "exit")
            while_loop=false
            ;;
        *)
            echo "${YELLOW}Invalid response...${NC}"
            ;;
    esac

    bool=true
    while $bool; do
        if [ $while_loop == "true" ]; then
            read -p "${GREEN}Press enter to continue...${NC}" x
        fi
        bool=false
        clear
    done
done
tmux kill-session
EOF

chmod +x /var/zds/temp_function.sh


# Start a new tmux session
tmux new-session -d -s my_session

# Split the tmux window into two panes
tmux split-window -h

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
                    echo \"Line num, PID, PPID, CMD, User\"
                else
                    echo \"\${count}: \${line}\"
                fi
                ((count++))
            done < \"/var/zds/new_processes\"
            sleep 2
        done
    }
" C-m
tmux send-keys -t my_session.0 'display_proc' C-m

# Allow user input in the bottom pane

tmux send-keys -t my_session.1 "/var/zds/temp_function.sh" C-m

# Attach to the tmux session
tmux attach -t my_session

echo "${GREEN}Cleaning up...${NC}"
tmux kill-session -t my_session
kill $loop_pid
rm /var/zds/new_processes
rm /var/zds/temp_function.sh