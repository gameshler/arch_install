#!/bin/sh -e

. "$COMMON_SCRIPT"

installNftables() {
    if ! command_exists nft; then
        install_packages nftables
    else
        printf "%b\n" "nftables is already installed."
    fi
}

configureNftables() {
    # Detect interface used for default route
    WAN_IF=$(ip route | awk '/^default/ {print $5; exit}')
    if [ -z "$WAN_IF" ]; then
        printf "%b\n" "Could not detect default interface, aborting nftables configuration."
        exit 1
    fi

    sudo WAN_IF="$WAN_IF" SSH_PORT="$SSH_PORT" bash -c '
    cat > /etc/nftables.conf << 'EOF'

#!/usr/bin/nft -f

destroy table inet filter
table inet filter {
  chain input {
    type filter hook input priority 0;
    policy drop;

    ct state invalid drop comment "drop invalid connections"
    ct state {established, related} accept comment "allow established/related"
    iif lo accept comment "allow loopback"
    iif != lo ip daddr 127.0.0.1/8 drop comment "block spoofed loopback"
    iif != lo ip6 daddr ::1/128 drop comment "block IPv6 loopback spoofing"

    # Rate-limited ICMP
    ip protocol icmp limit rate 4/second accept comment "allow ICMP"
    meta l4proto ipv6-icmp limit rate 4/second accept comment "allow ICMPv6"

    # SSH brute-force protection
    tcp dport $SSH_PORT ct state new meter ssh_conn_limit { ip saddr timeout 30s limit rate 6/minute } jump ssh_check

    # Web services
    tcp dport {80, 443} accept comment "allow HTTP/HTTPS"

    # Libvirt (VMs)
    iifname "virbr0" ct state {established, related, new} accept comment "allow VM traffic"

    # Block spoofed private IPs on external interface
    iifname "$WAN_IF" ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8 } drop comment "anti-spoofing"

    # Final logging and drop
    log prefix "DROP: " level warn counter drop comment "log and drop"
  }

  chain ssh_check {
    tcp dport $SSH_PORT counter accept comment "SSH accepted"
  }

  chain forward {
    type filter hook forward priority 0; policy drop;

    ct state {established, related} accept comment "allow forwarded replies"
    iifname "virbr0" accept comment "allow VM forwarding"
  }

  chain output {
    type filter hook output priority 0;
    policy accept;
  }
}

EOF

systemctl enable --now nftables

    cat > /etc/sysctl.d/90-network.conf << 'EOF'
# Do not act as a router
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable ICMP redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
    sysctl --system
'
}

installNftables
configureNftables
