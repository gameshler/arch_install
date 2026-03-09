#!/bin/sh -e

. "$COMMON_SCRIPT"

installOpenssh() {
    if ! command_exists ssh; then
        printf "%b\n" "Installing openssh..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm openssh
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
    else
        printf "%b\n" "openssh is already installed."
    fi
}

generate_ssh_key() {
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        printf "%b\n" "SSH key not found, generating one..."
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)"
        eval "$(ssh-agent -s)"

    else
        printf "%b\n" "SSH key already exists."
    fi
}

configure_ssh() {
    printf "%b\\n" "Configuring SSH server..."

    # Port 566 (change as needed)
    sudo sed -i '/^#*Port[[:space:]]/d' /etc/ssh/sshd_config
    sudo sed -i '/^Port[[:space:]]/d' /etc/ssh/sshd_config
    echo "Port 566" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # AddressFamily inet
    sudo sed -i 's/^#*AddressFamily.*/AddressFamily inet/' /etc/ssh/sshd_config ||
        echo "AddressFamily inet" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PermitRootLogin no
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config ||
        echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PubkeyAuthentication yes
    sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config ||
        echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PasswordAuthentication no
    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config ||
        echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # PermitEmptyPasswords no
    sudo sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config ||
        echo "PermitEmptyPasswords no" | sudo tee -a /etc/ssh/sshd_config >/dev/null

    # Test and restart
    sudo sshd -t && sudo systemctl restart sshd || {
        printf "Config error!\n"
        exit 1
    }
    printf "%b\\n" "SSH configured successfully."
}

installOpenssh
generate_ssh_key
configure_ssh
