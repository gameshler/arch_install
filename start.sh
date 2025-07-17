#!/usr/bin/env bash
set -euo pipefail

# Configuration
REPO="gameshler/arch_install"
BRANCH="development"
TEMP_DIR=$(mktemp -d -t arch_install-XXXXXX)
INSTALL_DIR="$HOME/Downloads/arch_install"

# Colors
COLOR_GREEN="\e[32m"
COLOR_RED="\e[31m"
COLOR_RESET="\e[0m"

cleanup() {
  echo -e "${COLOR_GREEN}Cleaning temporary files...${COLOR_RESET}"
  rm -rf "$TEMP_DIR"
}

run_main_script() {
  local main_script="$INSTALL_DIR/core/main.sh"
  
  if [[ -f "$main_script" ]]; then
    echo -e "${COLOR_GREEN}Starting installation...${COLOR_RESET}"
    (cd "$INSTALL_DIR" && exec bash "./core/main.sh")
  else
    echo -e "${COLOR_RED}Main script missing${COLOR_RESET}"
    exit 1
  fi
}

main() {
  trap cleanup EXIT
  
  echo -e "${COLOR_GREEN}Downloading repository...${COLOR_RESET}"
  curl -fsSL "https://github.com/$REPO/archive/$BRANCH.tar.gz" | \
    tar -xz -C "$TEMP_DIR" || { echo -e "${COLOR_RED}Download failed${COLOR_RESET}"; exit 1; }

  EXTRACTED_DIR="$TEMP_DIR/$(basename "$REPO")-$BRANCH"
  [[ ! -d "$EXTRACTED_DIR" ]] && { echo -e "${COLOR_RED}Invalid repo structure${COLOR_RESET}"; exit 1; }

  echo -e "${COLOR_GREEN}Installing to $INSTALL_DIR...${COLOR_RESET}"
  mkdir -p "$INSTALL_DIR"
  cp -r "$EXTRACTED_DIR"/* "$INSTALL_DIR"/
  find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} +

  export INSTALL_DIR
  run_main_script
}

main