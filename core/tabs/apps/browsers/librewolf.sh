#!/bin/sh -e

. "$COMMON_SCRIPT" 

installLibreWolf() {
    if ! command_exists thorium-browser; then
        printf "%b\n" "Installing Thorium Browser..."
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

checkAurHelper
installLibreWolf