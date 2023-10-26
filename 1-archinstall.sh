#!/bin/bash
clear
echo "    _             _       ___           _        _ _ "
echo "   / \   _ __ ___| |__   |_ _|_ __  ___| |_ __ _| | |"
echo "  / _ \ | '__/ __| '_ \   | || '_ \/ __| __/ _' | | |"
echo " / ___ \| | | (__| | | |  | || | | \__ \ || (_| | | |"
echo "/_/   \_\_|  \___|_| |_| |___|_| |_|___/\__\__,_|_|_|"
echo "Based on Stephan Raabe's archinstall https://gitlab.com/stephan-raabe/archinstall/"
echo "-----------------------------------------------------"
echo ""

# ------------------------------------------------------
# Enter partition names
# ------------------------------------------------------
lsblk
read -p "Enter the name of the EFI partition (eg. nvme0np1): " nvme0n1p1
read -p "Enter the name of the ROOT partition (eg. nvme0np2): " nvme0n1p2
read -p "Enter the name of the VM partition (keep it empty if not required): " nvme0n1p3
cpu_microcode=""
while true; do
    read -p "Do you use intel or amd cpu? (Ii (intel), Aa (amd) or Xx (None)): " ai
    case $ai in
        [iI]* ) 
            cpu_microcode="intel-ucode"
            break;;
        [aA]* )
            cpu_microcode="amd-ucode"
            break;;
        [xX]* )
            echo "No additional CPU microcode will be added."
            break;;
        * ) echo "Please answer i, a or x.";;
    esac
done

# ------------------------------------------------------
# Sync time
# ------------------------------------------------------
timedatectl set-ntp true

# ------------------------------------------------------
# Format partitions
# ------------------------------------------------------
mkfs.fat -F 32 /dev/$nvme0n1p1;
mkfs.btrfs -f /dev/$nvme0n1p2
mkfs.btrfs -f /dev/$nvme0n1p3

# ------------------------------------------------------
# Mount points for btrfs
# ------------------------------------------------------
mount /dev/$nvme0n1p2 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@log
umount /mnt

mount -o compress=zstd:1,noatime,subvol=@ /dev/$nvme0n1p2 /mnt
mkdir -p /mnt/{boot/efi,home,.snapshots,var/{cache,log},vm}
mount -o compress=zstd:1,noatime,subvol=@cache /dev/$nvme0n1p2 /mnt/var/cache
mount -o compress=zstd:1,noatime,subvol=@home /dev/$nvme0n1p2 /mnt/home
mount -o compress=zstd:1,noatime,subvol=@log /dev/$nvme0n1p2 /mnt/var/log
mount -o compress=zstd:1,noatime,subvol=@snapshots /dev/$nvme0n1p2 /mnt/.snapshots
mount /dev/$nvme0n1p1 /mnt/boot/efi

mount /dev/$nvme0n1p3 /mnt/vm

# ------------------------------------------------------
# Install base packages
# ------------------------------------------------------
sudo pacman -S --needed base base-devel git linux linux-firmware vim openssh reflector rsync $cpu_microcode

# ------------------------------------------------------
# Generate fstab
# ------------------------------------------------------
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab

# ------------------------------------------------------
# Install configuration scripts
# ------------------------------------------------------
mkdir /mnt/archinstall
cp nvidia.hook /mnt/archinstall/
cp 2-configuration.sh /mnt/archinstall/
cp 3-after-install.sh /mnt/archinstall/
cp kvm.sh /mnt/archinstall/
# ------------------------------------------------------
# Chroot to installed sytem
# ------------------------------------------------------
arch-chroot /mnt ./archinstall/2-configuration.sh
