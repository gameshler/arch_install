#!/bin/sh -e

. "$COMMON_SCRIPT"

installTelegram() {
    if ! command_exists telegram-desktop; then
        install_packages telegram-desktop
    else
        printf "%b\n" "Telegram is already installed."
    fi
}

installTelegram
