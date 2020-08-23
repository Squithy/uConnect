#!/bin/sh

VERSION="2.5"

USB0_RW=0         # set USB0 access to false by default
PRG_NAME=$0
DC_SHORT=0        # short version is initialized to false

ETFS_MOUNT_POINT=""  # Mount point for etfs.  Set when find_etfs_mount is called

CONSOLE_DEV=/dev/tty

show_usage()
{
   echo ""
   echo "=========================================================== $VERSION ====="
   echo ""
   echo "Usage: $PRG_NAME [-b] [-c] [-e] [-h] [-i] [-m] [-s]"
   echo ""
   echo "   -b        Save screenshot to /tmp"
   echo "   -c        Send to the console instead of to an archive"
   echo "   -e        Save ETFS to /fs/usb0/SERIAL_NUM.etfs"
   echo "   -h        Show help and exit"
   echo "   -i        Show extra info and exit"
   echo "   -m        Include full MMC checks (~ 20 mins)"
   echo "   -s        Run short-form version"
   echo ""
   echo "Please dump QNX tools that may not be on the target or may"
   echo "be unavailable due to MMC problems into a directory called"
   echo "\"qnx_tools\" on your USB stick.  These include, but are"
   echo "not limited to; hd, awk, find, grep, cat, cksum"
   echo ""
   echo "if in doubt please run at least:  dc.sh -c"
   echo ""
   echo "NOTE:  This script can take several minutes to run in normal mode"
   echo "       (no options).  Add 20 minutes if using -m and add 5 minutes"
   echo "       if using (-e)"
   echo ""
   echo "NOTE:  This -e and -m script slays drivers so you must reset after using it"
   echo ""
   echo "NOTE:  When running short-form version any parameters other then -c and -b"
   echo "       will be ignored."

}

# send message to the console device
msg()
{
   if [[ $DC_OUT = "" ]]; then
      echo $1
   else
      echo $1 2>&1
      echo $1 >> $CONSOLE_DEV
   fi
}

# check if an executable ($1) exists and optionally exit if it is not ($2 == 1)
exec_exists()
{
   echo -n "$PRG_NAME - Checking for $1 ... "
   if command -v $1 >/dev/null 2>&1; then
      echo "exists"
      return 0
   else
      echo -n "not available"
      if [[ $2 -eq 1 ]]; then
         echo " so exiting"
         exit 1
      else
         echo ""
         return 1
      fi
   fi 
}

# write out a header for this section
start_sect()
{
   if [[ $DC_SHORT -eq 1 ]]; then
      msg ""
      msg "$PRG_NAME - $1"
   elif [[ $DC_SHORT -eq 0 ]]; then
      msg ""
      msg "====================================================================="
      msg "$PRG_NAME - $1"
      msg "====================================================================="
      msg ""
   fi
}

# write out a warning
show_warning()
{
   msg ""
   msg "!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   msg "$PRG_NAME - $1"
   msg "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   msg ""
}

# write out an error
show_error()
{
   msg ""
   msg "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   msg "!!!!!!!!!!!!!!!!!!!!!!!!!!! ERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   msg "$PRG_NAME - $1"
   msg "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   msg "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   msg ""
}

