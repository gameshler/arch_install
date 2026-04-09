#!/bin/sh -e

. "$COMMON_SCRIPT"

installVsCode() {
    if ! command_exists com.visualstudio.code && ! command_exists code; then
        install_packages --aur visual-studio-code-bin
    else
        printf "%b\n" "VS Code is already installed."
    fi
}
installVsCode
