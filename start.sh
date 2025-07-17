


#!/usr/bin/env bash
set -euo pipefail

REPO="gameshler/arch_install"
BRANCH="development"
TEMP_DIR=$(mktemp -d -t arch_install-XXXXXX)
export INSTALL_DIR="$HOME/Downloads/arch_install"

cleanup() {
  echo -e "${COLOR_GREEN}Cleaning up temporary files...${COLOR_RESET}"
  rm -rf "$TEMP_DIR"
  read -rp "Delete installation files in $INSTALL_DIR? [y/N] " choice
  if [[ "$choice" =~ ^[Yy] ]]; then
    rm -rf "$INSTALL_DIR"
  fi
}

mkdir -p "$INSTALL_DIR"
cp -r "$TEMP_DIR"/* "$INSTALL_DIR"/
find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} +
cd "$INSTALL_DIR"
install_repo(){
 
  if [[ ! -f "main.sh" ]]; then
    echo "Downloading repository..."
    trap cleanup EXIT
    curl -fsSL "https://github.com/$REPO/archive/$BRANCH.tar.gz" | \
        tar -xz -C "$TEMP_DIR" --strip-components=1

    cp -r "$TEMP_DIR"/* .
    find . -name "*.sh" -exec chmod +x {} +
  fi
  exec ./core/main.sh
}

install_repo
