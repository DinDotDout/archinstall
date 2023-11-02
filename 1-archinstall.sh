#!/bin/bash
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

	graphics_drivers=""
	while true; do
		read -rp "Do you want any graphics drivers? (Nn (Nvidia), Aa (amd) or Xx (None)): " an
		case $an in
		[Nn]*)
			graphics_drivers="nvidia-dkms"
			break
			;;
		[aA]*)
			graphics_drivers="xf86-video-amdgpu"
			break
			;;
		[xX]*)
			break
			;;
		*) echo "Please answer n, a or x." ;;
		esac
	done

	while true; do
		read -rsp "Enter your user password: " usrpasswd
		echo
		read -rsp "Confirm your user password: " password_confirm
		echo
		if [ "$usrpasswd" == "$password_confirm" ]; then
			echo "Passwords match."
			break
		else
			clear
			echo "Passwords do not match. Please try again."
		fi
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

install_base_pcks() {
	base_packages=(base base-devel git linux linux-firmware vim openssh reflector rsync "$cpu_microcode")
	pacman -S --needed --noconfirm "${base_packages[@]}" ||
		{
			echo 'Failed to install base packages.'
			exit 1
		}
}

generate_fstab() {
	genfstab -U /mnt >>/mnt/etc/fstab || {
		echo "Failed to generate fstab."
		exit 1
	}
	cat /mnt/etc/fstab
}

installation() {
	format_partitions
	mount_partitions
	install_base_pcks
	generate_fstab
	timedatectl set-ntp true

}

main() {
	welcome_message
	get_user_input
	installation

	mkdir /mnt/archinstall
	cp -R resources/ /mnt/root/archinstall/resources/
	cp 2-configuration.sh /mnt/root/archinstall/
	arch-chroot /mnt /bin/bash -- <<EOCHROOT
      source \$HOME/archintall/2-configuration;
      configuration "${usrpasswd}" "${graphics_drivers}"
EOCHROOT
	find /mnt/root/archinstall/ -type f -exec shred --verbose -u --zero --iterations=3 {} \;
	rm -r /mnt/root/archinstall/
}

main
