#!/usr/bin/env bash

command_exists() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
    return 0
}

checkPackageManager() {
    local managers=("$@")
    for pgm in "${managers[@]}"; do
        if command_exists "${pgm}"; then
            PACKAGER=${pgm}
            printf "%b\n" "Using ${pgm} as package manager"
            return
        fi
    done
    echo "No supported package manager found" >&2
    exit 1
}
checkAurHelper() {
    local helpers=("yay paru")

    for h in "${helpers[@]}"; do
        if command_exists "${h}"; then
            HELPER="${h}"
            printf "%b\n" "Using ${h} as Aur Helper"
            return
        fi
    done

    printf "%b\n" "No AUR helper found. Installing yay..."

    sudo "$PACKAGER" -S --needed --noconfirm base-devel git

    mkdir -p "$HOME/opt" && cd "$HOME/opt" || exit
    if [[ ! -d yay-bin ]]; then
        git clone https://aur.archlinux.org/yay-bin.git
    fi
    sudo chown -R "$USER":"$USER" ./yay-bin
    cd yay-bin && makepkg --noconfirm -si

}

checkFlatpak() {
    if ! command_exists flatpak; then
        printf "%b\n" "Installing Flatpak..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm flatpak
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
        printf "%b\n" "Adding Flathub remote..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        printf "%b\n" "Applications installed by Flatpak may not appear on your desktop until the user session is restarted..."
    else
        if ! flatpak remotes | grep -q "flathub"; then
            printf "%b\n" "Adding Flathub remote..."
            sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        else
            printf "%b\n" "Flatpak is installed"
        fi
    fi
}

install_packages() {
    local source=""

    # Detect if first arg is a source flag
    case "$1" in
    --official | --aur | --flatpak)
        source="$1"
        shift
        ;;
    esac

    # Default to official if not specified
    source="${source:---official}"

    case "$source" in
    --official)
        sudo pacman -S --needed --noconfirm "$@"
        ;;
    --aur)
        checkAurHelper
        "$HELPER" -S --needed --noconfirm "$@"
        ;;
    --flatpak)
        checkFlatpak
        flatpak install -y flathub "$@"
        ;;
    *)
        printf "%b\n" "Unsupported package manager: ""$source"
        exit 1

        ;;
    esac
}

check_init_manager() {
    local candidates="$1"
    local manager

    for manager in $candidates; do
        if command_exists "$manager"; then
            INIT_MANAGER="$manager"
            printf "%b\n" "Using ${manager} to interact with init system"
            return 0
        fi
    done

    printf "%b\n" "No supported init system found. Exiting."
    exit 1
}

checkPackageManager "pacman"
check_init_manager 'systemctl rc-service sv'
