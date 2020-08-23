#!/bin/sh

# Handle an Ethernet connection via the CISCO Linksys USB300M adapter

test_service_flag network
if [ $? -ne 0 ]; then
   echo "NETWORK network flag is not enabled"
   exit 1
fi

# get the user variables if defined
if [ -e /fs/etfs/development/net ] ;  then
   . /fs/etfs/development/net
else
	echo "NETWORK variables not sourced from \"/fs/etfs/development/net\""
	echo "NETWORK see template file at \"/fs/mmc0/app/share/develop/net_template\""
fi

# Verify that the USB driver has been started properly
waitfor /dev/io-usb
if [ $? -ne 0 ] ;  then
   echo "NETWORK waited for 5 seconds, but the USB driver is not loaded"
   exit 1
fi

# Load the adapter driver if not already running
echo NETWORK starting ...
if [ ! -e /dev/io-net/en0 ]; then
   mount -T io-pkt devn-asix.so
   waitfor /dev/io-net/en0
   if [ $? -ne 0 ] ;  then
      echo "NETWORK waited for 5 seconds, but the D-Link adapter driver did not load"
      exit 2
   fi
fi

if [ -a /fs/etfs/useWLAN4QXDM ] ; then
 	rm /fs/etfs/useWLAN4QXDM
fi

# use static ip address if set, else use DHCP, else fall back to default static ip address
DHCP_TIMEOUT=80
ifconfig en0 delete 2> /dev/null
if [ $STATIC_IP ] ; then
   echo "Static IP $STATIC_IP requested, setting"
   ifconfig en0 $STATIC_IP
else
   slay -f -s KILL dhcp.client > /dev/null
   if [ $TARGET_NAME ] ;  then
      echo "NETWORK requesting IP address with name \"${TARGET_NAME}\" ..."
      nice -n-1 dhcp.client -umb -A0 -i en0 -t1 -T$DHCP_TIMEOUT -h $TARGET_NAME
   else
      echo "NETWORK requesting IP address without setting TARGET_NAME ..."
      nice -n-1 dhcp.client -umb -A0 -i en0 -t1 -T$DHCP_TIMEOUT
   fi
   if [ $? -eq 3 ] ;  then
      STATIC_IP=192.168.6.1
      echo "NETWORK could not find a DHCP server after $DHCP_TIMEOUT deconds so setting static IP to $STATIC_IP"
      ifconfig en0 $STATIC_IP   
   else
      touch /tmp/networkingpossible
      touch /fs/etfs/useWLAN4QXDM
   fi
fi

# Start networking daemons
slay -f -s KILL inetd > /dev/null
echo "NETWORK starting network daemons..."
inetd
if [ $? -ne 0 ] ;  then
   echo "NETWORK inetd did not start"
fi
   
if [ ! -e /fs/etfs/FORCE_DBUSTRACE_MON ]; then
   slay -f -s KILL dbustracemonitor > /dev/null
   dbustracemonitor -f=/usr/var/trace/traceDbusServices --tp=/fs/mmc0/app/share/trace/DBusTraceMonitor.hbtc --bp=/HBpersistence &
   if [ $? -ne 0 ] ;  then
      echo "NETWORK dbustracemonitor did not start"
   fi
else
   echo "NETWORK dbustracemonitor is already being forced"
fi

echo "NETWORK setup complete"

exit 0
