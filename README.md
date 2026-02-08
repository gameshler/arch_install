# Arch Install

## Table of Contents

1. [Introduction](#Introduction)

   - Pre-requisites & Checklist
   - Preparing the USB and Booting the Installer

2. [Disk Partitioning](#Disk-Partitioning)

   - Wiping and Partitioning the Drive
   - Creating Encrypted Volume and LVM Setup
   - Mounting the Partitions

3. [System Bootstrapping](#System-Bootstrapping)

   - Pacman Setup and System Base Installation
   - Basic Configuration (Timezone, Locale, User Creation, etc.)

4. [Unified Kernel Image (UKI) Setup](#Unified-Kernel-Image)

   - Dracut Setup and Pacman Hooks
   - Generating the Unified Kernel Image
   - UEFI Boot Entry Configuration

5. [SecureBoot Configuration](#SecureBoot-Configuration)

   - Enabling SecureBoot in BIOS
   - Signing EFI Binaries with `sbctl`
   - SecureBoot Key Enrollment

6. [Firewall Configuration](#Firewall-Configuration)

   - Installing and Configuring `nftables`
   - Configuring Kernel Network Parameters

7. [Password Manager](#Password-Manager)

   - Installing KeePassXC for Password Management

8. [KDE Plasma Installation / Arch DWM on Arch Linux](#KDE-Plasma-Installation)

   - Installing KDE Plasma Desktop Environment
   - Wayland Session Setup
   - Creating Custom Login Manager Script
   - Arch DWM

9. [Arch Linux Setup Guide](#Arch-Linux-Setup-Guide)

   - Automating Installation with a Script

10. [Applications and Packages](#Applications-and-Packages)

    - Essential Applications Installation
    - Yay AUR Helper Setup
    - System Configuration and Tweaks

11. [Additional Tools and Configurations](#Additional-Tools-and-Configuration)
    - CoreCtrl, MangoHud, and Node.js Setup
    - Github SSH Setup and Global Modules

# Introduction

A walkthrough installation guide for a secure arch linux based system.

**Check this list before starting!**

- Your computer supports SecureBoot/UEFI
- Your computer allows for enrollment of your own secureboot keys
- Your computer does not have manufacturer's backdoors

## Preparing USB and booting the installer

Download the latest Archlinux ISO and copy it to your USB:

    sudo dd if=/path/to/file.iso of=/dev/sdX status=progress
    sync

Reboot your machine and if enabled, disable secureboot in BIOS. After that, boot ArchLinux USB.

When your installer has booted, especially on laptop, you may want to enable WiFi connection:

    iwctl
    station wlan0 connect SSID
    <password prompt>
    exit

## Disk Partitioning

Following example assumes you have a nvme drive. Your drive may as well report as /dev/sdX.

> Before doing anything make sure you have a wiped drive: `lsblk` if needed

```
wipefs -fa /dev/nvme0n1
```

You can use your favorite tool, that supports creating the GPT partition, for example `gdisk`:

    +----------------------+----------------------+----------------------+----------------------+
    | EFI system partition |         LVM                                                        |
    |                      |                                                                    |
    | /efi                 |         /                                                          |
    |                      |                                                                    |
    | /dev/nvme0n1p1       |         /dev/vg/root                                               |
    |                      |----------------------+----------------------+----------------------+
    | unencrypted          | /dev/nvme0n1p2 encrypted using LUKS2                               |
    +----------------------+--------------------------------------------------------------------+

My partition sizes and used partition codes look like this:

    /dev/nvme0n1p1 - EFI - 1024MB;				partition code EF00
    /dev/nvme0n1p2 - encrypted LUKS - remaining space;	partition code 8309

The lack of SWAP partition is intentional; if you need it, you can configure SWAP as file in your filesystem later.

We also need to format EFI partition:

    mkfs.fat -F32 /dev/nvme0n1p1

Now we can create encrypted volume and open it:

    cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
    cryptsetup open --allow-discards --persistent /dev/nvme0n1p2 cryptlvm

Configuring LVM and formatting root partition:

    pvcreate /dev/mapper/cryptlvm
    vgcreate vg /dev/mapper/cryptlvm
    lvcreate -l 100%FREE vg -n root

    mkfs.ext4 /dev/vg/root

After all is done we need to mount our drives:

    mount /dev/vg/root /mnt
    mkdir -p /mnt/boot/efi
    mount /dev/nvme0n1p1 /mnt/boot/efi

> If you have more than one drive you can use `automount.sh`, make sure to gdisk before using it:

> you can use `wipefs`,`gdisk` and mkfs your preferred fs type if needed and make sure they are setup as default (if the drive has data dont use neither wipefs nor gdisk)

    mkfs.ext4 -L Storage /dev/nvme1n1p1
    mkdir -p /mnt/storage
    mount /dev/nvme1n1p1 /mnt/storage

Editing /etc/fstab later to assign uuid's (use `blkid /mnt/storage` to get the uuid)

```
UUID=YOUR_UUID   /mnt/storage    ntfs-3g or ext4       defaults,noatime 0 2

```

```
blkid -s UUID -o value /dev/nvme0n1p1 >> /etc/fstab
```

load the `/etc/fstab`:

```
mount -a
```

> Note: if you have an sda make sure to install `ntfs-3g`
> If later after booting into the system you cant write to the drive unless with sudo:

```
sudo chown -R $USER:$USER /mnt/storage # you can use `whoami` to check your system name
```

## System Bootstrapping

It seems pacman now requires PGP shenaningans, so first of all I had to execute:

        pacman-key --init
    pacman-key --populate

_In the next step it is recommended to install CPU microcode package. Depending on whether you have intel of amd you should append intel-ucode or amd-ucode to your pacstrap_

My pacstrap presents as follows:

    pacstrap /mnt base linux linux-firmware YOUR_UCODE_PACKAGE sudo vim nano konsole lvm2 dracut sbsigntools iwd git ntfs-3g efibootmgr binutils networkmanager pacman

Generate fstab:

    genfstab -U /mnt >> /mnt/etc/fstab

Now you can chroot to your system and perform some basic configuration:

    arch-chroot /mnt

Set the root password:

    passwd

My suggestion is to also install man for additional help you may require:

    pacman -Syu man-db

Set timezone and generate /etc/adjtime:

    ln -sf /usr/share/zoneinfo/<Region>/<city> /etc/localtime
    hwclock --systohc

Set your desired locale:

    vim /etc/locale.gen # uncomment locales you want
    locale-gen

    vim /etc/locale.conf
    	LANG=en_GB.UTF-8

Configure your keyboard layout:

    vim /etc/vconsole.conf
    	KEYMAP=us
    	FONT=Lat2-Terminus16
    	FONT_MAP=8859-1

Set your hostname:

    vim /etc/hostname

Create your user:

    useradd -m YOUR_NAME
    passwd YOUR_NAME

Add your user to sudo:

    visudo
    	%wheel	ALL=(ALL) ALL # Uncomment this line

    usermod -aG wheel YOUR_NAME

Enable some basic systemd units:

```
 systemctl enable NetworkManager # Letter case is important !!!!!!
 systemctl enable fstrim.timer
```

## Unified Kernel Image

Create dracut scripts that will hook into pacman:

    vim /usr/local/bin/dracut-install.sh

    	#!/usr/bin/env bash

    	mkdir -p /boot/efi/EFI/Linux

    	while read -r line; do
    		if [[ "$line" == 'usr/lib/modules/'+([^/])'/pkgbase' ]]; then
    			kver="${line#'usr/lib/modules/'}"
    			kver="${kver%'/pkgbase'}"

    			dracut --force --uefi --kver "$kver" /boot/efi/EFI/Linux/bootx64.efi
    		fi
    	done

And the removal script:

    vim /usr/local/bin/dracut-remove.sh

    	#!/usr/bin/env bash
     	rm -f /boot/efi/EFI/Linux/bootx64.efi

Make those scripts executable and create pacman's hook directory:

    chmod +x /usr/local/bin/dracut-*
    mkdir /etc/pacman.d/hooks

Now the actual hooks, first for the install and upgrade:

     vim /etc/pacman.d/hooks/90-dracut-install.hook

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

And for removal:

    vim /etc/pacman.d/hooks/60-dracut-remove.hook

    	[Trigger]
    	Type = Path
    	Operation = Remove
    	Target = usr/lib/modules/*/pkgbase

    	[Action]
    	Description = Removing linux EFI image
    	When = PreTransaction
    	Exec = /usr/local/bin/dracut-remove.sh
    	NeedsTargets

Check UUID of your encrypted volume and write it to file you will edit next:

    blkid -s UUID -o value /dev/nvme0n1p2 >> /etc/dracut.conf.d/cmdline.conf

Edit the file and fill with with kernel arguments:

    vim /etc/dracut.conf.d/cmdline.conf
    	kernel_cmdline="rd.luks.uuid=luks-YOUR_UUID rd.lvm.lv=vg/root root=/dev/mapper/vg-root rootfstype=ext4 rootflags=rw,relatime"

Create file with flags:

    vim /etc/dracut.conf.d/flags.conf
    	compress="zstd"
    	hostonly="no"

Generate your image by re-installing `linux` package and making sure the hooks work properly:

    pacman -S linux

> You should have `bootx64.efi` within your `/efi/EFI/Linux/`
> note: you can check for bootx64.efi to make sure its setup correctly ls -alh /boot/efi/EFI/Linux

Now you only have to add UEFI boot entry and create an order of booting:

    efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Arch Linux" --loader 'EFI\Linux\bootx64.efi' --unicode

    efibootmgr 		# Check if you have left over UEFI entries, remove them with efibootmgr -b INDEX -B and note down Arch index
    efibootmgr -o ARCH_INDEX_FROM_PREVIOUS_COMMAND # 0 or whatever number your Arch entry shows as

Now you can reboot and log into your system.

:exclamation: :exclamation: :exclamation: **Compatibility thing I noticed** :exclamation: :exclamation: :exclamation:

Some (older?) platforms can ignore entries by efibootmgr all together and just look for `EFI\BOOT\bootx64.efi`, in that case you may generate your UKI directly to that directory and under that name. It's very important that the name is also `bootx64.efi`.

## SecureBoot Configuration

At this point you should enable Setup Mode for SecureBoot in your BIOS, and erase your existing keys (it may spare you setting attributes for efi vars in OS). If your system does not offer reverting to default keys (useful if you want to install windows later), you should backup them, though this will not be described here.

Configuring SecureBoot is easy with sbctl:

    pacman -S sbctl

Check your status, setup mode should be enabled (You can do that in BIOS):

    sbctl status
      Installed:      ✘ Sbctl is not installed
      Setup Mode:     ✘ Enabled
      Secure Boot:    ✘ Disabled

Create keys and sign binaries:
note: use sudo su - for root

    sbctl create-keys
    sbctl sign -s /boot/efi/EFI/Linux/bootx64.efi #it should be single file with name verying from kernel version
    ls /var/lib/sbctl/keys/db # make sure db.key and db.pem are available

Configure dracut to know where are signing keys:

    vim /etc/dracut.conf.d/secureboot.conf
    	uefi_secureboot_cert="/var/lib/sbctl/keys/db/db.pem"
    	uefi_secureboot_key="/var/lib/sbctl/keys/db/db.key"

We also need to fix sbctl's pacman hook. Creating the following file will overshadow the real one:

    vim /etc/pacman.d/hooks/zz-sbctl.hook
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

Enroll previously generated keys (drop microsoft option if you don't want their keys):

    sbctl enroll-keys --microsoft

Reboot the system. Enable only UEFI boot in BIOS and set BIOS password so evil maid won't simply turn off the setting. If everything went fine you should first of all, boot into your system, and then verify with sbctl or bootctl:

    sbctl status
      Installed:	✓ sbctl is installed
      Owner GUID:	YOUR_GUID
      Setup Mode:	✓ Disabled
      Secure Boot:	✓ Enabled

## Firewall Configuration

I'm goning to use nftables. Most distros started switching to it and it streamlines persistence compared to iptables.

Install nftables:

```
pacman -S nftables
```

Edit the `/etc/nftables.conf`. Proposed firewall rules:

- drop all forwarding traffic (we're not a router),
- allow loopback (127.0.0.0)
- allow ICMP for v4 and v6 (you can turn it off, but for v6 it will disable [SLAAC](<https://wiki.archlinux.org/title/IPv6#Stateless_autoconfiguration_(SLAAC)>)),
- allow returning packets for established connections,
- ssh protection
- block all else.

```
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
```

Enable the nftables service and list loaded rules for confirmation:

```
systemctl enable --now nftables

nft list ruleset
```

## Kernel parameters

Since firewall allows ICMP traffic, it may be a good idea to disable some network options. Edit your `/etc/sysctl.d/90-network.conf`:

```
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
```

Load your new rules with:

```
sysctl --system
```

## Password Manager

My preferred solution is KeePass with their .kdbx format, that can be opened by multitude of programs and solutions.

For arch you can install local client, KeePassXC:

```
pacman -S keepassxc
```

# KDE Plasma Installation

Follow these steps to install and run **KDE Plasma** with a **Wayland session** on Arch Linux. This guide assumes `sudo` privileges and a clean system.

---

## Full System Update

```
sudo pacman -Syu

```

## installing desktop env

```
sudo pacman -S plasma

note: put everything to default

```

```bash
# you need a login manager:

nano /kde_plasma.sh

#!/bin/bash
/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland

# make it executable
chmod +x kde_plasma.sh
```

# Arch DWM

Follow these steps to install and run **DWM** on Arch Linux. This guide assumes `sudo` privileges and a clean system.

## installing desktop env

```
git clone https://git.suckless.org/dwm
git clone https://git.suckless.org/st

```

```
sudo pacman -Sy xorg-server xorg-xinit libx11 libxinerama libxft webkit2gtk
```

## login manager

```
vim .xinitrc

exec dwm 
```

- cd into st
- ```
  sudo make clean install 
  ```
- cd into dwm
- ```
  sudo make clean install 
  ```
- vim into .bash_profile 
  ```
    startx
  ```


# Arch Linux Setup Guide

> you can install everything with one script using

```
bash <(curl -fsSL https://raw.githubusercontent.com/gameshler/arch_install/main/start.sh)
```

## Applications and Packages

```bash
sudo pacman -S firefox libreoffice-fresh vlc curl flatpak fastfetch p7zip unrar tar rsync exfat-utils fuse-exfat flac jdk-openjdk gimp steam vulkan-radeon lib32-vulkan-radeon base-devel kate mangohud lib32-mangohud corectrl openssh dolphin telegram-desktop discord visual-studio-code-bin --needed --noconfirm
```

### yay installation:

> `mkdir opt` if you dont have it

```
cd /opt
git clone https://aur.archlinux.org/yay-bin.git
sudo chown -R "$USER": ./yay-bin
cd yay-bin
makepkg --noconfirm -si
```

```
yay -S postman-bin brave-bin
```

## Additional Tools and Configuration

### configuring pacman:

```
sudo nano /etc/pacman.conf
```

- remove # from:
  - Color
  - ParallelDownloadds
- Add the following line for visual pacman

```
ILoveCandy
```

Update the config:

```
sudo pacman -Sy
```

#### enabling multilib:

uncomment the following lines:

```
[multilib]
Include = /etc/pacman.d/mirrorlist

```

Then update:

```
sudo pacman -Syyu
```

### corectrl (optional):

More info: [corectrl Wiki](https://gitlab.com/corectrl/corectrl/-/wikis/Setup)

Enable corectrl at startup:

```
cp /usr/share/applications/org.corectrl.CoreCtrl.desktop ~/.config/autostart/org.corectrl.CoreCtrl.desktop
```

> note: if the command above isnt working you need to make a new file for auto starting:

```
mkdir ~/.config/autostart # then run the above command
```

### mangohud configuration:

```
cp /usr/share/doc/mangohud/MangoHud.conf.example ~/.config/MangoHud/MangoHud.conf

```

> Edit ~/.config/MangoHud/MangoHud.conf to suit your preferences.

### Nodejs

I use nvm to manage the installed versions of Node.js on my machine. This allows me to easily switch between Node.js versions depending on the project I'm working in.

See installation instructions [here](https://github.com/nvm-sh/nvm#installing-and-updating).

OR run this command (make sure v0.40.3 is still the latest)

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```

Now that nvm is installed, you can install a specific version of node.js and use it:

```
nvm install 22
nvm use 22
node --version
```

### Github SSH Setup

- Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) to setup an ssh key for github
- Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) to add the ssh key to your github account

### Global Modules

There are a few global node modules I use a lot:

> install in your development directory

- license
  - Auto generate open source license files
- gitignore
  - Auto generate `.gitignore` files base on the current project type

```
pnpm install -g license gitignore
```
