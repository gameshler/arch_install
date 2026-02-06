#!/usr/bin/env bash
# Arch Linux Automated Installer 

set -euo pipefail

# =============================================================================
# CONFIGURATION - EDIT THESE VALUES FOR YOUR SYSTEM
# =============================================================================
DISK="/dev/nvme0n1"                    # Target disk (use lsblk to confirm)
EFI_SIZE="1024M"                       # EFI partition size
HOSTNAME="arch-secure"
USERNAME="gameshler"
LOCALE="en_GB.UTF-8"
KEYMAP="us"
TIMEZONE="Region/Area"              
UCODE="cpu-ucode"                      # IE: "intel-ucode" or "amd-ucode"
ROOT_PASSWORD="changeme_root"
USER_PASSWORD="changeme_user"


echo "=== Arch Linux Automated Installer ==="
echo "Disk: $DISK | Hostname: $HOSTNAME | User: $USERNAME"
echo "Timezone: $TIMEZONE | Locale: $LOCALE"
read -p "Confirm? (y/N): " confirm && [[ $confirm =~ ^[Yy]$ ]] || exit 1

# =============================================================================
# 1. PREPARATION
# =============================================================================
echo "Updating pacman keys..."
pacman-key --init
pacman-key --populate archlinux

timedatectl set-ntp true
iwctl device list 2>/dev/null | grep -q wlan || echo "Connect to WiFi manually first with: iwctl"

# =============================================================================
# 2. DISK PARTITIONING (LUKS2 + LVM)
# =============================================================================
echo "Wiping and partitioning $DISK..."
wipefs -fa "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n1:0:"$EFI_SIZE" -t1:ef00 "$DISK"
sgdisk -n2:0:0 -t2:8309 "$DISK"
partprobe "$DISK"

EFI_PART="${DISK}p1"
CRYPT_PART="${DISK}p2"

echo "Formatting EFI partition..."
mkfs.fat -F32 -n EFI "$EFI_PART"

echo "Setting up LUKS encryption..."
echo "cryptlvm" | cryptsetup luksFormat --type luks2 --key-file - "$CRYPT_PART"
echo "cryptlvm" | cryptsetup open --allow-discards --key-file - "$CRYPT_PART" cryptlvm

echo "Setting up LVM..."
pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm
lvcreate -l 100%FREE -n root vg
mkfs.ext4 -L root /dev/vg/root

# Mount filesystems
mount /dev/vg/root /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi



# =============================================================================
# 3. BASE SYSTEM INSTALL
# =============================================================================
echo "Installing base system..."
BASE_PKGS=(base linux linux-firmware "$UCODE" sudo vim nano konsole lvm2 dracut 
           sbsigntools iwd git ntfs-3g efibootmgr binutils networkmanager 
           nftables sbctl man-db base-devel)

pacstrap /mnt "${BASE_PKGS[@]}"

genfstab -U /mnt >> /mnt/etc/fstab

# =============================================================================
# 4. POST-CHROOT CONFIGURATION SCRIPTS
# =============================================================================

cat > /mnt/root/base_config.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Arguments passed from main script
HOSTNAME="${HOSTNAME}"
USERNAME="${USERNAME}"
LOCALE="${LOCALE}"
KEYMAP="${KEYMAP}"
TIMEZONE="${TIMEZONE}"
ROOT_PASSWORD="${ROOT_PASSWORD}"
USER_PASSWORD="${USER_PASSWORD}"

echo "root:${ROOT_PASSWORD}" | chpasswd
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

# Timezone
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# Locale
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Console
cat > /etc/vconsole.conf << EOC
KEYMAP=${KEYMAP}
FONT=Lat2-Terminus16
FONT_MAP=8859-1
EOC

# Hostname
echo "${HOSTNAME}" > /etc/hostname
cat >> /etc/hosts << EOC
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOC

# User setup
useradd -m -G wheel "${USERNAME}"
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers.d/*
EOF

cat > /mnt/root/uki_secureboot.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

CRYPT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)

# Dracut UKI hooks
mkdir -p /boot/efi/EFI/Linux /etc/pacman.d/hooks /usr/local/bin /etc/dracut.conf.d

cat > /usr/local/bin/dracut-install.sh << 'DRACUT_INSTALL'
#!/usr/bin/env bash
mkdir -p /boot/efi/EFI/Linux
while read -r line; do
    if [[ "$line" == 'usr/lib/modules/'+([^/])'/pkgbase' ]]; then
        kver="${line#'usr/lib/modules/'}"
        kver="${kver%'/pkgbase'}"
        dracut --force --uefi --kver "$kver" /boot/efi/EFI/Linux/bootx64.efi
    fi
done
DRACUT_INSTALL

cat > /usr/local/bin/dracut-remove.sh << 'DRACUT_REMOVE'
#!/usr/bin/env bash
rm -f /boot/efi/EFI/Linux/bootx64.efi
DRACUT_REMOVE

chmod +x /usr/local/bin/dracut-*

cat > /etc/pacman.d/hooks/90-dracut-install.hook << 'HOOK1'
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Target = usr/lib/modules/*/pkgbase

[Action]
Description = Updating linux EFI image
When = PostTransaction
Exec = /usr/local/bin/dracut-install.sh
Depends = dracut
NeedsTargets
HOOK1

