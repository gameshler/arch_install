#!/bin/sh -e

. "$COMMON_SCRIPT"

installLibreWolf() {
    if ! command_exists io.gitlab.librewolf-community && ! command_exists librewolf; then
        printf "%b\n" "Installing LibreWolf Browser..."
        case "$PACKAGER" in
        pacman)
            "$helper" -S --needed --noconfirm librewolf-bin
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
    else
        printf "%b\n" "LibreWolf Browser is already installed."
    fi
}

checkEnv
installLibreWolf

