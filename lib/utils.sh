#!/usr/bin/env bash

error() {
    # log to stderr and exit with failure.
    printf "\n[bootstrap-script] ERROR: %s\n" "$1" >&2
    exit 1
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        return 1
    fi

    return 0
}


is_live_environment() {
    [ "$(hostname)" = "void-live" ] && return 0

    which void-installer >/dev/null 2>&1 && return 0

    # if none of the checks passed, assume it's not a live environment
    return 1
}

check_efi() {
    ls /sys/firmware/efi/efivars >/dev/null \
    || whiptail --title "EFI" \
                --yesno '"ls /sys/firmware/efi/efivars" didnt work. Are you sure you would like to proceed?' 15 60 \
                --defaultno \
    || exit 1
}

check_internet() {
    ping -q -c 1 -W 2 9.9.9.9 >/dev/null 2>&1
}

temp_sudoers() {
    username="$2"

    case "$1" in
    grant)
        cp -f /etc/sudoers /etc/sudoers.bak
        
        echo "root ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
        echo "$username ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
        
        visudo -c >/dev/null 2>&1 || cp -f /etc/sudoers.bak /etc/sudoers
        ;;
    revert)
        sed -i '/^root ALL=(ALL:ALL) NOPASSWD: ALL$/d' "/etc/sudoers"
        sed -i "/^$username ALL=(ALL:ALL) NOPASSWD: ALL$/d" "/etc/sudoers"

        echo "Sudoers file reverted to its original state."
        ;;
    *)
        echo "usage: $0 [grant|revert] <username>"
        exit 1
        ;;
    esac
}

# https://github.com/kkrruumm/void-install-script/blob/ea7a046dabd1d52f5aeb957813a3544c2a7d08b7/misc/libviss#L64-L83
set_kernel_param() {
    sed -i -e "s:loglevel=4:loglevel=4 $1:" /etc/default/grub || error "error setting kernel parameter"
}

save_options() {
    {
        echo "#!/bin/sh"

        for var in \
            _KEYBOARD \
            _USERNAME \
            _USER_PASSWORD \
            _HOSTNAME \
            _TIMEZONE \
            _DISK \
            _LUKS_PASSWORD \
            LUKS_PART \
            _HIBERNATION \
            _CPU_DRIVERS \
            _GPU_DRIVERS
        do
            eval "val=\${$var}"
            escaped=$(printf '%s' "$val" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/")
            printf '%s=%s\n' "$var" "$escaped"
        done
    } > "$SCRIPT_DIR/user-options.env"
}

enable_service() {
    for svc in "$@"; do
        sudo ln -sf /etc/sv/"$svc" /etc/runit/runsvdir/default/
    done
}