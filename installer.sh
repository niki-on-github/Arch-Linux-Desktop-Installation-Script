#!/bin/bash
# Description: Simple Arch Packages Installer Script


DOTFILES_BARE_REPO="http://10.0.0.80:3000/root/My-Dotfiles.git"

LANG="de_DE.UTF-8"
KEYMAP="de-latin1"
X11_KEYMAP="de pc105"


usage() {
    cat <<EOF
'`basename $0`' This script autoinstalls and configures a fully-functioning and minimal Arch Linux environment.


Dependecies: - git
             - sudo
             - dialog


Usage: $0 -d [URL]
       $0 -h


The following specific options are supported:

  -d none   installation without dotfiles
  -d [URL]  set a custom dotfiles repository URL
  -h        display this help


EOF
    exit ${1-0}
}

error() {
    removeTmpSudoInstallPermission ; clear ; echo -e "ERROR:\n$1" ; exit 1
}

rootCheck() {
    [ "$EUID" -ne 0 ] && error "Please run script with sudo"
}

installDependecies() {
    which sudo >/dev/null 2>&1 || pacman --noconfirm --needed -Sy "sudo" >/dev/null 2>&1
    which dialog >/dev/null 2>&1 || pacman --noconfirm --needed -Sy "dialog" >/dev/null 2>&1
}