cat > /etc/pacman.d/hooks/60-dracut-remove.hook << 'HOOK2'
[Trigger]
Type = Path
Operation = Remove
Target = usr/lib/modules/*/pkgbase

[Action]
Description = Removing linux EFI image
When = PreTransaction
Exec = /usr/local/bin/dracut-remove.sh
NeedsTargets
HOOK2

# Dracut config
echo "kernel_cmdline=\"rd.luks.uuid=${CRYPT_UUID} rd.lvm.lv=vg/root root=/dev/mapper/vg-root rootfstype=ext4 rootflags=rw,relatime\"" > /etc/dracut.conf.d/cmdline.conf
echo 'compress="zstd"' > /etc/dracut.conf.d/flags.conf

# Generate UKI
pacman -S --noconfirm linux

# EFI boot entry
efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Arch Linux" \
    --loader '\EFI\Linux\bootx64.efi' --unicode
ARCH_BOOT=$(efibootmgr | grep "Arch Linux" | cut -d' ' -f1 | tr -d '#*')
efibootmgr -o "$ARCH_BOOT"
EOF

cat > /mnt/root/kde_firewall.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

USERNAME="${USERNAME}"

# Enable services
systemctl enable NetworkManager fstrim.timer

# KDE Plasma + apps
pacman -S --noconfirm --needed plasma sddm pipewire pipewire-alsa pipewire-pulse \
    pipewire-jack wireplumber konsole dolphin kate ark spectacle krunner \
    partitionmanager firefox libreoffice-fresh vlc flatpak fastfetch p7zip \
    unrar rsync exfat-utils fuse-exfat flac jdk-openjdk gimp steam \
    vulkan-radeon lib32-vulkan-radeon mangohud lib32-mangohud corectrl \
    openssh telegram-desktop discord visual-studio-code-bin ntfs-3g

# SDDM setup
systemctl enable sddm

# Yay AUR helper
su - "$USERNAME" -c "
  cd /opt
  git clone https://aur.archlinux.org/yay-bin.git
  cd yay-bin
  makepkg -si --noconfirm
  yay -S --noconfirm postman-bin brave-bin
"

# Firewall (nftables)
cat > /etc/nftables.conf << 'NFT'
#!/usr/bin/nft -f
destroy table inet filter
table inet filter {
  chain input {
    type filter hook input priority filter; policy drop;
    ct state invalid drop comment "early drop of invalid connections"
    ct state {established, related} accept comment "allow tracked connections"
    iif lo accept comment "allow from loopback"
    ip protocol icmp accept comment "allow icmp"
    meta l4proto ipv6-icmp accept comment "allow icmp v6"
    meter ssh_conn_limit { ip saddr timeout 30s limit rate 6/minute } counter jump ssh_check
    tcp dport 22 accept comment "allow SSH"
    tcp dport 80 accept comment "allow HTTP"
    tcp dport 443 accept comment "allow HTTPS"
    pkttype host limit rate 5/second counter reject with icmpx type admin-prohibited
    counter
  }
  chain ssh_check {
    tcp dport 22 counter accept comment "SSH passed brute-force check"
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
  }
}
NFT

systemctl enable --now nftables

# Kernel parameters
cat > /etc/sysctl.d/90-network.conf << 'SYSCTL'
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
SYSCTL
sysctl --system

# SecureBoot setup
sbctl create-keys
sbctl sign -s /boot/efi/EFI/Linux/bootx64.efi
echo 'uefi_secureboot_cert="/var/lib/sbctl/keys/db/db.pem"' > /etc/dracut.conf.d/secureboot.conf
echo 'uefi_secureboot_key="/var/lib/sbctl/keys/db/db.key"' >> /etc/dracut.conf.d/secureboot.conf

cat > /etc/pacman.d/hooks/zz-sbctl.hook << 'SBCTL_HOOK'
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
SBCTL_HOOK

sbctl enroll-keys --microsoft

# CoreCtrl autostart
mkdir -p /home/"$USERNAME"/.config/autostart
cp /usr/share/applications/org.corectrl.CoreCtrl.desktop /home/"$USERNAME"/.config/autostart/
chown -R "$USERNAME:$USERNAME" /home/"$USERNAME"/.config

# MangoHud
mkdir -p /home/"$USERNAME"/.config/MangoHud
cp /usr/share/doc/mangohud/MangoHud.conf.example /home/"$USERNAME"/.config/MangoHud/MangoHud.conf
chown -R "$USERNAME:$USERNAME" /home/"$USERNAME"/.config

echo "Installation complete! Reboot and enroll SecureBoot keys in BIOS (Setup Mode)."
EOF

chmod +x /mnt/root/*.sh

# =============================================================================
# 5. RUN CHROOT SCRIPTS
# =============================================================================
echo "Running chroot configuration..."
arch-chroot /mnt /bin/bash /root/base_config.sh \
    HOSTNAME="$HOSTNAME" USERNAME="$USERNAME" LOCALE="$LOCALE" \
    KEYMAP="$KEYMAP" TIMEZONE="$TIMEZONE" \
    ROOT_PASSWORD="$ROOT_PASSWORD" USER_PASSWORD="$USER_PASSWORD"

arch-chroot /mnt /bin/bash /root/uki_secureboot.sh
arch-chroot /mnt /bin/bash /root/kde_firewall.sh

# Cleanup
rm -rf /mnt/root/*.sh

# =============================================================================
# 6. UNMOUNT AND FINISH
# =============================================================================
echo "Unmounting filesystems..."
umount -R /mnt
swapoff -a 2>/dev/null || true

echo ""
echo "=== INSTALLATION COMPLETE! ==="
echo "1. Remove USB drive"
echo "2. Reboot: reboot"
echo "3. Enter BIOS -> Enable SecureBoot (Setup Mode first)"
echo "4. Enroll sbctl keys if needed"
echo "5. Login as $USERNAME / $USER_PASSWORD"
echo "6. Change passwords immediately!"
echo ""
echo "Default KDE Plasma with Wayland, SecureBoot, LUKS2+LVM, nftables, all your apps!"
