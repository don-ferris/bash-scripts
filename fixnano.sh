#!/bin/bash
wget -c https://raw.githubusercontent.com/don-ferris/bash-scripts/main/etc-nanorc
if (( $EUID != 0 )); then
    sudo mv ./etc-nanorc /etc/nanorc
    sudo nano /etc/nanorc
else
    mv ./etc-nanorc /etc/nanorc
    nano /etc/nanorc
fi
