#!/bin/sh

. "$COMMON_SCRIPT"

setupDWM() {
    printf "%b\n" "Installing DWM..."
    case "$PACKAGER" in
    pacman)
        sudo "$PACKAGER" -S --needed --noconfirm base-devel libx11 libxinerama libxft imlib2 git unzip flameshot nwg-look feh mate-polkit alsa-utils ghostty rofi xclip xarchiver thunar tumbler tldr gvfs thunar-archive-plugin dunst feh nwg-look dex xscreensaver xorg-xprop polybar picom xdg-user-dirs xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring flatpak networkmanager network-manager-applet
        ;;
    *)
        printf "%b\n" "Unsupported package manager: ""$PACKAGER"""
        exit 1
        ;;
    esac
}

makeDWM() {
    [ ! -d "$HOME/.local/share" ] && mkdir -p "$HOME/.local/share/"
    if [ ! -d "$HOME/.local/share/dwm" ]; then
        printf "%b\n" "DWM not found, cloning repository..."
        cd "$HOME/.local/share/" && git clone https://github.com/gameshler/dwm.git
        cd dwm/
    else
        printf "%b\n" "DWM directory already exists, replacing.."
        cd "$HOME/.local/share/dwm" && git pull
    fi
    sudo make clean install # Run make clean install
}

install_nerd_font() {
    # Check to see if the FiraCode Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="FiraCode Nerd Font Mono"
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    FONT_INSTALLED=$(fc-list | grep -i "FiraCode")

    if [ -n "$FONT_INSTALLED" ]; then
        printf "%b\n" "FiraCode Nerd-fonts are already installed."
        return 0
    fi

    printf "%b\n" "Installing FiraCode Nerd-fonts"

    # Create the fonts directory if it doesn't exist
    if [ ! -d "$FONT_DIR" ]; then
        mkdir -p "$FONT_DIR" || {
            printf "%b\n" "Failed to create directory: $FONT_DIR"
            return 1
        }
    fi
    printf "%b\n" "Installing font '$FONT_NAME'"
    # Change this URL to correspond with the correct font
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    FONT_DIR="$HOME/.local/share/fonts"
    TEMP_DIR=$(mktemp -d)
    curl -sSLo "$TEMP_DIR"/"${FONT_NAME}".zip "$FONT_URL"
    unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
    mkdir -p "$FONT_DIR"/"$FONT_NAME"
    mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
    fc-cache -fv
    rm -rf "${TEMP_DIR}"
    printf "%b\n" "'$FONT_NAME' installed successfully."
}

clone_config_folders() {
    # Ensure the target directory exists
    [ ! -d ~/.config ] && mkdir -p ~/.config
    [ ! -d ~/.local/bin ] && mkdir -p ~/.local/bin
    # Copy scripts to local bin
    cp -rf "$HOME/.local/share/dwm/scripts/." "$HOME/.local/bin/"

    # Iterate over all directories in config/*
    for dir in config/*/; do
        # Extract the directory name
        dir_name=$(basename "$dir")

        # Clone the directory to ~/.config/
        if [ -d "$dir" ]; then
            cp -r "$dir" ~/.config/
            printf "%b\n" "Cloned $dir_name to ~/.config/"
        else
            printf "%b\n" "Directory $dir_name does not exist, skipping"
        fi
    done
}

configure_backgrounds() {
    # Set the variable PIC_DIR which stores the path for images
    PIC_DIR="$HOME/Pictures"

    # Set the variable BG_DIR to the path where backgrounds will be stored
    BG_DIR="$PIC_DIR/backgrounds"

    # Check if the ~/Pictures directory exists
    if [ ! -d "$PIC_DIR" ]; then
        # If it doesn't exist, print an error message and return with a status of 1 (indicating failure)
        printf "%b\n" "Pictures directory does not exist"
        mkdir ~/Pictures
        printf "%b\n" "Directory was created in Home folder"
    fi

    # Check if the backgrounds directory (BG_DIR) exists
    if [ ! -d "$BG_DIR" ]; then
        # If the backgrounds directory doesn't exist, attempt to clone a repository containing backgrounds
        if ! git clone https://github.com/ChrisTitusTech/nord-background.git "$PIC_DIR/backgrounds"; then
            # If the git clone command fails, print an error message and return with a status of 1
            printf "%b\n" "Failed to clone the repository"
            return 1
        fi
        # Print a success message indicating that the backgrounds have been downloaded
        printf "%b\n" "Downloaded desktop backgrounds to $BG_DIR"
    else
        # If the backgrounds directory already exists, print a message indicating that the download is being skipped
        printf "%b\n" "Path $BG_DIR exists for desktop backgrounds, skipping download of backgrounds"
    fi
}

setupDisplayManager() {
    printf "%b\n" "Setting up Xorg"
    case "$PACKAGER" in
    pacman)
        sudo "$PACKAGER" -S --needed --noconfirm xorg-xinit xorg-server
        ;;
    *)
        printf "%b\n" "Unsupported package manager: $PACKAGER"
        exit 1
        ;;
    esac
    printf "%b\n" "Xorg installed successfully"
    printf "%b\n" "Setting up Display Manager"
    currentdm="none"
    for dm in gdm sddm lightdm; do
        if command -v "$dm" >/dev/null 2>&1 || isServiceActive "$dm"; then
            currentdm="$dm"
            break
        fi
    done
    printf "%b\n" "Display Manager Setup: $currentdm"
    if [ "$currentdm" = "none" ]; then
        printf "%b\n" "--------------------------"
        DM="sddm"
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm "$DM"
            if [ "$DM" = "lightdm" ]; then
                sudo "$PACKAGER" -S --needed --noconfirm lightdm-gtk-greeter
            elif [ "$DM" = "sddm" ]; then
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
            fi
            ;;
        *)
            printf "%b\n" "Unsupported package manager: $PACKAGER"
            exit 1
            ;;
        esac
        printf "%b\n" "$DM installed successfully"
        enableService "$DM"

    fi
}

checkEnv
setupDisplayManager
setupDWM
makeDWM
install_nerd_font
clone_config_folders
configure_backgrounds
