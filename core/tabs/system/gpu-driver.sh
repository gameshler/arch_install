#!/bin/sh -e

. "$COMMON_SCRIPT"

installLACT() {
    if ! command_exists lact; then
        install_packages "$PACKAGER" lact
        sudo systemctl enable --now lactd
    else
        printf "%b\n" "LACT is already installed."
    fi
}

installGpuDriver() {

    printf "%b\n" "Installing GPU Drivers"
    gpu_type=$(lspci | grep "VGA|3D|Display")
    case "$gpu_type" in
    *NVIDIA* | *GeForce*)
        echo "Installing NVIDIA drivers"
        install_packages "$PACKAGER" nvidia-dkms nvidia-utils nvidia-settings cuda nvidia
        ;;
    *Radeon* | *AMD*)
        echo "Installing AMD drivers"
        install_packages "$PACKAGER" mesa vulkan-radeon libva-mesa-driver lib32-vulkan-radeon lib32-mesa xf86-video-amdgpu lib32-libva-mesa-driver
        ;;
    *Integrated\ Graphics\ Controller*)
        echo "Installing Intel drivers"
        install_packages "$PACKAGER" mesa vulkan-intel intel-media-driver
        ;;
    *Intel\ Corporation\ UHD*)
        echo "Installing Intel UHD drivers"
        install_packages "$PACKAGER" libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
        ;;
    *)
        echo "Unknown GPU type: $gpu_type"
        ;;
    esac

}

installGpuDriver
installLACT
