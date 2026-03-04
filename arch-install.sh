#!/bin/bash


exec > >(tee -a arch-install.log) 2>&1

# === INITIAL CHECKS ===
clear

# Safety checks
if [ ! -f /usr/bin/pacstrap ]; then
    echo "❌ Must run from Arch Linux ISO environment"
    exit 1
fi
if [[ $EUID -ne 0 ]]; then
    echo "❌ Must run as root"
    exit 1
fi

# Reusable selector (arrow keys)
select_option() {
    local options=("$@") num_options=${#options[@]} selected=0 last_selected=-1
    while true; do
        [ $last_selected -ne -1 ] && echo -ne "\033[${num_options}A"
        echo "Please select (↑↓ arrows, Enter):"
        for i in "${!options[@]}"; do
            [ "$i" -eq "$selected" ] && echo "> ${options[$i]}" || echo "  ${options[$i]}"
        done
        last_selected=$selected
        read -rsn1 key
        case $key in
            $'\x1b') read -rsn2 -t 0.1 key
                case $key in '[A') ((selected--)) [ $selected -lt 0 ] && selected=$((num_options-1));;
                               '[B') ((selected++)) [ $selected -ge $num_options ] && selected=0;; esac;;
            '') break;; esac
    done
    return $selected
}

# === USER INPUT ===
echo -e "\n🔧 Gathering system information...\n"

# Disk selection (WARNING!)
echo -e "\n💾 ⚠️  SELECT DISK - THIS WILL WIPE ALL DATA ⚠️"
PS3="Select disk to install on: "
mapfile -t disks < <(lsblk -n -o NAME,SIZE,TYPE | awk '$3=="disk" {print "/dev/"$1" ("$2")"}')
select_option "${disks[@]}"
DISK="${disks[$?]/ (*}"
echo "✅ Selected: $DISK"

# Timezone
timezone() {
    local tz=$(curl -s --fail https://ipapi.co/timezone 2>/dev/null || echo "")
    echo "🌍 Detected timezone: ${tz:-none}"
    local options=("Yes" "No" "Manual")
    select_option "${options[@]}"
    case $? in 0) export TIMEZONE=$tz;; 1) read -p "Enter timezone (Region/City): " TIMEZONE;; *) read -p "Enter timezone: " TIMEZONE;; esac
}
timezone

# Username/hostname
read -p "👤 Username: " USERNAME
read -rs -p "🔑 Password: " PASSWORD; echo
read -r -p "🏷️  Hostname: " HOSTNAME

# UCODE (detect CPU)
UCODE="amd-ucode"
grep -q "GenuineIntel" /proc/cpuinfo && UCODE="intel-ucode"
echo "🖥️  Using $UCODE"

# === DISK PARTITIONING (Your exact layout) ===
echo -e "\n💿 Partitioning $DISK (EFI + LUKS2 + LVM)..."
wipefs -af "$DISK"
gdisk "$DISK" <<EOF
o
n
1

+1G
EF00
n
2


8309
w
y
EOF

# Determine partition names
[[ $DISK =~ nvme ]] && EFI_PART="${DISK}p1" && LUKS_PART="${DISK}p2" || EFI_PART="${DISK}1" && LUKS_PART="${DISK}2"

# Format EFI
mkfs.fat -F32 "$EFI_PART"

# LUKS2 + LVM (YOUR EXACT GUIDE)
cryptsetup luksFormat --type luks2 "$LUKS_PART"
cryptsetup open --allow-discards "$LUKS_PART" cryptlvm
pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm
lvcreate -L 5G vg -n swap
lvcreate -L 25G vg -n root  
lvcreate -l 100%FREE vg -n home

mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home  
mkswap /dev/vg/swap; swapon /dev/vg/swap

# Mount everything
mount /dev/vg/root /mnt
mkdir -p /mnt/{home,boot/efi}
mount /dev/vg/home /mnt/home
mount "$EFI_PART" /mnt/boot/efi

# Mirrors & pacstrap (mkinitcpio UKI path)
timedatectl set-ntp true
pacman -Syy
reflector --country GB --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -S --noconfirm gptfdisk lvm2

# YOUR pacstrap (mkinitcpio UKI)
pacstrap /mnt base linux linux-firmware linux-lts $UCODE sudo vim lvm2 sbsigntools systemd systemd-ukify git ntfs-3g efibootmgr binutils networkmanager pacman konsole
genfstab -U /mnt >> /mnt/etc/fstab

# === CHROOT PHASE ===
echo "🔄 Entering chroot for system configuration..."
cat > /mnt/root-install.sh << 'EOF'
#!/bin/bash
set -e

# Timezone & locale (YOUR guide)
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# vconsole & hostname
cat > /etc/vconsole.conf << EOF2
KEYMAP=us
FONT=Lat2-Terminus16
FONT_MAP=8859-1
EOF2
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << EOF2
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF2

# Users (YOUR guide)
passwd << EOF3
$PASSWORD
$PASSWORD
EOF3
useradd -m -G wheel -s /bin/bash $USERNAME
passwd $USERNAME << EOF3
$PASSWORD
$PASSWORD
EOF3
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Essential services
systemctl enable NetworkManager fstrim.timer

# === MKINITCPIO UKI (YOUR exact guide) ===
cat > /etc/mkinitcpio.conf << 'EOF_MKI'
HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt lvm2 filesystems fsck)
EOF_MKI

# Kernel cmdline
LUKS_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)
echo "rd.luks.name=$LUKS_UUID=cryptlvm root=/dev/vg/root rootfstype=ext4 rw quiet bgrt_disable" > /etc/kernel/cmdline

# systemd-boot
bootctl --path=/boot/efi install
cat > /boot/efi/loader/loader.conf << EOF_LOADER
default arch-linux.efi
timeout 4
console-mode auto
editor no
EOF_LOADER

# Linux presets (YOUR exact config)
cat > /etc/mkinitcpio.d/linux.preset << EOF_PRESET
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default')
default_uki="/boot/efi/EFI/Linux/arch-linux.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"
fallback_uki="/boot/efi/EFI/Linux/arch-linux-fallback.efi"
fallback_options="-S autodetect"
EOF_PRESET

cat > /etc/mkinitcpio.d/linux-lts.preset << EOF_PRESET
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-lts"
PRESETS=('default')
default_uki="/boot/efi/EFI/Linux/arch-linux-lts.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"
fallback_uki="/boot/efi/EFI/Linux/arch-linux-lts-fallback.efi"
fallback_options="-S autodetect"
EOF_PRESET

mkinitcpio -P
systemctl enable systemd-boot-update.service

# === FIREWALL (nftables - YOUR exact rules) ===
pacman -S --noconfirm nftables
cat > /etc/nftables.conf << 'EOF_NFT'
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
EOF_NFT
systemctl enable --now nftables

# === KERNEL PARAMETERS (sysctl) ===
cat > /etc/sysctl.d/90-network.conf << EOF_SYSCTL
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
EOF_SYSCTL
sysctl --system


# === FINAL CLEANUP ===
echo "✅ Installation complete!"
echo "🔄 Reboot: reboot"
EOF

chmod +x /mnt/root-install.sh
arch-chroot /mnt /root-install.sh
rm /mnt/root-install.sh

echo -e "\n🎉 ARCH INSTALLATION COMPLETE!"
echo "📋 Log saved to: arch-install.log"
echo "🔄 Reboot when ready: reboot"

