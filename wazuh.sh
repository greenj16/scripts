#!/bin/bash

. IPs.sh

current_ip=$(hostname -I | awk '{print $1}')

if [[ "$ubu_web" == "$current_ip" ]]; then

    #changes vm.max_map_count value to 262144 (requirement)
    sed -i 's/#\?\(vm.max_map_count=\s*\).*$/vm.max_map_count=262144/' /etc/sysctl.conf

    #download files to create ssl certs
    curl -sO https://packages.wazuh.com/4.7/wazuh-certs-tool.sh
    curl -sO https://packages.wazuh.com/4.7/config.yml

    #configure yml to include ubuntu web ip as server
    sed -i "s/<indexer-node-ip>/$ubu_web/" ./config.yml
    sed -i "s/<wazuh-manager-ip>/$ubu_web/" ./config.yml
    sed -i "s/<dashboard-node-ip>/$ubu_web/" ./config.yml

    bash ./wazuh-certs-tool.sh -A
    tar -cvf ./wazuh-certificates.tar -C ./wazuh-certificates/ .
    rm -rf ./wazuh-certificates


<<COMMENTS

    ***Need to set certificates in python server in order to allow clients to PULL certs not push them***

    #uses for loop to send certs to each host
    file_path="./IPs.sh"
    while IFS= read -r line; do

        host_name=$(echo "$line" | grep -oP '^[^=]+')
        host_ip=$(echo "$line" | grep -oP '(?<=\").*(?=\")')

        #prompts user for each host to input username and password in order to scp
        if [[ $host_name != "ubu_web" && $host_name != "panos" ]]; then

            scp ./wazuh-certificates.tar 
        fi
    done < $file_path
COMMENTS

    # installing nessesary packages
    apt-get install debconf adduser procps
    apt-get install gnupg apt-transport-https

    # download gpg key
    curl -sk https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg

    # edits apt repos
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list

    apt-get update

    apt-get -y install wazuh-indexer



else
    echo "please run this on the Ubuntu Web host..."
fi