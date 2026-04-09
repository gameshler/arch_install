#!/usr/bin/env bash

set -euo pipefail

# Configuration
REPO="gameshler/archsetup"
BRANCH="main"
export TEMP_DIR=$(mktemp -d -t archsetup-XXXXXX)
export INSTALL_DIR="$HOME/Downloads/archsetup"

# Main
main() {

    # Download and extract repository
    if ! curl -fsSL "https://github.com/$REPO/archive/$BRANCH.tar.gz" |
        tar -xz -C "$TEMP_DIR"; then
        echo -e "Failed to download repository"
        exit 1
    fi

    # Verify extracted directory exists
    EXTRACTED_DIR="$TEMP_DIR/$(basename "$REPO")-$BRANCH"
    if [[ ! -d "$EXTRACTED_DIR" ]]; then
        echo -e "Extracted directory not found at $EXTRACTED_DIR"
        exit 1
    fi

    # Move to permanent location
    echo -e "Installing to $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    mkdir -p "$(dirname "$INSTALL_DIR")"
    mv "$EXTRACTED_DIR" "$INSTALL_DIR"

    # Make scripts executable
    find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} +

    # Verify and run main script
    MAIN_SCRIPT="$INSTALL_DIR/core/main.sh"
    if [[ -f "$MAIN_SCRIPT" ]]; then
        "$MAIN_SCRIPT"
    else
        echo -e "Main script not found at $MAIN_SCRIPT"
        exit 1
    fi
}

main
