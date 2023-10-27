#!/bin/bash

keyboardlayout="us"
zoneinfo="Europe/Madrid"
hostname="arch_joan"
username="joan"

welcome_message() {
	clear
	echo "    _             _       ___           _        _ _ "
	echo "   / \   _ __ ___| |__   |_ _|_ __  ___| |_ __ _| | |"
	echo "  / _ \ | '__/ __| '_ \   | || '_ \/ __| __/ _' | | |"
	echo " / ___ \| | | (__| | | |  | || | | \__ \ || (_| | | |"
	echo "/_/   \_\_|  \___|_| |_| |___|_| |_|___/\__\__,_|_|_|"
	echo "-----------------------------------------------------"
	echo ""
}

get_user_input() {
	lsblk
	# ------------------------------------------------------
	# Enter partition names
	# ------------------------------------------------------
	read -rp "Enter the name of the EFI partition (eg. nvme0n1p1): " nvme0n1p1
	read -rp "Enter the name of the ROOT partition (eg. nvme0n1p2): " nvme0n1p2
	read -rp "Enter the name of the VM partition (keep it empty if not required): " nvme0n1p3

	# cpu to be used
	cpu_microcode=""
	while true; do
		read -rp "Do you use intel or amd cpu? (Ii (intel), Aa (amd) or Xx (None)): " ai
		case $ai in
		[iI]*)
			cpu_microcode="intel-ucode"
			break
			;;
		[aA]*)
			cpu_microcode="amd-ucode"
			break
			;;
		[xX]*)
			echo "No additional CPU microcode will be added."
			break
			;;
		*) echo "Please answer i, a or x." ;;
		esac
	done

	while true; do
		read -rsp "Enter your password: " password
		echo
		read -rsp "Confirm your password: " password_confirm
		echo
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
		read -rp "Do you want any graphics drivers? (Nn (Nvidia), Aa (amd) or Xx (None)): " an
		case $an in
		[Nn]*)
			graphics_driver="nvidia-dkms"
			break
			;;
		[aA]*)
			graphics_driver="xf86-video-amdgpu"
			break
			;;
		[xX]*)
			break
			;;
		*) echo "Please answer n, a or x." ;;
		esac
	done
}

format_partitions() {
	mkfs.fat -F 32 "/dev/$nvme0n1p1" || {
		echo 'Failed to format EFI partition.'
		exit 1
	}
	mkfs.btrfs -f "/dev/$nvme0n1p2" || {
		echo 'Failed to format ROOT partition.'
		exit 1
	}
	if [ -n "$nvme0n1p3" ]; then
		mkfs.btrfs -f "/dev/$nvme0n1p3" || {
			echo 'Failed to format VM partition.'
			exit 1
		}
	fi
}

mount_partitions() {
	# ------------------------------------------------------
	# Mount points for btrfs
	# ------------------------------------------------------
	mount /dev/"$nvme0n1p2" /mnt
	btrfs su cr /mnt/@
	btrfs su cr /mnt/@cache
	btrfs su cr /mnt/@home
	btrfs su cr /mnt/@snapshots
	btrfs su cr /mnt/@log
	umount /mnt

	mount -o compress=zstd:1,noatime,subvol=@ /dev/"$nvme0n1p2" /mnt
	mkdir -p /mnt/{boot/efi,home,.snapshots,var/{cache,log}}
	mount -o compress=zstd:1,noatime,subvol=@cache /dev/"$nvme0n1p2" /mnt/var/cache
	mount -o compress=zstd:1,noatime,subvol=@home /dev/"$nvme0n1p2" /mnt/home
	mount -o compress=zstd:1,noatime,subvol=@log /dev/"$nvme0n1p2 /mnt/var/log"
	mount -o compress=zstd:1,noatime,subvol=@snapshots /dev/"$nvme0n1p2" /mnt/.snapshots
	mount "/dev/$nvme0n1p1" /mnt/boot/efi
	if [ -n "$nvme0n1p3" ]; then
		mkdir -p /mnt/vm
		mount "/dev/$nvme0n1p3" /mnt/vm
	fi
}

# ------------------------------------------------------
# Sync time
# ------------------------------------------------------
timedatectl set-ntp true

install_base_pcks() {
	base_packages=(base base-devel git linux linux-firmware vim openssh reflector rsync "$cpu_microcode")
	pacman -S --needed "${base_packages[@]}" ||
		{
			echo 'Failed to install base packages.'
			exit 1
		}
}

# ------------------------------------------------------
# Generate fstab
# ------------------------------------------------------
generate_fstab() {
	genfstab -U /mnt >>/mnt/etc/fstab || {
		echo "Failed to generate fstab."
		exit 1
	}
	cat /mnt/etc/fstab
}

setup_time() {
	ln -sf /usr/share/zoneinfo/$zoneinfo /etc/localtime
	hwclock --systohc
}

install_pcks() {
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

	if [[ -n "$graphics_driver" ]]; then
		packages+=("$graphics_driver")
		mkdir -p /etc/pacman.d/hooks/
		cp ./archinstall/resources/nvidia.hook /etc/pacman.d/hooks/nvidia.hook
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
	echo "Add user $username"
	useradd -m -G wheel $username
	echo "$username:password" | chpasswd -c DES

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

archinstall() {
	format_partitions
	mount_partitions
	install_base_pcks
	generate_fstab
	timedatectl set-ntp true

	mkdir /mnt/archinstall
	cp nvidia.hook /mnt/archinstall/
	cp 2-configuration.sh /mnt/archinstall/
	cp 3-after-install.sh /mnt/archinstall/
	cp kvm.sh /mnt/archinstall/
	arch-chroot /mnt ./archinstall/2-configuration.sh
}

configuration() {
	setup_time
	install_pcks
	generate_locale_and_keymaps
	add_user_and_services
	setup_hostname
	install_grub
	configure_initramfs
}

main() {
	welcome_message
	get_user_input
	archinstall
	configuration
}

main
