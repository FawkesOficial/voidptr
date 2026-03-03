#!/usr/bin/env bash

# install dependencies
install_pkg newt >/dev/null 2>&1 || error "failed to install dependencies: newt (whiptail)"
install_pkg fzf  >/dev/null 2>&1 || error "failed to install dependencies: fzf"

# required for some functionalities of whiptail
export TERM=ansi

# whiptail theme
export NEWT_COLORS='
root=white,black
window=white,black
border=green,black
shadow=black,black

title=green,black
label=white,black

button=black,green
actbutton=black,white

entry=white,black

listbox=white,black
actlistbox=black,green

textbox=white,black
acttextbox=white,black
'


# TODO: get better banner? (current font: DOS Rebel)
print_banner() {
    clear
    cat << "EOF"
                       ███      █████      ███     
                      ░░░      ░░███  ███ ░███  ███
 █████ █████  ██████  ████   ███████ ░░░█████████░ 
░░███ ░░███  ███░░███░░███  ███░░███   ░░░█████░   
 ░███  ░███ ░███ ░███ ░███ ░███ ░███    █████████  
 ░░███ ███  ░███ ░███ ░███ ░███ ░███  ███░░███░░███
  ░░█████   ░░██████  █████░░████████░░░  ░███ ░░░ 
   ░░░░░     ░░░░░░  ░░░░░  ░░░░░░░░      ░░░      
EOF
}

infobox() {
    whiptail --infobox "$1" 8 40
}

welcome_msg() {
    whiptail --title "WARNING!!!" \
             --yesno "This script should only be ran on an unconfigured, fresh live Void Linux ISO environment.\\nDO NOT RUN THIS ON YOUR COMPUTER" 10 70 \
             --yes-button "All ready!" \
             --no-button "Return..."

    whiptail --title "Welcome!" \
             --msgbox "Welcome to Fawkes's Void Linux Bootstrapping Script!\\n\\nThis script will automatically install a fully-featured Linux desktop, and some configs.\\n\\n-Fawkes" 15 60
}

select_keyboard() {
    clear
    echo "[+] Select your keyboard layout:"
    echo "[!] note: the currently loaded keyboard layout is US so you might have to use weird keys while typing here :/"

    _KEYBOARD=$(
        find /usr/share/kbd/keymaps -type f -name "*.map.gz" \
        | sed 's#.*/##' \
        | sed 's/.map.gz//' \
        | sort -u \
        | fzf --prompt="Keyboard Layout > " \
              --height=40% \
              --border \
              --preview "echo {}"
    )

    if [[ -z "$_KEYBOARD" ]]; then
        whiptail --msgbox "No keyboard selected!" 8 40
        select_keyboard
    fi

    loadkeys "$_KEYBOARD"
}

