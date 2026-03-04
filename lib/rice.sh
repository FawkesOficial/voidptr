#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="/bootstrap-scripts"
LIB_DIR="$SCRIPT_DIR/lib"

source "$SCRIPT_DIR/config.cfg"
source "$SCRIPT_DIR/user-options.env"
source "$LIB_DIR/pkg-installs.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/ui.sh"


# install dependencies
install_pkg git base-devel || error "failed to install dependencies: git + base-devel"
install_pkg firefox || error "failed to install dependencies: firefox" # [TODO]: this isnt really a "dependency"
install_pkg nautilus || error "failed to install dependencies: nautilus" # [TODO]: this isnt really a "dependency"
install_pkg starship || error "failed to install dependencies: starship" # [TODO]: this isnt really a "dependency"
install_pkg xorg xinit libX11-devel libXft-devel libXinerama-devel freetype-devel harfbuzz-devel  || error "failed to install dependencies: suckless" # [TODO]: this isnt really a "dependency"


install_desktop() {
    
}


install_dotfiles() {
    # https://www.atlassian.com/git/tutorials/dotfiles

    # check if the dotifles repo has a branch with the name of the current hostname
    git ls-remote --heads "https://github.com/$DOTFILES_REPO.git" | grep -q "refs/heads/$(uname -n)" \
        && branch="$(uname -n)" \
        || branch="$DOTFILES_REPO_DEFAULT_BRANCH"

    # clone and install dotfiles
    git clone --bare "https://github.com/$DOTFILES_REPO.git" "$HOME/.config/dotfiles"
    git --git-dir="$HOME/.config/dotfiles" --work-tree="$HOME" config --local status.showUntrackedFiles no
    git --git-dir="$HOME/.config/dotfiles" --work-tree="$HOME" remote set-url origin git@github.com:$DOTFILES_REPO.git
    git --git-dir="$HOME/.config/dotfiles" --work-tree="$HOME" checkout -f "$branch"

    unset branch
}

install_suckless_software() {
    name=$(whoami)

    sudo mkdir -p "$SRC_PACKAGES_INSTALL_DIR"
    sudo chown -R "$name:$name" "$SRC_PACKAGES_INSTALL_DIR"

    cd "$SRC_PACKAGES_INSTALL_DIR"
    for suckless in dwm dmenu slstatus st; do
        sudo git clone https://github.com/FawkesOficial/$suckless.git
        sudo chown -R "$name:$name" "$suckless"
        cd "$suckless"
        make
        sudo make install
        cd ..
    done
    cd "$HOME"

    unset name
}

clean_bash_files() {
    rm "$HOME/.bashrc"       || error "error deleting .bash files"
    rm "$HOME/.bash_logout"  || error "error deleting .bash files"
    rm "$HOME/.bash_profile" || error "error deleting .bash files"
}

nautilus_dark_theme() {
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark || error "error setting Nautilus Dark Theme"
}

#
# note: currently untested and honestly not required for now
#
# installffaddons() {
#     addonlist="ublock-origin decentraleyes istilldontcareaboutcookies vim-vixen"
#     addontmp="$(mktemp -d)"
#     trap "rm -fr $addontmp" HUP INT QUIT TERM PWR EXIT
#     IFS=' '
#     sudo -n -u "$username" mkdir -p "$pdir/extensions/"
#     for addon in $addonlist; do
#         addonurl="$(curl --silent "https://addons.mozilla.org/en-US/firefox/addon/${addon}/" | grep -o 'https://addons.mozilla.org/firefox/downloads/file/[^"]*')"
#         file="${addonurl##*/}"
#         sudo -n -u "$username" curl -LOs "$addonurl" > "$addontmp/$file"
#         id="$(unzip -p "$file" manifest.json | grep "\"id\"")"
#         id="${id%\"*}"
#         id="${id##*\"}"
#         sudo -n -u "$username" mv "$file" "$pdir/extensions/$id.xpi"
#     done
# }

config_firefox() {
    browserdir="$HOME/.mozilla/firefox" # [TODO]: change this to librewolf
    profilesini="$browserdir/profiles.ini"

    # start firefox headless so it generates a profile
    firefox --headless &
    ff_pid=$!
    sleep 3
    profile="$(sed -n "/Default=.*.default-release/ s/.*=//p" "$profilesini")"
    pdir="$browserdir/$profile"

    # [ -d "$pdir" ] && installffaddons

    mkdir -p "$pdir/chrome"
    ln -s "$HOME/.config/firefox/userChrome.css" "$pdir/chrome"

    # Kill the now unnecessary firefox instance.
    kill -9 "$ff_pid" || error "error while killing the firefox process"
}


# [TODO]: take things out of functions?
main() {
    install_desktop
    install_dotfiles
    install_suckless_software # [TODO]: wayland setup in the future
    clean_bash_files
    nautilus_dark_theme
    # config_firefox # [TODO]: currently borked due to firefox not creating .mozilla dir
}

main "$@"