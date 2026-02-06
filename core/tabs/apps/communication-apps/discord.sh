#!/bin/sh -e

. "$COMMON_SCRIPT"

installDiscord() {
    if ! command_exists com.discordapp.Discord && ! command_exists discord; then
        printf "%b\n" "Installing Discord..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm discord
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
    else
        printf "%b\n" "Discord is already installed."
    fi
}
checkEnv
installDiscord

