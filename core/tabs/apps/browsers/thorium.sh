#!/bin/sh -e

. "$COMMON_SCRIPT"

installThrorium() {
    if ! command_exists thorium-browser; then
        install_packages yay thorium-browser-bin
    else
        printf "%b\n" "Thorium Browser is already installed."
    fi
}
checkAurHelper
installThrorium
