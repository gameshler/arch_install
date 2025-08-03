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
  local current_dir="$TABS_DIR"
  local parent_stack=()

  while true; do
    clear
    echo -e "Current Path: ${current_dir/$TABS_DIR\//}"
    echo "Available Items:"
    local options=()
    local i=1

    if [[ "$current_dir" == "$TABS_DIR" ]]; then
      mapfile -t ENTRIES < <(find "$current_dir" -mindepth 1 -maxdepth 1 -type d | sort)
    else
      mapfile -t ENTRIES < <(find "$current_dir" -mindepth 1 -maxdepth 1 \( -type d -o -type f -name "*.sh" \) | sort)
    fi

    if [[ "${#ENTRIES[@]}" -eq 0 ]]; then
      echo "No items found."
    fi

    for entry in "${ENTRIES[@]}"; do
      if [[ -d "$entry" ]]; then
        echo "$i) $(basename "$entry")/"
        options+=("$entry|dir")
      elif [[ -f "$entry" && "$entry" == *.sh ]]; then
        echo "$i) $(basename "$entry")"
        options+=("$entry|file")
      fi
      ((i++))
    done

    if [[ "${#parent_stack[@]}" -eq 0 ]]; then
      echo "$i) Exit"
    else
      echo "$i) Back"
    fi
    echo ""

    read -rp "Choose an item to open or run [1-$i]: " choice

    if (( choice >= 1 && choice <= ${#options[@]} )); then
      selected="${options[$((choice - 1))]}"
      IFS='|' read -r path type <<< "$selected"
      if [[ "$type" == "dir" ]]; then
        parent_stack+=("$current_dir")
        current_dir="$path"
      else
        clear
        echo -e "Running: $(basename "$path")\n"
        bash "$path"
        pause
      fi
    elif (( choice == ${#options[@]} + 1 )); then
      if [[ "${#parent_stack[@]}" -eq 0 ]]; then
        echo -e "Exiting."
        exit 0
      else
        current_dir="${parent_stack[-1]}"
        parent_stack=("${parent_stack[@]::${#parent_stack[@]}-1}")
      fi
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
