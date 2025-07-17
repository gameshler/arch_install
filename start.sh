#!/usr/bin/env bash

set -euo pipefail

# Configuration
REPO="gameshler/arch_install"
BRANCH="main"
TEMP_DIR=$(mktemp -d -t arch_install-XXXXXX)
INSTALL_DIR="$HOME/Downloads/arch_install" 

# Colors
COLOR_GREEN="\e[32m"
COLOR_RED="\e[31m"
COLOR_RESET="\e[0m"

# Cleanup 
cleanup() {
  echo -e "${COLOR_GREEN}Cleaning temporary files...${COLOR_RESET}"
  rm -rf "$TEMP_DIR"

  read -rp "Delete installation files in $INSTALL_DIR? [y/N] " choice
  if [[ "$choice" =~ ^[Yy] ]]; then
    rm -rf "$INSTALL_DIR"
  fi
}

# Main
main() {
  trap cleanup EXIT
  
  echo -e "${COLOR_GREEN}Downloading repository...${COLOR_RESET}"
  
  # Download and extract repository
  if ! curl -fsSL "https://github.com/$REPO/archive/$BRANCH.tar.gz" | \
       tar -xz -C "$TEMP_DIR"; then
    echo -e "${COLOR_RED}Failed to download repository${COLOR_RESET}"
    exit 1
  fi
  
  # Verify extracted directory exists
  EXTRACTED_DIR="$TEMP_DIR/$(basename "$REPO")-$BRANCH"
  if [[ ! -d "$EXTRACTED_DIR" ]]; then
    echo -e "${COLOR_RED}Extracted directory not found at $EXTRACTED_DIR${COLOR_RESET}"
    exit 1
  fi
  
  # Move to permanent location
  echo -e "${COLOR_GREEN}Installing to $INSTALL_DIR...${COLOR_RESET}"
  rm -rf "$INSTALL_DIR" 2>/dev/null || true
  mkdir -p "$(dirname "$INSTALL_DIR")"
  mv "$EXTRACTED_DIR" "$INSTALL_DIR"
  
  # Make scripts executable
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} +
  
  # Set environment variables
  readonly SCRIPT_DIR="$INSTALL_DIR"
  export DOT_FILES="$INSTALL_DIR/dotfiles"
  export TABS_DIR="$INSTALL_DIR/core/tabs"
  export COMMON_SCRIPT="$TABS_DIR/common-script.sh"
  export AUTO_MOUNT="$TABS_DIR/utils/auto-mount.sh"
  
  # Verify and run main script
  MAIN_SCRIPT="$INSTALL_DIR/core/main.sh"
  if [[ -f "$MAIN_SCRIPT" ]]; then
    echo -e "Make sure to run setup.sh first"
    echo -e "${COLOR_GREEN}Starting installation...${COLOR_RESET}"
    exec "$MAIN_SCRIPT"
  else
    echo -e "${COLOR_RED}Main script not found at $MAIN_SCRIPT${COLOR_RESET}"
    exit 1
  fi
}

main