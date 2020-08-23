#!/bin/sh

# This little piece of magic (ASRCDAMP) modifies the ASRC dampening factor
# and reduces the likelyhood of having audio cut-outs during iPod playback.
export ASRCDAMP=2
# Below flag is for ELVIS 309982:Stuck on fast rewind/forward (same issue ELVIS 1067789: BT Track looping)
export MEDIAFS_DISABLE_SPEED_CHECK=1

###### Start io-media-generic
if [ ! -e /fs/etfs/VERBOSE_IO_MEDIA ]; then
	qon io-media-generic -c /etc/io_media_generic.conf
else
	qon io-media-generic -DD -c /etc/io_media_generic.conf
fi
######

(
if [ ! -e /fs/etfs/VERBOSE_MME ]; then
	qon mme-generic -c /etc/mme.conf -S
else
	qon mme-generic -vvvvvv -D -c /etc/mme.conf -S
fi
if [[ 0 != $? ]]; then
	echo "MME DB Schema mismatch or corrupt DB - remove /usr/var/qdb/mme*"
    slay -f -sterm persistency_mgr
    slay -f -sterm qdb
    rm /usr/var/qdb/mme*
# Keep this section as similar as possible to boot.sh
mediaShLocale=latin2@unicode
if [ ! -e /fs/etfs/VERBOSE_QDB ]; then
    qdbVerbose=
    qdbTraceProfile=
else
    qdbVerbose=-vvvvvv
    qdbTraceProfile=,trace,profile
fi
#echo qon qdb -c /etc/qdb.cfg -s ${mediaShLocale} ${qdbVerbose} -o unblock=0,tempstore=/usr/var/qdb${qdbTraceProfile} -R auto -X /bin/qdb_recover.sh > $CONSOLE_DEVICE
    qon qdb -c /etc/qdb.cfg -s ${mediaShLocale} ${qdbVerbose} -o unblock=0,tempstore=/usr/var/qdb${qdbTraceProfile} -R auto -X /bin/qdb_recover.sh
    
    qwaitfor /dev/qdb/mme
    qon -d persistency_mgr -p -v2 -c /etc/persistency_mgr/pmem.ini
	if [ ! -e /fs/etfs/VERBOSE_MME ]; then
		qon mme-generic -c /etc/mme.conf -S
	else
		qon mme-generic -vvvvvv -D -c /etc/mme.conf -S
	fi
fi
) &

# Start the media service
(qwaitfor /dev/mme; MediaService)  &
