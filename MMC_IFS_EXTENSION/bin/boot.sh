#!/bin/sh

# ----- Functions ----

loadtertiaryifs()
{
   echo memifs2 with 4-bit ECC including spare area
	# (use this if loading with etfs not already loaded) memifs2 -q -N -e 2 -n /
   memifs2 -p 3 -q -N -e 2 -n /
   if [[ 0 != $? ]] ; then
      echo "**********Failure while loading tertiary IFS**********" > /dev/ser3
      echo "**********Marking current IFS as invalid ***********"
      qwaitfor /dev/mmap/
      adjustImageState -c 1
      if [[ 0 == $? ]] ; then
         echo "**********Image state set to bad************"
      else
         echo "*******Unable to adjust image state - FRAM not available********"
      fi
      echo "**********Resetting the hardware********************"
      echo -n "\\0021" > /dev/ipc/ch4
   else
      echo "Tertiary IFS loaded successfully"
   fi
}



loadquadifs()
{
   echo memifs2 with 4-bit ECC including spare area
	# (use this if loading with etfs not already loaded) memifs2 -q -N -e 2 -n /
   memifs2 -q -l 40 -p 4 -N -e 2 -n /
   if [[ 0 != $? ]] ; then
      echo "**********Failure while loading quaternary IFS**********" > /dev/ser3
      echo "**********Marking current IFS as invalid ***********"
      qwaitfor /dev/mmap/
      adjustImageState -c 1
      if [[ 0 == $? ]] ; then
         echo "**********Image state set to bad************"
      else
         echo "*******Unable to adjust image state - FRAM not available********"
      fi
      adjustImageState -c 1
      echo "**********Resetting the hardware********************"
      echo -n "\\0021" > /dev/ipc/ch4
   else
      echo "quad IFS loaded successfully"
   fi
}

startdbustracemonitor()
{
   /fs/mmc0/app/bin/enableTraceScopes.sh
   echo "\nWaiting for dbustracemonitor to be available\n" > /dev/ser3
   qwaitfor /usr/bin/dbustracemonitor 30
   qwaitfor /usr/var/trace/traceDbusServices 30
   qwaitfor /fs/mmc0/app/share/trace/DBusTraceMonitor.hbtc 30
   dbustracemonitor -f=/usr/var/trace/traceDbusServices --tp=/fs/mmc0/app/share/trace/DBusTraceMonitor.hbtc --bp=/HBpersistence &
}

# ---- Main ----

export CONSOLE_DEVICE=/dev/ser3

# Redirect all output to /dev/null at startup to clean up the console
# Can turn on after etfs driver starts with /fs/etfs/VERBOSE_STARTUP
reopen /dev/null

echo ========= Start of boot.sh ====================

###   echo starting io-pkt............
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/wicome io-pkt-v4 -ptcpip stacksize=8192


###   echo starting dbus............
# Start dbus with the debug version if needed.  Required for automated testing
qln -sfP /tmp /usr/var/run/dbus
if [ -e /fs/mmc1/flags/debug-session.conf ]; then
   nice -n-2 /usr/bin/dbus-launch --sh-syntax --config-file=/fs/mmc1/flags/debug-session.conf > /tmp/envars.sh
else
   nice -n-2 /usr/bin/dbus-launch --sh-syntax --config-file=/etc/dbus-1/session.conf > /tmp/envars.sh
fi

echo "setting dbus variables for clients"
echo "export SVCIPC_DISPATCH_PRIORITY=12;" >> /tmp/envars.sh
eval `cat /tmp/envars.sh`

### Dbus monitor if requested
if [ -e /fs/mmc1/DBUS_MONITOR ]; then
(
  #Store dbus monitor to file in /tmp for 5 minutes and then stop
  dbus_outfile='/tmp/dbus-monitor.log'
  . /tmp/envars.sh
  dbus-monitor >$dbus_outfile &
  DBM_PID=$!
  echo "starting dbus-logging to /tmp"
  sleep 300 
  slay $DBM_PID
) &
fi

echo "starting service-monitor"
/usr/bin/service-monitor > $CONSOLE_DEVICE &

# Set the platform variant information. Must come before launching platform services
eval `variant export`

