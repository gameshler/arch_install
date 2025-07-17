#!/usr/bin/env bash
set -euo pipefail

# Configuration
REPO="gameshler/arch_install"
BRANCH="development"
export INSTALL_DIR="$HOME/Downloads/arch_install"

# Colors
COLOR_GREEN="\e[32m"
COLOR_RED="\e[31m"
COLOR_RESET="\e[0m"

# Cleanup function
cleanup() {
  echo -e "${COLOR_GREEN}Cleaning temporary files...${COLOR_RESET}"
  [[ -n "${TEMP_DIR:-}" ]] && rm -rf "$TEMP_DIR"
}

# Main installation function
install_repo() {
  echo -e "${COLOR_GREEN}Downloading repository...${COLOR_RESET}"
  TEMP_DIR=$(mktemp -d)
  trap cleanup EXIT
  
  curl -fsSL "https://github.com/$REPO/archive/$BRANCH.tar.gz" | \
    tar -xz -C "$TEMP_DIR" --strip-components=1 || {
    echo -e "${COLOR_RED}Download failed${COLOR_RESET}"
    exit 1
  }

  # Install files
  mkdir -p "$INSTALL_DIR"
  cp -r "$TEMP_DIR"/* "$INSTALL_DIR"/
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} +
}

# Check if installation exists
if [[ ! -f "$INSTALL_DIR/core/main.sh" ]]; then
  install_repo
fi

# Run main script
cd "$INSTALL_DIR"
exec ./core/main.sh