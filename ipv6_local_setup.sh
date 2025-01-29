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

    cat <<EOF >> /etc/netplan/01-netcfg.yaml
        
network:
    version: 2
    renderer: networkd
    ethernets:
        ens33:
            dhcp4: no
            dhcp6: no
            addresses:
            - 172.20.240.20/24 #ubu_wrk IP
            - 2001:db8:2::200/64 # randomly crafted IP with same prefix as ubu_web
            routes:
                - to: default   #default IPv4
                  via: 172.20.240.254 # gateway?
                - to: "::/0"   #default IPv6
                  via: 2001:db1:2::1
                  on-link: true
            nameservers:
                addresses:
                - 172.20.240.20
EOF

    netplan apply

}


function ubu_web_config_ipv6() {

    cat <<EOF >> /etc/netplan/01-netcfg.yaml
        
network:
    version: 2
    renderer: networkd
    ethernets:
        ens33:
            dhcp4: no
            dhcp6: no
            addresses:
            - 172.20.242.10/24 #ubu_wrk IP
            - 2001:db8:1::200/64 # randomly crafted IP with same prefix as ubu_web
            routes:
                - to: default   #default IPv4
                  via: 172.20.242.254 # gateway?
                - to: "::/0"   #default IPv6
                  via: 2001:db1:1::1
                  on-link: true
            nameservers:
                addresses:
                - 172.20.240.20
EOF

    netplan apply

}

function ubu_work_config_ipv6() {

    mv /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.bak
    cat <<EOF >> /etc/netplan/01-netcfg.yaml
        
network:
    version: 2
    renderer: networkd
    ethernets:
        ens33:
            dhcp4: no
            dhcp6: no
            addresses:
            - 172.20.242.120/24 #ubu_wrk IP
            - 2001:db8:1::100/64 # randomly crafted IP with same prefix as ubu_web
            routes:
                - to: default   #default IPv4
                  via: 172.20.242.254 # gateway?
                - to: "::/0"   #default IPv6
                  via: 2001:db1:1::1
                  on-link: true
            nameservers:
                addresses:
                - 172.20.240.20
EOF

    netplan apply

}

function panic(){
    echo "$FUNCNAME: ${RED}fatal error${NC}"
    exit -1
}


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


if [ "$UID" != "0" ]; then
    echo "$0: ${RED}you must be root to configure this box.${NC}"
    exit -1
fi