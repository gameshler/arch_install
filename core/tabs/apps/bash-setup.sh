#!/usr/bin/env bash

. "$COMMON_SCRIPT"

gitpath="$HOME/.local/share/bash"

installDepend() {
    if [ ! -f "/usr/share/bash-completion/bash_completion" ] || ! command_exists bash tar bat tree unzip fc-list git; then
        printf "%b\n" "Installing Bash..."
        case "$PACKAGER" in
        pacman)
            sudo "$PACKAGER" -S --needed --noconfirm bash bash-completion tar bat tree unzip fontconfig git fzf
            ;;

        *)
            printf "%b\n" "Unsupported package manager: ""$PACKAGER"
            exit 1
            ;;
        esac
    fi
}

setupBash() {
    if [ -d "$gitpath" ]; then
        rm -rf "$gitpath"
    fi
    mkdir -p "$HOME/.local/share"
    files=(starship.toml .bashrc)

    for file in "${files[@]}"; do
        src="$FILES/$file"
        dest="$gitpath/$file"
        if [ -f "$src" ]; then
            cp "$src" "$dest"
        else
            echo "Warning: $src not found, skipping."
        fi
    done
}

installFont() {
    # Check to see if the FiraCode Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="FiraCode Nerd Font"
    if fc-list :family | grep -iq "$FONT_NAME"; then
        printf "%b\n" "Font '$FONT_NAME' is installed."
    else
        printf "%b\n" "Installing font '$FONT_NAME'"
        # Change this URL to correspond with the correct font
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
        FONT_DIR="$HOME/.local/share/fonts"
        curl -sSLo "$TEMP_DIR"/"${FONT_NAME}".zip "$FONT_URL"
        unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
        mkdir -p "$FONT_DIR"/"$FONT_NAME"
        mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
        fc-cache -fv
        printf "%b\n" "'$FONT_NAME' installed successfully."
    fi
}

installStarshipAndFzf() {
    if command_exists starship; then
        printf "%b\n" "Starship already installed"
        return
    else

        curl -sSL https://starship.rs/install.sh | sudo sh || {
            printf "%b\n" "Failed to install starship!"
            exit 1
        }

    fi
    if command_exists fzf; then
        printf "%b\n" "Fzf already installed"
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        sudo ~/.fzf/install
    fi
}

linkConfig() {
    OLD_BASHRC="$HOME/.bashrc"
    if [ -e "$OLD_BASHRC" ] && [ ! -e "$HOME/.bashrc.bak" ]; then
        printf "%b\n" "Moving old bash config file to $HOME/.bashrc.bak"
        if ! mv "$OLD_BASHRC" "$HOME/.bashrc.bak"; then
            printf "%b\n" "Can't move the old bash config file!"
            exit 1
        fi
    fi

    printf "%b\n" "Linking new bash config file..."
    ln -svf "$gitpath/.bashrc" "$HOME/.bashrc" || {
        printf "%b\n" "Failed to create symbolic link for .bashrc"
        exit 1
    }

    mkdir -p "$HOME/.config"
    ln -svf "$gitpath/starship.toml" "$HOME/.config/starship.toml" || {
        printf "%b\n" "Failed to create symbolic link for starship.toml"
        exit 1
    }
    printf "%b\n" "Done! restart your shell to see the changes."
}

checkEnv
installDepend
setupBash
installFont
installStarshipAndFzf
linkConfig
