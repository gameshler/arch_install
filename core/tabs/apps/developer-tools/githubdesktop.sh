#!/bin/sh -e

. "$COMMON_SCRIPT"

installGithubDesktop() {
    if ! command_exists github-desktop; then
        install_packages "$helper" github-desktop-bin
    else
        printf "%b\n" "Github Desktop is already installed."
    fi
}
checkAurHelper
installGithubDesktop
