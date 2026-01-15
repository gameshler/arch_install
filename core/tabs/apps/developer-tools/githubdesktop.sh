#!/bin/sh -e

. "$COMMON_SCRIPT" 

installGithubDesktop() {
    if ! command_exists github-desktop; then
        printf "%b\n" "Installing Github Desktop..."
        case "$PACKAGER" in
            pacman)
                "$helper" -S --needed --noconfirm github-desktop-bin
                ;;
            *)
                printf "%b\n" "Unsupported package manager: ""$PACKAGER"
                exit 1
                ;;
        esac
    else
        printf "%b\n" "Github Desktop is already installed."
    fi
}

checkAurHelper
installGithubDesktop