getUser() {
    users=( )
    for user in $( cat /etc/passwd | grep /home/ | cut -d ":" -f1 ); do
        # do username contains space?
        grep " " <<< "$user" >/dev/null 2>&1 || users+=( "$user" "/home/$user" )
    done
    users+=( "CreateNewUser" "/home/???" )
    username=$(dialog --no-cancel --menu "Select User" 15 60 10 ${users[@]} 3>&1 1>&2 2>&3 3>&1)
    [ -z "$username" ] && error "user not found"
    [ ! "CreateNewUser" = "$username" ] && return

    # Prompts user for new username an password.
    local name=$(dialog --inputbox "Enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
    while ! grep "^[a-z_][a-z0-9_-]*$" <<< "$name" >/dev/null 2>&1 || (id -u "$name" >/dev/null) 2>&1; do
        local name=$(dialog --no-cancel --inputbox "Username not valid. Give a not existing username with only lowercase letters" 10 60 3>&1 1>&2 2>&3 3>&1)
    done

    local pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
    local pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    while ! [ "$pass1" = "$pass2" ]; do
        unset pass2
        local pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        local pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done

    dialog --infobox "Adding user \"$name\"..." 4 50
    useradd -g users -G wheel,audio,video -m -s /bin/bash $name
    sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
    echo "$name:$pass1" | chpasswd
    unset pass1 pass2

    username="$name"
}

# Allow user to run sudo without password (required for AUR programs that must be installed in a fakeroot environment)
addTmpSudoInstallPermission() {
    [ ! -f /etc/sudoers ] && error "sudo is not configured"
    [ -z "$(sudo -u $username groups | grep "wheel")" ] && error "user \"$username\" is not in wheel group"
    grep "^%wheel ALL=(ALL) NOPASSWD: ALL" /etc/sudoers >/dev/null 2>&1 && return
    grep "^%wheel ALL=(ALL) ALL" /etc/sudoers >/dev/null 2>&1 && sed -i 's/^%wheel ALL=(ALL) ALL/%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers && return
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}

removeTmpSudoInstallPermission() {
    sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers
}

welcomeMsg() {
    dialog --title "Welcome" --yes-label "Let's go" --no-label "exit" --yesno "Welcome to Arch DE/WM Installation\\n\\nThis script will automatically install a fully-featured Linux desktop" 10 60 || { clear; exit; }
}

refreshKeys() {
    dialog --infobox "Refreshing Arch Keyring ..." 4 40
    pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1 || error "Refreshing Arch Keyring failed"
}

repoInstall() {
    dialog --title "Installation ($n of $totalPKGs)" --infobox "Installing \`$1\` from the Repository \\n> $2" 5 70
    pacman --noconfirm --needed -S "$1" >> /tmp/install.log 2>&1 || error "Installation of $1 failed\n\nerror trace: \n$(tail -n 3 /tmp/install.log)"
}

runCommands() {
    [ -z "$1" ] && return
    IFS=';' # set before read -a
    read -a commdandArray <<< "$1"
    for instruction in "${commdandArray[@]}"; do
        instruction=$(echo $instruction | sed "s/\$username/$username/g")
        tryCommand="false"
        echo "$instruction" | grep "^try " >/dev/null 2>&1 && tryCommand="true"
        instruction=$(echo $instruction | sed "s/^try //g")
        echo "Run (try=$tryCommand): $instruction" >> /tmp/install.log
        eval "$instruction" >> /tmp/install.log 2>&1
        [ $? -ne 0 ] && [ "$tryCommand" = "false" ] && error "RunPostCommand: $instruction failed"
    done
    unset IFS
}

gitInstall() {
    pacman --noconfirm --needed -S cmake git >> /tmp/install.log 2>&1
    dir=$(sudo -u $username mktemp -d)
    dialog --title "Installation ($n of $totalPKGs)" --infobox "Installing \`$(basename "$1")\` via git \\n> $3" 5 70
    sudo -u $username git clone --recursive "$1" "$dir" >> /tmp/install.log 2>&1 || error "Installation of GIT package $1 failed"
    cd "$dir" || error "Installation of GIT package $1 failed"
    [ -z "$(ls -A)" ] && error "Installation of GIT package $1 failed"
    runCommands "$2"
    cd /tmp
}

aurInstall() {
    which yay >/dev/null 2>&1 || gitInstall "https://aur.archlinux.org/yay.git" "sudo -u $username makepkg --noconfirm -si" "yay is a AUR helper written in go"
    dialog --title "Installation ($n of $totalPKGs)" --infobox "Installing \`$1\` from the AUR \\n> $2" 5 70
    pacman -Qqm | grep "^$1$" >/dev/null 2>&1 && return # is the package already installed?
    sudo -u $username yay --answerdiff N --answerclean N --noconfirm --needed --noredownload --norebuild --aur --useask -S "$1" >> /tmp/install.log 2>&1 || error "Installation of AUR package $1 failed\n\nerror trace: \n$(tail -n 3 /tmp/install.log)"
}

pipInstall() {
    dialog --title "Installation ($n of $totalPKGs)" --infobox "Installing the Python package \`$1\` via pip \\n> $2" 5 70
    command -v pip || pacman --noconfirm --needed -S python-pip >> /tmp/install.log 2>&1
    yes | pip install "$1" >> /tmp/install.log 2>&1 || error "Installation of Python package $1 failed\n\nerror trace: \n$(tail -n 3 /tmp/install.log)"
}

cmdInstall() {
    dialog --title "Installation ($n of $totalPKGs)" --infobox "Installing package \`$1\` with Commands \\n> $3" 5 70
    runCommands "$2"
}

installPackages() {
    [ -f $1 ] || error "pkg list $1 not found"
    [ -d ./default ] || error "directory not found: \"./default\""
    [ -z "$(ls -A ./default | grep ".csv$")" ] && "default csv files not exists"
    local workingDirectory=$pwd
    cat $1 | sed '/^#/d' > /tmp/pkg.csv

    local defaultFiles=()
    mapfile -t defaultFiles <<< "$(ls -A ./default | grep ".csv$")"

    local items=() && n=$((0))
    for file in "${defaultFiles[@]}"; do
        # do file contains space?
        if ! grep " " <<< "$file" >/dev/null 2>&1; then
            items+=( "$n" "./default/$file" )
        fi
        n=$((n+1)) # foreach element n++ (required to map selection to correct element)
    done

    local selection=$(dialog --no-cancel --menu "Select System Type:" 15 60 10 ${items[@]} 3>&1 1>&2 2>&3 3>&1) && clear
    cat ./default/${defaultFiles[$selection]} | sed '/^#/d' > /tmp/default.csv
    unset selection && unset items

    local items=( )
    while IFS=, read -r gid tag program preCommands postCommands comment; do
        [ -z "$gid" ] && continue
        # new tag?
        if [ -z "$(grep "$gid" <<< "${items[@]}")" ]; then
            # tag not in defaults.csv?
            if [ -z "$(grep "^$gid" /tmp/default.csv)" ]; then
                items+=( "$gid" "optinal" "off" )
            else
                items+=( "$gid" "default" "on" )
            fi
        fi
    done < /tmp/pkg.csv
    unset IFS

    local selections=$(dialog --no-cancel --checklist "Select Packages:" 15 60 10 ${items[@]} 3>&1 1>&2 2>&3 3>&1) && clear

    [ -f /tmp/pkg_filtered.csv ] && rm -f /tmp/pkg_filtered.csv >/dev/null 2>&1
    while IFS=, read -r gid tag program preCommands postCommands comment; do
        [ -z "$tag" ] && continue
        [ -z "$(grep " $gid " <<< " $selections ")" ] && echo "Filter $program" >> /tmp/install.log && continue
        echo "$gid,$tag,$program,$preCommands,$postCommands,$comment" >> /tmp/pkg_filtered.csv
    done < /tmp/pkg.csv
    unset IFS

    refreshKeys
    systemUpdate "fix pkg confilicts for outdated systems"

    [ ! -f /tmp/pkg_filtered.csv ] && return
    totalPKGs=$(wc -l < /tmp/pkg_filtered.csv)
    n=$((0))
    while IFS=, read -r gid tag program preCommands postCommands comment; do
        n=$((n+1))
        [ -z "$comment" ] && error "Broken Entry in line $n (/tmp/pkg_filtered.csv)"
        echo "$preCommands" | grep "^\".*\"$" >/dev/null 2>&1 && preCommands="$(echo "$preCommands" | sed "s/\(^\"\|\"$\)//g")"
        echo "$postCommands" | grep "^\".*\"$" >/dev/null 2>&1 && postCommands="$(echo "$postCommands" | sed "s/\(^\"\|\"$\)//g")"
        echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        case "$tag" in
            "A") runCommands "$preCommands" && aurInstall "$program" "$comment" && runCommands "$postCommands" ;;
            "P") runCommands "$preCommands" && pipInstall "$program" "$comment" && runCommands "$postCommands" ;;
            "R") runCommands "$preCommands" && repoInstall "$program" "$comment" && runCommands "$postCommands" ;;
            "G") runCommands "$preCommands" && gitInstall "$program" "$postCommands" "$comment" ;;
            "C") runCommands "$preCommands" && cmdInstall "$program" "$postCommands" "$comment" ;;
            *) error "Unknown Tag in line $n (/tmp/pkg_filtered.csv)" ;;
        esac
    done < /tmp/pkg_filtered.csv
    unset IFS

    cd $workingDirectory
}

