Maintenance Reminder is a script for Debian and derivatives that reminds the user to run One-Click Maintenance when a week or more has passed since the last time it was run. To do this, it uses (the last modified date/time stamp of) a simple tracking (text) file - last.run. The file is updated with the current date and time (as contents) which, of course, updates its last modified date/timestamp each time maintenance is run. The code has lots of echo statements for debugging. Once the script is finished, I comment them out but they still serve as comments for documentation. (This is my standard M.O.)

Prerequisites are:
  * exo-open
  * ucaresystem-core
The script checks for installs the prerequisites as necessary. 


sudo add-apt-repository ppa:utappia/stable
sudo apt update
sudo apt install -y ucaresystem-core


#!/bin/bash
clear
_TRACKING_FILE=~/bin/lastrun.txt # used to track when maintenance was last run
# sudo date --set="Fri Nov 25 10:08:58 PST 2022"
_CUR_DATE_TIME=$(date +%s)
_SECONDS_IN_WEEK=604800
# echo "Current date and time in seconds is $_CUR_DATE_TIME"
if [ -f "$_TRACKING_FILE" ]; 
then
  _LAST_MOD=$(date +%s -r $_TRACKING_FILE)
  # echo "Tracking file exists. It was last modified at $_LAST_MOD (seconds)"
else
  # echo $_CUR_DATE_TIME > $_TRACKING_FILE
  # echo "Tracking File $_TRACKING_FILE has been created with contents '$_CUR_DATE_TIME'"
  echo ""
fi
let "_ELAPSED=$_CUR_DATE_TIME-$_LAST_MOD"
echo "$_ELAPSED seconds have elapsed since the tracking file was modified."
if (( _ELAPSED > _SECONDS_IN_WEEK ));
then
  # echo "$_ELAPSED is greater than $_SECONDS_IN_WEEK. It has been a week or more since maintenance was run."
  if zenity --question --width=600 --title="Maintenance Reminder" --text "It's been a week or more since One-Click Maintenance was run on this computer. Would you like to run One Click Maintenance now?";
  then
    exo-open --launch TerminalEmulator gksu ucaresystem-core
    # zenity --info --title="Maintenance Reminder" --text="Maintenance complete" --timeout=4
    # bash /opt/extras.ubuntu.com/uCareSystemCoreStarter/startucaresystemcore.sh
  else
    if zenity --question --width=600 --title="Maintenance Reminder" --text "It's important to run One-Click Maintenance regularly. It fixes any bugs that have been found recently and applies important system updates including security updates. Are you sure you don't want to run One-Click Maintenance now? (If you choose yes, you will be reminded again later.)";
    then
      exit
    else
      exo-open --launch TerminalEmulator gksu ucaresystem-core
      # zenity --info --title="Maintenance Reminder" --text="Maintenance complete" --timeout=4
      # bash /opt/extras.ubuntu.com/uCareSystemCoreStarter/startucaresystemcore.sh
    fi
  fi
else
  # echo "$_ELAPSED is less than $_SECONDS_IN_WEEK. It has been less than a week or more since maintenance was run."
  exit
fi
# Script tested and working OK to here.
# sleep 5
# clear
