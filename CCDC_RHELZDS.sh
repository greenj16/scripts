#!/bin/bash


RED=`tput setaf 1`                          # code for red console text
GREEN=`tput setaf 2`                        # code for green text
YELLOW=`tput setaf 3`                       # code for yellow text
NC=`tput sgr0`                              # Reset the text color

yum install dnf -y
echo "y" | dnf install yum


function update(){

    # This function is COMPLETE AND TESTED in regards to
    # hardenubuntu.com/hardenubuntu.com/initial-setup/system-updates.html

    echo "$FUNCNAME: ${GREEN}Updating your machine...${NC}"
    yum update -y
    dnf check-update
}


function enable_only_tty1(){

    # This function is COMPLETE AND TESTED in regards to
    # hardenubuntu.com/hardenubuntu.com/server-setup/secure-console.html

    echo "$FUNCNAME: ${GREEN}Enabling only tty1 (disabling everything else)...${NC}"

    # sed -i '/^\(tty1\|console\|:0\)$/! s/\(.*\)/\# \1/g' /etc/securetty

    cat <<EOF > /etc/securetty
console
tty1
EOF

    sed -i 's/ACTIVE_CONSOLES="\/dev\/tty\[1-6\]/ACTIVE_CONSOLES=\"\/dev\/tty1\"/g' /etc/default/console-setup

    mv /etc/init/tty2.conf /etc/init/tty2.conf_backup
    mv /etc/init/tty3.conf /etc/init/tty3.conf_backup
    mv /etc/init/tty4.conf /etc/init/tty4.conf_backup
    mv /etc/init/tty5.conf /etc/init/tty5.conf_backup
    mv /etc/init/tty6.conf /etc/init/tty6.conf_backup

    echo "$FUNCNAME: ${GREEN}You will need to reboot to see these changes!${NC}"
}


function remove_usb_storage_driver(){

    echo "$FUNCNAME: ${GREEN}Removing USB storage driver...${NC}"

    rm -f /lib/modules/3.19.0-25-generic/kernel/drivers/usb/storage/usb-storage.ko
}

function disable_anacron(){

    # This function is COMPLETE AND TESTED in regards to 
    # hardenubuntu.com/disable-services/disable-anacron/

    echo "$FUNCNAME: ${GREEN}Disabling the anacron service...${NC}"

    sed -i 's/^\(25\|47\|52\)\(.*\)/\# \1\2/g' /etc/crontab
}

function disable_cups(){

    # This function is COMPLETE AND TESTED in regards to 
    # hardenubuntu.com/disable-services/disable-cups/

    echo "$FUNCNAME: ${GREEN}Disabling the cups service...${NC}"

    echo 'manual' > /etc/init/cups.override
    echo "$FUNCNAME: ${GREEN}Removing the cups service...${NC}"

    echo "y" | yum remove cups
}


function remove_telnet(){

    # This function is COMPLETE AND TESTED in regards to 
    # http://hardenubuntu.com/disable-services/disable-telnet/

    echo "$FUNCNAME: ${GREEN}Removing Telnet (thank god)...${NC}"
    if command_exists telnet; then
        echo "y" | yum remove telnetd inetutils-telnetd telnetd-ssl
    fi
}


function verify_permissions_on_crucial_files(){

    # This function is COMPLETE AND TESTED 

    echo "$FUNCNAME: ${GREEN}Verifying/setting permissions on specific files...${NC}"

    echo "$FUNCNAME: ${GREEN}Making sure root own /etc/shadow & passwd & group & gshadow...${NC}"
    chown root:root /etc/passwd /etc/shadow /etc/group /etc/gshadow
    
    echo "$FUNCNAME: ${GREEN}Setting permissions to 644 on /etc/passwd and /etc/group...${NC}"
    chmod 644 /etc/passwd /etc/group

    echo "$FUNCNAME: ${GREEN}Setting permissions to 400 on /etc/shadow and /etc/gshadow...${NC}"
    chmod 400 /etc/shadow /etc/gshadow
}


