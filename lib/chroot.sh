#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="/bootstrap-scripts"
LIB_DIR="$SCRIPT_DIR/lib"

source "$SCRIPT_DIR/config.cfg"
source "$SCRIPT_DIR/user-options.env"
source "$LIB_DIR/pkg-installs.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"


# set XBPS mirror
install_pkg xbps xmirror  >/dev/null 2>&1 || error "failed to install dependencies."
xmirror -s "$VOID_REPO"


# [TODO]: install the rest of packages & drivers
infobox "Installing drivers..."
install_pkg custom_cpu_drivers >/dev/null 2>&1
install_pkg custom_gpu_drivers >/dev/null 2>&1

install_pkg zsh >/dev/null 2>&1 # [TODO]: temporary


# setup hostname and /etc/hosts
echo "$_HOSTNAME" > /etc/hostname

echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    $_HOSTNAME.localdomain    $_HOSTNAME" >> /etc/hosts


# configure locales
infobox "Configuring locales..."

ln -sf "/usr/share/zoneinfo/$_TIMEZONE" /etc/localtime
hwclock --systohc
install_pkg chrony
enable_service chronyd

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
sed -i "s/^#\?KEYMAP=.*/KEYMAP=\"$_KEYBOARD\"/" /etc/rc.conf
xbps-reconfigure -f glibc-locales >/dev/null 2>&1


# note: setting the root password the same as the user password
printf 'root:%s\n' "$_USER_PASSWORD" | chpasswd -c SHA512


# configure grub
infobox "Configuring Grub..."

echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
# echo 'GRUB_DISABLE_OS_PROBER="false"' >> /etc/default/grub

LUKS_UUID=$(blkid -o value -s UUID "$LUKS_PART")

# [TODO]: rd.luks.allow-discards ? check the entire "LUKS on an SSD story"
set_kernel_param "rd.lvm.vg=vg0 rd.luks.uuid=$LUKS_UUID"

grub-install --target=x86_64-efi --bootloader-id=grub_uefi --efi-directory=/boot/efi >/dev/null 2>&1 || error "error installing grub"
grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || error "error installing grub"


# LUKS key setup
infobox "Creating LUKS key..."

# dd bs=515 count=4 if=/dev/random of=/boot/keyfile.bin # [TODO] check if this is better for security
dd bs=1 count=64 if=/dev/urandom of=/boot/volume.key
printf "%s" "$_LUKS_PASSWORD" | \
cryptsetup luksAddKey \
    --batch-mode \
    --key-file - \
    "$LUKS_PART" \
    /boot/volume.key
chmod 000 /boot/volume.key
chmod -R g-rwx,o-rwx /boot
echo "cryptroot $LUKS_PART /boot/volume.key luks" >> /etc/crypttab
echo 'install_items+=" /boot/volume.key /etc/crypttab "' >> /etc/dracut.conf.d/10-crypt.conf


# enable hibernation
if [ "$_HIBERNATION" = "true" ]; then
    echo 'add_dracutmodules+=" resume "' > /etc/dracut.conf.d/resume.conf

    set_kernel_param "resume=/dev/mapper/vg0-swap"
fi


# enable the NetworkManager service
infobox "Configuring Networking..."

enable_service dbus
enable_service NetworkManager
sleep 5
# [TODO]: check if this is really fixed now
set_dns_after_boot() {
    mkdir -p "/etc/sv/firstboot"

    cat > "/etc/sv/firstboot/run" << 'EOF'
#!/bin/bash

echo "[firstboot] Starting first boot configuration..."

# ==== COMMANDS ====

echo "nameserver 9.9.9.9" >> /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# ==== END OF COMMANDS ====

echo "[firstboot] Cleaning up..."

# remove service so it only runs once
rm -f /etc/runit/runsvdir/default/firstboot
rm -rf /etc/sv/firstboot

echo "[firstboot] Done."
EOF
    chmod +x "/etc/sv/firstboot/run"

    ln -sf "/etc/sv/firstboot" /etc/runit/runsvdir/default/
}
set_dns_after_boot


# [TODO]: is this still required for anything?
# dbus-uuidgen > /var/lib/dbus/machine-id


# setup user account
infobox "Adding user \"$_USERNAME\"..."

useradd -m -s "$USER_SHELL" "$_USERNAME"
# [TODO]: figure out if we still require some of the following groups:
# - [ ] storage
# - [x] power
# - [ ] tty
# - [ ] audio
# - [ ] video
# - [x] network
# - [ ] kvm
# - [ ] input
# - [ ] plugdev
groupadd power
usermod -aG wheel,power,network "$_USERNAME"
# https://github.com/gudrak1/void-mklive/commit/e8f015ce5570e6afc413f91f4cfcd5e8b2b5864c
printf '%s:%s\n' "$_USERNAME" "$_USER_PASSWORD" | chpasswd -c SHA512

# setup autologin
sed -i "s/GETTY_ARGS=.*/GETTY_ARGS=\"--noclear --autologin $_USERNAME\"/g" /etc/runit/runsvdir/default/agetty-tty1/conf


# configure sudoers
configure_sudoers() {
    cp -f /etc/sudoers /etc/sudoers.bak
    
    # allow members of the "wheel" group to run commands as root
    echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

    # allow members of the "power" group to run poweroff, reboot and shutdown without a password
    echo "%power ALL=NOPASSWD: /usr/bin/poweroff, /usr/bin/reboot, /usr/bin/shutdown, /etc/runit/stopit" >> /etc/sudoers

    # allows running sudo commands without a password within a certain timeout (default is 5mins)
    echo "Defaults !tty_tickets" >> /etc/sudoers 

    # makes it so that sudo never times-out for waiting for the password
    echo "Defaults passwd_timeout=0" >> /etc/sudoers 

    # never show the first time usage message (this was blocking the script)
    echo "Defaults lecture = never" >> /etc/sudoers
    
    visudo -c >/dev/null 2>&1 || cp -f /etc/sudoers.bak /etc/sudoers
}
configure_sudoers || error "error while patching the sudoers file"


infobox "Installing dotfiles..."

# enable root and user to temporarily run any command as any user without password prompt
temp_sudoers grant "$_USERNAME" || error "error while patching the sudoers file (tempsudoers)"

# install dotfiles and other user configs
# note: see `rice.sh` for more details on
#       the rest of the ricing process
runuser -u "$_USERNAME" -- "$LIB_DIR/rice.sh" || error "error installing user configs"

# disable tempsudoers
temp_sudoers revert "$_USERNAME" || error "error while patching the sudoers file (tempsudoers)"


# ensure an initramfs is generated and all installed packages are configured properly
xbps-reconfigure -fa