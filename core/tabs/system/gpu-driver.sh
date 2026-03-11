#!/bin/sh -e

. "$COMMON_SCRIPT"

installLACT() {
    if ! command_exists lact; then
        printf "%b\n" "Installing LACT..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm lact
            sudo systemctl enable --now lactd
            ;;
        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
    else
        printf "%b\n" "LACT is already installed."
    fi
}

installGpuDriver() {

    printf "%b\n" "Installing GPU Drivers"
    gpu_type=$(lspci | grep -E "VGA|3D|Display")
    case "$gpu_type" in
    *NVIDIA* | *GeForce*)
        echo "Installing NVIDIA drivers"
        sudo "$PACKAGER" -S --noconfirm --needed nvidia-dkms nvidia-utils nvidia-settings cuda nvidia
        ;;
    *Radeon* | *AMD*)
        echo "Installing AMD drivers"
        sudo "$PACKAGER" -S --noconfirm --needed mesa vulkan-radeon libva-mesa-driver lib32-vulkan-radeon lib32-mesa xf86-video-amdgpu lib32-libva-mesa-driver
        ;;
    *Integrated\ Graphics\ Controller*)
        echo "Installing Intel drivers"
        sudo "$PACKAGER" -S --noconfirm --needed mesa vulkan-intel intel-media-driver
        ;;
    *Intel\ Corporation\ UHD*)
        echo "Installing Intel UHD drivers"
        sudo "$PACKAGER" -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
        ;;
    *)
        echo "Unknown GPU type: $gpu_type"
        ;;
    esac

}

installGpuDriver
installLACT
