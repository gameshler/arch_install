#!/bin/bash

background_checks() {
  # Check Arch environment
  [[ ! -f /usr/bin/pacstrap ]] && echo "Run from Arch ISO!" && exit 1
  # Check root
  [[ "$(id -u)" != "0" ]] && echo "ERROR! Run as root!" && exit 0
  # Check Arch
  [[ ! -e /etc/arch-release ]] && echo "This script must be run in Arch Linux!" && exit 0
  # Check pacman lock
  [[ -f /var/lib/pacman/db.lck ]] && echo "Pacman locked! Remove /var/lib/pacman/db.lck" && exit 0
}

select_option() {
  local options=("$@")
  local num_options=${#options[@]}
  local selected=0
  local last_selected=-1

  while true; do
    # Move cursor up to the start of the menu
    if [ $last_selected -ne -1 ]; then
      echo -ne "\033[${num_options}A"
    fi

    if [ $last_selected -eq -1 ]; then
      echo "Please select an option using the arrow keys and Enter:"
    fi
    for i in "${!options[@]}"; do
      if [ "$i" -eq $selected ]; then
        echo "> ${options[$i]}"
      else
        echo "  ${options[$i]}"
      fi
    done

    last_selected=$selected

    # Read user input
    read -rsn1 key
    case $key in
    $'\x1b') # ESC sequence
      read -rsn2 -t 0.1 key
      case $key in
      '[A') # Up arrow
        ((selected--))
        if [ $selected -lt 0 ]; then
          selected=$((num_options - 1))
        fi
        ;;
      '[B') # Down arrow
        ((selected++))
        if [ $selected -ge $num_options ]; then
          selected=0
        fi
        ;;
      esac
      ;;
    '') # Enter key
      break
      ;;
    esac
  done

  return $selected
}
set_password() {
  while true; do
    read -rs -p "Please enter password: " PASSWORD1
    echo -ne "\n"
    read -rs -p "Please re-enter password: " PASSWORD2
    echo -ne "\n"
    if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
      break
    else
      echo -ne "ERROR! Passwords do not match. \n"
    fi
  done
  export PASSWORD=$PASSWORD1
}

