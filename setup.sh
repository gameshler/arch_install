#!/usr/bin/env bash

. ./common-script.sh

set -euo pipefail

printf "%b\n" "Checking System Package Manager and AUR"
checkPackageManager "pacman"
check_init_manager 'systemctl rc-service sv'

/bin/bash <<EOF

    pacman -S sbctl --noconfirm 
    sbctl create-keys
    sbctl sign -s /boot/efi/EFI/Linux/bootx64.efi
    
    echo 'uefi_secureboot_cert="/var/lib/sbctl/keys/db/db.pem"' > /etc/dracut.conf.d/secureboot.conf
    echo 'uefi_secureboot_key="/var/lib/sbctl/keys/db/db.key"' >> /etc/dracut.conf.d/secureboot.conf
    cat >/etc/pacman.d/hooks/zz-sbctl.hook <<'HOOK'
  [Trigger]
	Type = Path
	Operation = Install
	Operation = Upgrade
	Operation = Remove
	Target = boot/*
	Target = efi/*
	Target = usr/lib/modules/*/vmlinuz
	Target = usr/lib/initcpio/*
	Target = usr/lib/**/efi/*.efi*

	[Action]
	Description = Signing EFI binaries...
	When = PostTransaction
	Exec = /usr/bin/sbctl sign /boot/efi/EFI/Linux/bootx64.efi
HOOK
    # Enroll keys with Microsoft keys included
    sbctl enroll-keys --microsoft
EOF
sudo pacman -Syu --noconfirm
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

sudo pacman -Syyu --noconfirm
printf "%b\n" "Installing packages"
install_packages "$PACKAGER" \
  libreoffice-fresh vlc curl flatpak fastfetch p7zip unrar tar rsync \
  exfat-utils fuse-exfat flac jdk-openjdk gimp vulkan-radeon lib32-vulkan-radeon \
  base-devel kate mangohud lib32-mangohud corectrl openssh dolphin \
  telegram-desktop htop discord steam
checkAurHelper
printf "%b\n" "Installing AUR packages with yay"
install_packages "yay" \
  postman-bin brave-bin visual-studio-code-bin

# corectrl autostart setup
printf "%b\n" "Setting up corectrl autostart"
mkdir -p $HOME/.config/autostart
cp /usr/share/applications/org.corectrl.CoreCtrl.desktop $HOME/.config/autostart/org.corectrl.CoreCtrl.desktop || true

# mangohud config
printf "%b\n" "Configuring MangoHud"
mkdir -p "$HOME/.config/MangoHud" && cp /usr/share/doc/mangohud/MangoHud.conf.example $HOME/.config/MangoHud/MangoHud.conf || true
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
source $HOME/.bashrc || true
pnpm add -g license gitignore

# Dotfiles array
dotfiles=(.gitignore .gitconfig .bashrc)

for dotfile in "${dotfiles[@]}"; do
  src="./$dotfile"
  dest="$HOME/$dotfile"
  if [ -f "$src" ]; then
    cp "$src" "$dest"
  else
    echo "Warning: $src not found, skipping."
  fi
done

# Source .bashrc to apply changes
source $HOME/.bashrc || true

printf "%b\n" "Mounting Drives..."

./auto-mount.sh

printf "%b\n" "Setup completed successfully!"
