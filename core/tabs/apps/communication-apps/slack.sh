#!/bin/sh -e

. "$COMMON_SCRIPT"

installSlack() {
    if ! command_exists com.slack.Slack && ! command_exists slack; then
        printf "%b\n" "Installing Slack..."
        install_packages --aur slack-desktop || install_packages --flatpak com.slack.Slack
    else
        printf "%b\n" "Slack is already installed."
    fi
}
installSlack
