#!/bin/bash

exec > >(tee -i archsetup.txt)
exec 2>&1

background_checks() {
  # Check Arch environment
  [[ ! -f /usr/bin/pacstrap ]] && echo "Run from Arch ISO!" && exit 1
  # Check root
  [[ "$(id -u)" != "0" ]] && echo "ERROR! Run as root!" && exit 1
  # Check Arch
  [[ ! -e /etc/arch-release ]] && echo "This script must be run in Arch Linux!" && exit 1
  # Check pacman lock
  [[ -f /var/lib/pacman/db.lck ]] && echo "Pacman locked! Remove /var/lib/pacman/db.lck" && exit 1
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
  read -rs -p "Please enter password: " PASSWORD1
  echo -ne "\n"
  read -rs -p "Please re-enter password: " PASSWORD2
  echo -ne "\n"
  if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
    break
  else
    echo -ne "ERROR! Passwords do not match. \n"
  fi
  export PASSWORD=$PASSWORD1
}
filesystem() {
  echo -ne "
    Please Select your file system for both boot and root
    "
  options=("btrfs" "ext4" "luks" "exit")
  select_option "${options[@]}"

  case $? in
  0) export FS=btrfs ;;
  1) export FS=ext4 ;;
  2)
    set_password "LUKS_PASSWORD"
    export FS=luks
    ;;
  3) exit ;;
  *)
    echo "Wrong option please select again"
    filesystem
    ;;
  esac

}
timezone() {

  echo "Please enter your desired timezone e.g. Europe/London :"
  read -r new_timezone
  echo "${new_timezone} set as timezone"
  export TIMEZONE=$new_timezone

}
keymap() {
  echo -ne "
    Please select key board layout from this list"
  # These are default key maps as presented in official arch repo archinstall
  # shellcheck disable=SC1010
  options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru se sg ua uk)

  select_option "${options[@]}"
  keymap=${options[$?]}

  echo -ne "Your key boards layout: ${keymap} \n"
  export KEYMAP=$keymap
}
drivessd() {
  echo -ne "
    Is this an ssd? yes/no:
    "

  options=("Yes" "No")
  select_option "${options[@]}"

  case ${options[$?]} in
  y | Y | yes | Yes | YES)
    export MOUNT_OPTIONS="noatime,compress=zstd,ssd,commit=120"
    ;;
  n | N | no | NO | No)
    export MOUNT_OPTIONS="noatime,compress=zstd,commit=120"
    ;;
  *)
    echo "Wrong option. Try again"
    drivessd
    ;;
  esac
}
diskpart() {

  PS3='
    Select the disk to install on: '
  options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

  select_option "${options[@]}"
  disk=${options[$?]%|*}

  echo -e "\n${disk%|*} selected \n"
  export DISK=${disk%|*}

}
userinfo() {
  # Loop through user input until the user gives a valid username
  while true; do
    read -r -p "Please enter username: " username
    if [[ "${username,,}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
      break
    fi
    echo "Incorrect username."
  done
  export USERNAME=$username

  # Loop through user input until the user gives a valid hostname, but allow the user to force save
  while true; do
    read -r -p "Please name your machine: " name_of_machine
    # hostname regex (!!couldn't find spec for computer name!!)
    if [[ "${name_of_machine,,}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then
      break
    fi
    # if validation fails allow the user to force saving of the hostname
    read -r -p "Hostname doesn't seem correct. Do you still want to save it? (y/n)" force
    if [[ "${force,,}" = "y" ]]; then
      break
    fi
  done
  export NAME_OF_MACHINE=$name_of_machine
}

# starting functions
background_checks
clear
userinfo
clear
diskpart
clear
filesystem
clear
timezone
clear
keymap

pacman -Sy
pacman -S --noconfirm archlinux-keyring
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
if [ ! -d "/mnt" ]; then
  mkdir /mnt
fi

pacman -S --noconfirm --needed gptfdisk
umount -A --recursive /mnt
wipefs -fa "${DISK}"
sync
# Create fresh GPT table
sgdisk -Z "${DISK}"
sync
partprobe "${DISK}"
sleep 2
# Create partitions
sgdisk -a 2048 -o "${DISK}"
sync
partprobe "${DISK}"
sleep 2
sgdisk -n 1::+2G --typecode=1:ef00 --change-name=1:"EFI" "${DISK}"
sync
partprobe "${DISK}"
sleep 2
sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:"ROOT" "${DISK}"
sync
partprobe "${DISK}"
sleep 3
echo "Verifying partition table:"
sgdisk -p "${DISK}"
lsblk -f "${DISK}"
sleep 3
createsubvolumes() {
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
}

# @description Mount all btrfs subvolumes after root has been mounted.
mountallsubvol() {
  mount -o "${MOUNT_OPTIONS}",subvol=@home "${partition2}" /mnt/home
}

# @description BTRFS subvolulme creation and mounting.
subvolumesetup() {
  # create nonroot subvolumes
  createsubvolumes
  # unmount root to remount with subvolume
  umount /mnt
  # mount @ subvolume
  mount -o "${MOUNT_OPTIONS}",subvol=@ "${partition2}" /mnt
  # make directories home, .snapshots, var, tmp
  mkdir -p /mnt/home
  # mount subvolumes
  mountallsubvol
}

if [[ "${DISK}" =~ "nvme" ]]; then
  partition1=${DISK}p1
  partition2=${DISK}p2

else
  partition1=${DISK}1
  partition2=${DISK}2
fi

if [[ "${FS}" == "btrfs" ]]; then
  mkfs.fat -F32 -n "EFI" "${partition1}"
  mkfs.btrfs -f "${partition2}"
  mount -t btrfs "${partition2}" /mnt
  subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
  mkfs.fat -F32 -n "EFI" "${partition1}"
  mkfs.ext4 "${partition2}"
  mount -t ext4 "${partition2}" /mnt
elif [[ "${FS}" == "luks" ]]; then
  mkfs.fat -F32 "${partition1}"
  # enter luks password to cryptsetup and format root partition
  set_password "LUKS_PASSWORD"
  echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat --type luks2 "${partition2}" -
  # open luks container and ROOT will be place holder
  echo -n "${LUKS_PASSWORD}" | cryptsetup open --allow-discards --persistent "${partition2}" ROOT -
  # now format that container
  mkfs.btrfs -f "${partition2}"
  mount -t btrfs "${partition2}" /mnt
  subvolumesetup
  ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value "${partition2}")
fi
BOOT_UUID=$(blkid -s UUID -o value "${partition2}")
EFI_UUID=$(blkid -s UUID -o value "${partition1}")
sync
if ! mountpoint -q /mnt; then
  echo "ERROR! Failed to mount ${partition2} to /mnt after multiple attempts."
  exit 1
fi
mkdir -p /mnt/boot/efi
mount -U "${EFI_UUID}" /mnt/boot/efi

pacman-key --init
pacman-key --populate
pacstrap /mnt base base-devel linux linux-firmware amd-ucode sudo \
  vim nano konsole lvm2 dracut sbsigntools git \
  ntfs-3g efibootmgr binutils networkmanager pacman --noconfirm --needed

genfstab -U /mnt >>/mnt/etc/fstab
cat /mnt/etc/fstab

arch-chroot /mnt /bin/bash -c "KEYMAP='${KEYMAP}' /bin/bash" <<EOF
systemctl enable NetworkManager
systemctl enable fstrim.timer
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
# Time/Locale
ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
hwclock --systohc
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add parallel downloading
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
#Set colors and enable the easter egg
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf
#Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm --needed
# Users
groupadd libvirt
useradd -m -G wheel,libvirt -s /bin/bash $USERNAME
echo "$USERNAME created, home directory created, added to wheel and libvirt group, default shell set to /bin/bash"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "$USERNAME password set"
# Set root password 
echo "Setting root password:"
passwd
# Hostname
echo $NAME_OF_MACHINE > /etc/hostname
pacman -Syu man-db

# Configure sudo 

# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

EOF

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
mkdir -p /etc/dracut.conf.d

if [[ "$FS" == "luks" ]]; then
  # LUKS configuration
  cat >/etc/dracut.conf.d/cmdline.conf <<CMD_CONF
kernel_cmdline="rd.luks.uuid="${ENCRYPTED_PARTITION_UUID}"  root=UUID=${BOOT_UUID} rootfstype=btrfs rootflags=${MOUNT_OPTIONS}"
CMD_CONF

elif [[ "$FS" == "btrfs" ]]; then
  # Plain Btrfs configuration
  cat >/etc/dracut.conf.d/cmdline.conf <<CMD_CONF
kernel_cmdline="root=UUID=${BOOT_UUID} rootfstype=btrfs rootflags=${MOUNT_OPTIONS}"
CMD_CONF

else
  # ext4 configuration
  cat >/etc/dracut.conf.d/cmdline.conf <<CMD_CONF
kernel_cmdline="root=UUID=${BOOT_UUID} rootfstype=ext4 rootflags=${MOUNT_OPTIONS}"
CMD_CONF
fi

cat >/etc/dracut.conf.d/flags.conf <<FLAGS_CONF
compress="zstd"
hostonly="no"
FLAGS_CONF
pacman -S linux --noconfirm
/bin/bash <<EOF
    for entry in \$(efibootmgr | grep 'Arch Linux' | awk '{print \$1}' | sed 's/Boot//;s/\*//'); do
        efibootmgr -b \$entry -B
    done
    
    efibootmgr --create --disk ${DISK} --part 1 --label "Arch Linux" --loader 'EFI\Linux\bootx64.efi' --unicode
    
    efibootmgr
EOF

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
pacman -Syu

install_kde() {

  pacman -S --noconfirm plasma sddm

  cat >/usr/local/bin/startplasma-wayland <<'SCRIPT'
#!/bin/bash
/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland
SCRIPT
  chmod +x /usr/local/bin/startplasma-wayland

  systemctl enable sddm
}
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
