#!/bin/sh -e

. "$COMMON_SCRIPT"

installLibreWolf() {
    if ! command_exists io.gitlab.librewolf-community && ! command_exists librewolf; then
        install_packages "$helper" librewolf-bin
    else
        printf "%b\n" "LibreWolf Browser is already installed."
    fi
}

checkAurHelper
installLibreWolf