# Launch isp-screen AFTER DBUS is fully setup
# isp-screen requires the VARIANT_PRODUCT shell variable exported via the above "eval `variant export`" command
echo "starting camera service"
nice -n-11 isp-screen -s -d /usr/bin/cmc/service/ispvideo ispVideoService.lua &

 
# Extend the LUA path to include platform services and bundles
LUA_PATH="$LUA_PATH;/usr/bin/cmc/service/?.lua;/usr/bin/cmc/service/platform/?.lua"

nice -n-1 lua -s -b -d /usr/bin service.lua
# Run the platform launcher in a "managed" manner by service.lua borrowed from VP3L
nice -n-1 lua -b -d /usr/bin/cmc/service/platform platform_launcher.lua -m -n launch_bundle -p bundle.stage0 

#  Start the usb overcurrent monitor utility
usb_hub_oc -p 10 -i 10 -d 500 &

#Command to start a kernel trace if desired at startup
#tracelogger -M -S 64M -s 3 -w &

#io -a 0x48320010 > $CONSOLE_DEVICE &
# Things started and used before loading the secondary IFS must be in the boot.ifs
###   echo loading Tertiary IFS............
loadtertiaryifs &

#Check for LOGGING flag in mmc1 (etfs is not available at this point in boot script).
#If not flag exists - route all trace points to dev/null and start mv2trace with socket connection
if [ ! -e /fs/mmc1/LOGGING ]; then
   qln -sP /dev/null /fs/mmc0/app/share/trace
   qln -sP /dev/null /hbsystem/multicore/navi/3
   qln -sP /dev/null /hbsystem/multicore/navi/4
   qln -sP /dev/null /hbsystem/multicore/navi/J
   qln -sP /dev/null /hbsystem/multicore/navi/dbglvl
   qln -sP /dev/null /hbsystem/multicore/navi/g
   qln -sP /dev/null /hbsystem/multicore/navi/q
   qln -sP /dev/null /hbsystem/multicore/navi/multi
   qln -sP /dev/null /hbsystem/multicore/navi/p
   qln -sP /dev/null /hbsystem/multicore/navi/r
   qln -sP /dev/null /hbsystem/multicore/temic/0
   qln -sP /dev/null /hbsystem/multicore/trace/0
   dev-mv2trace -b 10000 -w 5 -m socket &
else
   # if want to write log directly to usb, make sure the mark /fs/mmc1/USB_LOGGING is removed.
   if [ -e /fs/mmc1/USB_LOGGING ]; then
      ###   echo starting trace client............
      multicored -D2 -F2 -n500 -Q -c file -q -m /hbsystem/multicore -R -f /fs/mmc1/LOGFILE.DAT -s 524288000 &
      qwaitfor /hbsystem/multicore
      dev-mv2trace -b 10000 -w 5 -m multicored -f &
      startdbustracemonitor &
      mount -uw /fs/mmc1 &
   elif [ -e /fs/mmc0/nav/GNLOG_MSD ]; then
      multicored -D2 -F2 -n500 -Q -c file -q -m /hbsystem/multicore -R -f /fs/usb0/LOGFILE.DAT -s 524288000 &
      qwaitfor /hbsystem/multicore
      dev-mv2trace -b 10000 -w 5 -m multicored -f &
      startdbustracemonitor &
   elif [ -e /fs/mmc0/nav/GNLOG_SD ]; then
      multicored -D2 -F2 -n500 -Q -c file -q -m /hbsystem/multicore -R -f /fs/sd0/LOGFILE.DAT -s 524288000 &
      qwaitfor /hbsystem/multicore
      dev-mv2trace -b 10000 -w 5 -m multicored -f &
      startdbustracemonitor &
   else
      multicored -D0 -F0 -n500 -Q -c file -q -m /hbsystem/multicore &
      qwaitfor /hbsystem/multicore
      dev-mv2trace -b 10000 -w 5 -m multicored &
   fi
fi

echo "starting io-audio "
nice -n-201 io-audio -osw_mixer_samples=3072,intr_thread_prio=254 -domap35xx-dsp mcbsp=2,clk_mode=1,tx_voices=4,rx_voices=4,protocol=tdm,xclk_pol=1,sample_size=16 -osw_mixer_samples=768,intr_thread_prio=254 -domap35xx-bt mcbsp=4,clk_mode=1,sample_size=16,tx_voices=1,rx_voices=1,protocol=tdm,bit_delay=1,cap_name=bt_capture,play_name=bt_play -osw_mixer_samples=1536,intr_thread_prio=254 -domap35xx-bt mcbsp=5,clk_mode=1,sample_size=16,tx_voices=2,rx_voices=2,protocol=pcm,bit_delay=1,cap_name=embedded_capture,play_name=embedded_play