function verify_world_writeable_dirs_have_sticky(){

    # This function is COMPLETE AND TESTED 

    echo "$FUNCNAME: ${GREEN}Verifying/setting that all world writable directories have their sticky bit set...${NC}"

    find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print | while read directory; do
        echo "$FUNCNAME: ${GREEN} Making sticky on ${directory}..."
        chmod +t ${directory}
    done
}


function verify_no_world_writable_files(){

    # This function is COMPLETE AND TESTED 

    echo "$FUNCNAME: ${GREEN}Verifying/setting that there are no world-writable files on the system...${NC}"

    find / -xdev -type f -perm -0002 -print | while read file; do
        echo "$FUNCNAME: ${GREEN} Removing world-write privilege on ${file}..."
        chmod o-w ${file}
    done
}


function verify_no_setuid_files(){

    # This function is COMPLETE AND TESTED 

    echo "$FUNCNAME: ${GREEN}Verifying/setting that there are no unauthorized SETUID/SETGID files on the system...${NC}"

    find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -print| while read file; do

        if grep -Fxq "$file" "allowed_suid_list.txt"
        then 
            # This program is allowed; leave it alone.
            echo "$FUNCNAME: ${GREEN} ${file} is in the ALLOWED_SUID_LIST! Doing nothing... ${NC}" > /dev/null
        else
            echo "$FUNCNAME: ${GREEN} Removing SUID/SGID bit on ${file}...${NC}"
            chmod -s ${file}
        fi
    done
}


function verify_no_unowned_files(){

    # This function is COMPLETE AND TESTED 

    echo "$FUNCNAME: ${GREEN}Verifying/setting that there are no unowned files on the system...${NC}"

    find / -xdev \( -nouser -o -nogroup \) -print| while read file; do
        echo "$FUNCNAME: ${GREEN} Removing unowned file ${file}..."
        rm -f ${file}
    done
}


function verify_any_world_writable_directories_are_owned_by_root(){

    # This function is COMPLETE AND TESTED 

    echo "$FUNCNAME: ${GREEN}Verifying/setting that any world writable directories are owned by root...${NC}"

    find / -xdev -type d -perm -0002 -uid +500 -print| while read file; do
        echo "$FUNCNAME: ${GREEN} Changing this world writeable directory to be owned only by root: ${file}..."
        chown root:root ${file}
    done
}


function set_umask_to_027(){

    # This function is COMPLETE AND TESTED 

    echo "$FUNCNAME: ${GREEN}Setting global umask to 027 in /etc/login.defs...${NC}"

    sed -i "s/UMASK.\*/UMASK\ \ \ \ \ \ \ \ \ \ \ 027/g" /etc/login.defs

    sed -i 's/umask 002/umask 027/g' /etc/profile
}



function disable_nonhuman_system_accounts(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Disabling 'non-human' system accounts...${NC}"

    awk -F: '{print $1 ":" $3 ":" $7}' /etc/passwd | while read line; do
        username=`echo $line | cut -d":" -f1`
        numid=`echo $line | cut -d":" -f2`

        if [ $numid -lt 500 ] && [ "$numid" != "0" ]; then

            echo "$FUNCNAME: ${GREEN}Locking the password for the account ${username}...${NC}"
            usermod -L $username
            echo "$FUNCNAME: ${GREEN}Disabling the shell for the account ${username}...${NC}"
            usermod -s /usr/sbin/nologin $username
        fi
    done
}


function verify_no_accounts_have_empty_passwords(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Verifying/setting no accounts have empty passwords in /etc/shadow...${NC}"
    awk -F: '($2 == "") {print}' /etc/shadow | cut -d":" -f1 | while read line; do
        echo "$FUNCNAME: ${GREEN} This account '$line' has an empty password! Locking account...${NC}"
        usermod -L $line
    done
}