# Copy logs from /usr/var/logs to usb0
copy_logs()
{
   msg "Grabbing log files from /usr/var/logs\n"
   #location of log files to copy
   FILES="/usr/var/logs/*"
   #directory to copy logs to
   MOVE_TO="/fs/usb0/"
   for f in $FILES ; do
      cp ${f} $MOVE_TO$SERIAL_NUM.${f#$FILES}
   done   
}

# Find ETFS mount point
find_etfs_mount()
{
   etfs="/dev/etfs2"
   integer index=0
   found_etfs=false    
   etfs_loc=$(mount | grep "type etfs")
   
   for f in ${etfs_loc} ; do
      if [[ $f == $etfs ]] ; then
         found_etfs=true
      fi
      if [ $found_etfs == true ] ; then 
         if [ $index -eq 2 ]; then
            ETFS_MOUNT_POINT=${f}
         fi
      fi
      $((index++))
   done
}

#Set the serial number and make sure it is not null
set_serial_num()
{
   
   SERIAL_NUM=`cat /fs/fram/serialnumber  2>/dev/null | awk '{print $1}'`

   SN=$(hd -An -tx1 /fs/fram/serialnumber | awk '{print $0}')
   
   if [ "$SN" == "ff ff ff ff ff ff ff ff ff ff ff ff ff ff " ] ; then      
      SERIAL_NUM="INVAL_SER"
   fi
   
   if [ "$SN" == "" ] ; then 
      SERIAL_NUM="INVAL_SER"
   fi
   
}


# Used as a flag to show HMI that the script is running.
touch /tmp/dcshRunning

# check if usb0 is there and read/write
if [[ -d /fs/usb0 ]]; then
   echo -n "$PRG_NAME - Checking read/write status of /fs/usb0 ... "
   if mount -uw /fs/usb0; then
      echo "read/write"
      USB0_RW=1
   else
      echo "READ ONLY"
      show_warning "/fs/usb0 exists, but is not read/write (/fs/usb0 is NTFS?)"
      USB0_RW=0
   fi
else
   show_warning "/fs/usb0 does not exist"
   USB0_RW=0
fi

# Get serial number of head unit
start_sect "Getting serial number of HU"
set_serial_num

if [[ USB0_RW -eq 1 ]]; then
   DC_OUT="/fs/usb0/$SERIAL_NUM.dc"
else
   DC_OUT=""
fi


# Parse command line arguments
while getopts bcehims o; do
   case "$o" in
   b) 
      . /tmp/envars.sh
      dbus-send --print-reply --type="method_call" --dest='com.harman.service.HMIGateWay' /com/harman/service/HMIGateWay com.harman.ServiceIpc.Invoke string:"displayGlobalPopup" string:'{"timeout":"3000","showonDisplayoff":"true","showRunningCategory":"true","msg":"Capturing screen snapshot..."}' 
      start_sect "Dumping screenshot to /tmp/ScreenShot.bmp"
      cp /dev/screen/0/win-0/win-0-2.bmp /tmp/ScreenShot.bmp
	  ;;
   c)
      DC_OUT=""
      ;;
   e)
      if [[ USB0_RW -eq 1 ]]; then
         SAVE_ETFS=1
      else
         show_error "Can't save ETFS because /fs/usb0 is not read/write"
      fi
      ;;
   h) 
      show_usage
      exit 1
      ;;
   i)
      msg "Information (things we want to know, but always forget)"
      msg "CAN messages"
      msg "Button presses"
      msg "Other information"
      exit 1
      ;;
   m)
      MMC_CHECK=1
      ;;
   s)
      DC_SHORT=1
      ;;
   *)
      ;;
   esac
done
shift $OPTIND-1
OPTIND=1

if [[ $DC_SHORT -eq 0 ]]; then
	# check if tools directory is available
    if [[ -d /fs/usb0/qnx_tools ]]; then
       export PATH=$PATH:/fs/usb0/qnx_tools
    else
       show_warning "don't see /fs/usb0/qnx_tools"
    fi

	# check for (possibly and absolutely) needed executables
	echo ""
    echo "====================================================================="
	echo "$PRG_NAME - Checking for utilities"
	echo "====================================================================="
	echo ""
	exec_exists echo 1
	exec_exists find 1
	exec_exists cat 1
	exec_exists touch 1
	exec_exists awk 1
	exec_exists grep 1
	exec_exists pidin 1
	exec_exists hd 1
	exec_exists dd 1
	exec_exists usb 1
	exec_exists basename 0
	exec_exists cksum 0
	exec_exists df 0
	exec_exists du 0
	exec_exists mount 0
	exec_exists etfsctl 0
	exec_exists rm 0
	exec_exists tar 0
	echo ""
fi

if [[ $DC_OUT != "" ]]; then
   echo "$PRG_NAME - Sending console output to file" 
   echo "$PRG_NAME - All other output will be per the usage" 
   exec >> $DC_OUT 2>&1
else
   echo "$PRG_NAME - Using console output only" 
fi

