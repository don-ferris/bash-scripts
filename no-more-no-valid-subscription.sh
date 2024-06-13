#!/bin/bash

# Function to ask a yes/no question
ask_question() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;  # Yes response
            [Nn]* ) return 1;;  # No response
            * ) echo "Please answer yes or no.";;
        esac
    done
}

sed -i.bak '/Ext.Msg.show/{N;/\n.*No valid sub/s/Ext.Msg.show/void/;}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
grep -n -B 1 'No valid sub' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Ask the question
if ask_question "Restart PVE proxy service?"; then
    # If the answer is yes, execute this command
    echo "You chose yes - restarting PVE Proxy service."
    systemctl restart pveproxy.service
else
    # If the answer is no, execute this command
    echo "You chose no. (Doing nothing.)"
    # Place your alternative command here
fi
