#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/gameshler/arch_install/main"
FILES=(setup.sh common-script.sh auto-mount.sh .bashrc .gitconfig .gitignore)

trap 'rm -f setup.sh common-script.sh auto-mount.sh' EXIT

printf "%s\n" "Fetching required files..."
for file in "${FILES[@]}"; do
  curl -fsSL "$REPO_URL/$file" -o "$file"
done

chmod +x setup.sh common-script.sh auto-mount.sh
printf "%s\n" "Running setup..."
./setup.sh