get_userinfo() {
  while true; do
    read -r -p "Please enter username: " username
    if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
      break
    fi
    echo "Incorrect username."
  done
  export USERNAME=$username

  set_password "USER_PASSWORD"

  while true; do
    read -r -p "Please name your machine: " hostname
    if [[ "${hostname,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
      break
    fi
  done
  export HOSTNAME=$hostname
}

select_disk() {
  options=($(lsblk -n -d -o NAME,SIZE | awk '$1!="sr0"{print "/dev/"$1"|"$2}'))
  PS3= "Select disk:"
  select_option "${options[@]}"
  export DISK="${options[$?]%|*}"
}

partition_disk() {
  wipefs -fa "$DISK"
  sgdisk -Z "$DISK"
  sgdisk -a 2048 -o "${DISK}"
  sgdisk -n 1::+1G -t 1:ef00 -c 1:"EFI" "$DISK"
  sgdisk -n 2:: -t 2:8309 -c 2:"LUKS" "$DISK"
  partprobe "${DISK}"
  if [[ "$DISK" =~ "nvme" ]]; then
    export EFI_PART="${DISK}p1"
    export LUKS_PART="${DISK}p2"
  else
    export EFI_PART="${DISK}1"
    export LUKS_PART="${DISK}2"
  fi
}
setup_luks_lvm() {
  mkfs.fat -F32 "$EFI_PART"
  set_password "LUKS_PASSWORD"
  export LUKS_PASSWORD="$LUKS_PASSWORD"
  echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$LUKS_PART"
  echo -n "$LUKS_PASSWORD" | cryptsetup open --allow-discards --persistent "$LUKS_PART" cryptlvm
  pvcreate /dev/mapper/cryptlvm
  vgcreate vg /dev/mapper/cryptlvm
  lvcreate -l 100%FREE vg -n root
}
format_filesystem() {
  mkfs.ext4 /dev/vg/root
  mount /dev/vg/root /mnt
  mkdir -p /mnt/boot/efi
  mount "$EFI_PART" /mnt/boot/efi
}

base_install() {
  pacman-key --init
  pacman-key --populate
  pacstrap /mnt base linux linux-firmware amd-ucode sudo \
    vim nano konsole lvm2 dracut sbsigntools git \
    ntfs-3g efibootmgr binutils networkmanager pacman
}
configure_fstab() {
  genfstab -U /mnt >>/mnt/etc/fstab
}

configure_system() {
  arch-chroot /mnt /bin/bash <<EOF
# Time/Locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
sed -i 's/^#en_GB.UTF-8/en_GB.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Hostname
echo "$HOSTNAME" > /etc/hostname

# Users
# Set root password 
echo "Setting root password:"
passwd

# Create user 
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Setting password for $USERNAME:"
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# Configure sudo 

# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Verify user is in wheel group 
usermod -aG wheel "$USERNAME"
systemctl enable NetworkManager
systemctl enable fstrim.timer

# Pacman
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

pacman -Sy
EOF
}

configure_uki() {

  # Create dracut scripts directory
  mkdir -p /usr/local/bin

  cat >/usr/local/bin/dracut-install.sh <<'INSTALL_SCRIPT'
#!/usr/bin/env bash

	mkdir -p /boot/efi/EFI/Linux

	while read -r line; do
		if [[ "$line" == 'usr/lib/modules/'+([^/])'/pkgbase' ]]; then
			kver="${line#'usr/lib/modules/'}"
			kver="${kver%'/pkgbase'}"

			dracut --force --uefi --kver "$kver" /boot/efi/EFI/Linux/bootx64.efi
		fi
	done
INSTALL_SCRIPT

  cat >/usr/local/bin/dracut-remove.sh <<'REMOVE_SCRIPT'
#!/usr/bin/env bash
 	rm -f /boot/efi/EFI/Linux/bootx64.efi
REMOVE_SCRIPT

  chmod +x /usr/local/bin/dracut-*

  mkdir -p /etc/pacman.d/hooks

  cat >/etc/pacman.d/hooks/90-dracut-install.hook <<'INSTALL_HOOK'
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
INSTALL_HOOK

  cat >/etc/pacman.d/hooks/60-dracut-remove.hook <<'REMOVE_HOOK'
  [Trigger]
	Type = Path
	Operation = Remove
	Target = usr/lib/modules/*/pkgbase

	[Action]
	Description = Removing linux EFI image
	When = PreTransaction
	Exec = /usr/local/bin/dracut-remove.sh
	NeedsTargets
REMOVE_HOOK

  local LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PART")
  cat >/etc/dracut.conf.d/cmdline.conf <<CMD_CONF
kernel_cmdline="rd.luks.uuid=luks-$LUKS_UUID rd.lvm.lv=vg/root root=/dev/mapper/vg-root rootfstype=ext4 rootflags=rw,relatime"
CMD_CONF

  cat >/etc/dracut.conf.d/flags.conf <<FLAGS_CONF
compress="zstd"
hostonly="no"
FLAGS_CONF
  pacman -S linux --noconfirm

}

configure_bootloader() {
  /bin/bash <<EOF
    for entry in \$(efibootmgr | grep 'Arch Linux' | awk '{print \$1}' | sed 's/Boot//;s/\*//'); do
        efibootmgr -b \$entry -B
    done
    
    efibootmgr --create --disk $DISK --part 1 --label "Arch Linux" --loader 'EFI\Linux\bootx64.efi' --unicode
    
    efibootmgr
EOF
}
configure_secureboot() {
  /bin/bash <<EOF
    pacman -S --noconfirm sbctl
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
}

configure_firewall() {
  pacman -S nftables --noconfirm
  cat >/etc/nftables.conf <<'NFT'
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

  cat >/etc/sysctl.d/90-network.conf <<'SYSCTL'
# Do not act as a router
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable ICMP redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
SYSCTL

  sysctl --system
  sudo pacman -Syu
}
install_kde() {

  pacman -S --noconfirm plasma sddm

  cat >/usr/local/bin/startplasma-wayland <<'SCRIPT'
#!/bin/bash
/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland
SCRIPT
  chmod +x /usr/local/bin/startplasma-wayland

  systemctl enable sddm
}
# --------------------------
# Main Script Execution
# --------------------------
main() {

  background_checks
  clear
  select_disk
  clear
  partition_disk
  clear
  setup_luks_lvm
  clear
  format_filesystem
  clear
  base_install
  clear
  configure_fstab
  clear
  # Configuration
  echo "=== Configuring System ==="
  echo "Please enter your desired timezone e.g. Europe/London :"
  read -r new_timezone
  echo "${new_timezone} set as timezone"
  export TIMEZONE=$new_timezone
  export KEYMAP="us"
  clear
  get_userinfo
  clear
  configure_system
  clear
  configure_uki
  clear
  configure_bootloader
  clear
  configure_secureboot
  clear
  configure_firewall
  clear
  # Optional KDE
  echo "Install KDE Plasma? (y/n)"
  read -n1 answer
  [[ "$answer" =~ [yY] ]] && install_kde

  # Completion
  echo "=== Installation Complete ==="
  echo "1. Reboot system"
  echo "2. Enable SecureBoot in BIOS"
  echo "3. Set BIOS password if desired"
  echo "4. Log in as $USERNAME"
}

main