if [[ $DC_SHORT -eq 0 ]]; then
   # Get data
   echo "############################################################# $VERSION ###"
   echo "dc.sh - Collecting all data on serial number $SERIAL_NUM"
   echo ""
   echo "           !!!! RESET AFTER RUNNING THIS SCRIPT  !!!!                " 
   echo ""
   echo "#####################################################################"
fi

start_sect "Basic information"

PART_NUM=`cat /fs/fram/partnumber  2>/dev/null | awk '{print $1}'`
PRODUCT_ID=`cat /fs/fram/productid  2>/dev/null | awk '{print $1}'`
HW_TYPE=`cat /fs/fram/hwtype  2>/dev/null | awk '{print $1}'`
MAIN_VER=`grep version /etc/version.txt | awk 'BEGIN { FS="=" } ; {print $2}'`
NAV_VER=`cat /fs/mmc0/nav/NNG/content/dbver.pinfo`
echo "Serial number:  $SERIAL_NUM"
echo "Part number:    $PART_NUM"
echo "Hardware type:  $HW_TYPE"
echo "Product ID:     $PRODUCT_ID"
echo "Nav DB version: $NAV_VER"
echo "Main version:   $MAIN_VER"

date > /tmp/datetime
DATETIME=`cat /tmp/datetime`
echo "Target time:    $DATETIME"

. /tmp/envars.sh


#Popup logic

if [[ -f /tmp/dcshInvokedFromHMI ]] ; then
    # dc.sh was invoked via HMI engineering menu.
    # Show popup for start of dc.sh
    if [[ SAVE_ETFS -eq 1 ]]; then
       # Start popup with -e option
       dbus-send --print-reply --type="method_call" --dest='com.harman.service.HMIGateWay' /com/harman/service/HMIGateWay com.harman.ServiceIpc.Invoke string:"displayGlobalPopup" string:'{"timeout":"","showonDisplayoff":"true","showRunningCategory":"true","msg":"Running dc.sh, this may take up to ~20 minutes... \nDo not remove USB.  When dc.sh has completed the radio will reset."}' 
    else
       # Start popup without -e option
       dbus-send --print-reply --type="method_call" --dest='com.harman.service.HMIGateWay' /com/harman/service/HMIGateWay com.harman.ServiceIpc.Invoke string:"displayGlobalPopup" string:'{"timeout":"","showonDisplayoff":"true","showRunningCategory":"true","msg":"Running dc.sh, this may take up to ~20 minutes... \nDo not remove USB until completion popup is shown."}' 
    fi

    if [[ $DC_SHORT -eq 0 ]]; then
        start_sect "Version information (< 5 seconds)"
        cat /etc/version.txt
    fi   
fi

start_sect "DBUS log (< 5 seconds)"
cat /dev/dbus_buffer

start_sect "Process list snapshot (< 5 seconds)"
pidin a

start_sect "Memory info snapshot (< 5 seconds)"
pidin info

start_sect "Process use snapshot (< 5 seconds)"
srm
thogs -t -z

start_sect "Memory Snapshot (< 5 seconds)"
showmem -P | sort -r -n -u -k 1

start_sect "Kernel fds snapshot (< 5 seconds)"
pidin -p1 fds | grep -c -e '[[:digit:]]*'

if [[ $DC_SHORT -eq 0 ]]; then
	start_sect "Syspage snapshot"
	pidin syspage=asinfo
fi

start_sect "USB info snapshot (< 5 seconds)"
usb -tvv

start_sect "Mounted drive snapshot (< 5 seconds)"
mount

start_sect "Mounted file systems snapshot (< 5 seconds)"
ls -l /fs/

start_sect "Persistant memory usage snapshot (< 5 seconds)"
df -gkh

start_sect "Persistant memory info snapshot (< 5 seconds)"
du -ks /fs/etfs/
du -ks /fs/mmc0/
du -ks /fs/mmc1/

start_sect "Service monitor snapshot (< 5 seconds)"
ls -l /dev/serv-mon/

start_sect "SDARS watchdog output"
ls -lv /usr/var/sdars/

