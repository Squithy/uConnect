#!/bin/sh

# Ensure Tags directory exists before starting the service
if [ ! -d /usr/var/iPodTags ]; then
mkdir -p /usr/var/iPodTags
cp -RX /fs/mmc0/app/share/iPodTags/ /usr/var/
chmod  -R +rwx /usr/var/iPodTags
fi

#Tagging component which ultimately copy tags to Ipod
iPodTagger -config /etc/iPodTagger.conf &

#Lua Tagging Service
lua -s -b -d /usr/bin/cmc/service/platform/misc taggingService.lua /etc/tagService.cfg  