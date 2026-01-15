#!/bin/sh -e

. "$COMMON_SCRIPT" 

installBrave() {
    if ! command_exists com.brave.Browser && ! command_exists brave; then
        printf "%b\n" "Installing Brave..."
        curl -fsS https://dl.brave.com/install.sh | sh
    else
        printf "%b\n" "Brave Browser is already installed."
    fi
}

installBrave