installDotfiles() {
    [ -z "$DOTFILES_BARE_REPO" ] && return
    [ "$DOTFILES_BARE_REPO" = "none" ] && return
    [ "$DOTFILES_BARE_REPO" = "None" ] && return
    [ -d /home/$username/.dotfiles ] && rm -rf /home/$username/.dotfiles

    dialog --infobox "Downloading and installing dotfiles ..." 4 60
    pacman --noconfirm --needed -S cmake git >> /tmp/install.log 2>&1  # install toolchain

    local workingDirectory=$pwd

    clear && sudo -u "$username" git clone --recursive --remote --bare "$DOTFILES_BARE_REPO" "/home/$username/.dotfiles" && cd /home/$username || error "Downloading dotfiles failed"

    branches=$(sudo -u "$username" git --git-dir=/home/$username/.dotfiles --work-tree=/home/$username branch -l | sed 's/\* //g' | sed 's/^ *//g' | awk '{print $1 " " $2}')
    if [ "$(echo "$branches" | wc -l)" = "1" ] ; then
        branch="$(echo $branches | cut -d ' ' -f1)"
    else
        branch=$(dialog --no-cancel --menu "Select Branch" 15 60 10 $branches 3>&1 1>&2 2>&3 3>&1)
    fi

    dialog --infobox "Installing dotfiles ..." 4 60
    [ -z "$branch" ] && branch="master"
    sudo -u "$username" git --git-dir=/home/$username/.dotfiles --work-tree=/home/$username checkout -f $branch
    sudo -u "$username" git --git-dir=/home/$username/.dotfiles --work-tree=/home/$username config --local status.showUntrackedFiles no

    if [ -d /home/$username/.config/dmenu/src ]; then
        dialog --infobox "Install dmenu from dotfiles" 4 60
        pacman --noconfirm -Rdd dmenu >/dev/null 2>&1
        cd /home/$username/.config/dmenu/src && make clean install >> /tmp/install.log 2>&1
    fi

    if [ -d /home/$username/.config/dwm/src ]; then
        dialog --infobox "Install dwm from dotfiles" 4 60
        pacman --noconfirm -Rdd dwm >/dev/null 2>&1
        cd /home/$username/.config/dwm/src && make clean install >> /tmp/install.log 2>&1
    fi

    cd $workingDirectory
}

