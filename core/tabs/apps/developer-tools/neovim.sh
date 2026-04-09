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
    if ! command_exists nvim ripgrep git fzf lua; then
        install_packages "$PACKAGER" neovim ripgrep fzf luarocks shellcheck git lua
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
