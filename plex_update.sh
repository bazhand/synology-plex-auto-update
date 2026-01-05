#!/bin/bash

# Author @loicdugay https://github.com/loicdugay
# Instructions at https://github.com/loicdugay/synology-plex-auto-update
#
# Thanks to
# @mj0nsplex https://forums.plex.tv/u/j0nsplex
# @martinorob https://github.com/martinorob/plexupdate
# @michealespinola https://github.com/michealespinola/syno.plexupdate

# Root check
if [ "$EUID" -ne "0" ];
  then
    printf " %s\n" "This script must be run as root."
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server auto-update failed.\n\nThis script must be run as root."}'
    printf "\n"
    exit 1
fi

# DSM version check
DSMVersion=$(cat /etc.defaults/VERSION | grep -i 'majorversion=' | cut -d"\"" -f 2)
/usr/bin/dpkg --compare-versions 7 gt "$DSMVersion"
if [ "$?" -eq "0" ];
  then
    printf " %s\n" "This script requires DSM 7."
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server auto-update failed.\n\nThis script requires DSM 7."}'
    printf "\n"
    exit 1
fi

# Get Plex Media Server version
curversion=$(synopkg version "PlexMediaServer")
curversion=$(echo $curversion | grep -oP '^.+?(?=\-)')
splitversion1=$(echo $curversion | cut -d "." -f 1 )
splitversion2=$(echo $curversion | cut -d "." -f 2 )
splitversion3=$(echo $curversion | cut -d "." -f 3 )
splitversion4=$(echo $curversion | cut -d "." -f 4 )
newpath=false
if [ $splitversion1 -ge 1 ]
then
  if [ $splitversion2 -ge 24 ]
  then
    if [ $splitversion3 -ge 2 ]
    then
      if [ $splitversion4 -ge 4973 ]
      then
        newpath=true
      fi
    fi
  fi
fi
if [[ $newpath ]];
then
  echo Plex version 1.24.2.4973 or newer detected
  token=$(cat /volume1/PlexMediaServer/AppData/Plex\ Media\ Server/Preferences.xml | grep -oP 'PlexOnlineToken="\K[^"]+')
else
  echo Plex version older than 1.24.2.4973 detected
  token=$(cat /volume1/@apphome/PlexMediaServer/Plex\ Media\ Server/Preferences.xml | grep -oP 'PlexOnlineToken="\K[^"]+')
fi

url=$(echo "https://plex.tv/api/downloads/5.json?channel=plexpass&X-Plex-Token=$token")
jq=$(curl -s ${url})
newversion=$(echo $jq | jq -r '.nas."Synology (DSM 7)".version')
newversion=$(echo $newversion | grep -oP '^.+?(?=\-)')

echo Available version: $newversion
echo Installed version: $curversion

if [ "$newversion" != "$curversion" ]
  then
    mkdir -p /tmp/plex/ > /dev/null 2>&1
    echo New version found, installing:
    CPU=$(uname -m)

if [ "$CPU" = "armv7l" ] # Plex denotes this CPU as armv7neon in releases. Tested on DS216Play.
then
    url=$(echo "${jq}" | jq -r '.nas."Synology (DSM 7)".releases[] | select(.build=="linux-armv7neon") | .url')
else
    url=$(echo "${jq}" | jq -r '.nas."Synology (DSM 7)".releases[] | select(.build=="linux-'"${CPU}"'") | .url')
fi

    /bin/wget $url -P /tmp/plex/
    /usr/syno/bin/synopkg install /tmp/plex/*.spk
    sleep 30
    /usr/syno/bin/synopkg start "PlexMediaServer"
    rm -rf /tmp/plex/*
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server auto-update installed the latest version."}'
  else
    echo No new version to install.
    /usr/syno/bin/synonotify PKGHasUpgrade '{"%PKG_HAS_UPDATE%": "Plex Media Server auto-update found no new version to install."}'
fi
exit
