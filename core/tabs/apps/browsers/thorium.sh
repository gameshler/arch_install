#!/bin/sh -e

. "$COMMON_SCRIPT" 

installThrorium() {
    if ! command_exists thorium-browser; then
        printf "%b\n" "Installing Thorium Browser..."
        case "$PACKAGER" in
            pacman)
                "$helper" -S --needed --noconfirm thorium-browser-bin
                ;;
            *)
                printf "%b\n" "Unsupported package manager: ""$PACKAGER"
                exit 1
                ;;
        esac
    else
        printf "%b\n" "Thorium Browser is already installed."
    fi
}

checkAurHelper
installThrorium