function verify_all_password_hashes_are_shadowed(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Verifying/setting no accounts have visible hashed passwords in /etc/passwd...${NC}"
    awk -F: '($2 != "x") {print}' /etc/passwd | cut -d":" -f1 | while read line; do
        echo "$FUNCNAME: ${GREEN} This account '$line' has an hashed password visible in /etc/passwd! Locking account...${NC}"
        usermod -L $line
    done
}

function verify_no_other_accounts_have_zero_uids(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Verifying/setting no accounts have a UID of 0 (only root should!)...${NC}"
    awk -F: '($3 == "0") {print}' /etc/passwd | cut -d":" -f1 | while read line; do
        if [ "${line}" != "root" ]; then
            echo "$FUNCNAME: ${GREEN} This account '$line' has a UID of 0, and it shouldn't! Locking account...${NC}"
            usermod -L $line
        fi
    done
}

function force_default_path_environment_variable(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Forcing PATH to be the default value...${NC}"
    export PATH="/usr/local/sbin:/usr/local/bin/:/usr/sbin/:/sbin/:/usr/bin/:/bin/:/usr/games/:/usr/local/games/"
}

function verify_path_directory_permissions(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Verifying/setting that all PATH directories are chmod 755 and owned by only root...${NC}"
    echo $PATH | tr ":" "\n" | while read line; do
        chmod 755 $line
        chown root:root $line
    done
}


function verify_home_directory_dot_files(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Verifying/setting that all HOME directory dot files are not world-writable...${NC}"
    ls /home | while read line; do
        ls -ld /home/$line/.[A-Za-z0-9]* | while read file; do
            chmod go-w /home/$line/$file
        done
    done
}

function verify_no_home_netrc_file(){

    # This function is COMPLETE AND TESTED

    echo "$FUNCNAME: ${GREEN}Verifying/setting that no HOME directory has a .netrc...${NC}"
    ls /home | while read line; do
        rm -f /home/$line/.netrc
    done
}

function install_selinux(){

    echo "$FUNCNAME: ${GREEN}Installing SELinux...${NC}"
    if ! command_exists sestatus; then
        
        yum -y install selinux-basics

    fi
}

function configure_selinux(){

    echo "$FUNCNAME: ${GREEN}Configuring SELinux...${NC}"
    
    sed -i s/SELINUX=.\*/SELINUX=enforcing/g /etc/selinux/config
    sed -i s/SELINUXTYPE=.\*/SELINUXTYPE=targeted/g /etc/selinux/config

    sed -i s/selinux=0//g /boot/grub/grub.cfg
    sed -i s/enforcing=0//g /boot/grub/grub.cfg
}

