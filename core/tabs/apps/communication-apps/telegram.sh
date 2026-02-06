#!/bin/sh -e

. "$COMMON_SCRIPT"

installTelegram() {
    if ! command_exists telegram-desktop; then
        printf "%b\n" "Installing Telegram..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm telegram-desktop
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
    else
        printf "%b\n" "Telegram is already installed."
    fi
}
checkEnv
installTelegram

