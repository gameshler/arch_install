#!/bin/sh -e

. "$COMMON_SCRIPT"

installGhostty() {
    if ! command_exists ghostty; then
        printf "%b\n" "Installing Ghostty..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm ghostty
            ;;

        *)
            printf "%b\n" "Unsupported package manager: ${PACKAGER}"
            exit 1
            ;;
        esac
    else
        printf "%b\n" "Ghostty is already installed."
    fi
}

setupGhosttyConfig() {
    printf "%b\n" "Copying ghostty config files..."
    if [ -d "${HOME}/.config/ghostty" ] && [ ! -d "${HOME}/.config/ghostty-bak" ]; then
        cp -r "${HOME}/.config/ghostty" "${HOME}/.config/ghostty-bak"
    fi
    mkdir -p "${HOME}/.config/ghostty/"
    curl -sSLo "${HOME}/.config/ghostty/config" "https://raw.githubusercontent.com/gameshler/dwm/main/config/ghostty/config"
    printf "%b\n" "Ghostty configuration files copied."
}

checkEnv
installGhostty
setupGhosttyConfig
