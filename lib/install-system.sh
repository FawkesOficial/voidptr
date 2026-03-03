#!/usr/bin/env bash

prepare_disk() {
    [ -n "${_DISK:-}" ] || error "\$_DISK not set"
    [ -b "$_DISK" ]     || error "$_DISK is not a block device"
    
    infobox "Setting up disk partitions and encryption..."

    # install some dependencies
    install_pkg parted bc >/dev/null 2>&1


    # - [ 0. Wipe the disk ] -
    wipefs -a "$_DISK"


    # - [ 1. Partition disk ] -
    parted -s "$_DISK" mklabel gpt

    # EFI boot partition
    EFI_START=1
    EFI_END="$((EFI_START + BOOT_PARTITION_SIZE_MB))"

    parted -s "$_DISK" mkpart ESP fat32 "${EFI_START}MiB" "${EFI_END}MiB"
    parted -s "$_DISK" set 1 esp on

    # single large partition for LUKS
    LUKS_START="$EFI_END"
    parted -s "$_DISK" mkpart primary ext4 "${LUKS_START}MiB" 100%

    # wait for kernel to recognize partitions
    partprobe "$_DISK"
    udevadm settle

    if echo "$_DISK" | grep -qE '[0-9]$'; then
        PART_SUFFIX="p"
    else
        PART_SUFFIX=""
    fi

    EFI_PART="${_DISK}${PART_SUFFIX}1"
    LUKS_PART="${_DISK}${PART_SUFFIX}2"


    # - [ 2. Setup LUKS container ] -
    printf "%s" "$_LUKS_PASSWORD" | \
    cryptsetup luksFormat \
        --type luks1 \
        --batch-mode \
        --key-file - \
        "$LUKS_PART"
    
    printf "%s" "$_LUKS_PASSWORD" | \
    cryptsetup open \
        --key-file - \
        "$LUKS_PART" cryptroot

    CRYPT_ROOT="/dev/mapper/cryptroot"


    # - [ 3. Setup LVM inside LUKS ] -
    pvcreate "$CRYPT_ROOT"
    vgcreate vg0 "$CRYPT_ROOT"

    RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)

    if [ "$_HIBERNATION" = "true" ]; then
        SWAP_SIZE_MB=$(echo "$RAM_MB * $SWAP_SIZE_FACTOR" | bc -l)
    else
        SWAP_SIZE_MB="$SWAP_DEFAULT_SIZE_MB"
    fi

    lvcreate --name swap -L "${SWAP_SIZE_MB}M" vg0
    lvcreate --name root -l 100%FREE vg0


    # - [ 4. Format volumes ] -
    mkfs.fat -F32 "$EFI_PART"
    fatlabel "$EFI_PART" "BOOT_EFI"

    mkswap /dev/vg0/swap

    mkfs.ext4 -F /dev/vg0/root -L ROOT


    # - [ 5. Mount partitions ] -
    mount  /dev/vg0/root /mnt
    swapon /dev/vg0/swap
    mount "$EFI_PART" --mkdir /mnt/boot/efi
}

install_base_system() {
    # - [ 1. Copy RSA keys ] -
    mkdir -p /mnt/var/db/xbps/keys
    cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

    # - [ 2. Install core packages ] -
    infobox "Installing Core Packages...\\n(This can take a couple of minutes)"
    
    # note: see config.cfg for package list
    XBPS_ARCH="$VOID_ARCH" xbps-install -Sy -r /mnt -R "$VOID_REPO" "${BASE_PACKAGES[@]}"

    # - [ 3. Generate fstab ] -
    xgenfstab -U /mnt > /mnt/etc/fstab
}

chroot_install() {
    # - [ 1. Copy over the bootstrap scripts to the new system ] -
    mkdir -p /mnt/bootstrap-scripts
    cp -r "$SCRIPT_DIR/"/. /mnt/bootstrap-scripts
    chmod +x /mnt/bootstrap-scripts/*.sh
    chmod +x /mnt/bootstrap-scripts/lib/*.sh

    # - [ 2. Run the `chroot.sh` script on the system ] -
    xchroot /mnt /bootstrap-scripts/lib/chroot.sh || error "an error occurred during the chroot script."

    # - [ 3. Cleanup ] -
    rm -rf /mnt/bootstrap-scripts >/dev/null 2>&1
}