get_username() {
    _USERNAME=$(whiptail --inputbox "Enter a the name of the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1

    while ! echo "$_USERNAME" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        _USERNAME=$(whiptail --nocancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
}

get_password() {
    _USER_PASSWORD=$(whiptail --nocancel --passwordbox "Enter the password for \"$_USERNAME\"." 10 60 3>&1 1>&2 2>&3 3>&1)
    _USER_PASSWORD_CONFIRM=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)

    while ! [ "$_USER_PASSWORD" = "$_USER_PASSWORD_CONFIRM" ]; do
        _USER_PASSWORD=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        _USER_PASSWORD_CONFIRM=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
}

get_hostname() {
    _HOSTNAME=$(whiptail --inputbox "Enter the computer's name (hostname)." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
    while ! echo "$_HOSTNAME" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        _HOSTNAME=$(whiptail --nocancel --inputbox "Hostname not valid. Give a hostname beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
}

select_timezone() {
    clear
    echo "[+] Select your timezone:"

    _TIMEZONE=$(
        find /usr/share/zoneinfo -type f \
        ! -path "*/posix/*" \
        ! -path "*/right/*" \
        ! -name "localtime" \
        ! -name "zone.tab" \
        | sed 's#/usr/share/zoneinfo/##' \
        | sort \
        | fzf --prompt="Timezone > " \
              --height=40% \
              --border \
              --preview "TZ={} date"
    )

    if [[ -z "$_TIMEZONE" ]]; then
        whiptail --msgbox "No timezone selected!" 8 40
        select_timezone
    fi
}

select_install_disk() {
    clear
    echo "[+] Select the disk to install the system to:"

    _DISK=$(
        lsblk -dpno NAME,SIZE,MODEL -e 7,11 \
        | grep -v "boot\|rpmb\|loop" \
        | fzf --prompt="Select Disk > " \
              --height=40% \
              --border \
              --preview 'lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT {}'
    )

    if [[ -z "$_DISK" ]]; then
        whiptail --msgbox "No disk selected!" 8 40
        select_install_disk
    else
        _DISK=$(echo "$_DISK" | awk '{print $1}')
    fi
}

get_disk_password() {
    _LUKS_PASSWORD=$(whiptail --nocancel --passwordbox "Enter the password for disk encryption (LUKS)." 10 60 3>&1 1>&2 2>&3 3>&1)
    _LUKS_PASSWORD_CONFIRM=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)

    while ! [ "$_LUKS_PASSWORD" = "$_LUKS_PASSWORD_CONFIRM" ]; do
        _LUKS_PASSWORD=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        _LUKS_PASSWORD_CONFIRM=$(whiptail --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
}

ask_hibernation() {
    if whiptail --title "Hibernation" \
                --yesno "Do you want to enable hibernation?" 10 60 \
                --yes-button "Yes" \
                --no-button "No" \
                --defaultno
    then
        _HIBERNATION="true"
    else
        _HIBERNATION="false"
    fi
}

ask_cpu_drivers() {
    if whiptail --title "CPU Selection" \
                --yesno "Select your CPU vendor:" 10 60 \
                --yes-button "Intel" \
                --no-button "AMD"
    then
        _CPU_DRIVERS="intel"
    else
        _CPU_DRIVERS="amd"
    fi
}

ask_gpu_drivers() {
    if whiptail --title "GPU Selection" \
                --yesno "Select your GPU vendor:" 10 60 \
                --yes-button "NVIDIA" \
                --no-button "AMD"
    then
        _GPU_DRIVERS="nvidia"
    else
        _GPU_DRIVERS="amd"
    fi
}

# TODO: propper messages?
confirm_install() {
    whiptail --title "Let's get this party started!" \
             --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 \
             --yes-button "Let's go!" \
             --no-button "No, nevermind!" \
    || {
        clear
        exit 1
    }
}

finalize() {
    whiptail --title "Finished !" \
             --yesno "If the script miraculously got this far, everything should be installed and set-up." 10 60 \
             --yes-button "Reboot now" \
             --no-button "Reboot later" \
    && umount -R /mnt \
    && sudo reboot
}


summary_screen() {
    clear

    summary=$(cat <<EOF
User:        $_USERNAME
Hostname:    $_HOSTNAME
Keyboard:    $_KEYBOARD
Timezone:    $_TIMEZONE

Disk:        $_DISK
Hibernation: $_HIBERNATION

CPU Drivers: $_CPU_DRIVERS
GPU Drivers: $_GPU_DRIVERS
EOF
)

    whiptail --title "Installation Summary" \
        --yesno "$summary\n\nProceed with installation?" 20 70

    if [[ $? -eq 0 ]]; then
        echo "confirm"
        return
    fi

    choice=$(whiptail --title "Modify Setup" \
        --menu "What would you like to do?" 15 60 3 \
        1 "Redo configuration" \
        2 "Exit installer" \
        3>&1 1>&2 2>&3)

    case "$choice" in
        1) return 2 ;;  # redo
        2) return 1 ;;  # exit
        *) return 1 ;;
    esac
}