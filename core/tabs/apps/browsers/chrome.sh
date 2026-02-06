#!/bin/sh -e

. "$COMMON_SCRIPT"

installChrome() {
    if ! command_exists google-chrome; then
        printf "%b\n" "Installing Google Chrome..."
        case "$PACKAGER" in
        pacman)
            "$helper" -S --needed --noconfirm google-chrome
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
    else
        printf "%b\n" "Google Chrome Browser is already installed."
    fi
}

checkEnv
installChrome

