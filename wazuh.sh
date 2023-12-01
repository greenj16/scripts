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

    #uses for loop to send certs to each host
    file_path="./IPs.sh"
    while IFS= read -r line; do
        host_name=$(echo "$line" | grep -oP '^[^=]+')
        host_ip=$(echo "$line" | grep -oP '(?<=\").*(?=\")')

        if [[ $host_name != "ubu_web" && $host_name != "panos" ]]; then
            
    done < $file_path





else
    echo "please run this on the Ubuntu Web host..."

fi