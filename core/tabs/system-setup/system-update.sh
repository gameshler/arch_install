#!/bin/sh -e

source "$COMMON_SCRIPT"

fastUpdate() {
    case "$PACKAGER" in
        pacman)
            install_packages "$helper" rate-mirrors-bin

            printf "%b\n" "Generating a new list of mirrors using rate-mirrors. This process may take a few seconds..."

            if [ -s "/etc/pacman.d/mirrorlist" ]; then
                sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
            fi

            dtype_local="${DTYPE:-arch}"
            echo "Using rate-mirrors with distro: $dtype_local"

            if ! sudo rate-mirrors "$dtype_local" \
                    --top-mirrors-number-to-retest=5 \
                    --disable-comments \
                    --save /etc/pacman.d/mirrorlist \
                    --allow-root > /dev/null \
                || [ ! -s "/etc/pacman.d/mirrorlist" ]; then

                printf "%b\n" "Rate-mirrors failed, restoring backup."
                sudo cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
            fi
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ${PACKAGER}"
            exit 1
            ;;
    esac
}

updateSystem() {
    printf "%b\n" "Updating system packages."
    case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -Sy --noconfirm --needed archlinux-keyring
            "$helper" -Su --noconfirm
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ${PACKAGER}"
            exit 1
            ;;
    esac
}

updateFlatpaks() {
    if command_exists flatpak; then
        printf "%b\n" "Updating flatpak packages."
        flatpak update -y
    fi
}

checkAurHelper
fastUpdate
updateSystem
updateFlatpaks