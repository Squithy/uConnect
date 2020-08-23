#!/bin/sh

echo "Load second part of configuration into connection manager"
qon -d /usr/bin/lua /usr/bin/connmgr/LoadConnMgrCfg.lua "/etc/system/config/connmgr_P_2_2.json"

echo "ConnMgr"
qon -d lua -s /usr/bin/cmc/service/CMCConnMgr/CMCConnMgr.lua -t -c /etc/system/config/cmcCnctMgr.cfg --tp=/fs/mmc0/app/share/trace/CMCConnMgr.hbtc

if [ $VARIANT_MARKET = "CH" ]; then
 echo "China wlan not supported..."
else
 echo "starting wlan..."
 qon wlan_startup.sh
fi

echo "starting histo log service............"
qon -d lua -s /usr/bin/cmc/service/HistoLogger/histologger.lua -t --tp=/fs/mmc0/app/share/trace/histoLogger.hbtc  

echo "start xlet diagnostic service...."
qon -d xletDiagService -- --tp=/usr/var/trace/xletDiagServiceTrace.hbtc

echo "start AMS"
qon -d jvm.sh

if [ $VARIANT_MARKET = "CH" ]; then
 echo "China ecodrive not supported..."
else
 echo "start EcoDrive"
 qon -d -e LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/ecoDrive EcoDriveSvc --tp=/fs/mmc0/app/share/trace/EcoDriveSvc.hbtc &
fi