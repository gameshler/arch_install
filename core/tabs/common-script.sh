#!/bin/sh -e

command_exists() {
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || return 1
  done
  return 0
}

checkPackageManager() {
  local managers=("$@")
  for pgm in "${managers[@]}"; do
    if command_exists "$pgm"; then
      declare -g PACKAGER="$pgm"
      printf "%b\n" "Using $pgm as package manager"
      return
    fi
  done
  echo "No supported package manager found" >&2
  exit 1
}

checkAurHelper() {
  if [[ "$PACKAGER" == "pacman" ]]; then
    export helper="yay"
    if command_exists "$helper"; then
      printf "%b\n" "Using $helper as AUR helper"
      return
    fi
    printf "%b\n" "Installing AUR helper: $helper"
    mkdir -p "$HOME"/opt && cd "$HOME"/opt || exit
    if [[ ! -d yay-bin ]]; then
      git clone https://aur.archlinux.org/yay-bin.git
    fi
    sudo chown -R "$USER":"$USER" ./yay-bin
    cd yay-bin && makepkg --noconfirm -si
  fi
}
checkFlatpak() {
    if ! command_exists flatpak; then
        printf "%b\n" "Installing Flatpak..."
        case "$PACKAGER" in
            pacman)
                sudo "$PACKAGER" -S --needed --noconfirm flatpak
                ;;
            *)
                sudo "$PACKAGER" install -y flatpak
                ;;
        esac
        printf "%b\n" "Adding Flathub remote..."
        sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        printf "%b\n" "Applications installed by Flatpak may not appear on your desktop until the user session is restarted..."
    else
        if ! flatpak remotes | grep -q "flathub"; then
            printf "%b\n" "Adding Flathub remote..."
            sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        else
            printf "%b\n" "Flatpak is installed"
        fi
    fi
}

install_packages() {
  local pkg_tool="$1"
  shift

  if ! command_exists "$pkg_tool"; then
    printf "%b\n" "Error: Package manager '$pkg_tool' not found"
    return 1
  fi

  local packages=("$@")
  local to_install=()

  for pkg in "${packages[@]}"; do
    if ! "$pkg_tool" -Q "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    fi
  done

  if [[ ${#to_install[@]} -gt 0 ]]; then
    printf "%b\n" "Installing packages with $pkg_tool: ${to_install[*]}"
    if [[ "$pkg_tool" == "pacman" ]]; then
      sudo "$pkg_tool" -S --needed --noconfirm "${to_install[@]}"
    else
      "$pkg_tool" -S --needed --noconfirm "${to_install[@]}"
    fi
  else
    printf "%b\n" "All packages already installed for $pkg_tool"
  fi
}

check_init_manager() {
  local candidates="$1"
  local manager

  for manager in $candidates; do
    if command_exists "$manager"; then
      INIT_MANAGER="$manager"
      printf "%b\n" "Using ${manager} to interact with init system"
      return 0
    fi
  done

  printf "%b\n" "No supported init system found. Exiting."
  exit 1
}

checkPackageManager "pacman"
check_init_manager 'systemctl rc-service sv'
