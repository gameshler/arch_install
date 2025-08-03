#!/bin/sh -e

source "$COMMON_SCRIPT" 

installFirefox() {
    if ! command_exists firefox; then
        printf "%b\n" "Installing Mozilla Firefox..."
        case "$PACKAGER" in
            pacman)
                sudo "$PACKAGER" -S --needed --noconfirm firefox
                ;;
            *)
                printf "%b\n" "Unsupported package manager: "$PACKAGER""
                exit 1
                ;;
        esac
    else
        printf "%b\n" "Firefox Browser is already installed."
    fi
}

installFirefox