# launching persistency manager is dependent on qdb
echo "starting persistency_mgr"
persistency_mgr -p -v 2 -c /etc/persistency_mgr/pmem.ini > $CONSOLE_DEVICE 2>&1

###   echo starting pps............
qwaitfor /dev/pmfs 
pps -p /dev/pmfs 

qon -p 11 -d audioCtrlSvc -c /etc/audioCtrlSvcDEFAULT.conf --tp=/fs/mmc0/app/share/trace/audioCtrlSvc.hbtc &
qwaitfor /dev/serv-mon/com.harman.service.PersistentKeyValue

echo "bundle::bundle.stage1a" >> /pps/launch_bundle
set_default_theme

###   echo starting canservice............
canservice 

# temp link so touch input works
qln -sfP /tmp /dev/devi

qwaitfor /bin/fs-etfs-omap3530_micron
echo "tertiary loaded"  > $CONSOLE_DEVICE &
#io -a 0x48320010 > $CONSOLE_DEVICE &

#starting the random generator now
random -t -p &

###   echo starting ETFS driver............
fs-etfs-omap3530_micron -c 1024 -D cfg -m/fs/etfs -f /etc/system/config/nand_partition.txt

hmiGateway -sj

#Boosting the priority
slay -T3 -P11 hmiGateway

# Must start prior to USB enumeration. We must ensure the itun
# setup is not delayed when an iPhone is connected at startup
# with the entune app running. We have 5 seconds to start the 
# itun driver and reply to the iPhone. If we miss this window 
# the user will have to disconnect/connect the entune app. So
# start this driver early so it has time to initialize.
mount -T io-pkt lsm-tun-v4.so


# Ensure qdb directories exists before starting it
if [ ! -d /usr/var/qdb ]; then
mkdir -p /usr/var/qdb
else
   ###   echo checking for 0 length key_value database............
   kv_chk.sh
fi

echo "starting qdb"
# Keep this section as similar as possible to media.sh
bootShQdbLocale=latin2@unicode
if [ ! -e /fs/etfs/VERBOSE_QDB ]; then
  qdbVerbose=
  qdbTraceProfile=
else
  qdbVerbose=-vvvvvv
  qdbTraceProfile=,trace,profile
fi
#echo qon qdb -c /etc/qdb.cfg -s ${bootShQdbLocale} ${qdbVerbose} -o unblock=0,tempstore=/usr/var/qdb${qdbTraceProfile} -R auto -X /bin/qdb_recover.sh > $CONSOLE_DEVICE
     qon qdb -c /etc/qdb.cfg -s ${bootShQdbLocale} ${qdbVerbose} -o unblock=0,tempstore=/usr/var/qdb${qdbTraceProfile} -R auto -X /bin/qdb_recover.sh
qon -p 11 cmcManager -m autoplay -c /etc/audioDSP/audioMgrCMC.conf --tp=/fs/mmc0/app/share/trace/cmcManager.hbtc &
lua -s -b /usr/bin/cmc/audioMgtWatchdog.lua

# Redirect all output back to the console if developer wants verbose output
if [ -e /fs/etfs/VERBOSE_STARTUP ]; then
   reopen $CONSOLE_DEVICE
fi

# start Replay Manager if Logging Enabled and /fs/etfs/REPLAY_ENABLED touched
if [[ -e  /fs/mmc1/LOGGING ]] && [[ -e /fs/etfs/REPLAY_ENABLED ]]; then
ReplayManager &
fi

echo "starting flexgps & ndr"
flexgps_ndr.sh 

# start packet filtering early enough to prevent telnet access 
# even if user has DHCP server on connected PC
# starts enabled and reads config from default /etc/pf.conf
mount -T io-pkt lsm-pf-v4.so

# Launch Clock Service
lua -s -b -d /usr/bin/cmc/service/platform/clock clock.lua

if [ -x /fs/etfs/custom.sh ]; then
   echo running custom.sh............ > $CONSOLE_DEVICE
   /fs/etfs/custom.sh > $CONSOLE_DEVICE
fi

