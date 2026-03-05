```
                       ███      █████      ███     
                      ░░░      ░░███  ███ ░███  ███
 █████ █████  ██████  ████   ███████ ░░░█████████░ 
░░███ ░░███  ███░░███░░███  ███░░███   ░░░█████░   
 ░███  ░███ ░███ ░███ ░███ ░███ ░███    █████████  
 ░░███ ███  ░███ ░███ ░███ ░███ ░███  ███░░███░░███
  ░░█████   ░░██████  █████░░████████░░░  ░███ ░░░ 
   ░░░░░     ░░░░░░  ░░░░░  ░░░░░░░░      ░░░      
```
yet another opinionated linux distro; based on Void Linux

## installing

### 1. get yourself a Void Linux ISO
1. got to https://voidlinux.org/download/
2. choose `base` -> `live image glibc`
3. flash the ISO to your USB (or burn it to a DVD like an og) using your favorite ISO burner (`dd`, `balenaEtcher`, `rufus`, etc.)

### 2. run the bootstrap script
after booting into the live environment, run the following commands:
```bash
xbps-install -Syu xbps git
git clone https://github.com/FawkesOficial/voidptr.git
cd voidptr
bash install.sh
```
> note: never run any scripts from the internet without checking them first (including this one). some malicious haxors might be out to get you

## TODO

- WM - wayland + sway + waybar setup
- terminal - foot (or alacritty)
- shell - figure out what shell to use
- dotfiles - remake/redo github repo and start from "scratch"
- librewolf - fix/implement setup/config function
- session and seat management - `seatd` or `elogind`
- extra package install - define and install "extra" packages
- todo - go through `[TODO]` comments
- hibernation - test hibernation after moving to wayland/sway setup since the current xorg+dwm(+nvidia drivers) is unreliable
- fonts - setup font installs and packages in `config.cfg`
- readme - time the installation and add a section to the readme with an estimate