#!/bin/sh
# LOCK to prevent two copies of script to run twice in a session
if ( set -o noclobber; echo "locked" > /tmp/HCPscript_lock) 2> /dev/null; then
	echo "\n#### runhcpclient.sh: called ####\n"  > /dev/ser3

	echo "starting ring buffer" > /dev/ser3
	/fs/mmc0/app/bin/ring_buffer -R /dev/dbus_buffer -B 102400 &
	
	# WAIT default 5 seconds for the path to appear
	qwaitfor /dev/dbus_buffer 
		
	echo "starting dbus-monitor" > /dev/ser3
	/fs/mmc0/app/bin/dbus-monitor > /dev/dbus_buffer &
	/fs/mmc0/app/bin/HCPMonitor -c /fs/etfs/usr/var/hcp/HCPConfig.conf &
else
	echo "HCP script has already ran once in this session. Exiting...." > /dev/ser3
fi	 
	