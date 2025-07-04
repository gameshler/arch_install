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
    local helper="yay"
    if command_exists "$helper"; then
      printf "%b\n" "Using $helper as AUR helper"
      return
    fi
    printf "%b\n" "Installing AUR helper: $helper"
    mkdir -p $HOME/opt && cd $HOME/opt
    if [[ ! -d yay-bin ]]; then
      git clone https://aur.archlinux.org/yay-bin.git
    fi
    sudo chown -R "$USER":"$USER" ./yay-bin
    cd yay-bin && makepkg --noconfirm -si
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

checkPackageManager "pacman"
checkAurHelper