function change_motd(){

    echo "$FUNCNAME: ${GREEN}Changing the Message of the Day login splash...${NC}"
    rm -f /etc/update-motd.d/*
    echo "Hello and welcome." > /etc/update-motd.d/00-header
    chmod 700 /etc/update-motd.d/00-header
    chown root:root /etc/update-motd.d/00-header

}

function use_proper_sysctl(){

    echo "$FUNCNAME: ${GREEN}Replacing /etc/sysctl.conf with the hardened one...${NC}"
    cp -f sysctl.conf /etc/sysctl.conf
}


function set_better_resolution(){

    if command_exists xrandr; then
        echo "$FUNCNAME: ${GREEN}Changing to a sane resolution of 1366x768...${NC}"
        xrandr -s 1366x768
    fi
}


# Misc
function extras() {
    echo "NOPASSWD commands in sudoers...remove" >> /root/ccdc/scriptCheck.txt
    grep -i NOPASSWD /etc/sudoers /etc/sudoers.d/* >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt

    echo "!authenticate commands in sudoers...remove" >> /root/ccdc/scriptCheck.txt
    sudo grep -i authenticate /etc/sudoers /etc/sudoers.d/* >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt 

    echo "user accoutns without home directories...remove" >> /root/ccdc/scriptCheck.txt
    sudo pwck -r >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt

    echo "Checking the permissions of 'cron.allow'... this should be root!" >> /root/ccdc/scriptCheck.txt
    ls -al /etc/cron.allow >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt

    echo "Checking for .shosts files on the system... remove these if found!" >> /root/ccdc/scriptCheck.txt
    find / -name '*.shosts' 2>/dev/null >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt

    echo "Checking for a shots.equiv file on the system... remove this if found!" >> /root/ccdc/scriptCheck.txt
    find / -name shosts.equiv 2>/dev/null >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt
}


# backup files for post analysis
function backup() {
    mkdir -p /root/ccdc/back

    cp /etc/ssh/ssh_config /root/ccdc/back/ssh_config
    cp /etc/ssh/sshd_config /root/ccdc/back/sshd_config
    cp /etc/passwd /root/ccdc/back/passwd
    cp /etc/sudoers /root/ccdc/back/sudoers
    cp ~/.bash_history /root/ccdc/back/.bash_history
    cp ~/.bashrc /root/ccdc/back/.bashrc
    cp /etc/skel /root/ccdc/back/skel
    cp ~/.profile /root/ccdc/back/.profile
    cp /etc/security/pwquality.conf /root/ccdc/back/pwquality.conf
    cp /etc/login.defs /root/ccdc/back/login.defs
    cp /etc/sysctl.conf /root/ccdc/back/sysctl.conf
    cp /etc/default/useradd /root/ccdc/back/useradd
    cp /var/spool/cron/crontabs/root /root/ccdc/back/root1crontab
    cp /var/spool/cron/root /root/ccdc/back/root2crontab
    cp /etc/hosts /root/ccdc/back/hosts
    cp /etc/resolv.conf /root/ccdc/back/resolv.conf
    cp -r /var/www/html /root/ccdc/back/html
    cp /etc/named.conf /root/ccdc/back/named.conf
    cp -r /var/named /root/ccdc/back/named

}

function panic(){
    echo "$FUNCNAME: ${RED}fatal error${NC}"
    exit -1
}

function command_exists(){
    type "$1" &> /dev/null
}


function main(){

    echo "$FUNCNAME: ${GREEN}Running harden_service.sh...${NC}"

    update || panic
    enable_only_tty1 || panic

    remove_usb_storage_driver || panic
    verify_permissions_on_crucial_files || panic
    verify_world_writeable_dirs_have_sticky || panic
    verify_no_world_writable_files || panic
    verify_no_setuid_files || panic
    verify_no_unowned_files || panic
    verify_any_world_writable_directories_are_owned_by_root || panic

    set_umask_to_027 || panic
    disable_nonhuman_system_accounts || panic
    verify_no_accounts_have_empty_passwords || panic
    verify_all_password_hashes_are_shadowed || panic
    verify_no_other_accounts_have_zero_uids || panic
    force_default_path_environment_variable || panic
    verify_path_directory_permissions || panic
    verify_home_directory_permissions || panic
    install_selinux || panic
    configure_selinux || panic
    disable_anacron || panic 
    disable_cups || panic
    remove_telnet || panic


    force_default_path_environment_variable || panic
    verify_path_directory_permissions || panic
    verify_home_directory_permissions || panic


    use_proper_sysctl || panic

    change_motd || panic
    extras || panic
    backup || panic
        
    echo "$FUNCNAME: ${GREEN}All done! You should DEFINITELY reboot your machine for these changes!${NC}"

    exit 0  
}


# Make sure the user is root (e.g. running as sudo)
if [ "$UID" != "0" ]; then
    echo "$0: ${RED}you must be root to configure this box.${NC}"
    exit -1
fi

# This makes it so every function has a "pre-declaration" of all the functions
main "$@"