start_sect "audioMgtWatchdog info snapshot"
cat /usr/var/audioMgt/*.txt

start_sect "Reset Log snapshot"
cat /usr/var/logs/reset.log

start_sect "PPS snapshot (< 5 seconds)"
find /pps -type f -exec "echo {};dumppps {};echo" \;

start_sect "IPC driver statistics (< 5 seconds)"
cat /dev/ipc/debug

start_sect "FRAM snapshot (< 5 seconds)"
   for i in `find /dev/mmap/`; do echo $i;hd -v $i;done
      if [[ USB0_RW -eq 1 ]]; then
         dd if=/dev/memory of=/fs/usb0/$SERIAL_NUM.dev_mem bs=1024 count=8
      fi

start_sect "Dbus Audio State Dump (<5 seconds)"
dbus-send --type=method_call --print-reply --dest='com.harman.service.AudioManager' /com/harman/service/AudioManager com.harman.ServiceIpc.Invoke string:getDebugInfo string:'{}'
dbus-send --type=method_call --print-reply --dest='com.harman.service.AudioCtrlSvc' /com/harman/service/AudioCtrlSvc com.harman.ServiceIpc.Invoke string:getDebugInfo string:'{}'
dbus-send --type=method_call --print-reply --dest='com.harman.service.AudioMixerManager' /com/harman/service/AudioMixerManager com.harman.ServiceIpc.Invoke string:getDebugInfo string:'{}'

      
if [[ $DC_SHORT -eq 0 ]]; then
   
   start_sect "MMC0 chkqnx6fs snapshot (~20 seconds)"
   chkqnx6fs -vvvvv /fs/mmc0

   start_sect "MMC1 chkqnx6fs snapshot (~20 seconds)"
   chkqnx6fs -vvvvv /fs/mmc1

   start_sect "Gather any *.core files (~15 seconds)"
   for i in `find / -type f -name \*\.core`; do TGT=$SERIAL_NUM.`basename $i`;cp $i /fs/usb0/$TGT; done


   if [[ MMC_CHECK -eq 1 ]]; then
      if exec_exists cksum; then
	     start_sect "MMC1 checksum snapshot (~ 1 minutes with factory files)"
	     find /fs/mmc1/ -type f -printf "%f " -exec cksum {} \;
	     start_sect "MMC0 checksums snapshot (~ 17 minutes)"
	     find /fs/mmc0/ -type f -printf "%f " -exec cksum {} \;
      else
	     show_error "Could not do mmc checksums because executable was not available"
      fi
   fi

   if [[ ! -e /dev/etfs2 ]]; then
      msg "ETFS driver was not detected as running so starting our own copy"
      fs-etfs-omap3530_micron -c 1024 -D cfg -f /etc/system/config/nand_partition.txt
   fi

   start_sect "ETFS state snapshot"
   if exec_exists etfsctl; then 
      etfsctl -d /dev/etfs2 -i
   else
      show_error "Could not do collect ETFS state because executable was not available"
   fi

   start_sect "IPL image checksum snapshot (< 5 seconds)"
   if [[ -e /dev/etfs2 ]]; then
      imageChecksumUtility -i
   else
      show_error "ETFS driver not detected so IPL image checksums cannot be done"
   fi

   start_sect "IFS image checksum snapshot (~30 seconds)"
   if [[ -e /dev/etfs2 ]]; then
      imageChecksumUtility
   else
      show_error "ETFS driver not detected so IFS image checksums cannot be done"
   fi

   if [[ SAVE_ETFS -eq 1 ]] && [[ USB0_RW -eq 1 ]]; then
      if exec_exists etfsctl; then 
	     start_sect "Creating raw ETFS image snapshot in $SERIAL_NUM.etfs (~ 5 minutes) "
         # Find mount point for etfs
         find_etfs_mount
         #Make sure mount point was found.  If found then unmount, otherwise just grab raw ETFS image
         if [ ! $ETFS_MOUNT_POINT == "" ] ; then
            if [ -d $ETFS_MOUNT_POINT ]; then
               umount -f $ETFS_MOUNT_POINT
               if [ $? -eq 1 ] ; then
                  show_error "Could not umount ETFS"
               else
                  sleep 10
                  etfsctl -d /dev/etfs2 -R /fs/usb0/$SERIAL_NUM.etfs_raw
               fi
            else
               show_error "Could not collect ETFS image because ETFS directory did not exist"
            fi
         else
            etfsctl -d /dev/etfs2 -R /fs/usb0/$SERIAL_NUM.etfs_raw
         fi
      else
	     show_error "Could not do collect ETFS image because executable was not available"
      fi
   fi

   if [[ USB0_RW -eq 1 ]] && [[ $DC_OUT != "" ]]; then
      start_sect "Copying logs from /usr/var/logs to USB0"
      copy_logs
   fi
   
   msg ""
   msg "#####################################################################"
   msg ""
   if [[ USB0_RW -eq 1 ]] && [[ $DC_OUT != "" ]]; then
      if exec_exists tar; then
         cd /fs/usb0/
		 cp /tmp/ScreenShot.bmp /fs/usb0/
         echo -n "$PRG_NAME - Archiving ... " > $CONSOLE_DEV
         UF=dc.$SERIAL_NUM.`date "+%Y.w%V.h%H.m%M.s%S"`.tar.gz
         if tar --remove-files -czf $UF $SERIAL_NUM.*; then
            msg "done\n$PRG_NAME - Please send /fs/usb0/$UF for analysis"
            tar -tf $UF > $CONSOLE_DEV
         else
            msg "archive failed"
            msg "$PRG_NAME - Gather console output and any $SERIAL_NUM.* files for analysis"
         fi
      else
         show_error "Could not do tar of results because executable was not available"
      fi
   else
      msg "$PRG_NAME - Gather console output and any $SERIAL_NUM.* files for analysis"
   fi
   msg "$PRG_NAME - Finished collecting data"
   msg ""
   if [[ SAVE_ETFS -eq 1 ]]; then
      msg " THIS SCRIPT HAS MOST ASSUREDLY CAUSED ISSUES.  AN IGN CYCLE IS RECOMMENDED"
      msg ""
   fi
   msg "#####################################################################"
fi

if [[ -f /tmp/dcshInvokedFromHMI ]] ; then
    if [[ SAVE_ETFS -eq 1 ]]; then
       # Popup to inform the user that the script has completed running.
       dbus-send --print-reply --type="method_call" --dest='com.harman.service.HMIGateWay' /com/harman/service/HMIGateWay com.harman.ServiceIpc.Invoke string:"displayGlobalPopup" string:'{"timeout":"","showonDisplayoff":"true","showRunningCategory":"true","msg":"dc.sh has completed.  The radio will reset in ~10 seconds."}'
       sleep 10
       reset
    else
       # Popup to inform the user that the script has completed running without -e option.  No reset needed.
       dbus-send --print-reply --type="method_call" --dest='com.harman.service.HMIGateWay' /com/harman/service/HMIGateWay com.harman.ServiceIpc.Invoke string:"displayGlobalPopup" string:'{"timeout":"","showonDisplayoff":"true","showRunningCategory":"true","msg":"dc.sh has completed.  It is now safe to remove the USB device."}'
    fi
fi

# Remove the HMI flag to show HMI that the script has completed.
rm /tmp/dcshRunning

if [[ -f /tmp/dcshInvokedFromHMI ]] ; then
	rm /tmp/dcshInvokedFromHMI
fi




# Notes
# ----------------------------------------------------------------------------------
# Stripping the path off of the files so we can compare without a lot of effort
#
#    - Extract EQ/ MMC_IFS_EXTENSION/ SKINS/ SPEECH/ XLETS/ from the ISO and...
#    - find EQ/ MMC_IFS_EXTENSION/ SKINS/ SPEECH/ XLETS/ -type f  -printf "%f " -exec cksum {} \;
#    - To get rid of spaces?
#    - for i in `find EQ/ MMC_IFS_EXTENSION/ SKINS/ SPEECH/ XLETS/ -type f`; do basename $i | tr '\n' ' '; cksum $i | sed 's/ /_/'; done
