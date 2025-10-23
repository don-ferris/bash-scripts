#!/bin/bash
# fixnano.sh
# a script to download and install a modified /etc/nanorc config file to enable mouse support in the nano text editor and to enable common key bindings (e.g. Ctrl+X = cut; Ctrl+V = Paste; Ctrl+S = Save, Ctrl+F = Find, etc.)
wget -c https://raw.githubusercontent.com/don-ferris/bash-scripts/main/etc-nanorc
if (( $EUID != 0 )); then
    sudo mv ./etc-nanorc /etc/nanorc
    sudo nano /etc/nanorc
else
    mv ./etc-nanorc /etc/nanorc
    nano /etc/nanorc
fi
