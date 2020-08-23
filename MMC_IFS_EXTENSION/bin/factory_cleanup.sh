#!/bin/sh

if [ ! -e /tmp/boot_done ]; then
   echo "###################################################################"
   echo "### CANNOT begin factory_cleanup before boot.sh is finished !!! ###"
   echo "###################################################################"
   exit 255
fi     

echo Checking temperature of MMC...
# check temperature here and exit script if not > -25
T=`check_temperature.lua`
if [[ $T -ne 0 ]]; then
   echo Brrrr too cold to do this now...
   exit 255
fi

# source DBUS environment
. /tmp/envars.sh

# signal that services have 5 seconds to shut down before factory reset, wait 5 seconds and then signal that we are starting
echo 5 second timeout while signaling on dbus for factory cleanup...
dbus-send --type=signal /com/harman/service/platform com.harman.service.platform.factory_reset string:"notifying" string:"{\"timeout\":5}"
sleep 5
dbus-send --type=signal /com/harman/service/platform com.harman.service.platform.factory_reset string:"starting"

echo Killing lua services and apps...
slay -f lua > /dev/null

# pet the watchdog so that we can slay/restart onOff safely with all other LUA's
echo Starting mongrel to pet the dog...
waitfor /usr/local/bin/mongrel.lua
lua -s -b /usr/local/bin/mongrel.lua &

mount -uw /fs/mmc0
mount -uw /fs/mmc1

if [ $VARIANT_MODEL = "VP3" ]; then
	echo Deactivating Navigation
	rm -rf /fs/mmc0/nav/NNG/license/ACTIVATION_CODES
	rm -rf /fs/mmc0/nav/NNG/license/device.nng
fi

if [ ! -d /fs/mmc1/logs ]; then
	mkdir /fs/mmc1/logs
fi

# Copy logs to /fs/mmc1/logs/ with an added timestamp
echo copying /usr/var/logs/* to mmc1...
for file in /usr/var/logs/*; do
	# Check if the file has already been copied over today,
	# this will prevent losing the original file we intended to keep.
	if [ ! -f /fs/mmc1/logs/`date "+%d_%b_%Y"`'_'${file##*/} ]; then
		cp "$file" /fs/mmc1/logs/`date "+%d_%b_%Y"`'_'${file##*/}
	fi
done

echo Resetting factory installed JAR files...
## For 523 China, we have AMS 2.0 that uses directory structure /fs/mmc1/xlets/xlets/
if [[ ($VARIANT_MODEL = "524") && ($VARIANT_MARKET = "CH") ]]; then
	echo this is ams 2
	rm -rf /fs/mmc1/xlets/xlets/*
	cp -rp /fs/mmc1/kona/preload/xlets/* /fs/mmc1/xlets/xlets/
else
	echo this is ams 1
	rm -rf /fs/mmc1/xletsdir/xlets/*
	cp -rp /fs/mmc1/kona/preload/xlets/* /fs/mmc1/xletsdir/xlets/
fi
rm -rf /fs/mmc1/kona/data/DRM.jar
cp -rp /fs/mmc1/kona/preload/DRM.jar /fs/mmc1/kona/data/
rm -rf /fs/mmc1/resource/*
cp -rp /fs/mmc1/kona/preload/resource/* /fs/mmc1/resource/

# Remove set flags from mmc1/flags/ 
# Logging flags location eventually will be relocated to 
#/fs/mmc1/flags
echo Removing flags from mmc1/flags
rm -rf /fs/mmc1/LOGGING
rm -rf /fs/mmc1/flags/extLogEnabledScopes
rm -rf /fs/mmc0/nav/GNLOG_MSD
rm -rf /fs/mmc0/nav/GNLOG_SD
touch /fs/mmc1/flags/extLogEnabledScopes/DBusTraceMonitor

# call factory_cleanup_support here
echo "Running factory cleanup support script ($1)..."
factory_cleanup_support.lua $1
echo ""
