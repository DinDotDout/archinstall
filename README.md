# Arch Linux Installation Scripts

This repository contains two bash scripts for automating the installation and configuration of Arch Linux.

## Overview

The scripts are designed to be run in sequence. The first script (`1-installation.sh`) formats and mounts the partitions, installs the base packages, and generates an fstab file. The second script (`2-configuration.sh`) is run inside a chroot environment and sets up various system configurations.

## Important Reminder
These scripts are tailored to specific needs and contain many baked-in defaults. If you’re planning to use these scripts for your own installation, you may need to modify these defaults to suit your own requirements. Always review and understand a script before running it on your system.

## Project Status
This project is ongoing but unscheduled as it is only for personal use and enjoyment.

## Prerequisites
- A system with Arch Linux bootable media.
- An internet connection.
- Ensure that the necessary partitions for boot and root are already created.

## Usage

1. Clone this repository to your local machine.
2. Run the `1-installation.sh` script. This will install the base system.
3. After the first script completes, it will automatically chroot into the new system and run the `2-configuration.sh` script. This will set up system configurations.

## Scripts

### 1-installation.sh

This script performs the following steps:

1. Displays a welcome message.
2. Prompts the user for input regarding partitioning, CPU microcode, graphics drivers, and user password.
3. Formats the specified partitions.
4. Mounts the partitions.
5. Installs the base packages.
6. Generates an fstab file.
7. Enters a chroot environment and runs the `2-configuration.sh` script.

### 2-configuration.sh

The script has several parameters at the top that you can modify to suit your needs:

- `keyboardlayout`: This sets the keyboard layout.
- `zoneinfo`: This sets the time zone.
- `hostname`: This sets the hostname.
- `username`: This sets the username.
- `dotfiles`: This sets the URL of the dotfiles repository to be cloned onto the specified user at the end. Keep empty if is not desired.
- `parallel_downloads`: This sets the number of parallel downloads.
- `parallel_compilation`: This sets whether to enable parallel compilation.

This script performs the following steps inside a chroot environment:

1. Sets up parallel downloads and compilations.
2. Configures the system time.
3. Adds multilib repositories.
4. Installs additional packages.
5. Generates locale and keymaps.
6. Adds a user and enables sudo.
7. Adds services.
8. Sets up the hostname.
9. Installs GRUB.
10. Configures initramfs.
11. Adds repositories.


## Cleanup

Both scripts are designed to clean up after themselves. If an error occurs during execution, the scripts will unmount any partitions mounted by the script and remove temporary files.

