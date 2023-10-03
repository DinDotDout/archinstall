#!/bin/bash
clear
echo "Installing paru!"
git clone https://aur.archlinux.org/paru-git.git
 (cd paru-git && makepkg -si)
echo "DONE!"

echo "Installing Paru pckgs!"
paru --noconfirm --needed -S neovim-remote stow \
	catppuccin-gtk-theme-macchiato catppuccin-cursors-mocha \
	protonup-qt timeshift zram-generator preload
echo "DONE!"
clear

echo "Adding zram"
if [ -f "/etc/systemd/zram-generator2.conf" ]; then
    echo "/etc/systemd/zram-generator.conf already exists!"
else
	sudo touch /etc/systemd/zram-generator.conf
	sudo bash -c 'echo "[zram0]" >> /etc/systemd/zram-generator.conf'
	sudo bash -c 'echo "zram-size = ram / 2" >> /etc/systemd/zram-generator.conf'
    sudo systemctl daemon-reload
    sudo systemctl start /dev/zram0
fi
echo "DONE!"

clear

# git clone git@github.com:DinDotDout/.dotfilesV2.git
git clone https://github.com/DinDotDout/.dotfilesV2 $HOME/.dotfiles
cd $HOME/.dotfiles
stow -R conf-base
xdg-user-dirs-update

echo "Changing to zsh shell"
chsh -s /usr/bin/zsh
zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1 --keep
echo "Changing to ly display manager"
dpmpath='ExecStart=/usr/bin/'
servicename=$(grep $dpmpath /etc/systemd/system/display-manager.service)
if ! [ -z "$service" ]; then
	echo "Disabling current display manager service"
	servicename="${servicename#$dpmpath}.service"
	systemctl disable $servicename
fi
echo "Enabling new display manager service"
systemctl enable ly.service

while true; do
  read -p "Do you want to install i3 or hyprland? (hH/iI/Xx(None)): " hin
    case $hin in
        [hH]* )
            echo "Hyprland configuration started."
            source install-hyprland.sh
        break;;
        [iI]* ) 
            echo "I3 configuration started."
            source install-i3.sh
        break;;
        [nN]* )
        break;;
        * ) echo "Please answer i, h or x.";;
    esac
done

echo "Finished"
echo "All options will be enabled after rebooting"
