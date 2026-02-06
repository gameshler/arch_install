#!/bin/sh -e

. "$COMMON_SCRIPT"

installVsCode() {
    if ! command_exists com.visualstudio.code && ! command_exists code; then
        printf "%b\n" "Installing VS Code..."
        case "$PACKAGER" in
        pacman)
            "$helper" -S --needed --noconfirm visual-studio-code-bin
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"""
            exit 1
            ;;
        esac
    else
        printf "%b\n" "VS Code is already installed."
    fi
}
checkEnv
installVsCode

