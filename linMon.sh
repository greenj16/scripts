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
        ps -eo pid,ppid,cmd --sort=start_time | tail | grep -Ev "splunk|\[|watch|tmux|tail|ps" > /var/zds/new_processes
        sleep 2
    done
}

# run watch in the background
loop &
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

            ps -co pid,cmd,user,lstart > /var/zds/t.txt

            process=()
            while IFS= read -r line; do
                IFS=' ' read -r -a line_array <<< "$line"
                if [[ $line_array[0] -eq $pid_input ]]; then

                    cmd="${line_array[1]}"
                    ps_user="${line_array[2]}"
                    location=$(find / -name $cmd)
                    time_start="${line_array[3]}"
                    cmd_line=$(ps -o cmd,pid | grep $pid_input | awk '{print $1}')

                    netstat_line=$(netstat -peanut | grep $pid_input)
                    if [[ $netstat_line -eq "" ]]; then
                        listen_state="This process is not using network connections"
                        dip="This process is not using network connections"
                    else
                        listen_state=$(echo "$netstat_line" | awk '{print $6}')
                        dip=$(echo "$netstat_line" | awk '{print $5}')
                    fi

                    if [[ $listen_state -eq "LISTEN" ]]; then

                        clear
                        echo "${GREEN}Command used: ${YELLOW}${cmd_line}{$NC}"
                        echo "${GREEN}Where app is located: ${YELLOW}${location}${NC}"
                        echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                        echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                        if [[ $listen_state -eq "ESTABLISHED" ]]; then
                            echo "${GREEN}Process network status: ${RED}${listen_state}${NC}"
                            echo "${GREEN}Destination address: ${RED}${dip}${NC}"
                            echo ""
                            echo "${RED}CONNECTION ESTABLISHED${GREEN} - Check logs for malicous activity from ${RED}${dip}${NC}"
                            echo "${GREEN}Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous${NC}"
                            echo ""
                            echo ""
                        else
                            echo "${GREEN}Process network status: ${YELLOW}${listen_state}${NC}"
                            echo "${GREEN}Destination address: ${YELLOW}${dip}${NC}"
                            echo ""
                            echo "${GREEN}Please use the 'Eradicate' option [enter '2'] if this is confirmed malicous${NC}"
                            echo ""
                            echo ""
                        fi
                fi
            done < "/var/zds/t.txt"

            rm /var/zds/t.txt
            ;;
        "2")
            clear
            read -p "${GREEN}Enter the PID to eradicate: ${NC}" pid_input
            clear

            ps_output=$(ps -co pid,cmd,user,lstart | grep $pid_input)
            cmd=$(echo "$ps_output" | awk '{print $2}')
            location=$(find / -name $cmd)

            IFS=' ' read -r -a locations <<< "$location"
            for index in "${!locations[@]}"; do
                echo "${GREEN}All locations of PUP:${NC}"
                echo "${index}: ${YELLOW}${locations[$index]}${NC}"
            done 

            echo ""
            bool=true
            while $bool; do
                read -p "${GREEN}Enter the number of the location to move, enter 'none', or enter 'all': ${NC}" location_input
                case $user_input in
                    "none")
                        echo "No file locations moved..."
                        $bool=false
                        ;;
                    "all")
                        for index in "${!locations[@]}"; do
                            echo "Moving all files to /var/zds/ ..."
                            mv "${locations[$index]}" "/var/zds/${cmd}_${index}"
                        done 
                        $bool=false
                        ;;
                    *)
                        IFS=' ' read -r -a indexes <<< "${!locations[@]}"
                        for element in "${indexes[@]}"; do
                            if [ "$element" == "$user_input" ]; then
                                echo "Moving ${locations[$user_input]} to /var/zds ..."
                                mv "${locations[$index]}" "/var/zds/${cmd}_${user_input}"
                                $bool=false
                            else    
                                echo "Invalid response..."
                                clear
                            fi
                        done
                        ;;
                esac
            done

            echo "${RED}Killing PID=${YELLOW}${pid_input}${RED}...${NC}"
            kill -9 $pid_input

            ;;
        "3")
            clear
            read -p "${GREEN}Enter the PID to investigate: ${NC}" pid_input

            ps -co pid,cmd,user,lstart > /var/zds/t.txt

            process=()
            while IFS= read -r line; do
                IFS=' ' read -r -a line_array <<< "$line"
                if [[ $line_array[0] -eq $pid_input ]]; then

                    cmd="${line_array[1]}"
                    ps_user="${line_array[2]}"
                    location=$(find / -name $cmd)
                    time_start="${line_array[3]}"
                    cmd_line=$(ps -o cmd,pid | grep $pid_input | awk '{print $1}')

                    netstat_line=$(netstat -peanut | grep $pid_input)
                    if [[ $netstat_line -eq "" ]]; then
                        listen_state="This process is not using network connections"
                        dip="This process is not using network connections"
                    else
                        listen_state=$(echo "$netstat_line" | awk '{print $6}')
                        dip=$(echo "$netstat_line" | awk '{print $5}')
                    fi

                    if [[ $listen_state -eq "LISTEN" ]]; then

                        clear
                        echo "${GREEN}Command used: ${YELLOW}${cmd_line}{$NC}"
                        echo "${GREEN}Where app is located: ${YELLOW}${location}${NC}"
                        echo "${GREEN}Who ran it: ${YELLOW}${ps_user}${NC}"
                        echo "${GREEN}Start time: ${YELLOW}${time_start}${NC}"
                        if [[ $listen_state -eq "ESTABLISHED" ]]; then
                            echo "${GREEN}Process network status: ${RED}${listen_state}${NC}"
                            echo "${GREEN}Destination address: ${RED}${dip}${NC}"
                            echo ""
                            echo "${RED}CONNECTION ESTABLISHED${GREEN} - Check logs for malicous activity from ${RED}${dip}${NC}"
                            echo ""
                            echo ""
                        else
                            echo "${GREEN}Process network status: ${YELLOW}${listen_state}${NC}"
                            echo "${GREEN}Destination address: ${YELLOW}${dip}${NC}"
                            echo ""
                            echo ""
                        fi
                fi
            done < "/var/zds/t.txt"

            rm /var/zds/t.txt
            
            ps_output=$(ps -co pid,cmd,user,lstart | grep $pid_input)
            cmd=$(echo "$ps_output" | awk '{print $2}')
            location=$(find / -name $cmd)

            IFS=' ' read -r -a locations <<< "$location"
            for index in "${!locations[@]}"; do
                echo "${GREEN}All locations of PUP:${NC}"
                echo "${index}: ${YELLOW}${locations[$index]}${NC}"
            done 

            echo ""
            bool=true
            while $bool; do
                read -p "${GREEN}Enter the number of the location to move, enter 'none', or enter 'all': ${NC}" location_input
                case $user_input in
                    "none")
                        echo "No file locations moved..."
                        $bool=false
                        ;;
                    "all")
                        for index in "${!locations[@]}"; do
                            echo "Moving all files to /var/zds/ ..."
                            mv "${locations[$index]}" "/var/zds/${cmd}_${index}"
                        done 
                        $bool=false
                        ;;
                    *)
                        IFS=' ' read -r -a indexes <<< "${!locations[@]}"
                        for element in "${indexes[@]}"; do
                            if [ "$element" == "$user_input" ]; then
                                echo "Moving ${locations[$user_input]} to /var/zds ..."
                                mv "${locations[$index]}" "/var/zds/${cmd}_${user_input}"
                                $bool=false
                            else    
                                echo "Invalid response..."
                                clear
                            fi
                        done
                        ;;
                esac
            done

            echo "${RED}Killing PID=${YELLOW}${pid_input}${RED}...${NC}"
            kill -9 $pid_input

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
        read -p "${GREEN}Press enter to continue...${NC}" x
        bool=false
    done
done
exit
EOF

chmod +x /var/zds/temp_function.sh


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
            done < \"/var/zds/new_processes\"
            sleep 2
        done
    }
" C-m
tmux send-keys -t my_session.0 'display_proc' C-m

# Allow user input in the bottom pane
tmux send-keys -t my_session.1 "/var/zds/temp_funciton.sh" C-m

# Attach to the tmux session
tmux attach -t my_session

echo "${GREEN}Cleaning up...${NC}"
tmux kill-session -t my_session
kill $watch_pid
rm /var/zds/new_processes
rm /var/zds/temp_funciton.sh