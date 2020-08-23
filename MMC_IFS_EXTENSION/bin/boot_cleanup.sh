#!/bin/sh
MAX_SIZE=2097152 #2MB


##############################
# Manage onOff.log filesize

fsize=`ls -la /usr/var/logs/onOff.log | sed -r 's/([^ ]+ +){4}([^ ]+).*/\2/'`

if [[ $fsize -gt MAX_SIZE ]]; then
   echo "[onOffLog] Filesize too large. Moving onOff.log to /fs/mmc1/logs/"

   mount -uw /fs/mmc1
   if [ ! -d /fs/mmc1/logs ]; then
      mkdir /fs/mmc1/logs
   fi
   mv /usr/var/logs/onOff.log /fs/mmc1/logs/$(date "+%d_%b_%Y")_onOff.log

   # Remount /fs/mmc1 to ready only
   mount -ur /fs/mmc1
fi

##############################
# Manage qdb_reset.log

qdbLogSize=`ls -la /usr/var/logs/qdb_reset.log | sed -r 's/([^ ]+ +){4}([^ ]+).*/\2/'`

#3kb
if [[ $qdbLogSize -gt 3072 ]]; then
   echo "[qdb_reset.log] Filesize too large. Moving qdb_reset.log to /fs/mmc1/logs/"

   mount -uw /fs/mmc1
   if [ ! -d /fs/mmc1/logs ]; then
      mkdir /fs/mmc1/logs
   fi
   mv /usr/var/logs/qdb_reset.log /fs/mmc1/logs/$(date "+%d_%b_%Y")_qdb_reset.log

   # Remount /fs/mmc1 to ready only
   mount -ur /fs/mmc1
fi