# This script can be used to set configuration settings after an update (if needed)
if [ -x /fs/mmc0/app/bin/runafterupdate.sh ]; then
   echo running runafterupdate.sh............ > $CONSOLE_DEVICE
   qon /fs/mmc0/app/bin/runafterupdate.sh &
fi


#audioCtrlSvc -c /etc/audioCtrlSvcDEFAULT.conf --tp=/fs/mmc0/app/share/trace/audioCtrlSvc.hbtc &

# echo "starting diag service"
#echo TestToolPresent::1 > /pps/can/tester
diagservON=0
if grep -qs TestToolPresent::1 /pps/can/tester; then
diagservON=1
lua -s -b  /usr/bin/cmc/service/diagserv.lua
fi

#echo "starting adl"
#io -a 0x48320010 > $CONSOLE_DEVICE &

# ARGUMENT TO SET ADL PID
ADL_PID_FILE=/tmp/adlpid

# Set HMI boost time in msec and priority
# Set time to 0 to disable priority boost
echo -n 0 > /tmp/HMI_BOOST_TIME

# Running ADL at priority 11 for hmi improvement
MALLOC_ARENA_SIZE=65535 nice -n-1 processStarter ADL /bin/adl -runtime /lib/air/runtimeSDK /fs/mmc0/app/share/hmi/main.xml & 
AD3_PID=$!
echo -n $AD3_PID > $ADL_PID_FILE

#temporarily raising priority of onoff, until natp is fixed
qon -p 11 lua -s -b /usr/bin/onoff/main.lua > $CONSOLE_DEVICE

echo "starting hwctrl"
hwctrl

# THIS IS CREATED BY ADL WHEN DISCLAIMER IS SHOWN
#TODO: REMOVE THIS WHEN ANGELO STARTUP CHANGES ARE BROUGHT IN
#waitfor /tmp/adl_startup.txt 10

# Stage1a Lua scripts
#echo "bundle::bundle.stage1a" >> /pps/launch_bundle
# Stage1 Lua scripts
echo "bundle::bundle.stage1" >> /pps/launch_bundle

# FOR 330 VARIANT ONLY
lua -s -b /usr/bin/cmc/service/330Service/330Serv.lua


if [ $VARIANT_MARKET = "JP" ]; then
   echo "starting dev-spi-omap35x driver for VICS spi" > $CONSOLE_DEVICE
   dev-spi-omap35x -c /etc/tuner/dev-spi_4-vics.cfg &
fi

echo "starting AM/FM tuner"
#-DEST uses DEST code
#-VEHLINE uses VC_VEH_LINE
if [ -e /var/override/verboseTunerStart ]; then
   lua -s -b -d /usr/bin/cmc/service/Tuner/ main.lua -VEHLINE -DEST -v 0x8000 > $CONSOLE_DEVICE
else
   lua -s -b -d /usr/bin/cmc/service/Tuner/ main.lua -VEHLINE -DEST
fi

echo "starting audio manager"
#cmcManager -m autoplay -c /etc/audioDSP/audioMgrCMC.conf --tp=/fs/mmc0/app/share/trace/cmcManager.hbtc &
#lua -s -b /usr/bin/cmc/audioMgtWatchdog.lua

export LAST_AUDIO_MODE=$(cat /tmp/lastAudioMode)

if [[ ($LAST_AUDIO_MODE = cd) || ($LAST_AUDIO_MODE = aux[12]) || ($LAST_AUDIO_MODE = hdmi[12]) ]]; then
    echo "last audio mode is a RSE source"  > $CONSOLE_DEVICE &
    #starting RSE as independent entity
    lua -s -b /usr/bin/cmc/service/platform/rse/rseDbusInterface.lua
fi

# Launch stage2 Lua scripts (software/hardware key processing)
echo "bundle::bundle.stage2" >> /pps/launch_bundle

echo "starting appManager"
if [ ! -d /fs/etfs/usr/var/appman/xletRMS ]; then
	mkdir -p /fs/etfs/usr/var/appman/xletRMS
fi

disableDRMArg=-d

if [ -e /fs/etfs/disableDRM ]; then
  disableDRMArg=
fi

appManager -s -j -v ${disableDRMArg} -c=/etc/system/config/appManager.cfg --tp=/fs/mmc0/app/share/trace/appManager.hbtc & 


