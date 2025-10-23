# bash-scripts
This is a collection of bash scripts that I wrote just to make my life easier and to make any (Debian-based) client or server machine work the way I like.

***Fix "No valid subscxription error for Proxmox:***

wget -c https://raw.githubusercontent.com/don-ferris/bash-scripts/main/no-more-no-valid-subscription.sh

***Add all my favorite aliases:***

wget -c https://raw.githubusercontent.com/don-ferris/bash-scripts/main/.aliases && source ./.aliases && alias

***Fix nano to work with a mouse and use common key bindings:***

wget -c https://raw.githubusercontent.com/don-ferris/bash-scripts/main/fixnano.sh && bash fixnano.sh
