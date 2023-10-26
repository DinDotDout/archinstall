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
while true; do
    read -sp "Enter your password: " password
    echo # This echo command is for a newline after the password input
    read -sp "Confirm your password: " password_confirm
    echo # This echo command is for a newline after the password input

    if [ "$password" == "$password_confirm" ]; then
        echo "Passwords match."
        break
    else
        clear
        echo "Passwords do not match. Please try again."
    fi
done

# Manage all user prompts
graphics_driver=""
while true; do
    read -p "Do you want any graphics drivers? (Nn (Nvidia), Aa (amd) or Xx (None)): " an
    case $an in
        [Nn]* ) 
            graphics_driver="nvidia-dkms"
            break;;
        [aA]* )
            graphics_driver="xf86-video-amdgpu"
            break;;
        [xX]* )
            break;;
        * ) echo "Please answer n, a or x.";;
    esac
done
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
packages=(grub xdg-desktop-portal-wlr efibootmgr networkmanager network-manager-applet \
  dialog wpa_supplicant mtools dosfstools base-devel linux-headers xdg-user-dirs xdg-utils \
  inetutils bluez bluez-utils cups hplip alsa-utils pipewire pipewire-alsa pipewire-pulse \
  pipewire-jack openssh rsync reflector acpi acpi_call dnsmasq openbsd-netcat ipset firewalld \
  sof-firmware nss-mdns acpid os-prober ntfs-3g exa bat htop ranger neofetch duf xorg \
  xorg-xinit grub-btrfs brightnessctl pacman-contrib git feh curl zsh alacritty neovim \
  firefox man-db udisks2 man-pages rofi ripgrep telegram-desktop dunst zip unzip unrar gtk3 \
  lxappearance-gtk3 ttf-hack zathura zathura-pdf-mupdf ueberzug sddm mlocate lf filelight pavucontrol)

if [[ ! -z "$graphics_driver" ]]; then
    packages+=($graphics_driver)
    mkdir -p /etc/pacman.d/hooks/
    cp ./archinstall/nvidia.hook /etc/pacman.d/hooks/nvidia.hook
fi

pacman --needed --noconfirm -S "${packages[@]}"
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
echo "$username:password" | chpasswd -c DES

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
echo "Adding user to wheel group and uncommenting sudoers file"
usermod -aG wheel $username
EDITOR='sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/"' visudo

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
