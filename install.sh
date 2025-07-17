#!/usr/bin/env bash

set -euo pipefail

# Config
BRANCH="development"
REPO="gameshler/arch_install"
FILE="start.sh"
TEMP_PATH="/tmp/$FILE"

# Colors
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Main
main() {
  echo -e "${GREEN}Downloading ${FILE}...${RESET}"
  if ! curl -fsSL -o "$TEMP_PATH" "https://raw.githubusercontent.com/$REPO/$BRANCH/$FILE"; then
    echo -e "${RED}Failed to download $FILE${RESET}"
    exit 1
  fi

  chmod +x "$TEMP_PATH"

  echo -e "${GREEN}Starting $FILE...${RESET}"
  exec bash -i "$TEMP_PATH"
}

main
