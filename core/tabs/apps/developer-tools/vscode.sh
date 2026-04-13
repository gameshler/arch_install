#!/bin/sh -e

. "$COMMON_SCRIPT"

install_vscode() {
    if ! command_exists com.visualstudio.code && ! command_exists code; then
        printf "%b\n" "Installing VSCode..."

        install_packages --aur visual-studio-code-bin
    else
        printf "%b\n" "VS Code is already installed."
    fi
}
install_vscode
