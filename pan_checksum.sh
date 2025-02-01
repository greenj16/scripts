#!/bin/bash

################################################################################################################
#
# Download file from github and set up cron in zds and download scripts first
#
################################################ project script ################################################
#
# curl -ko pan_checksum "https://raw.githubusercontent.com/greenj16/scripts/refs/heads/main/pan_checksum.sh"
#
################################################## ZDS script ##################################################
#
# echo Downloading and running pan_checksum
# curl -o pan_checkcum $VULPIX/pan_checksum
# chmod +x pan_checksum
# ./pan_checksum
# echo "*/10 * * * * /root/ccdc/pan_checksum" >> /etc/crontab 
#
################################################################################################################




RED=`tput setaf 1`                          # code for red console text
GREEN=`tput setaf 2`                        # code for green text
YELLOW=`tput setaf 3`                       # code for yellow text
ORANGE=`tput setaf 214`                     # code for orange text
WHITE=`tput setaf 7`                        # code for white text
NC=`tput sgr0`                              # Reset the text color

username=""
pass=""
file1=""
file2=""
var=""
host_ip=""
function prompt {
	#[prompt] [variable]
	read -p "$1" var
	if [[ -z "$var" ]]; then
		echo "${RED}Please enter valid response${NC}" 
        exit -1
	fi
}
function panic(){
    echo "$FUNCNAME: ${RED}fatal error${NC}"
    $password=""
    exit -1
}
function command_exists(){
    type "$1" &> /dev/null
}
function config_pull(){
    arg1=$1
    echo "${GREEN}Pulling config...${NC}"
    echo -n "${GREEN}Enter username: ${NC}"
    read $username
    echo -n "${GREEN}Enter password: ${NC}"
    read -s $password
    curl -k -o /root/ccdc/pan_conf/${arg1} -u $username:$password https://172.20.242.254/api/?type=export&category=configuration&exportType=runningConfig
}   

# must run as root
if [[ "$UID" != "0" ]]; then
    echo "$0: ${RED}you must be root to configure this box.${NC}"
    exit -1
fi


#111111111111111111111111111111111
if command_exists hostname; then

    $host_ip=$(hostname -I | awk '{print $1}')

    #2222222222222222222222222222222
    if [ "$host_ip" == "172.20.242.120"]; then

        #3333333333333333333333333333
        if [[ -e /root/ccdc/pan_conf_old ]]; then

            # pull pan config
            config_pull "new" || panic

            # prompt user for file path
            prompt "${GREEN}Path to OLD PAN config?${NC}" file
            $file1=$var

            prompt "${GREEN}Path to NEW PAN config?${NC}" file
            $file2=$var

            output="changed_lines.txt"

            # Calculate checksums
            checksum1=$(md5sum "$file1" | awk '{print $1}')
            checksum2=$(md5sum "$file2" | awk '{print $1}')

            # Compare checksums
            #44444444444444444444444444444444444
            if [ "$checksum1" != "$checksum2" ]; then
                echo "${RED}Files are different. Saving the newly changed lines to $output${NC}"
                diff "$file1" "$file2" | grep '>' | awk '{for (i=2; i<=NF; i++) printf "%s ", $i; print ""}' > "$output"
            else
                echo "${GREEN}Files are identical.${NC}"
            fi
            #44444444444444444444444444444444444

            rm -f /root/ccdc/pam_conf_old
            mv /root/ccdc/pam_conf_new /root/ccdc/pam_conf_old

        else
            config_pull "old" || panic
        fi
        #3333333333333333333333333333
    else
        echo "${GREEN}You are not Ubuntu Workstation...have a fish instead${NC}"
        echo "      ${YELLOW}/\ ${NC}"
        echo "    ${YELLOW}_/./ ${NC}"
        echo "${YELLOW} ,-${RED}'    ${YELLOW}\`${RED}-:..${YELLOW}-'/ ${NC}"
        echo "${YELLOW}: ${GREEN}o ${RED})      _  ${YELLOW}(${NC}"
        echo "${YELLOW}\"\`-..${RED}..,${YELLOW}--${RED}; \`${YELLOW}-.\ ${NC}"
        echo "${YELLOW}    \`${RED}'\"${NC}"
    fi
    #2222222222222222222222222222222
fi
#111111111111111111111111111111111