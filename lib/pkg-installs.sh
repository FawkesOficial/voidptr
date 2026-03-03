#!/usr/bin/env bash


install_cmd() {
    sudo xbps-install -Syu -R "$VOID_REPO" "$@" || error "error installing $@." # >/dev/null 2>&1
}

# [TODO]: setup custom package installations here
custom_pkgs() {
    if [[ "$1" != custom_* ]]; then
        error "$1 is not a custom package"
    fi

    pkg="${1#custom_}"
    case "$pkg" in
        # https://github.com/kkrruumm/void-install-script/blob/main/modules/cpu-ucode
        cpu|cpu_drivers|cpu_ucode)
            case "$_CPU_DRIVERS" in
                intel)
                    install_cmd void-repo-nonfree
                    install_cmd intel-ucode
                    xbps-reconfigure -f linux"$(find /boot -name vmlinuz\* | tr -d "/boot/vmlinuz-" | cut -f1,2 -d".")"
                ;;
                amd)
                    # this package should already be installed as a dep. of linux-base, but just incase something changes:
                    install_cmd linux-firmware-amd
                ;;
                *)
                    error "unsuported \"$_CPU_DRIVERS\" CPU drivers"
                ;;
            esac
        ;;
        # https://github.com/kkrruumm/void-install-script/blob/main/setup/desktop
        gpu|gpu_drivers)
            case "$_GPU_DRIVERS" in
                amd)
                    install_cmd mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau
                ;;
                nvidia)
                    install_cmd void-repo-nonfree
                    install_cmd nvidia # nvidia-utils?

                    # enable mode setting for wayland compositors
                    # this default should change to drm enabled with more recent nvidia drivers, expect this to be removed in the future.
                    set_kernel_param "nvidia_drm.modeset=1"
                ;;
                nvidia-nouveau)
                    install_cmd mesa-dri mesa-nouveau-dri
                ;;
                intel)
                    install_cmd mesa-dri vulkan-loader mesa-vulkan-intel intel-video-accel
                ;;
                *)
                    error "unsuported \"$_GPU_DRIVERS\" GPU drivers"
                ;;
            esac
        ;;
        wifi|wifi_drivers)
            # [NOTE]: untested
            install_cmd void-repo-nonfree
            install_cmd broadcom-wl-dkms dkms
        ;;
        bluetooth|bluetooth_drivers|bt)
            # [NOTE]: untested
            error "NOT IMPLEMENTED YET: bluetooth_drivers"
            install_cmd bluez bluez-runit bluez-utils
        ;;
        # virtual-machines)
        #     install_cmd virt-manager qemu-base libvirt bridge-utils >/dev/null 2>&1
        # ;;
        # discord|vesktop)
        #     install_cmd discord betterdiscordctl pywal-discord-git >/dev/null 2>&1
        #     sudo -n -u "$name" betterdiscordctl install >/dev/null 2>&1 || error "An error occurred while installing BetterDiscord."
        #     sudo -n -u "$name" pywal-discord >/dev/null 2>&1 || error "An error occurred while installing the pywal theme in BetterDiscord."
        # ;;
        # obs|obs-studio)
        #     install_cmd obs-studio obs-v4l2sink v4l-utils v4l2loopback-dkms >/dev/null 2>&1
        # ;;
        # wireshark)
        #     install_cmd wireshark-cli wireshark-qt >/dev/null 2>&1
        # ;;
        # razer) 
        #     install_cmd openrazer-daemon openrazer-driver-dkms openrazer-meta polychromatic >/dev/null 2>&1
        #     gpasswd -a $name plugdev # Required by openrazer
        # ;;
        # java)
        #     install_cmd jre-openjdk jre-openjdk-headless jdk-openjdk jre17-openjdk jre17-openjdk-headless jdk17-openjdk >/dev/null 2>&1
        # ;;
        # nodejs)
        #     install_cmd nodejs npm >/dev/null 2>&1
        # ;;
        *)
            error "no custom install is set up for $pkg"
        ;;
    esac
}

install_pkg() {
    for pkg in "$@"; do
        case "$pkg" in
            custom_*) custom_pkgs "$pkg" ;;
            *)        install_cmd "$pkg" ;;
        esac
    done
}
