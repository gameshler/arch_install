#!/bin/sh -e

. "$COMMON_SCRIPT"

install_pkg() {
    if ! command_exists ufw; then
        printf "%b\n" "Installing UFW..."

        install_packages ufw
    else
        printf "%b\n" "UFW is already installed."
    fi
}

configure_ufw() {
    printf "%b\n" "Recommended Firewall Rules"

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

configure_sysctl() {
    sudo bash -c '
    cat > /etc/sysctl.d/90-network.conf << EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

net.ipv4.tcp_syncookies = 1

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

EOF
    sysctl --system
'
}

install_pkg
configure_ufw
configure_sysctl