# NOTE: Required to fix some pkg dependecies
systemUpdate() {
    dialog --title "Installation ($@)" --infobox "System Update ..." 5 70
    pacman --noconfirm -Syu >> /tmp/install.log 2>&1
}

setupLocale() {
    dialog --title "Installation ($@)" --infobox "Setup locale ..." 5 70
    localectl set-keymap $KEYMAP
    localectl set-x11-keymap $X11_KEYMAP
    localectl set-locale LANG=$LANG
}

# NOTE: The script does not work in the chroot environment, so it is included in this installer.
setup_snapper() {
   [ -d /.snapshots ] || return # continue only if we have a common btrfs structure
   [ -f /etc/snapper/configs/root ] && return
   dialog --title "Installation" --infobox "Setup snapper for btrfs snapshots" 5 70
   pacman --noconfirm --needed -S snapper snap-pac >> /tmp/install.log 2>&1 || error "Installation of snapper failed\n\nerror trace: \n$(tail -n 3 /tmp/install.log)"

   #NOTE: snapper required a not existing /.snapshots directory for setup!
   umount /.snapshots
   rm -r /.snapshots

   snapper -c root create-config /
   btrfs quota enable /

   # config path: /etc/snapper/configs/root
   snapper -c root set-config "TIMELINE_CREATE=no"
   snapper -c root set-config "NUMBER_CLEANUP=yes"
   snapper -c root set-config "NUMBER_MIN_AGE=0"
   snapper -c root set-config "NUMBER_LIMIT=10"
   snapper -c root set-config "NUMBER_LIMIT_IMPORTANT=3"

   systemctl enable snapper-cleanup.timer

   #NOTE: we delete the snapshots directory from snapper and use our own btrfs subvolume
   btrfs sub delete /.snapshots
   mkdir /.snapshots
   mount -a # mount .snapshots from fstab
}

finalize() {
    dialog --title "All done!" --msgbox "Congrats! There were no errors, the script completed successfully and all the programs and configuration files should be in place." 12 80
    clear
}


#####################################################################
# MAIN
#####################################################################

while getopts ":d:h:" arg; do
  case $arg in
    d) DOTFILES_BARE_REPO=$OPTARG ;;
    h) usage 0 ;;
  esac
done

rootCheck
installDependecies
welcomeMsg
getUser
addTmpSudoInstallPermission
installPackages "./pkg.csv"
installDotfiles
setupLocale
systemUpdate  "fix pkg dependecies"
setup_snapper
removeTmpSudoInstallPermission
finalize
