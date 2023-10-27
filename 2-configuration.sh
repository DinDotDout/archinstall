#!/bin/bash

keyboardlayout="us"
zoneinfo="Europe/Madrid"
hostname="arch_joan"
username="joan"
dotfiles="https://github.com/DinDotDout/.dotfilesV2"

setup_time() {
	ln -sf /usr/share/zoneinfo/$zoneinfo /etc/localtime
	hwclock --systohc
}

install_pcks() {
	local graphics_drivers=$1
	echo "Start reflector..."
	reflector -c "Spain" -p https -a 3 --sort rate --save /etc/pacman.d/mirrorlist
	pacman -Syy

	packages=(grub xdg-desktop-portal-wlr efibootmgr networkmanager network-manager-applet
		dialog wpa_supplicant mtools dosfstools base-devel linux-headers xdg-user-dirs xdg-utils
		inetutils bluez bluez-utils cups hplip alsa-utils pipewire pipewire-alsa pipewire-pulse
		pipewire-jack openssh rsync reflector acpi acpi_call dnsmasq openbsd-netcat ipset firewalld
		sof-firmware nss-mdns acpid os-prober ntfs-3g exa bat htop ranger neofetch duf xorg
		xorg-xinit grub-btrfs brightnessctl pacman-contrib git feh curl zsh alacritty neovim
		firefox man-db udisks2 man-pages rofi ripgrep telegram-desktop dunst zip unzip unrar gtk3
		lxappearance-gtk3 ttf-hack zathura zathura-pdf-mupdf ueberzug sddm mlocate lf filelight
		pavucontrol btop)

	if [[ -n "$graphics_drivers" ]]; then
		packages+=("$graphics_drivers")
		mkdir -p /etc/pacman.d/hooks/
		cp ./archinstall/nvidia.hook /etc/pacman.d/hooks/nvidia.hook
	fi
	pacman --needed --noconfirm -S "${packages[@]}" || {
		echo 'Failed to install packages.'
		exit 1
	}
}

generate_locale_and_keymaps() {
	echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
	locale-gen
	echo "LANG=en_US.UTF-8" >>/etc/locale.conf

	echo "KEYMAP=$keyboardlayout" >>/etc/vconsole.conf
}

add_user_and_services() {
	local passwd=$1
	echo "Add user $username"
	useradd -m -G wheel $username
	echo "$username:$passwd" | chpasswd -c DES

	systemctl enable NetworkManager
	systemctl enable bluetooth
	systemctl enable cups.service
	systemctl enable sshd
	systemctl enable avahi-daemon
	systemctl enable reflector.timer
	systemctl enable fstrim.timer
	systemctl enable firewalld
	systemctl enable acpid
}

setup_hostname() {
	echo "$hostname" >>/etc/hostname
	{
		echo "127.0.0.1 localhost"
		echo "::1       localhost"
		echo "127.0.1.1 $hostname.localdomain $hostname"
	} >>/etc/hosts
}

install_grub() {
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable || {
		echo 'Failed to install GRUB.'
		exit 1
	}
	grub-mkconfig -o /boot/grub/grub.cfg || {
		echo 'Failed to generate GRUB configuration.'
		exit 1
	}
}

configure_initramfs() {
	sed -i 's/BINARIES=()/BINARIES=(btrfs setfont)/g' /etc/mkinitcpio.conf
	mkinitcpio -p linux
}

add_repo() {
	read -rp "Enter the repository URL: " repo_url
	git clone "$repo_url" /home/"$username"/ || {
		echo 'Failed to clone repository, try another url.'
	}
}

add_repos() {
	if [ -n "$dotfiles" ]; then
		echo "Cloning dotfiles"
		git clone "$dotfiles" /home/"$username"/ || {
			echo 'Failed to clone dotfiles'
		}
	fi

	while true; do
		read -rp "Do you want to clone a repository? (Yy/Nn): " yn
		case $yn in
		[yY]*)
			add_repo
			;;
		[nN]*)
			break
			;;
		*) echo "Please answer (Yy/Nn)" ;;
		esac
	done
}

configuration() {
	local usrpasswd=$1
	local graphics_drivers=$2
	setup_time
	install_pcks "$graphics_drivers"
	generate_locale_and_keymaps
	add_user_and_services "$usrpasswd"
	setup_hostname
	install_grub
	configure_initramfs
	add_repos
}
