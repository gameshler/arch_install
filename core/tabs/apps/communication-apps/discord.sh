#!/bin/sh -e

. "$COMMON_SCRIPT"

installDiscord() {
    if ! command_exists com.discordapp.Discord && ! command_exists discord; then
        install_packages "$PACKAGER" discord
    else
        printf "%b\n" "Discord is already installed."
    fi
}

installDiscord
