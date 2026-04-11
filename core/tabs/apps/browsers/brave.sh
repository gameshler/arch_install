#!/bin/sh -e

. "$COMMON_SCRIPT"

installBrave() {
    if ! command_exists com.brave.Browser && ! command_exists brave; then
        printf "%b\n" "Installing Brave..."
         install_packages --aur brave-bin
    else
        printf "%b\n" "Brave Browser is already installed."
    fi
}

installBrave
