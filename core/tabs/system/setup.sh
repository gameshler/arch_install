#!/usr/bin/env bash

source "$COMMON_SCRIPT" 

set -euo pipefail

select_country() {
  echo -ne "
    Please select your country code from this list"
  # These are default key maps as presented in official arch repo archinstall
  # shellcheck disable=SC1010
  options=("AU" "AT" "BY" "BE" "BR" "BG" "CA" "CL" "CN" "CO" "CZ" "DK" "EC" "FI"
    "FR" "DE" "GR" "HK" "HU" "IS" "IN" "ID" "IR" "IE" "IL" "IT" "JP" "KZ"
    "LV" "LT" "LU" "MK" "NL" "NC" "NZ" "NO" "PL" "PT" "RO" "RU" "RS" "SG"
    "SK" "ZA" "KR" "ES" "SE" "CH" "TW" "TH" "TR" "UA" "GB" "US" "VN")

  select_option "${options[@]}"
  country=${options[$?]}

  echo -ne "Your country code is: ${country} \n"
  export COUNTRY=$country
}

printf "%b\n" "Checking System Package Manager and AUR"

sudo "$PACKAGER" -Syu --noconfirm
# pacman config
printf "%b\n" "Configuring pacman"
sudo sed -i -E \
  -e 's/^\s*#\s*(Color)/\1/' \
  -e 's/^\s*#\s*(ParallelDownloads\s*=)/\1/' \
  /etc/pacman.conf

sudo sed -i -E '/^\s*#?\s*\[multilib\]/,/^\s*\[.*\]/ {
  s/^\s*#\s*(\[multilib\])/\1/
  s/^\s*#\s*(Include\s*=\s*\/etc\/pacman\.d\/mirrorlist)/\1/
}' /etc/pacman.conf

if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
  sudo sed -i '/^ParallelDownloads *=.*/a ILoveCandy' /etc/pacman.conf
fi

sudo "$PACKAGER" -Syyu --noconfirm
printf "%b\n" "Installing packages"
gpu_type=$(lspci | grep -E "VGA|3D|Display")
if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
    echo "Installing NVIDIA drivers: nvidia-lts"
    "$PACKAGER" -S --noconfirm --needed nvidia-lts
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
    echo "Installing AMD drivers: xf86-video-amdgpu"
    "$PACKAGER" -S --noconfirm --needed vulkan-radeon lib32-vulkan-radeon
elif echo "${gpu_type}" | grep -E "Integrated Graphics Controller"; then
    echo "Installing Intel drivers:"
    "$PACKAGER" -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
elif echo "${gpu_type}" | grep -E "Intel Corporation UHD"; then
    echo "Installing Intel UHD drivers:"
    "$PACKAGER" -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
fi

install_packages "$PACKAGER" \
  libreoffice-fresh vlc curl flatpak fastfetch p7zip unrar tar rsync \
  exfat-utils fuse-exfat flac jdk-openjdk gimp \
  base-devel kate mangohud lib32-mangohud corectrl openssh dolphin \
  telegram-desktop htop discord steam reflector

select_country
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector --verbose --protocol https -a 48 -c "$COUNTRY" --score 5 -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
systemctl enable --now reflector.timer

checkAurHelper
printf "%b\n" "Installing AUR packages with yay"
install_packages "$helper" \
  insomnia-bin brave-bin visual-studio-code-bin

if echo "${gpu_type}" | grep -E "NVIDIA|GeForce"; then
  # check if flatpak is installed
  printf "%b\n" "Setting up GreenWithEnvy"
  flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak --user install flathub com.leinardi.gwe
  flatpak update 
elif echo "${gpu_type}" | grep 'VGA' | grep -E "Radeon|AMD"; then
  # corectrl autostart setup
  printf "%b\n" "Setting up corectrl autostart"
  mkdir -p "$HOME/.config/autostart"
  cp /usr/share/applications/org.corectrl.CoreCtrl.desktop "$HOME/.config/autostart/org.corectrl.CoreCtrl.desktop" || true
fi 

# mangohud config
printf "%b\n" "Configuring MangoHud"
mkdir -p "$HOME/.config/MangoHud" && cp /usr/share/doc/mangohud/MangoHud.conf.example "$HOME/.config/MangoHud/MangoHud.conf" || true
config_file="$HOME/.config/MangoHud/MangoHud.conf"

# Settings you want to enable
settings_to_uncomment=(
  "gpu_stats"
  "gpu_temp"
  "gpu_core_clock"
  "gpu_mem_temp"
  "gpu_mem_clock"
  "gpu_power"
  "gpu_voltage"
  "cpu_stats"
  "cpu_temp"
  "cpu_power"
  "cpu_mhz"
  "fps"
  "frametime"
  "throttling_status"
  "frame_timing"
  "text_outline"
)

# Loop and uncomment each line that starts with the key (if commented)
for setting in "${settings_to_uncomment[@]}"; do
  sed -i -E "s/^\s*#\s*(${setting})(\s*(=|$))/${setting}\2/" "$config_file"
done

# NVM install
printf "%b\n" "Installing NVM"
export NVM_VERSION="v0.40.3"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/"$NVM_VERSION"/install.sh | bash

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

printf "%b\n" "Installing Node.js v22 via nvm"
nvm install 22
nvm use stable
node --version

# pnpm global tools
printf "%b\n" "Installing pnpm and global node modules"
curl -fsSL https://get.pnpm.io/install.sh | sh -
source "$HOME/.bashrc" || true
pnpm add -g license gitignore

# Dotfiles array
dotfiles=(.gitignore .gitconfig .bashrc)

for dotfile in "${dotfiles[@]}"; do
  src="$DOT_FILES/$dotfile"
  dest="$HOME/$dotfile"
  if [ -f "$src" ]; then
    cp "$src" "$dest"
  else
    echo "Warning: $src not found, skipping."
  fi
done

# Source .bashrc to apply changes
source "$HOME/.bashrc" || true

printf "%b\n" "Mounting Drives..."

source "$AUTO_MOUNT" 

printf "%b\n" "Setup completed successfully!"
