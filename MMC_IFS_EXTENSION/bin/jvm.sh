#!/bin/sh

export KD_QNX_WINDOWPROPERTY_CLASS=FlashWindow
export KD_QNX_WINDOWPROPERTY_ID_STRING=AMS
export KD_WINDOWPROPERTY_VISIBILITY=false



# FOR 520 VARIANT ONLY
export SCREENSIZE=800x480
export WIDTH=800
export HEIGHT=480



export AMS_CLIP_WITH_SCISSORS=false
export AMS_JAVA_STACK_SIZE=20k
export AMS_NATIVE_STACK_SIZE=64k


export AMS_HEAP_SIZE=60M
export AMS_NUM_THREADS=200
export AMS_MAX_NUM_THREADS=200


# Set the priority map for the AMS.
# This does not need to be changed since the default is optimal.
# Please use the default value.

export AMS_PRIORITY_MAP=0=1,1=7,2..4=9,5..37=10,38..39=11
export AMS_TEXTURE_CACHE_SIZE=14336


export AMS_MAX_NUMBER_GC_CALLS=6




# If an xlet does not provide its own budgets, the following
# environment variables can be used to force a budget upon it.
export AMS_FORCED_BUDGET_PERIOD=500ms
export AMS_FORCED_BUDGET_RUNNING=300ms
export AMS_FORCED_BUDGET_PAUSED=100ms

# These environment variables put a budget on the
# GL ES rendering thread.
export AMS_GLES_RENDERER_BUDGET_PERIOD=500ms
export AMS_GLES_RENDERER_BUDGET=300ms

# These environment variables influence Jamaica's boosting
export JAMAICA_BOOST_BY_SYNC_THREAD=no
export JAMAICA_BOOST_BLOCKED=no
export JAMAICA_BOOST_JNI=no

echo "JAMAICA_BOOST_BY_SYNC_THREAD=$JAMAICA_BOOST_BY_SYNC_THREAD"
echo "JAMAICA_BOOST_BLOCKED=$JAMAICA_BOOST_BLOCKED"
echo "JAMAICA_BOOST_JNI=$JAMAICA_BOOST_JNI"

export AMS_SECURITY_JAR=/fs/mmc1/kona/security/security.jar
[ -f /fs/etfs/AMS_DEVELOPMENT ] && export AMS_SECURITY_JAR=/fs/mmc1/kona/security/development/security.jar

echo "Launching AMS with $AMS_SECURITY_JAR" > /dev/ser3

AMS -installationDirectory /fs/mmc1/xletsdir -extensionDirectory /fs/mmc1/kona/extension -initializerJar ams_initializer.jar -xletExtensionDirectory /fs/mmc1/kona/lib -amsPropertyFile /fs/mmc1/kona/data/ams.properties -securityConfiguration "$AMS_SECURITY_JAR" -secure &





if [ -e /fs/mmc1/ota/tree.xml ]; then
   cp -cu /fs/mmc1/ota/tree.xml /fs/etfs/usr/var/ota/
fi

# For Redbend OTA
mount -uw /fs/mmc1
if [ -e /bin/smm.exe ]; then
   chmod +x ./smm.exe ./rb_ua
   nice -n1 /bin/smm.exe config=/etc/ota/dma_config.txt > /dev/null &
elif [ -e /fs/mmc1/ota/smm.exe ]; then
   cd /fs/mmc1/ota
   chmod +x ./smm.exe ./rb_ua
   nice -n1 /fs/mmc1/ota/smm.exe config=/fs/mmc1/ota/dma_config.txt > /dev/null &
fi
