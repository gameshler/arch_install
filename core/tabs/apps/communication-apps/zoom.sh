#!/bin/sh -e

. "$COMMON_SCRIPT"

installZoom() {
    if ! command_exists us.zoom.Zoom && ! command_exists zoom; then
        printf "%b\n" "Installing Zoom..."
        case "$PACKAGER" in
        pacman)
            "$helper" -S --needed --noconfirm zoom
            ;;
        *)
            checkFlatpak
            flatpak install -y flathub us.zoom.Zoom
            ;;
        esac
    else
        printf "%b\n" "Zoom is already installed."
    fi
}
checkEnv
installZoom

