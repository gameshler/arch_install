#!/bin/sh -e

. "$COMMON_SCRIPT"

install_cursor() {
    if ! command_exists cursor; then
        printf "%b\n" "Installing Cursor..."

        install_packages --aur cursor-bin
    else
        printf "%b\n" "Cursor is already installed."
    fi
}
install_cursor
