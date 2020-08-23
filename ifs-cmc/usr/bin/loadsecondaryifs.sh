#!/bin/sh
echo memifs2 with 4-bit ECC including spare area
nice -n-201 memifs2 -q -N -e 2 -p 2 -n /
if [[ 0 != $? ]] ; then
   echo "**********Failure in loading secondary IFS**********" > /dev/ser3
   echo "**********Marking current IFS as invalid ***********"
   waitfor /dev/gpio/
   waitfor /dev/mmap/
   adjustImageState -c 1 -v 1
   if [[ 0 == $? ]] ; then
       echo "**********Image state set to bad************"
   else
       echo "*******Unable to adjust image state - FRAM not available********"
   fi
   echo "**********Resetting the hardware********************"
   echo -n "\0021" > /dev/ipc/ch4
else 
   echo "Secondary IFS loaded successfully"
fi
