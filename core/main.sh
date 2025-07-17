#!/usr/bin/env bash

set -euo pipefail

# Set environment variables
export DOT_FILES="$INSTALL_DIR/dotfiles"
export TABS_DIR="$INSTALL_DIR/core/tabs"
export COMMON_SCRIPT="$TABS_DIR/common-script.sh"
export AUTO_MOUNT="$TABS_DIR/utils/auto-mount.sh"

COLOR_YELLOW="\e[33m"
COLOR_GREEN="\e[32m"
COLOR_RED="\e[31m"
COLOR_RESET="\e[0m"

pause() {
  read -rp $'\nPress Enter to return...'
}

choose_directory() {
  mapfile -t DIRS < <(find "$TABS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  if [[ "${#DIRS[@]}" -eq 0 ]]; then
    echo -e "${COLOR_RED}No folders found in $TABS_DIR.${COLOR_RESET}"
    exit 1
  fi

  while true; do
    echo -e "${COLOR_YELLOW}Available Categories:${COLOR_RESET}"
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
      echo -e "${COLOR_GREEN}Exiting.${COLOR_RESET}"
      exit 0
    else
      echo -e "${COLOR_RED}Invalid choice.${COLOR_RESET}"
    fi
  done
}

choose_script() {
  local dir="$1"
  mapfile -t SCRIPTS < <(find "$dir" -maxdepth 1 -type f -name "*.sh" | sort)

  if [[ "${#SCRIPTS[@]}" -eq 0 ]]; then
    echo -e "${COLOR_RED}No scripts found in $(basename "$dir").${COLOR_RESET}"
    pause
    return
  fi

  while true; do
    echo -e "${COLOR_YELLOW}Scripts in $(basename "$dir"):${COLOR_RESET}"
    local i=1
    for script in "${SCRIPTS[@]}"; do
      echo "$i) $(basename "$script")"
      ((i++))
    done
    echo "$i) Back"
    echo ""

    read -rp "Choose a script to run [1-$i]: " choice
    if (( choice >= 1 && choice <= ${#SCRIPTS[@]} )); then
      echo -e "${COLOR_GREEN}Running: $(basename "${SCRIPTS[$((choice - 1))]}")${COLOR_RESET}"
      bash "${SCRIPTS[$((choice - 1))]}"
      pause
    elif (( choice == ${#SCRIPTS[@]} + 1 )); then
      return
    else
      echo -e "${COLOR_RED}Invalid choice.${COLOR_RESET}"
    fi
  done
}

main() {
  while true; do
    choose_directory
  done
}

main
