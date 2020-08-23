#!/bin/sh

#
#
#
#
#

echo "\nSetting trace scopes for GNLOG to external file\n" > /dev/ser3
set -A scopes CMCConnMgr DBusTraceMonitor Media NavJpn TunerApp VR WifiSvc XMApp appManager audioCtrlSvc bluetooth cmcManager dabService dbService dev-tuner-dab dev-tuner ecallService histoLogger nav xletDiagServiceTrace
enabledScopesDir=/fs/mmc1/flags/extLogEnabledScopes/
enabledScopesDirContents=$enabledScopesDir*
i=0
match=0

if [[ -d /fs/mmc0/app/share/trace ]]; then
   echo "\nThe trace file directory exists\n" > /dev/ser3
fi

for flag in ${scopes[@]}
do
   echo $flag
   for file in $enabledScopesDirContents
   do
      if [[ ${file#$enabledScopesDir} = $flag ]]; then
         echo "$flag is set and we are making the link to ON" > /dev/ser3
         qln -sP /fs/mmc0/app/share/trace/On/$flag.hbtc /fs/mmc0/app/share/trace/$flag.hbtc
         match=1
         break
      fi
   done
   
   if [[ match -eq 0 ]]; then
      echo "$flag is not set and we are making the link to OFF" > /dev/ser3
      qln -sP /fs/mmc0/app/share/trace/Off/$flag.hbtc /fs/mmc0/app/share/trace/$flag.hbtc
   fi
   match=0
done


