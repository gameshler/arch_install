#!/bin/sh -e

. "$COMMON_SCRIPT"

installFirefox() {
    if ! command_exists firefox; then
        install_packages firefox
    else
        printf "%b\n" "Firefox Browser is already installed."
    fi
}

installFirefox
