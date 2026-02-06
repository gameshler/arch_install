#!/usr/bin/env bash
 
set -euo pipefail

# =============================================================================
# CONFIG - EDIT THESE FOR YOUR SYSTEM
# =============================================================================
DISK="drive name"                    # lsblk to confirm!
HOSTNAME="arch-secure"
USERNAME="username" 
ROOT_PASSWORD="changeme_root"
USER_PASSWORD="changeme_user"
UCODE="amd-ucode or intel-ucode"          
TIMEZONE="Region/Area"
LOCALE="your locale"
KEYMAP="your keymap"

clear
echo "=== ARCH INSTALLER ==="
echo "Disk: $DISK | User: $USERNAME | Host: $HOSTNAME"
read -p "CONFIRM WIPE $DISK? (y/N): " confirm && [[ $confirm =~ ^[Yy]$ ]] || { echo "Aborted"; exit 1; }

# =============================================================================
# 1. PREP 
# =============================================================================
echo "→ Preparing system..."
pacman-key --init
pacman-key --populate 
timedatectl set-ntp true

# =============================================================================
# 2. DISK PARTITIONING 
# =============================================================================
echo "→ Partitioning $DISK (EFI + LUKS2 + LVM)..."
wipefs -fa "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G -t1:EF00 "$DISK"      # EFI 1GB
sgdisk -n2:0:0   -t2:8309 "$DISK"      # LUKS remaining
partprobe "$DISK"

EFI_PART="${DISK}p1"
LUKS_PART="${DISK}p2"

mkfs.fat -F32 "$EFI_PART"
echo "cryptlvm" | cryptsetup luksFormat --type luks2 --key-file - "$LUKS_PART"
echo "cryptlvm" | cryptsetup open --allow-discards --key-file - "$LUKS_PART" cryptlvm

pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm  
lvcreate -l 100%FREE -n root vg
mkfs.ext4 -L root /dev/vg/root

mount /dev/vg/root /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi

# =============================================================================
# 3. BASE SYSTEM
# =============================================================================
echo "→ Installing base system..."
pacstrap /mnt base linux linux-firmware "$UCODE" sudo vim nano konsole lvm2 dracut \
  sbsigntools iwd git ntfs-3g efibootmgr binutils networkmanager pacman man-db \
  base-devel nftables sbctl

genfstab -U /mnt >> /mnt/etc/fstab
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PART")

# =============================================================================
# 4. CHROOT CONFIG
# =============================================================================
cat > /mnt/root/config << EOF
HOSTNAME=$HOSTNAME
USERNAME=$USERNAME
ROOT_PASSWORD=$ROOT_PASSWORD
USER_PASSWORD=$USER_PASSWORD
LOCALE=$LOCALE
KEYMAP=$KEYMAP
TIMEZONE=$TIMEZONE
LUKS_UUID=$LUKS_UUID
DISK=$DISK
EOF

cat > /mnt/root/chroot.sh << 'EOF'
#!/bin/bash
set -euo pipefail
source /root/config

# YOUR BASIC CONFIG
echo "root:$ROOT_PASSWORD" | chpasswd
echo "$USERNAME:$USER_PASSWORD" | chpasswd
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP
FONT=Lat2-Terminus16
FONT_MAP=8859-1" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts << EOH
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain $HOSTNAME
EOH
useradd -m -G wheel "$USERNAME"
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
systemctl enable NetworkManager fstrim.timer

# YOUR DRACUT UKI HOOKS (EXACT COPY)
mkdir -p /boot/efi/EFI/Linux /etc/pacman.d/hooks /usr/local/bin /etc/dracut.conf.d
cat > /usr/local/bin/dracut-install.sh << 'D1'
#!/usr/bin/env bash
mkdir -p /boot/efi/EFI/Linux
while read -r line; do
  if [[ "$line" == 'usr/lib/modules/'+([^/])'/pkgbase' ]]; then
    kver="${line#'usr/lib/modules/'}"
    kver="${kver%'/pkgbase'}"
    dracut --force --uefi --kver "$kver" /boot/efi/EFI/Linux/bootx64.efi
  fi
