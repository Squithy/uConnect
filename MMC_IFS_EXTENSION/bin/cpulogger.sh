#!/bin/sh

echo "\n### CPU Logger v1.2 ###\n" > $CONSOLE_DEVICE

incrementCounterInConfig()
{
  . $CONFIG_FILE
   COUNTER=$counter
   echo $COUNTER
   ((COUNTER+=1))
   echo $COUNTER
   echo "counter=$COUNTER" > $CONFIG_FILE
}

MonProcStart()
{
   if [ -e /fs/sd0/cpulogger.cfg ]; then 
     pathname=/fs/sd0/
   elif [ -e /fs/usb0/cpulogger.cfg ]; then
     pathname=/fs/usb0/
   else
     echo "\n### Authenticated storage media not detected ###\n"  > $CONSOLE_DEVICE
	 return 0;
   fi

          
   echo "\n### Storage Media is available, launching MonitorProcesses ###\n"  > $CONSOLE_DEVICE
   . $CONFIG_FILE
   logfname=$pathname'MonitorProcess_'$counter'_'$(date "+%d_%b_%H_%M")'.txt'
   vinfname=$pathname'VIN.txt'
   echo $fname > $CONSOLE_DEVICE
   
   MonitorProcesses -t 30 -f $logfname -% 50 -a &
   sleep 3
   EnableDisableLog -s 1
   incrementCounterInConfig
   echo "$(date "+%d_%b_%H_%M")::$(dumppps /pps/can/vehcfg VIN)::$(dumppps /pps/can/vehstat ODO)::$(dumppps /pps/version application)" >> $vinfname
   echo "\n#### Launched MonitorProcesses ####\n"  > $CONSOLE_DEVICE
   
   srm
   dumper -d $pathname -n &
   }


start_process()
{
MonProcStart &
}
 
var=$(pidin a | grep MonitorProcesses | grep -v grep )
if [ -n "$var" ]; then
   echo "\n#### MonitorProcesses already running ####\n"  > $CONSOLE_DEVICE
   return 0
else
 
   CONFIG_FILE=/usr/var/LogCounter
     if [ ! -e $CONFIG_FILE ]; then
        touch $CONFIG_FILE
     fi

   start_process
fi
 