if [ $VARIANT_SDARS = "YES" ]; then
   echo "starting XM control port"
   ####
   # Note: If the command line for the serial driver is changed, please make the same change in platform_xmApp.lua
   ####
   devc-ser8250 -u4 -I32768 -r200 -R50 -D800 -c7372800/16 0x09000000^1,167
   qwaitfor /dev/ser4 4
fi


if [[ $LAST_AUDIO_MODE = sat ]]; then
    echo "[BOOT] Last audio mode is XM"  > $CONSOLE_DEVICE &
    if [ $VARIANT_SDARS = "YES" ]; then
        echo "[BOOT] Starting xmApp"    
        if [ -e /fs/etfs/SYSTEM_UPDATE_DONE ]; then
            echo "Copying from /fs/mmc0/app/share/sdars/traffic to /fs/etfs/usr/var/sdars/ (no overwrite)"  > $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/traffic /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/sports to /fs/etfs/usr/var/sdars/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/sports /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/sportsservice to /fs/etfs/usr/var/sdars/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/sportsservice /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/channelart to /fs/etfs/usr/var/sdars/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/channelart /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/phonetics to /fs/etfs/usr/var/sdars/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/phonetics /fs/etfs/usr/var/sdars/            

            chmod  -R +rwx /fs/etfs/usr/var/sdars 
        fi              

        if [ $VARIANT_MODEL = "VP4" ]; then
            (qwaitfor /tmp/xm_shdn_line_ready.txt; xmApp -c /etc/sdars/XMApp.cfg --tp=/fs/mmc0/app/share/trace/XMApp.hbtc) &       
			lua -s -b /usr/bin/cmc/xmwatchdog.lua
        else
            (qwaitfor /tmp/xm_shdn_line_ready.txt; xmApp -c /etc/sdars/XMAppAudioOnly.cfg --tp=/fs/mmc0/app/share/trace/XMApp.hbtc) &      
            lua -s -b /usr/bin/cmc/xmwatchdog.lua
        fi
        qwaitfor /tmp/xmAppModuleInitializing 10 
    fi
fi


# THIS IS CREATED BY  LAYER MANAGER WHEN ACCEPT BUTTON IS READY
qwaitfor /tmp/accept.txt 10

# save sequentual dumps to ETFS if requested
if [ -e /fs/etfs/enableDumper ]; then
   dumper -d /fs/usb0 -n &
fi

echo copy resolv.conf to /tmp....
cp /fs/mmc0/app/share/ppp/resolv.conf /tmp/resolv.conf

# Must start prior to USB enumeration. We must ensure the itun
# setup is not delayed when an iPhone is connected at startup
# with the entune app running.
echo "starting connection manager"
connmgr -c "/etc/system/config/connmgr_P_1_2.json"

# Link different config files
lua /fs/mmc0/app/bin/enum_devices.lua

echo "starting usb detection"
enum-devices -c /etc/system/enum/common


# Start media.  Do not background this.
media.sh
qwaitfor /dev/serv-mon/com.harman.service.Media

#Start IPod Tagging services
ipodtagging_startup.sh

# Launch the bundle that launches vehicle status, and CAN reporting services
echo "bundle::bundle.stage3" >> /pps/launch_bundle

# Start dbus-monitor  only if this flag is set  else its started when 
# cisco or dlink adapter is detected
if [ -e /fs/etfs/FORCE_DBUSTRACE_MON ]; then
    echo "starting dbustracemonitor"
    dbustracemonitor -f=/usr/var/trace/traceDbusServices --tp=/fs/mmc0/app/share/trace/DBusTraceMonitor.hbtc --bp=/HBpersistence &
fi

