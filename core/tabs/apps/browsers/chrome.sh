#!/bin/sh -e

. "$COMMON_SCRIPT"

installChrome() {
    if ! command_exists google-chrome; then
        install_packages yay google-chrome
    else
        printf "%b\n" "Google Chrome Browser is already installed."
    fi
}

checkAurHelper
installChrome
