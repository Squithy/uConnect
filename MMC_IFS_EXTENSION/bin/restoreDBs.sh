#!/bin/sh
source=$1
dest=$2

if [ ! -d  "$dest" ]; then
   mkdir -p "$dest"
fi

# Example of source and dest: 
# /fs/mmc0/app/share/sdars/channelart /fs/etfs/usr/var/sdars/channelart
cp -f -R "$source" "$dest/.."

chmod -R +rwx "$dest"

exit
