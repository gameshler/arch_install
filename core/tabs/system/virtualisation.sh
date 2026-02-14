#!/bin/sh -e

. "$COMMON_SCRIPT"

installQEMUDesktop() {
    if ! command_exists qemu-img; then
        printf "%b\n" "Installing QEMU."
        sudo "$PACKAGER" -S --needed --noconfirm qemu-desktop
    else
        printf "%b\n" "QEMU is already installed."
    fi
    checkKVM
}

installQEMUEmulators() {
    if ! "$PACKAGER" -Q | grep -q "qemu-emulators-full "; then
        printf "%b\n" "Installing QEMU-Emulators."
        sudo "$PACKAGER" -S --needed --noconfirm qemu-emulators-full swtpm
    else
        printf "%b\n" "QEMU-Emulators already installed."
    fi
}

installVirtManager() {
    if ! command_exists virt-manager; then
        printf "%b\n" "Installing Virt-Manager."
        sudo "$PACKAGER" -S --needed --noconfirm virt-manager
    else
        printf "%b\n" "Virt-Manager already installed."
    fi
}

checkKVM() {
    if [ ! -e "/dev/kvm" ]; then
        printf "%b\n" "KVM is not available. Make sure you have CPU virtualization support enabled in your BIOS/UEFI settings. Please refer https://wiki.archlinux.org/title/KVM for more information."
    else
        sudo usermod "$USER" -aG kvm
    fi
}

setupLibvirt() {
    printf "%b\n" "Configuring Libvirt."

    sudo "$PACKAGER" -S --needed --noconfirm dnsmasq
    sudo sed -i 's/^#\?firewall_backend\s*=\s*".*"/firewall_backend = "nftables"/' "/etc/libvirt/network.conf"

    if systemctl is-active --quiet polkit; then
        sudo sed -i 's/^#\?auth_unix_ro\s*=\s*".*"/auth_unix_ro = "polkit"/' "/etc/libvirt/libvirtd.conf"
        sudo sed -i 's/^#\?auth_unix_rw\s*=\s*".*"/auth_unix_rw = "polkit"/' "/etc/libvirt/libvirtd.conf"
    fi

    sudo usermod "$USER" -aG libvirt

    for value in libvirt libvirt_guest; do
        if ! grep -wq "$value" /etc/nsswitch.conf; then
            sudo sed -i "/^hosts:/ s/$/ ${value}/" /etc/nsswitch.conf
        fi
    done

    sudo systemctl enable --now libvirtd.service
    sudo virsh net-autostart default

    checkKVM
}

installLibvirt() {
    if ! command_exists libvirtd; then
        sudo "$PACKAGER" -S --needed --noconfirm libvirt dmidecode
    else
        printf "%b\n" "Libvirt is already installed."
    fi
    setupLibvirt
}

main() {
    printf "%b\n" "Choose what to install:"
    printf "%b\n" "1. QEMU"
    printf "%b\n" "2. QEMU-Emulators ( Extended architectures )"
    printf "%b\n" "3. Libvirt"
    printf "%b\n" "4. Virtual-Manager"
    printf "%b\n" "5. All"
    printf "%b" "Enter your choice [1-5]: "
    read -r CHOICE
    case "$CHOICE" in
    1) installQEMUDesktop ;;
    2) installQEMUEmulators ;;
    3) installLibvirt ;;
    4) installVirtManager ;;
    5)
        installQEMUDesktop
        installQEMUEmulators
        installLibvirt
        installVirtManager
        ;;
    *) printf "%b\n" "Invalid choice." && exit 1 ;;
    esac
}

main
