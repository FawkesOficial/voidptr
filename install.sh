#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$SCRIPT_DIR/config.cfg"
source "$LIB_DIR/pkg-installs.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"
source "$LIB_DIR/install-system.sh"


run_setup_wizard() {
    while true; do
        clear

        select_keyboard     || error "user exited."
        select_timezone     || error "user exited."

        get_username        || error "user exited."
        get_password        || error "user exited."
        get_hostname        || error "user exited."

        ask_cpu_drivers     || error "user exited."
        ask_gpu_drivers     || error "user exited."
        ask_hibernation     || error "user exited."

        select_install_disk || error "user exited."
        get_disk_password   || error "user exited."

        summary_screen
        case "$?" in
            0) return 0 ;;      # confirm
            2) continue ;;      # redo
            1) return 1 ;;      # exit
        esac
    done
}


main() {
    # - [ 0. Sanity checks ] -
    require_root        || error "please run this script as root."
    is_live_environment || error "this script must be run as root in a void linux live environment."
    check_efi           || error "the system was not booted in EFI mode."
    check_internet      || error "the system does not have internet access."

    # - [ 1. User Options Wizard ] -
    print_banner        && sleep 3
    welcome_msg         || error "user exited."

    run_setup_wizard    || error "user exited."

    confirm_install     || error "user exited."

    # - [ 2. Installation ] -
    prepare_disk
    install_base_system
    save_options        || error "user exited."
    # note: see `chroot.sh` for more details on
    #       the rest of the installation process
    chroot_install

    # - [ 3. Finish ] -
    finalize
}

main "$@"