if [[ $LAST_AUDIO_MODE != sat ]]; then
    echo "[BOOT] Last audio mode is not XM"  > $CONSOLE_DEVICE &
    if [ $VARIANT_SDARS = "YES" ]; then
        echo "[BOOT] Starting xmApp"    
        if [ -e /fs/etfs/SYSTEM_UPDATE_DONE ]; then
            echo "Copying from /fs/mmc0/app/share/sdars/traffic to /fs/etfs/usr/var/sdars/ (no overwrite)"  > $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/traffic /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/sports to /fs/etfs/usr/var/sdars/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/sports /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/sportsservice to /fs/etfs/usr/var/sdars/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/sportsservice /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/channelart to /fs/etfs/usr/var/sdars/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/channelart /fs/etfs/usr/var/sdars/ 

            echo "Copying from /fs/mmc0/app/share/sdars/phonetics/rec to /fs/etfs/usr/var/sdars/phonetics/ (no overwrite)" >  $CONSOLE_DEVICE
            cp -RX /fs/mmc0/app/share/sdars/phonetics/rec /fs/etfs/usr/var/sdars/phonetics/            
            # Not copying tts files since tts is not used.

            chmod  -R +rwx /fs/etfs/usr/var/sdars 
        fi              
        if [ $VARIANT_MODEL = "VP4" ]; then
            (qwaitfor /tmp/xm_shdn_line_ready.txt; xmApp -c /etc/sdars/XMApp.cfg --tp=/fs/mmc0/app/share/trace/XMApp.hbtc) &
            lua -s -b /usr/bin/cmc/xmwatchdog.lua
        else
            (qwaitfor /tmp/xm_shdn_line_ready.txt; xmApp -c /etc/sdars/XMAppAudioOnly.cfg --tp=/fs/mmc0/app/share/trace/XMApp.hbtc) &      
            lua -s -b /usr/bin/cmc/xmwatchdog.lua
        fi
    fi
    

fi

echo loading quaternary IFS............   > $CONSOLE_DEVICE
loadquadifs


# echo "starting diag service"
#start diagserver only if it diagserv is not already running 1= running 0 not- running
if [ $diagservON -ne 1 ]; then
lua -s -b  /usr/bin/cmc/service/diagserv.lua
fi
# starting cpulogger and HCPClient if related flag is on
if [ -e /fs/etfs/SYSTEM_UPDATE_DONE ]; then
            echo "Copying from /fs/mmc0/app/share/hcp/HCPConfig.conf to //fs/etfs/usr/var/HCP/ (Overwrite)"  > $CONSOLE_DEVICE
            cp /fs/mmc0/app/share/hcp/HCPConfig.conf /fs/etfs/usr/var/hcp/ 
fi
echo "starting cpulogger service " > $CONSOLE_DEVICE
qon -d lua -s -b /fs/mmc0/app/bin/cpulogger.lua 
mqueue
if [ -e /fs/etfs/HCPClientON ]; then
	
	echo "starting runhcpclient task " > $CONSOLE_DEVICE
    /fs/mmc0/app/bin/runhcpclient.sh &
fi

echo "starting Vehicle Lua services" 

# Launch the bundle that launches personal configuration, swcPal, vehicle settings,
# hvac, climate and psse 
echo "bundle::bundle.stage4" >> /pps/launch_bundle

if [[ ($LAST_AUDIO_MODE != cd) && ($LAST_AUDIO_MODE != aux[12]) && ($LAST_AUDIO_MODE != hdmi[12]) ]]; then
    echo "last audio mode was not an RSE source"  > $CONSOLE_DEVICE &
    #starting RSE as independent entity
    lua -s -b /usr/bin/cmc/service/platform/rse/rseDbusInterface.lua
fi

# Starting dabLauncher
# DR: Temporary until DAB_PRSNT is added to canservice
# ST: This lua script exits, and even with the -b option it was taking 3 sec. to continue the boot.sh
# ST: Removing -b option and using & to put it in the background
if [ -e /var/override/forceDABStart ]; then
   lua -s /usr/bin/cmc/dabLauncher.lua -v -f &
else
   lua -s /usr/bin/cmc/dabLauncher.lua &
fi

echo "Starting Authentication Service"
authenticationService -k /etc/system/config/authenticationServiceKeyFile.json &


echo "starting Navigation"
nav.sh

qwaitfor /dev/serv-mon/com.harman.service.Navigation 10 

echo "starting WavePrompter service"

wavePrompter -p12 -c /fs/mmc0/app/share/wavePrompter/wavePrompter.conf &


echo "starting Bluetooth"
bt_wicome_start.sh 

qwaitfor /dev/serv-mon/com.harman.service.BluetoothService 5


echo "starting UISpeechService and natp for speech recognition and tts"
#/bin/sh /fs/mmc0/app/bin/start_natp.sh
speech.sh 

# this file is not createed by anyone , this is just a dumb wait 
# so that natp gets time to finish initial startup.
# Will be removed with the file created by UISS 
qwaitfor /tmp/waitfornothing 12 

qwaitfor /dev/serv-mon/com.harman.service.UISpeechService 5

