#!/usr/bin/env bash

set -euo pipefail

# Configuration
REPO="gameshler/arch_install"
BRANCH="development"
TEMP_DIR=$(mktemp -d -t arch_install-XXXXXX)
export INSTALL_DIR="$HOME/Downloads/arch_install"

# Colors
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Download repo archive and extract
echo -e "${GREEN}Downloading $REPO@$BRANCH...${RESET}"
if ! curl -fsSL "https://github.com/${REPO}/archive/${BRANCH}.tar.gz" | tar -xz -C "$TEMP_DIR"; then
  echo -e "${RED}Failed to download or extract repo${RESET}"
  exit 1
fi

# Extracted path
EXTRACTED="$TEMP_DIR/$(basename "$REPO")-$BRANCH"
if [[ ! -d "$EXTRACTED" ]]; then
  echo -e "${RED}Extraction failed: $EXTRACTED not found${RESET}"
  exit 1
fi

# Move to target location
echo -e "${GREEN}Installing to $INSTALL_DIR...${RESET}"
rm -rf "$INSTALL_DIR"
mv "$EXTRACTED" "$INSTALL_DIR"

# Make all .sh scripts executable
find "$INSTALL_DIR" -type f -name "*.sh" -exec chmod +x {} \;

# Run the installer (either install.sh or core/main.sh)
TARGET_SCRIPT="$INSTALL_DIR/core/main.sh"

if [[ -f "$TARGET_SCRIPT" ]]; then
  echo -e "${GREEN}Running $TARGET_SCRIPT...${RESET}"
  exec bash -i "$TARGET_SCRIPT"
else
  echo -e "${RED}Could not find $TARGET_SCRIPT${RESET}"
  exit 1
fi
