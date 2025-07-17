#!/usr/bin/env bash

set -euo pipefail

# Function to display available drives and allow the user to select one
select_drive() {
  clear
  printf "%b\n" "Available drives and partitions:"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,LABEL,UUID | grep -v 'loop' # list all non-loop devices
  printf "\n"
  printf "%b\n" "Enter the drive/partition name (e.g., sda1, nvme0n1p1): "
  read -r drive_name
  # Check if the input is valid
  if [ -b "/dev/$drive_name" ]; then
    partition="/dev/${drive_name}"
  else
    printf "%b\n" "Invalid drive/partition name!"
    exit 1
  fi
}

# Function to get UUID and FSTYPE of the selected drive
get_uuid_fstype() {
  UUID=$(sudo blkid -s UUID -o value "${partition}")
  FSTYPE=$(lsblk -no FSTYPE "${partition}")
  NAME=$(lsblk -no NAME "${partition}")

  if [ -z "$UUID" ]; then
    printf "%b\n" "Failed to retrieve the UUID. Exiting."
    exit 1
  fi

  if [ -z "$FSTYPE" ]; then
    printf "%b\n" "Failed to retrieve the filesystem type. Exiting."
    exit 1
  fi
}

# Function to create a mount point
create_mount_point() {
  printf "%b\n" "Enter the mount point path (e.g., /mnt/hdd): "
  read -r mount_point
  if [ ! -d "$mount_point" ]; then
    printf "%b\n" "Mount point doesn't exist. Creating it..."
    sudo mkdir -p "$mount_point"
  else
    printf "%b\n" "Mount point already exists."
  fi
}

# Function to update /etc/fstab with a comment on the first line and the actual entry on the second line
update_fstab() {
  printf "%b\n" "Adding entry to /etc/fstab..."
  sudo cp /etc/fstab /etc/fstab.bak # Backup fstab

  # Prepare the comment and the fstab entry
  comment="# Mount for /dev/$NAME"
  fstab_entry="UUID=$UUID $mount_point $FSTYPE defaults 0 2"

  # Append the comment and the entry to /etc/fstab
  printf "%b\n" "$comment" | sudo tee -a /etc/fstab >/dev/null
  printf "%b\n" "$fstab_entry" | sudo tee -a /etc/fstab >/dev/null
  printf "%b\n" "" | sudo tee -a /etc/fstab >/dev/null

  printf "%b\n" "Entry added to /etc/fstab:"
  printf "%b\n" "$comment"
  printf "%b\n" "$fstab_entry"
}

# Function to mount the drive
mount_drive() {
  printf "%b\n" "Mounting the drive..."
  sudo mount -a
  if mount | grep "$mount_point" >/dev/null; then
    printf "%b\n" "Drive mounted successfully at $mount_point."
  else
    printf "%b\n" "Failed to mount the drive."
    exit 1
  fi
}

