#!/bin/sh -e

. "$COMMON_SCRIPT" 

installLibreWolf() {
    if ! command_exists firefox; then
        printf "%b\n" "Installing Mozilla Firefox..."
        case "$PACKAGER" in
            pacman)
                sudo "$PACKAGER" -S --needed --noconfirm librewolf-bin
                ;;
            *)
                printf "%b\n" "Unsupported package manager: ""$PACKAGER"""
                exit 1
                ;;
        esac
    else
        printf "%b\n" "LibreWolf Browser is already installed."
    fi
}

installLibreWolf