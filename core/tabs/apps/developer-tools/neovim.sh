#!/bin/sh -e

. "$COMMON_SCRIPT" 

cloneNeovim() {
    if [ -z "${TEMP_DIR:-}" ] || [ ! -d "$TEMP_DIR" ]; then
        printf "Missing or Invalid Temp Directory\n" >&2
        exit 1
    fi

    git clone https://github.com/gameshler/neovim.git "$TEMP_DIR/neovim"

}

installNeovim() {
    if ! command_exists neovim ripgrep git fzf; then
        printf "%b\n" "Installing Github Desktop..."
        case "$PACKAGER" in
            pacman)
                sudo "$PACKAGER" -S --needed --noconfirm neovim ripgrep fzf luarocks shellcheck git
                ;;
            *)
                printf "%b\n" "Unsupported package manager: ""$PACKAGER"
                exit 1
                ;;
        esac
    else
        printf "%b\n" "Neovim is already installed."
    fi
}

linkNeovimConfig() {
    printf "Linking Neovim Configuration Files..."
    mkdir -p "$HOME/.config/nvim"
    cp -r "$TEMP_DIR/neovim/lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/init.lua" "$HOME/.config/nvim/"
    cp -r "$TEMP_DIR/neovim/lazy-lock.json" "$HOME/.config/nvim/"

}

installNeovim
cloneNeovim
linkNeovimConfig
