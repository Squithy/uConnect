#!/bin/sh
#Script that starts ServiceBroker if service is not running, else dont start again.
if ( set -o noclobber; echo "locked" > /tmp/ServiceBroker_lock) 2> /dev/null; then
	echo "\n#### ServiceBroker.sh: called ####\n"  > /dev/ser3

	echo "starting servicebroker" > /dev/ser3
	/fs/mmc0/app/bin/servicebroker &
	
else
	echo "ServiceBroker script has already ran once in this session. Exiting...." > /dev/ser3
fi	 
	
