#!/bin/bash

RED=`tput setaf 1`                          # code for red console text
GREEN=`tput setaf 2`                        # code for green text
YELLOW=`tput setaf 3`                       # code for yellow text
NC=`tput sgr0`                              # Reset the text color

# Example usage: echo "$FUNCNAME: ${GREEN}You will need to reboot to see these changes!${NC}"


function update(){

    # This function is COMPLETE AND TESTED in regards to
    # hardenubuntu.com/hardenubuntu.com/initial-setup/system-updates.html

    echo "$FUNCNAME: ${GREEN}Updating your machine...${NC}"
    apt-get update
    echo "y" |  apt-get upgrade
    apt-get autoremove
    apt-get autoclean
}

# Only allowing the use of tty1
function securetty() {

# allows root login to only the listed consoles
cat <<EOF > /etc/securetty
console
tty1
EOF
    #removes all tty's except tty1
    sed -i 's/ACTIVE_CONSOLES="\/dev\/tty\[1-6\]/ACTIVE_CONSOLES=\"\/dev\/tty1\"/g' /etc/default/console-setup

    mv /etc/init/tty2.conf /etc/init/tty2.conf_backup
    mv /etc/init/tty3.conf /etc/init/tty3.conf_backup
    mv /etc/init/tty4.conf /etc/init/tty4.conf_backup
    mv /etc/init/tty5.conf /etc/init/tty5.conf_backup
    mv /etc/init/tty6.conf /etc/init/tty6.conf_backup

    echo "$FUNCNAME: ${GREEN}You will need to reboot to see these changes!${NC}"
}

function anacronless() {
# Disables anacron
echo "$FUNCNAME: ${GREEN}Disabling the anacron service...${NC}"

sed -i 's/^\(25\|47\|52\)\(.*\)/\# \1\2/g' /etc/crontab
}

# remove unecessary services
function cupsless() {
echo "$FUNCNAME: ${GREEN}Disabling the cups service...${NC}"

echo 'manual' > /etc/init/cups.override
echo "y" | apt-get remove cups
}


function telnetless() {
echo "$FUNCNAME: ${GREEN}Removing Telnet...${NC}"
if command_exists telnet; then
    echo "y" | apt-get purge telnetd inetutils-telnetd telnetd-ssl
fi
}


# Removing USB Driver (Ubuntu)
function usbless() {
echo "$FUNCNAME: ${GREEN}Removing USB storage driver...${NC}"

rm -f /lib/modules/3.19.0-25-generic/kernel/drivers/usb/storage/usb-storage.ko
}

# Important file permissions
function root_owns_shadow_passwd() {
echo "$FUNCNAME: ${GREEN}Making sure root own /etc/shadow & passwd & group & gshadow...${NC}"
chown root:root /etc/passwd /etc/shadow /etc/group /etc/gshadow
}

function root_read_write_passwd() {
echo "$FUNCNAME: ${GREEN}Setting permissions to 644 on /etc/passwd and /etc/group...${NC}"
chmod 644 /etc/passwd /etc/group
}

function root_read_shadow() {
echo "$FUNCNAME: ${GREEN}Setting permissions to 400 on /etc/shadow and /etc/gshadow...${NC}"
chmod 400 /etc/shadow /etc/gshadow
}

# World writable directories have sticky bit
function sticky() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that all world writable directories have their sticky bit set...${NC}"

find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) -print | while read directory; do
    echo "$FUNCNAME: ${GREEN} Making sticky on ${directory}..."
    chmod +t ${directory}
done
}


# No world writable files
function global_writable_fileless() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that there are no world-writable files on the system...${NC}"

find / -xdev -type f -perm -0002 -print | while read file; do
    echo "$FUNCNAME: ${GREEN} Removing world-write privilege on ${file}..."
    chmod o-w ${file}
done
}


# Checks for files with setuid/setgid bit
function remove_setuid() {
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

# Lists unowned files
function unowned_files() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that there are no unowned files on the system...${NC}"

    find / -xdev \( -nouser -o -nogroup \) -print| while read file; do
        echo "$FUNCNAME: ${Yellow} ${file} is unowned...${NC}"
        echo "${file}" >> ~/unownedFiles.txt
    done
}

# making world writable directiores owned by root
function writable_direct_root() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that any world writable directories are owned by root...${NC}"

    find / -xdev -type d -perm -0002 -uid +500 -print| while read file; do
        echo "$FUNCNAME: ${GREEN} Changing this world writeable directory to be owned only by root: ${file}..."
        chown root:root ${file}
    done
}

# ensures that newly created files are readable and executable by the owner, but not accessible by others
function new_file_perms() {
 echo "$FUNCNAME: ${GREEN}Setting global umask to 027 in /etc/login.defs...${NC}"

    sed -i "s/UMASK.\*/UMASK\ \ \ \ \ \ \ \ \ \ \ 027/g" /etc/login.defs

    sed -i 's/umask 002/umask 027/g' /etc/profile
}