if [ $VARIANT_MARKET = "CH" ]; then
echo "China embeddedPhoneDbusService not supported..."
else
echo "starting embeddedPhoneDbusService"
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/wicome embeddedPhone -s /usr/bin/cmc/service/embeddedPhoneDbusService.lua &
fi

# Start sideStreamer, create system directory files used by mediaService for streaming files
#   these entries must match entries in mcd.conf and mme_data.sql
if [ -e /fs/etfs/VERBOSE_SIDESTREAMER_USB ]; then
	echo starting sideStreamer verbosely with log
	/usr/bin/sideStreamer -v 7ff -s /etc/system/config/sideStreamer.conf > /fs/usb0/streamer.log &
elif [ -e /fs/etfs/VERBOSE_SIDESTREAMER_ETFS ]; then
	echo starting sideStreamer verbosely with log
	if [! -e /fs/etfs/tmp/sideStreamer ]; then
		mkdir /fs/etfs/tmp/sideStreamer
	fi
	/usr/bin/sideStreamer -v 7ff -s /etc/system/config/sideStreamer.conf > /fs/etfs/tmp/sideStreamer/streamer.log &
else
	echo starting sideStreamer 
	/usr/bin/sideStreamer -v 1 -s /etc/system/config/sideStreamer.conf &
fi

# FOR 330 VARIANT ONLY
echo "Starting Accenture UConnect service listener for proxy..."
lua -s -b /usr/bin/cmc/service/TomTomLiveProxy.lua --bp=/HBpersistence --tp=/usr/local/share/trace/TomTomLiveProxy.hbtc >/hbsystem/multicore/navi/p 2>&1 &

if [ $VARIANT_MARKET = "CH" ]; then
echo "China ecallService not supported..."
else
echo "starting ecallService"
(qwaitfor /dev/serv-mon/com.harman.service.EmbeddedPhone 30; ecallService --tp=/fs/mmc0/app/share/trace/ecallService.hbtc)  &
fi

echo "starting connectivity"  > $CONSOLE_DEVICE
connectivity_startup.sh &

echo "starting eqService............."
lua -s -b  -d /usr/bin/service/eqService/ eqService.lua -i /dev/mcd/SER_ATTACH -e /dev/mcd/SER_DETACH -b /fs/mmc0/eq

# Launch the bundle that launches embedded phone, SDP DataManager, and DTC services
echo "bundle::bundle.stage5" >> /pps/launch_bundle  

#lets start the service which are less important after navigation is up 
qwaitfor /dev/serv-mon/com.aicas.xlet.manager.AMS 30 

# Launch the bundle that launches systemInfo, screen shot, nav trail service,
# and file services
echo "bundle::bundle.stage6" >> /pps/launch_bundle

echo "starting software update service"
(cd /usr/bin/cmc/service/swdlMediaDetect; lua -s -b  ./swdlMediaDetect.lua) &

echo "Starting Anti Read Disturb Service"
ards_startup.sh &

echo "Starting omapTempService ........."
omapTempService -d -p 2000 

echo "Starting fsloginfo"
fsloginfo -f /usr/var/logs/fdumper -l 8 -m 19333 &
fsloginfo -f /usr/var/logs/ndr -l 512 -m 20356 &

echo "Starting fdumper"
fdumper -R /dev/dbus_buffer &


# Start Image Rot Fixer, currently started with high verbosity
# Options -v for Verbosity and -p for priority
image_rot_fixer -v 6 -p 9

 lua -s -b /usr/bin/cmc/service/platform/platform_ams_restart.lua > $CONSOLE_DEVICE & 

# This starts versionInfo which is a service to output the version information from each package on the system to
# console A on multicored.
/usr/bin/versionInfo -cfg=/etc/masterConfig.json &

if [ ! -e /fs/etfs/BOX_INITIALIZED ]; then
    # script to perform factory initialization (reset required for changes to be effective)
    initialize_hu.lua
    touch /fs/etfs/BOX_INITIALIZED
fi     

echo "Running cleanup script"
boot_cleanup.sh &   

# Clear the flag set by software update, used to initialize 
# XMAPP datatbase after a system update
rm -rf /fs/etfs/SYSTEM_UPDATE_DONE

# Create a flag indicating boot.sh has completed executing
# (Used to prohibit certain actions prematurely; i.e., factory_cleanup.sh)
touch /tmp/boot_done
