#!/bin/ksh
# This script monitors available disk space.
# Set your threshold percentage (do not include the % sign), email address, and excluded mount points, then add to crontab
# This script can check the top 20 big files under the threshold breached filesystems
# Author: Mohankumar Gandhi
# Date: 28th Aug 2017
# Ver: 1.0 
#
# Add this to crontab -e for root
# Diskspace monitoring script
# 0 6 * * 1-5 /Path/location/fs_mon_big_file.ksh >/dev/null 2>&1
#
THRESHOLD="90"
EMAIL="mohankumarg@in.ibm.com"

LOG_FILE=/tmp/big_file.txt
> $LOG_FILE

# "|" pipe symbol is must between the filesystem names
INCLUDE="/var|/home"

df -k | awk '{print $7"\t"$4}' |egrep "(${INCLUDE})" | while read LINE; do
 PERC=`echo $LINE |awk '{print $2}' |cut -d"%" -f1`
 FS_NAME=`echo $LINE |awk '{print $1}'`
 if [ $PERC -gt $THRESHOLD ]; then
   echo "************START of ${FS_NAME}**************" >> $LOG_FILE
   echo "${FS_NAME} is ${PERC}% ALERT" >> $LOG_FILE
   find ${FS_NAME} -xdev -depth -type f -ls |sort -nr -k 7 |head -20 >> $LOG_FILE
   echo "************END Of ${FS_NAME}**************" >> $LOG_FILE
 fi
done
# Mail the file if the file is not zero size
if [[ -s $LOG_FILE ]] ; then
cat $LOG_FILE | /usr/bin/mail -s "Disk Space Alert on `hostname`" $EMAIL
else
exit 0
fi ;


