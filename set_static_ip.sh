#!/bin/bash
# set vars
_TMP_FILE=/tmp/00-installer-config.yaml
_DEST_FILE=/etc/netplan/00-installer-config.yaml
_GATEWAY=`ip route show | head -1 | awk '{print $3}'`
# echo gateway = $_GATEWAY & exit
_DNS1=1.0.0.1
_DNS2=1.0.0.2
_DNS3=8.8.8.8
# show current config
sudo echo 
clear
echo 
echo 
echo Look at the configuration below...
echo 
echo 
cat /etc/netplan/00-installer-config.yaml
echo 
echo 
# get interface name from user input
echo Directly below \"ethernets:\" is the interface name.
echo Enter the interface name \(omit the trailing colon\) :
read _INTERFACE_NAME
echo 
# get (new/static) IP from user input
echo Enter the new static IP address:
read _STATIC_IP
echo 
echo 
echo Enter the first DNS server. Press Enter to use the default - \'$_DNS1\'
read _DNS1
if [ -z "$_DNS1" ]; # if DNS1 var is empty
then
  # echo "\$_DNS1 is empty"
  _DNS1="1.0.0.1"
fi
echo 
echo Enter the second DNS server. Press Enter to use the default - \'$_DNS2\'
read _DNS2
if [ -z "$_DNS2" ]; # if DNS2 var is empty
then
  # echo "\$_DNS2 is empty"
  _DNS2="1.0.0.2"
fi
echo 
echo Enter the third DNS server. Press Enter to use the default - \'$_DNS3\'
read _DNS3
if [ -z "$_DNS3" ]; # if DNS3 var is empty
then
  # echo "\$_DNS3 is empty"
  _DNS3="8.8.8.8"
fi
echo 
#
# Debug...
# uncomment 4 lines below for debug
# echo interface name is $_INTERFACE_NAME
# echo new IP address is $_STATIC_IP
# echo default gateway is $_GATEWAY
# echo DNS servers are $_DNS_SERVERS
_DNS_SERVERS="$_DNS1, $_DNS2, $_DNS3"
echo DNS Servers set to = \'$_DNS_SERVERS\'
#
#########    WRITE THE FILE    ########
#
printf "network:\n" > $_TMP_FILE
printf "  ethernets:\n" >> $_TMP_FILE
printf "    $_INTERFACE_NAME:\n" >> $_TMP_FILE
printf "      dhcp4: false\n" >> $_TMP_FILE
printf "      addresses:\n" >> $_TMP_FILE
printf "        - $_STATIC_IP/24\n" >> $_TMP_FILE
printf "      nameservers:\n" >> $_TMP_FILE
printf "        addresses: [$_DNS_SERVERS]\n" >> $_TMP_FILE
printf "      routes:\n" >> $_TMP_FILE
printf "        - to: default\n" >> $_TMP_FILE
printf "          via: $_GATEWAY\n" >> $_TMP_FILE
printf "  version: 2" >> $_TMP_FILE
echo 
clear 
echo 
echo 
echo Review the new configuration:
echo 
echo 
cat $_TMP_FILE
echo 
echo 
echo If you choose to apply these settings, you may have to close
echo this terminal window, open a new one, and reconnect using:
echo 
printf "    ssh [username]@$_STATIC_IP\n"
echo 
echo Press Enter to apply these settings or Ctrl+C to quit and start over.
read _CONFIRM
if [ -z "$_CONFIRM" ]; # if CONFIRM var is empty
then
  # user didn't break out - write new config file
  echo 
fi
sudo cp $_DEST_FILE $_DEST_FILE.bak
sudo cp $_TMP_FILE $_DEST_FILE
sudo netplan apply

