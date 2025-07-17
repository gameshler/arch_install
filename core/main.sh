#!/usr/bin/env bash

set -euo pipefail

# Set environment variables
export DOT_FILES="$INSTALL_DIR/dotfiles"
export TABS_DIR="$INSTALL_DIR/core/tabs"
export COMMON_SCRIPT="$TABS_DIR/common-script.sh"
export AUTO_MOUNT="$TABS_DIR/utils/auto-mount.sh"

pause() {
  read -rp $'\nPress Enter to return...'
}
cleanup() {
  echo -e "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
  read -rp "Delete installation files in $INSTALL_DIR? [y/N] " choice
  if [[ "$choice" =~ ^[Yy] ]]; then
    rm -rf "$INSTALL_DIR"
  fi
}
choose_directory() {
  mapfile -t DIRS < <(find "$TABS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  if [[ "${#DIRS[@]}" -eq 0 ]]; then
    echo -e "No folders found in $TABS_DIR."
    exit 1
  fi

  while true; do
    echo -e "Available Categories:"
    local i=1
    for dir in "${DIRS[@]}"; do
      echo "$i) $(basename "$dir")"
      ((i++))
    done
    echo "$i) Exit"
    echo ""

    read -rp "Choose a category [1-$i]: " choice
    if (( choice >= 1 && choice <= ${#DIRS[@]} )); then
      choose_script "${DIRS[$((choice - 1))]}"
    elif (( choice == ${#DIRS[@]} + 1 )); then
      echo -e "Exiting."
      exit 0
    else
      echo -e "Invalid choice."
    fi
  done
}

choose_script() {
  local dir="$1"
  mapfile -t SCRIPTS < <(find "$dir" -maxdepth 1 -type f -name "*.sh" | sort)

  if [[ "${#SCRIPTS[@]}" -eq 0 ]]; then
    echo -e "No scripts found in $(basename "$dir")."
    pause
    return
  fi

  while true; do
    echo -e "Scripts in $(basename "$dir"):"
    local i=1
    for script in "${SCRIPTS[@]}"; do
      echo "$i) $(basename "$script")"
      ((i++))
    done
    echo "$i) Back"
    echo ""

    read -rp "Choose a script to run [1-$i]: " choice
    if (( choice >= 1 && choice <= ${#SCRIPTS[@]} )); then
      echo -e "Running: $(basename "${SCRIPTS[$((choice - 1))]}")"
      bash "${SCRIPTS[$((choice - 1))]}"
      pause
    elif (( choice == ${#SCRIPTS[@]} + 1 )); then
      return
    else
      echo -e "Invalid choice."
    fi
  done
}

main() {
  trap cleanup EXIT
  while true; do
    choose_directory
  done
}

main
