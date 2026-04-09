#!/bin/sh -e

. "$COMMON_SCRIPT"

installPkg() {
    if ! command_exists ufw; then
        install_packages ufw
    else
        printf "%b\n" "UFW is already installed."
    fi
}

configureUFW() {
    printf "%b\n" "Recommended Firewall Rules"

    printf "%b\n" "Disabling UFW"
    sudo ufw disable
    printf "%b\n" "Limiting Port $SSH_PORT/tcp"
    sudo ufw limit "$SSH_PORT"/tcp
    printf "%b\n" "Allowing Port 80/tcp"
    sudo ufw allow 80/tcp
    printf "%b\n" "Allowing Port 443/tcp"
    sudo ufw allow 443/tcp
    printf "%b\n" "Deny Incoming Packets by Default"
    sudo ufw default deny incoming
    printf "%b\n" "Allow Outcoming Packets by Default"
    sudo ufw default allow outgoing
    printf "%b\n" "Enabling UFW"
    sudo ufw enable

    printf "%b\n" "Enabled Firewall with UFW"

}

installPkg
configureUFW