done
D1
cat > /usr/local/bin/dracut-remove.sh << 'D2'
#!/usr/bin/env bash
rm -f /boot/efi/EFI/Linux/bootx64.efi
D2
chmod +x /usr/local/bin/dracut-*

cat > /etc/pacman.d/hooks/90-dracut-install.hook << 'H1'
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
H1
cat > /etc/pacman.d/hooks/60-dracut-remove.hook << 'H2'
[Trigger]
Type = Path
Operation = Remove
Target = usr/lib/modules/*/pkgbase
[Action]
Description = Removing linux EFI image
When = PreTransaction
Exec = /usr/local/bin/dracut-remove.sh
NeedsTargets
H2

echo "kernel_cmdline=\"rd.luks.uuid=$LUKS_UUID rd.lvm.lv=vg/root root=/dev/mapper/vg-root rootfstype=ext4 rootflags=rw,relatime\"" > /etc/dracut.conf.d/cmdline.conf
echo 'compress="zstd"
hostonly="no"' > /etc/dracut.conf.d/flags.conf

# Generate UKI
pacman -S --noconfirm linux
efibootmgr --create --disk $DISK --part 1 --label "Arch Linux" --loader '\EFI\Linux\bootx64.efi' --unicode

# YOUR SECUREBOOT (EXACT)
pacman -S --noconfirm sbctl
sbctl create-keys
sbctl sign -s /boot/efi/EFI/Linux/bootx64.efi
cat > /etc/dracut.conf.d/secureboot.conf << 'SB'
uefi_secureboot_cert="/var/lib/sbctl/keys/db/db.pem"
uefi_secureboot_key="/var/lib/sbctl/keys/db/db.key"
SB
cat > /etc/pacman.d/hooks/zz-sbctl.hook << 'SBH'
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
SBH
sbctl enroll-keys --microsoft

# YOUR NFTABLES (EXACT COPY)
cat > /etc/nftables.conf << 'NFT'
#!/usr/bin/nft -f
destroy table inet filter
table inet filter {
  chain input {
    type filter hook input priority filter
    policy drop
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
    type filter hook forward priority filter
    policy drop
  }
}
NFT
systemctl enable --now nftables

cat > /etc/sysctl.d/90-network.conf << 'SYS'
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
SYS
sysctl --system

pacman -S sudo pacman -S firefox libreoffice-fresh vlc curl flatpak fastfetch p7zip unrar tar rsync exfat-utils fuse-exfat flac jdk-openjdk gimp steam vulkan-radeon lib32-vulkan-radeon base-devel kate mangohud lib32-mangohud corectrl openssh dolphin telegram-desktop discord visual-studio-code-bin sddm --needed --noconfirm

systemctl enable sddm

# YOUR YAY AUR
su - "$USERNAME" -c "
  mkdir -p /opt
  cd /opt
  git clone https://aur.archlinux.org/yay-bin.git
  cd yay-bin
  makepkg -si --noconfirm
  yay -S --noconfirm postman-bin brave-bin
"

# YOUR PACMAN CONFIG
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads 5/' /etc/pacman.conf
sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf

# YOUR CORECTRL + MANGOHUD
mkdir -p "/home/$USERNAME/.config/autostart"
cp /usr/share/applications/org.corectrl.CoreCtrl.desktop "/home/$USERNAME/.config/autostart/"
mkdir -p "/home/$USERNAME/.config/MangoHud"
cp /usr/share/doc/mangohud/MangoHud.conf.example "/home/$USERNAME/.config/MangoHud/MangoHud.conf"
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"

pacman -Syyu --noconfirm
EOF

chmod +x /mnt/root/chroot.sh
echo "→ Running chroot configuration (30-45 mins)..."
arch-chroot /mnt /root/chroot.sh
rm /mnt/root/chroot.sh /mnt/root/config

# =============================================================================
# 5. CLEANUP & FINISH
# =============================================================================
echo "→ Unmounting..."
umount -R /mnt
echo "=== INSTALLATION COMPLETE! ==="
