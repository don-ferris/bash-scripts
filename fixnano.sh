#!/bin/bash
wget -c https://raw.githubusercontent.com/don-ferris/bash-scripts/main/etc-nanorc
if (( $EUID != 0 )); then
    mv ./etc-nanorc /etc/nanorc
    nano /etc/nanorc
    exit
else
    sudo mv ./etc-nanorc /etc/nanorc
    sudo nano /etc/nanorc
fi
