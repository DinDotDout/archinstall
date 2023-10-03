#!/bin/bash

#   ____             __ _                       _   _             
#  / ___|___  _ __  / _(_) __ _ _   _ _ __ __ _| |_(_) ___  _ __  
# | |   / _ \| '_ \| |_| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \ 
# | |__| (_) | | | |  _| | (_| | |_| | | | (_| | |_| | (_) | | | |
#  \____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_|
#                         |___/                                   
# ------------------------------------------------------
clear
keyboardlayout="us"
zoneinfo="Europe/Madrid"
hostname="arch"
username="joan"

# ------------------------------------------------------
# Set System Time
# ------------------------------------------------------
ln -sf /usr/share/zoneinfo/$zoneinfo /etc/localtime
hwclock --systohc

# ------------------------------------------------------
# Update reflector
# ------------------------------------------------------
echo "Start reflector..."
reflector -c "Spain" -p https -a 3 --sort rate --save /etc/pacman.d/mirrorlist

# ------------------------------------------------------
# Synchronize mirrors
# ------------------------------------------------------
pacman -Syy

# ------------------------------------------------------
# Install Packages
# ------------------------------------------------------

while true; do
  read -p "Do you want any graphics drivers? (Nn (Nvidia), Aa (amd) or Xx (None)): " an
    case $an in
        [Nn]* ) 
            # ------------------------------------------------------
            # add nvidia hook
            # ------------------------------------------------------
            mkdir /etc/pacman.d/hooks/
            echo "
            [Trigger]
            Operation=Install
            Operation=Upgrade
            Operation=Remove
            Type=Package
            Target=nvidia-dkms
            Target=linux
            # Change the linux part above if a different kernel is used

            [Action]
            Description=Update NVIDIA module in initcpio
            Depends=mkinitcpio
            When=PostTransaction
            NeedsTargets
            Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
            " >> /etc/pacman.d/hooks/nvidia.hook
            echo "Adding nvidia-dkms"
            pacman --needed --noconfirm -S nvidia-dkms
        break;;
        [aA]* )
            echo "Adding xf86-video-amdgpu"
            pacman --needed --noconfirm -S xf86-video-amdgpu
        break;;
        [xX]* )
            exit;
        break;;
        * ) echo "Please answer n, a or x.";;
    esac
done

pacman --needed --noconfirm -S grub xdg-desktop-portal-wlr \
  efibootmgr networkmanager network-manager-applet dialog wpa_supplicant\
  mtools dosfstools base-devel linux-headers xdg-user-dirs xdg-utils\
  inetutils bluez bluez-utils cups hplip \
  alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack \
  openssh rsync reflector acpi acpi_call dnsmasq openbsd-netcat ipset firewalld \
  sof-firmware nss-mdns acpid os-prober ntfs-3g exa bat htop \
  ranger neofetch duf xorg xorg-xinit grub-btrfs nvidia-dkms \
  brightnessctl pacman-contrib git feh curl zsh \
	alacritty neovim firefox  man-db udisks2 \
	man-pages rofi ripgrep telegram-desktop \
	zip unzip  gtk3 lxappearance-gtk3  ttf-hack zathura \
	zathura-pdf-mupdf ueberzug ly mlocate lf filelight pavucontrol \
  virt-manager virt-viewer qemu vde2 ebtables iptables-nft nftables dnsmasq bridge-utils ovmf swtpm


# ------------------------------------------------------
# set lang utf8 US
# ------------------------------------------------------
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

# ------------------------------------------------------
# Set Keyboard
# ------------------------------------------------------
# echo "FONT=ter-v18n" >> /etc/vconsole.conf
echo "KEYMAP=$keyboardlayout" >> /etc/vconsole.conf

# ------------------------------------------------------
# Set hostname and localhost
# ------------------------------------------------------
echo "$hostname" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
clear

# ------------------------------------------------------
# Add User
# ------------------------------------------------------
echo "Add user $username"
useradd -m -G wheel $username
passwd $username

# ------------------------------------------------------
# Enable Services
# ------------------------------------------------------
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable firewalld
systemctl enable acpid

# ------------------------------------------------------
# Grub installation
# ------------------------------------------------------
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------------
# Add btrfs and setfont to mkinitcpio
# ------------------------------------------------------
# Before: BINARIES=()
# After:  BINARIES=(btrfs setfont)
sed -i 's/BINARIES=()/BINARIES=(btrfs setfont)/g' /etc/mkinitcpio.conf
mkinitcpio -p linux

# ------------------------------------------------------
# Add user to wheel
# ------------------------------------------------------
clear
echo "Uncomment %wheel group in sudoers (around line 85):"
echo "Before: #%wheel ALL=(ALL:ALL) ALL"
echo "After:  %wheel ALL=(ALL:ALL) ALL"
echo ""
read -p "Open sudoers on press" c
EDITOR=vim sudo -E visudo
usermod -aG wheel $username

# ------------------------------------------------------
# Copy installation scripts to home directory 
# ------------------------------------------------------
cp /archinstall/3-after-install.sh /home/$username
cp /archinstall/kvm.sh /home/$username

clear
echo "     _                   "
echo "  __| | ___  _ __   ___  "
echo " / _' |/ _ \| '_ \ / _ \ "
echo "| (_| | (_) | | | |  __/ "
echo " \__,_|\___/|_| |_|\___| "
echo "                         "
echo ""
echo "Please find the following additional installation scripts in your home directory:"
echo "3-after-install.sh"
echo ""
echo "Exit & shutdown (shutdown -h now), remove the installation media and start again."