# locking users with empty passwords
function emtpy_password() {
echo "$FUNCNAME: ${GREEN}Verifying/setting no accounts have empty passwords in /etc/shadow...${NC}"
    awk -F: '($2 == "") {print}' /etc/shadow | cut -d":" -f1 | while read line; do
        echo "$FUNCNAME: ${GREEN} This account '$line' has an empty password! Locking account...${NC}"
        usermod -L $line
    done
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




# locks non root accounts with uid of 0
function uid0_accounts() {
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

# make sure path directories are owned by root with proper permissions
function path_direct_perm() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that all PATH directories are chmod 755 and owned by only root...${NC}"
    echo $PATH | tr ":" "\n" | while read line; do
        chmod 755 $line
        chown root:root $line
    done
}

# verify home directory permissions and ownership
function home_direct_perms() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that all HOME directories are chmod 755 and owned by only the home user...${NC}"
    ls /home | while read line; do
        chmod g-w /home/$line
        chmod o-rwx /home/$line
        chown $line:$line /home/$line
    done
}


# verify home directory dot files
function dot_files() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that all HOME directory dot files are not world-writable...${NC}"
    ls /home | while read line; do
        ls -ld /home/$line/.[A-Za-z0-9]* | while read file; do
            chmod go-w /home/$line/$file
        done
    done
}

# removing .netrc files
function netrc_files() {
echo "$FUNCNAME: ${GREEN}Verifying/setting that no HOME directory has a .netrc...${NC}"
    ls /home | while read line; do
        rm -f /home/$line/.netrc
    done
}

# changing MOTD
function change_motd() {
echo "$FUNCNAME: ${GREEN}Changing the Message of the Day login splash...${NC}"
    rm -f /etc/update-motd.d/*
    echo "This is a message" > /etc/update-motd.d/00-header
    chmod 700 /etc/update-motd.d/00-header
    chown root:root /etc/update-motd.d/00-header
}

# installing and configuring SELinux
function config_selinux() {
echo "$FUNCNAME: ${GREEN}Installing SELinux...${NC}"
    if ! command_exists sestatus; then
        
        apt-get -y install selinux-basics

    fi
echo "$FUNCNAME: ${GREEN}Configuring SELinux...${NC}"
    
    sed -i s/SELINUX=.\*/SELINUX=permissive/g /etc/selinux/config
    sed -i s/SELINUXTYPE=.\*/SELINUXTYPE=targeted/g /etc/selinux/config

    sed -i s/selinux=0//g /boot/grub/grub.cfg
    sed -i s/enforcing=0//g /boot/grub/grub.cfg
}


# changes resolution (may be useful)
function change_res() {
if command_exists xrandr; then
        echo "$FUNCNAME: ${GREEN}Changing to a sane resolution of 1366x768...${NC}"
        xrandr -s 1366x768
    fi
}

# using premade hardened config files for important configs !!!!!!!!!
function premade_config_files(){
echo "$FUNCNAME: ${GREEN}Replacing /etc/sysctl.conf with the hardened one...${NC}"
    cp -f sysctl.conf /etc/sysctl.conf
}

# Misc
function extras() {
    # adds lines with NOPASSWD to file
    echo "NOPASSWD commands in sudoers...remove" >> /root/ccdc/scriptCheck.txt
    grep -i NOPASSWD /etc/sudoers /etc/sudoers.d/* >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt

    # adds lines with !authenticate to file
    echo "!authenticate commands in sudoers...remove" >> /root/ccdc/scriptCheck.txt
    sudo grep -i authenticate /etc/sudoers /etc/sudoers.d/* >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt 

    # lists users with no home directory in file
    echo "user accounts without home directories...remove" >> /root/ccdc/scriptCheck.txt
    sudo pwck -r >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt

    # lists perms of cron.allow to file
    echo "Checking the permissions of 'cron.allow'... this should be root!" >> /root/ccdc/scriptCheck.txt
    ls -al /etc/cron.allow >> /root/ccdc/scriptCheck.txt
    echo "" >> /root/ccdc/scriptCheck.txt

    # adds .shosts files to file
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


# closes script if function fails
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
    securetty || panic
    anacronless || panic
    cupsless || panic
    telnetless || panic
    usbless || panic
    root_owns_shadow_passwd || panic
    root_read_write_passwd || panic
    root_read_shadow || panic
    sticky || panic
    global_writable_fileless || panic
    remove_setuid || panic
    unowned_files || panic
    writable_direct_root || panic
    new_file_perms || panic
    emtpy_password || panic
    disable_nonhuman_system_accounts || panic
    uid0_accounts || panic
    force_default_path_environment_variable || panic
    path_direct_perm || panic
    home_direct_perms || panic
    dot_files || panic
    netrc_files || panic
    change_motd || panic
    config_selinux || panic
    change_res || panic
    premade_config_file || panics
    extras || panic
    backup || panic
    
    echo "$FUNCNAME: ${GREEN}All done! You should DEFINITELY reboot your machine for these changes!${NC}"

    exit 0  
}

if [ "$UID" != "0" ]; then
    echo "$0: ${RED}you must be root to configure this box.${NC}"
    exit -1
fi

# This makes it so every function has a "pre-declaration" of all the functions
main "$@"