#!/bin/bash 

RED=`tput setaf 1`                          # code for red console text
GREEN=`tput setaf 2`                        # code for green text
YELLOW=`tput setaf 3`                       # code for yellow text
NC=`tput sgr0`                              # Reset the text color


var=""
function prompt {
	#[prompt] [variable]
	read -p "$1" "$3"
	if [[ "${!3}" == "" ]]; then
		echo "${RED}Please enter valid response${NC}" 
        exit -1
	fi
    var=$3
    echo $var
}

function enable_ipv6() {

    echo "$FUNCNAME: ${GREEN}Disabling IPv6...${NC}"

    sysctl_config_file="/etc/sysctl.conf"

    sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sysctl -w net.ipv6.conf.default.disable_ipv6=0
    sysctl -w net.ipv6.conf.lo.disable_ipv6=0

    echo "$FUNCNAME: ${GREEN}Reloading sysctl so the changes take place...${NC}"

    sysctl -p

}

function deb_config_ipv6() {

    ip -6 addr add 2001:db8:2::200/64 dev ens33
    ip -6 route add  default via 2001:db8:2::1 dev ens33

}


function ubu_web_config_ipv6() {

    ip -6 addr add 2001:db8:1::200/64 dev ens33
    ip -6 route add  default via 2001:db8:1::1 dev ens33

}

function ubu_work_config_ipv6() {

    ip -6 addr add 2001:db8:1::100/64 dev ens33
    ip -6 route add default via 2001:db8:1::1 dev ens33

}

function panic(){
    echo "$FUNCNAME: ${RED}fatal error${NC}"
    exit -1
}

function main {
# prompt user for host name
prompt "${GREEN}What is your host?: ${YELLOW}ubu_web, ubu_work, deb${NC}" host

# ubu web commands
if [[ "${3}" == "ubu_web"]]; then
    
    echo "${GREEN}Setting up ubu_web...${NC}"

    enable_ipv6 || panic
    ubu_web_config_ipv6 || panic

fi

#ubu workstation commands
if [[ "${3}" == "ubu_work"]]; then
    
    echo "${GREEN}Setting up ubu_work...${NC}"

    enable_ipv6 || panic
    ubu_work_config_ipv6 || panic

fi

# debian commands
if [[ "${3}" == "deb"]]; then
    
    echo "${GREEN}Setting up ubu_work...${NC}"

    enable_ipv6 || panic
    ubu_work_config_ipv6 || panic

fi

exit 0
}

if [ "$UID" != "0" ]; then
    echo "$0: ${RED}you must be root to configure this box.${NC}"
    exit -1
fi

main "$@"
