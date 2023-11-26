#!/bin/bash

. IPs.sh

current_ip=$(hostname -I | awk '{print $1}')

if [ "$ubu_web" == "$current_ip" ]; then

sed -i 's/#\?\(vm.max_map_count=\s*\).*$/vm.max_map_count=262144/' /etc/sysctl.conf






else
    echo "please run this on the Ubuntu Web host..."

fi