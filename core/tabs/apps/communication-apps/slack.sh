#!/bin/sh -e

. "$COMMON_SCRIPT"

installSlack() {
    if ! command_exists com.slack.Slack && ! command_exists slack; then
        printf "%b\n" "Installing Slack..."
        case "$PACKAGER" in
        pacman)
            "$helper" -S --needed --noconfirm slack-desktop
            ;;
        *)
            checkFlatpak
            flatpak install -y flathub com.slack.Slack
            ;;
        esac
    else
        printf "%b\n" "Slack is already installed."
    fi
}
checkEnv
installSlack

