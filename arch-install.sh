#!/usr/bin/env bash
set -euo pipefail

# CONFIG - EDIT THESE
DISK="your disk" UCODE="amd-ucode or intel-ucode" HOSTNAME="pc-name" USERNAME="username"
LOCALE="your locale" TIMEZONE="Region/Area" ROOT_PASS="changeme_root" USER_PASS="changeme_user"

echo "Disk: $DISK | Host: $HOSTNAME | User: $USERNAME | Confirm? (y/N): " && read -r c && [[ $c =~ ^[Yy]$ ]] || exit 1

# 1. PREP
pacman-key --init && pacman-key --populate archlinux
timedatectl set-ntp true

# 2. DISK (LUKS2 + LVM - YOUR EXACT LAYOUT)
wipefs -fa "$DISK" && sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1024M -t1:ef00 "$DISK" && sgdisk -n2:0:0 -t2:8309 "$DISK" && partprobe "$DISK"
EFI_PART="${DISK}p1" CRYPT_PART="${DISK}p2"

mkfs.fat -F32 "$EFI_PART"
echo "cryptlvm" | cryptsetup luksFormat --type luks2 --key-file - "$CRYPT_PART"
echo "cryptlvm" | cryptsetup open --allow-discards --key-file - "$CRYPT_PART" cryptlvm

pvcreate /dev/mapper/cryptlvm && vgcreate vg /dev/mapper/cryptlvm
lvcreate -l 100%FREE -n root vg && mkfs.ext4 /dev/vg/root

mount /dev/vg/root /mnt && mkdir -p /mnt/boot/efi && mount "$EFI_PART" /mnt/boot/efi

# 3. BASE SYSTEM
pacstrap /mnt base linux linux-firmware "$UCODE" sudo vim nano lvm2 dracut sbsigntools \
  iwd git ntfs-3g efibootmgr binutils networkmanager nftables sbctl man-db base-devel
genfstab -U /mnt >> /mnt/etc/fstab

CRYPT_UUID=$(blkid -s UUID -o value "$CRYPT_PART")

# 4. CHROOT SCRIPTS (FIXED VARIABLE PASSING)
cat > /mnt/root/install.conf << EOF
HOSTNAME=$HOSTNAME
USERNAME=$USERNAME
LOCALE=$LOCALE
KEYMAP=$KEYMAP
TIMEZONE=$TIMEZONE
ROOT_PASSWORD=$ROOT_PASS
USER_PASSWORD=$USER_PASS
CRYPT_UUID=$CRYPT_UUID
DISK=$DISK
EOF

cat > /mnt/root/chroot1.sh << 'EOF'
#!/bin/bash
source /root/install.conf
echo "root:$ROOT_PASSWORD" | chpasswd && echo "$USERNAME:$USER_PASSWORD" | chpasswd
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime && hwclock --systohc
sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen && locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP
FONT=Lat2-Terminus16
FONT_MAP=8859-1" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
cat >> /etc/hosts << EOH
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOH
useradd -m -G wheel "$USERNAME"
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
systemctl enable NetworkManager fstrim.timer
EOF

cat > /mnt/root/chroot2.sh << 'EOF'
#!/bin/bash
source /root/install.conf
mkdir -p /boot/efi/EFI/Linux /etc/pacman.d/hooks /usr/local/bin /etc/dracut.conf.d

cat > /usr/local/bin/dracut-install.sh << 'D1'
#!/bin/bash
mkdir -p /boot/efi/EFI/Linux
while read line; do [[ $line == usr/lib/modules/*/*pkgbase ]] && kver=${line#usr/lib/modules/}; kver=${kver%/pkgbase}; dracut --force --uefi --kver "$kver" /boot/efi/EFI/Linux/bootx64.efi; done
D1
cat > /usr/local/bin/dracut-remove.sh << 'D2'
#!/bin/bash
rm -f /boot/efi/EFI/Linux/bootx64.efi
D2
chmod +x /usr/local/bin/dracut-*

cat > /etc/pacman.d/hooks/90-dracut-install.hook << 'H1'
[Trigger]
Type=Path
Operation=Install
Operation=Upgrade
Target=usr/lib/modules/*/pkgbase
[Action]
Description=Updating linux EFI image
When=PostTransaction
Exec=/usr/local/bin/dracut-install.sh
Depends=dracut
NeedsTargets
H1

cat > /etc/pacman.d/hooks/60-dracut-remove.hook << 'H2'
[Trigger]
Type=Path
Operation=Remove
Target=usr/lib/modules/*/pkgbase
[Action]
Description=Removing linux EFI image
When=PreTransaction
Exec=/usr/local/bin/dracut-remove.sh
NeedsTargets
H2

echo "kernel_cmdline=\"rd.luks.uuid=$CRYPT_UUID rd.lvm.lv=vg/root root=/dev/mapper/vg-root rootfstype=ext4 rootflags=rw,relatime\"" > /etc/dracut.conf.d/cmdline.conf
echo 'compress="zstd"' > /etc/dracut.conf.d/flags.conf
pacman -S --noconfirm linux
efibootmgr --create --disk $DISK --part 1 --label "Arch Linux" --loader \\EFI\\Linux\\bootx64.efi --unicode
EOF

cat > /mnt/root/chroot3.sh << 'EOF'
#!/bin/bash
source /root/install.conf
pacman -Syu --noconfirm plasma sddm pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  firefox vlc flatpak steam telegram-desktop discord ntfs-3g corectrl mangohud
systemctl enable sddm

# AUR (yay)
su - $USERNAME -c 'cd /opt && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm && yay -S --noconfirm brave-bin'

# Firewall (YOUR EXACT RULES)
cat > /etc/nftables.conf << 'NFT'
#!/usr/bin/nft -f
destroy table inet filter
table inet filter {
  chain input { type filter hook input priority filter; policy drop;
    ct state invalid drop
    ct state {established, related} accept
    iif lo accept
    ip protocol icmp accept
    meta l4proto ipv6-icmp accept
    tcp dport {22,80,443} accept
    counter
  }
  chain forward { type filter hook forward priority filter; policy drop; }
}
NFT
systemctl enable --now nftables

# SecureBoot
sbctl create-keys && sbctl sign -s /boot/efi/EFI/Linux/bootx64.efi
echo 'uefi_secureboot_cert="/var/lib/sbctl/keys/db/db.pem"
uefi_secureboot_key="/var/lib/sbctl/keys/db/db.key"' > /etc/dracut.conf.d/secureboot.conf
sbctl enroll-keys --microsoft

# User config
mkdir -p /home/$USERNAME/.config/{autostart,MangoHud}
cp /usr/share/applications/org.corectrl.CoreCtrl.desktop /home/$USERNAME/.config/autostart/
cp /usr/share/doc/mangohud/MangoHud.conf.example /home/$USERNAME/.config/MangoHud/MangoHud.conf
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config
EOF

chmod +x /mnt/root/chroot*.sh
arch-chroot /mnt /root/chroot1.sh && arch-chroot /mnt /root/chroot2.sh && arch-chroot /mnt /root/chroot3.sh
rm /mnt/root/chroot*.sh /mnt/root/install.conf

echo "Unmounting..." && umount -R /mnt
echo "=== DONE! REBOOT ===" && echo "Login: $USERNAME/$USER_PASS | BIOS: Enable SecureBoot"
