#!/bin/ksh
RCCS="@(#)backupos-V2.95-03-13-2017"     # version
VERSION=$(echo $RCCS | cut -c5-)
##############
# mksysb and alt_disk copy version 2.0
#
# Due to convergence of scripts, this script starts at 2.0
# v2 Feb 08 2011 - MWS - Initial Version 
# 2.131 31 May 2011 - MWS - Changed copy_mksysb to handle date change 
# 2.2 11 oct 2011 MWS - Added Checks, changed verification
# 2.3 11 Jan 2012 MWS - Added logging functions
# 2.4 6 Sept 2012 MWS - Added logic to not use /mksysb/.server
# 2.5  Susith Ruwanpura made following changes
# 2.5 Added extra DMZ functions to collect cfg2html 
# 2.6 Removed ipl_varyon command use. Introduce lqueryvg for checking BLV
#     Changed alt_disk logic to look for disks the same size
# 2.7 Added code to use backup interface on both source and target
#	No version change - 11/13/2014 - fixed the bug that fills /etc/eclude.rootvg with duplicate entries
#
#	Version change - V2.8 03/31/2015 - Modified to support SAN boot disks
#	mysysb_command fucntion updated
#	alt_disk_copy functions changed to accomodate SAN boot
#	removed lspv command to reduce execution time
#Bug fixes - V 2.8 - No versoin change
#	Adding version to log file
#	Declare existing variables at the begining of script
#	New disk type sisarray should be included in the search pattern June 19 2015
#Version change 2.91-08-06-2015
#	SAN boot servers picking up Oracle disks when disk for image_1 is selected 
#Version change 2.91-08-14-2015
#Bug fixes
#	When image is SYMM_RAID device, detect the right power disk name 08/14/2015
#
#	When hostname has temporary extension, the repository is not found Ex, xxxxxx99new Oct 2015
#	Backup Lebel can be different on non standard host names. updated on Oct 20, 2015 V2.92-10-20-2015
#	Version release 01-06-2016
#	ssh time out changed from 9 sec to 20 secs
#	ping replaced with traceroute to default backup gateway
##############

## VARIABLES ##
HomeDir="/usr/local/scripts/"
logDir=/var/log
bkupFile=""
hostname=`hostname|awk -F. '{print $1}'`
ClientName=`hostname|cut -d\. -f1`
logfilename=${hostname}.osbackup.log
itmlogfilename=backupos.itm.log
DATETIME=`date +"%D-%H:%M"`
DATE=`date +"%m%d%Y"`
MksysbFile=${hostname}.mksysb.${DATE}
GzipMksysbFile=${MksysbFile}.gz
MksysbFiletoSend=" "
WaitTime=15
SSHCMD=' '		#03/31/2015
SCPCMD=' '              #03/31/2015
HNseq=			#10/19/2015  #Host name Serial Num
SCPPID=			#01/18/2017
>/tmp/osbackup.temp.log

## LOGGING ##
logFile="${logDir}/${logfilename}"
ITMlogFile="${logDir}/${itmlogfilename}"
htmllogfile=/var/log/${hostname}.osbackup.log.html

#Get the host name sequence number
hostnametrunc=`hostname |awk -F. '{print $1}' | sed 's/v1$//g; s/h$//g; s/v2$//g'`
Length=$(echo $hostnametrunc | wc -c | bc)
i=0
while [[ $i -lt $Length ]]; do
  let  i=$i+1
  Lett=$(echo $hostnametrunc | cut -c$i | tr -d '[a-z]')  #Filter only digits
  if [[ X != X$Lett ]]; then
   HNseq="${HNseq}${Lett}"
  else
   if [[ X == X$HNseq ]]; then
    continue
   else
     break
   fi
  fi
 done

# Declare functions 
DATETIME() {
  date +"%D-%H:%M:%S"
}

PrintINFO() {
 echo "`DATETIME`     INFO: $* " | tee -a ${logFile}
}
PrintERRO() {
 echo "`DATETIME`    ERROR: $* " | tee -a ${logFile}
}
PrintWARN() {
 echo "`DATETIME`  WARNING: $* " | tee -a ${logFile}
}
PrintSUCC() {
 echo "`DATETIME`  SUCCESS: $* " | tee -a ${logFile}
}
PrintFAIL() {
 echo "`DATETIME`     FAIL: $* " | tee -a ${logFile}
}

clean_slate() {
# clean_slate will clear the logfile and will wipe out /mksysbfs each time the script is run
chk4oldlog=`find $logDir -name $logfilename -mtime +6`
> $ITMlogFile
# Adding OS level capture 
if [ -f /usr/ios/cli/ioscli ]
then
  find /home -xdev -type f -name core.\* -mtime +30 -exec rm {} \;
  OSNAME="VIO"
  oslevel=`/usr/ios/cli/ioscli ioslevel`
else
  OSNAME="AIX"
  oslevel=`oslevel -s`
  find /opt/core -xdev -type f -mtime +30 ! -name lost\* -exec rm {} \;
fi
PrintINFO "RUNNING $OSNAME $oslevel"

# Adding section to prevent BBS from deleting all of their files
chkhostname=`echo $hostname| egrep -i "bbs|raxbs"`
if [ -z "$chkhostname" ]
then
PrintINFO "CLEANSLATE ACTIVATED. OLD MKSYSBS WILL BE DELETED"
    for oldmksysbfile in `find /mksysbfs -xdev -size +1024k`
    do
     PrintWARN "DELETING $oldmksysbfile .. "
     rm $oldmksysbfile
    done

    for rootvgfs in `lsvgfs rootvg`
    do
     for bigfile in `find $rootvgfs -size +512000k -xdev`
     do
      bigfilesize=`du -sm $bigfile`
      #PrintWARN "LARGE FILE FOUND: $bigfilesize Adding to exclude"
     cat /etc/exclude.rootvg | grep $bigfile >/dev/null && PrintWARN "LARGE FILE $bigfilesize already excluded" || (PrintWARN "LARGE FILE FOUND: $bigfilesize Adding to exclude" && echo "^.$bigfile" >> /etc/exclude.rootvg)
     done
    done
else
        PrintINFO "BBS SERVER. NOT DELETING FILES FROM MKSYSBFS"
fi

#adding section to test SSH connection 
if [ -z $D_FLAG ]
then
	test_ssh_conn
fi
}

mksysb_precheck() {
# the purpose of this function is to perform the following prechecks:
# The existence of /mksysbfs, and the appropriate size 

PrintINFO "STARTING MKSYSB PRECHECK"
ITM_flush
# check for filesystem
chk4mksysbfs=`df -m|grep mksysbfs `
if [ -z "$chk4mksysbfs" ]
then
	PrintERRO "/mksysbfs does not exist! Critcal error."
else

# Check to see if we can expand temporarily /mksysbfs by 10G if there is 15G free on rootvg 
chk4freespace=`lsvg rootvg|grep 'FREE PPs:'|cut -d: -f3|awk '{print $2}'|sed 's/(//'`
mksysbfssize=`df -m /mksysbfs|grep -v File|awk '{print $2}'`
chk4jfs2=`lsfs /mksysbfs|grep jfs2`
resizemksysbfs=0
if [ $chk4freespace -ge 15000 -a $mksysbfssize -le 10000 -a "$chk4jfs2" ]
then
        PrintINFO "TEMPORARILY RESIZING MKSYSBFS BY 10G"
	resizemksysbfs=1
	chfs -a size=+10G /mksysbfs
fi
chk4mksysbfs=`df -m|grep mksysbfs `

freespace=`echo $chk4mksysbfs|awk '{print $3}'`
        if [ $freespace -lt 5000 ]
        then
        PrintERRO "/mksysbfs does not have enough space. It only has ${freespace}M . Exitting"
        fi
fi

for rootvgfs in `lsvgfs rootvg`
do
fsfull=`df -m $rootvgfs|grep -v File|awk '{print $4}'|sed 's/%//g'`
	if [ $fsfull -eq 100 ]
	then
		PrintERRO "$rootvgfs is full. CANNOT proceed with mksysb."
	fi
done

# Adding section to ensure script is in crontab
chk4crontab=`crontab -l|grep 'backupos.ksh'|grep -v "^#"`
if [ -z "$chk4crontab" ]
then
     PrintERRO "BACKUPOS IS NOT IN CRONTAB. PLEASE ADD BACKUPOS TO ROOT CRONTAB."
fi

# Initiating HACMP Collection....
chk4HACMP=`lssrc -s clstrmgrES|grep active`
if [ "$chk4HACMP" ]
then
	PrintINFO "STARTING HACMP SNAPSHOT"
	HACMP_info
fi
}


VIO_stagger_start () {
houroftheday=`date +"%H"`
if [ "$houroftheday" -le 4 ]
then
PrintINFO "SLEEP FOR 60 MINUTES FOR ODD NUMBERED VIO SERVERS"
lastchr=${HNseq#${HNseq%?}}
[ $(( $lastchr % 2 )) -eq 1 ] && sleep 300 || echo $lastchr is even
fi
}

ITM_flush() {
cat ${logFile} |egrep "SUCCESS|ERROR" > $ITMlogFile
}

PowerDiskName= 		#For SAN boot environment
HdiskType=
ImageDisk=
BootPowerNumber=0 	#For SAN boot environment
BackingDisks= 		#For SAN boot environment
CurrRootDisks=
StartingBootList=
CurrImage1=
altVGname=
SANimage=

BPNumber() {
 NumberOf=$1
     BootPowerNumber=$(echo $NumberOf | tr '[A-Z]' '[a-z]' | sed 's/[a-z]//g')
}

GetPowerDiskName() {
[ $T_FLAG == TRUE ] && set -x
TestDisk=$1
[ X == X$TestDisk ] && TestDisk=NONE
[ $TestDisk != NONE ] && HdiskType=$(lsdev -l $TestDisk -F type) || HdiskType=
   if [[ $HdiskType == @(power|Power|SYMM_VRAID) ]]; then
     PowerDiskName=$(odmget -q "value=$TestDisk AND attribute=pnpath" CuAt | grep -w name | sed 's/"//g' | awk '{print $NF}')
     if [[ -z $PowerDiskName ]]; then
       PowerDiskName=$(powermt display dev=all | egrep -wp ${TestDisk} | grep Pseudo | awk -F= '{print $NF}')
     fi
   else
     PowerDiskName=$TestDisk
   fi
   if [[ $PowerDiskName == @(hdiskpower*) ]]; then
    BackingDisks=$(powermt display dev=$PowerDiskName | grep fscsi | awk '{printf $3 " "}')
    HdiskType=$(lsdev -l $PowerDiskName -F type)
    PrintINFO "$TestDisk - type $HdiskType Disk ${BackingDisks}"
   elif [[ $TestDisk != NONE ]]; then
       BakingDisks=$(lspath -l $TestDisk | sed 's/Enabled //g; s/ /\<\-\>/g' | awk '{printf $0", "}')
       PrintINFO "$TestDisk - type $HdiskType Disk ${BackingDisks}"
   fi
 }

PrepareRootVG() {
[ $T_FLAG == TRUE ] && set -x
 CurrRootDisks=$(lsvg -p rootvg | grep active | awk '{printf $1 " "}' ) #Get active rootvg disks
 SBL=$(bootlist -m normal -o | awk '{printf $0", "}')
 PrintINFO "Starting boot list is ${SBL}"
 FirstBootDisk=`echo $CurrRootDisks | awk '{printf $1}'` #Take one and determine type and backing hdisks if necessary 
 GetPowerDiskName $FirstBootDisk #Get the PowerDiskName and set HdiskType

   if [[ $HdiskType == @(power|Power|SYMM_VRAID) ]]; then
      PrintINFO "Server boot disk is on a SAN boot device"
      SANimage=YES
      #GetPowerDiskName $CurrRootDisks
      pprootdev on >/dev/null #&& pprootdev fix #&& bosboot -ad /dev/ipldevice  #This should fix blv issue
      StartBootListCount=$(echo $StartingBootList | wc -w | bc)
      BackingDiskCount=$(echo ${BackingDisks} | wc -w | bc)
      if [[ $StartBootListCount -ne $BackingDiskCount ]]; then
          for DisK in `echo ${BackingDisks}`
          do
            bootlist -m normal -o | grep $DisK 2>/dev/null || (PrintINFO "BLV is not seen over $DisK. Adding.."; bosboot -ad $DisK)
          done
      else
        PrintINFO "All backing disks seem to have blv=hd5 on them"
      fi
      bootlist -m normal ${BackingDisks}   #$BackingDisks better
      pprootdev fix >/dev/null
      bosboot -a >/dev/null
        #PrintINFO "Setting reserve lock for disk $PowerDiskName"
        #chdev -l $PowerDiskName -a reserve_policy=single_path -P
      StartingBootList=$(bootlist -m normal -o | grep blv | cut -d" " -f1-2 | sort | uniq | awk '{printf $1 " "}')
      CurrRootDisks=$BackingDisks
  fi
#Fix boot list if necessary
  if [[ `echo $CurrRootDisks | wc -w | bc` -ne `bootlist -m normal -o | grep blv | grep -v grep | wc -w | bc` ]]; then
   if [[ $HdiskType == @(scsd|vdisk|sisarray|mpioosdisk) ]]; then
        bootlist -m normal -o | grep hdisk | grep -v grep | awk '{print $1 " " $2}' | sort | uniq | while read hDisk
        do
         #PrintINFO "Checking current rootvg disk $hDisk for BLV."
         if [[ $hDisk != @(*blv*) ]]; then
           hDisk=$(echo $hDisk | awk '{print $1}')
           PrintINFO "Current rootvg disk $hDisk does not have BLV on it. Fixing"
           bosboot -ad $hDisk
         fi
        done
   fi
   #altVGname=$(lsdev -Ct vgtype -Fname | egrep -w "altinst_rootvg|old_rootvg|image_1")
   #[ X == X${altVGname} ] || alt_rootvg_op -X ${altVGname}  #Clean the image, so that case is treated as new
  else
    PrintINFO "Current Boot list is good"
  fi
}

mksysb_command() {
ITM_flush

if [ -f /usr/ios/cli/ioscli ]
then
	PrintINFO "STARTING VIO BACKUPIOS"
	VIO_stagger_start
	/usr/ios/cli/ioscli backupios -file /mksysbfs/${MksysbFile} -mksysb 2>&1 | tee -a /tmp/osbackup.temp.log
        _MksysbStatus=$?
	cd /mksysbfs
else
 PrintINFO "mksysb to be taken for an AIX server"
	PrintINFO "STARTING MKSYSB"
	/usr/bin/mksysb '-e' '-i' '-X' '-p' /mksysbfs/${MksysbFile} 2>&1 | tee -a /tmp/osbackup.temp.log
        _MksysbStatus=$?
fi

cat /tmp/osbackup.temp.log | while read line
do
   PrintINFO "$line"
done

if [ $_MksysbStatus -ne 0 ]
then
	PrintERRO "PROBLEM COMPLETING MKSYSB COMMAND. RC $_MksysbStatus. "
else
	PrintSUCC "MKSYSB COMPLETED SUCCESSFULLY. "
fi
}

mksysb_postcheck() {
PrintINFO "MKSYSB COMPLETE. BEGINNING POSTCHECK. "
ITM_flush

chk4fileexist=`find /mksysbfs -xdev -name $MksysbFile`
if [ -z "$chk4fileexist" ]
then
	PrintERRO "MKSYSB FILE DOES NOT EXIST. EXITTING...."
fi

mksysbfilesize=`du -sm /mksysbfs/${MksysbFile}|awk '{print $1}'|awk -F. '{print $1}'`
if [ $mksysbfilesize -le 100 ]
then
	PrintERRO "MKSYSB UNDER 100M. ABORTING."
else
	PrintINFO "MKSYSB OVER 100M. CHECKING lsmksysb"
	confirmgoodmksysb=`lsmksysb -l -f  /mksysbfs/$MksysbFile|grep hd8`
	if [ -z "$confirmgoodmksysb" ] 
	then
		PrintERRO "MKSYSB does not appear to be valid per lsmksysb"		
	else
                PrintSUCC "$MksysbFile appears to be good per lsmksysb."
	fi
fi
} 

compress_mksysb() {
ITM_flush
 PrintINFO "gzipping ${MksysbFile}" 
cd /mksysbfs
/usr/bin/gzip -q -9 /mksysbfs/"${MksysbFile}" | tee -a ${logFile}
PrintINFO "SPACE in /mksysbfs `du -sm /mksysbfs/* | grep -v lost`"

# Section to resize mksysbfs back to original size
if [ resizemksysbfs -eq 1 ]
then
	PrintINFO "MKSYSBFS was resized for this operation. Shrinking it back"
	freespaceonfs=`df -m /mksysbfs|grep -v File|awk '{print $3}'`
	
	if [ $freespaceonfs -ge 10001 ]
	then
		PrintINFO "resizing FS to original size..."
		chfs -a size=-10G /mksysbfs
	fi
fi

}

copy_mksysb() {
ITM_flush
 PrintINFO "${CpmleteStatus}" 
#test_ssh_conn
if [[ ! -s /mksysbfs/${GzipMksysbFile} ]]; then
  MksysbFiletoSend=`find /mksysbfs -xdev -size +1000 -name "${ClientName}.mksysb*"|head -1`
else
  MksysbFiletoSend="/mksysbfs/${GzipMksysbFile}"
fi
RemoteFile=$($SSHCMD "chmod 640 ${MksysbFiletoSend} 2>/dev/null")

#ThisHost=$(netstat -r | awk '{print $2}' | grep -w `uname -n` | uniq | sed 1q)
PrintINFO "STARTING MKSYSBCOPY FUNCTION "
PrintINFO "FILE `du -m ${MksysbFiletoSend}` to be copied from ${ThisHost} TO ${mksysbServer}"
BacupNetwork=$(netstat -Cnr | grep -w ${BackupGW} 2>/dev/null )
if [[ ! -z ${BacupNetwork} ]]; then
   if [[ ${mksysbServer} != @(*e.*) ]]; then
     PrintINFO "Backup files MAY NOT be transferred over BACKUP NETWORK. Trying .."
   else
     PrintINFO "BACKUP NETWORK is used to transfer files"
   fi
fi
PrintINFO "Starting background SCP - \c"
$SCPCMD -q ${MksysbFiletoSend} mksysbu@${mksysbServer}:/mksysbfs/ & SCPPID=$!
echo "SCP Process ID is $SCPPID"
sleep 5
chk4mksysb=`ps -eaf |grep [s]cp | grep "${MksysbFiletoSend}" | grep -v grep`
}

FileToSend() {
  if [[ ! -s /mksysbfs/${GzipMksysbFile} ]]; then
    MksysbFiletoSend=`find /mksysbfs -xdev -size +1000 -name "${ClientName}.mksysb*"|head -1`
  else
    MksysbFiletoSend="/mksysbfs/${GzipMksysbFile}"
  fi
}

Verify_SCP() {
  FileToSend
  if [[ X != "X$SCPPID" ]]; then
   if [[ X == "X$(ps -p $SCPPID | grep -v PID)" ]]; then PrintINFO "Copying mksysb file seem to be over"; fi
   if [[ X != "X$(ps -p $SCPPID | grep -v PID)" ]]; then PrintINFO "Still copying mksysb file in the background"; fi
  fi
  if [[ $WaitTime -gt 30 ]]; then PrintINFO "Check backup interface and IP. May not be working correctly"; fi
  chk4mksysb=`ps -eaf | grep [s]cp | grep "${MksysbFiletoSend}" | grep -v grep`
  while [ "$chk4mksysb" ]
  do
	PrintINFO "MKSYSB SCP STILL IN PROGRESS. SLEEPING $WaitTime more seconds" 
	sleep $WaitTime
	chk4mksysb=`ps -eaf |grep [s]cp | grep "${MksysbFiletoSend}" |grep -v grep`
  done
  sleep 2
}

verify_mksysb() {
  ITM_flush
  # Split out verify to reduce the time for the mksysb copy
  FileToSend
  Verify_SCP

  if [[ -s ${MksysbFiletoSend} ]]; then
   currentfilesize=$(sum ${MksysbFiletoSend} |awk '{print $1}')
   PrintINFO "LOCAL SUM $currentfilesize ."
   #test_ssh_conn
   RemoteFile=$($SSHCMD "ls -l ${MksysbFiletoSend}")
   sleep 1
   [ X == X${RemoteFile} ] && RemoteFile=$($SSHCMD "ls -l ${MksysbFiletoSend}") #Try again for the file in server
   if [[ -z ${RemoteFile} ]]; then
     PrintERRO "FILE TRANSFER UNSUCCESSFUL."
   else
     PrintINFO "FILE TRANSFER IS SUCCESSFUL."
     remotefilesize=$($SSHCMD  "sum ${MksysbFiletoSend}"|awk '{print $1}')
   fi
   
   PrintINFO "REMOTE SUM $remotefilesize."
  
        if [[ $remotefilesize -ne $currentfilesize ]]; then
	        PrintERRO "REMOTE MKSYSB ( ${MksysbFiletoSend} )FILESIZE DOES NOT MATCH LOCAL SUM"
        else
        	PrintSUCC "REMOTE MKSYSB FILESIZE ( ${MksysbFiletoSend} ) MATCHES LOCAL SUM"
        fi
  fi
} #End verify mksysb

HACMP_info() {
# hacmp snapshot if a cluster is running.  
HNAME=`/usr/sbin/cluster/utilities/cltopinfo -c|grep 'Cluster Name: '|awk '{print $3}'`
tdate=`date +"%d-%m-%Y"`
/usr/es/sbin/cluster/utilities/clsnapshot -c -i -n "backupos-snapshot1-${HNAME}-${tdate}" -m "$HNAME"  -d "${HNAME}-backupos-snapshot-${tdate}" | tee -a /tmp/osbackup.temp.log
sleep 5
cat /tmp/osbackup.temp.log | while read line
do
  PrintINFO "$line"
done
# snapshot trimming:
recentsnapshots=`find /usr/es/sbin/cluster/snapshots/ -name "*backupos-snapshot*" -mtime -100| sed -e 's!/usr/es/sbin/cluster/snapshots/!!g'|awk -F. '{print $1}'|uniq|wc -l|awk '{print $1}'`
if [ $recentsnapshots -ge 10 ]
then
	PrintINFO "There are currently $recentsnapshots in in the directory"
	for x in `find /usr/es/sbin/cluster/snapshots/ -name "*backupos-snapshot*" -mtime +80| sed -e 's!/usr/es/sbin/cluster/snapshots/!!g'|awk -F. '{print $1}'|uniq`
	do
		PrintINFO "Deleting $x"
		clsnapshot -r -n "$x"
	done
fi
}

html_logfile() {
# make an HTML version of the logfile for Mksysb site - Code from Susith
htmllogfile=/var/log/${hostname}.osbackup.log.html
echo "<a href=http://172.21.178.147/CFG2HTML/${hostname}.html > Link to cfg2html file </a> <br>" > ${htmllogfile}

  echo "<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
        <HTML>
        <style type=text/css>
        BODY            {FONT-FAMILY: Arial, Verdana, Helvetica, Sans-serif; FONT-SIZE: 12pt;}
        </style>
        <TITLE> $line </TITLE> " >${htmllogfile}
  echo '<BODY>' >> ${htmllogfile}


  cat ${logFile} | while read LinE
   do
      MarRed=NO
        echo "$LinE" | egrep "ERROR|WARNING|FAIL|ATTENTION|does" >/dev/null && MarRed=Yes || MarRed=NO
        echo "$LinE" | egrep "SUCCESS" >/dev/null && MarBlue=Yes || MarBlue=NO
        if [[ $MarRed != NO ]]; then
         echo "<font color=red> $LinE </font><br>" >> ${htmllogfile}
        elif [[ $MarBlue != NO ]]; then
         echo "<font color=blue> $LinE </font><br>" >> ${htmllogfile}
        else
         echo "$LinE <br>" >> ${htmllogfile}
        fi
        LinE=" "
    done
   echo "<a href=http://172.21.178.147/CFG2HTML/${hostname}.html > Link to cfg2html file </a> <br>" >> ${htmllogfile}
   echo '</BODY></HTML>' >> ${htmllogfile}
}

test_ssh_conn() { 
if [ -f $CopyKey ]
then
        sleep 4
	$SSHCMD date  > /dev/null 2>&1
  	 sshsuccess=$?
     	if [[ $sshsuccess != 0 ]]; then
	       PrintINFO "SSH key file $(ls -l /.ssh/mksysbukey | awk '{print $1 "  " $3 ":" $4 "  " $NF}') ."
	       PrintINFO "mksysb file $(ls -l /mksysbfs/*.mksysb.* | awk '{print $1 "  " $3 ":" $4 "  " $NF}' ) ."
	       PrintERRO "SSH unsuccessful. SSH keys does not seem to be right. File copy may not work... "
	else
	       PrintSUCC "SSH KEY APPEARS TO WORK"
	fi
fi
}

copy_logfile() {
ITM_flush
$SCPCMD -q -p ${logFile}.html  mksysbu@${mksysbServer}:/mksysbfs; SCP_Status=`echo $?`
 if [[ $SCP_Status -eq 0 ]]; then
   PrintSUCC "LOG FILE SENT."	
 else
   PrintFAIL "LOG FILE SCP FAILED."	
 fi
$SCPCMD -q -p ${logFile} mksysbu@${mksysbServer}:/mksysbfs/
}

#Creating image starts here
#
run_altrootvg_copy() {
[ $T_FLAG == TRUE ] && set -x
PrintINFO "ALT DISK COPY ACTIVATED"
ITM_flush

# Stop the process if the altdisk lpp is not installed
chklpp=`lslpp -l bos.alt_disk_install.rte`
if [ -z $chklpp ]
then
        PrintERRO "ALT DISK LPP NOT INSTALLED. ABORTING"
	exit_function
fi

#=====================================================================
# collect information
# Determination for SAN boot OR VSCSI versus physical SCSI. 

SelectDiskForImage() {
[ $T_FLAG == TRUE ] && set -x
#set -x
TYpe=$1
PrintINFO "LOOKING FOR SUITABLE DISK of type $TYpe"
case $TYpe in
 power|SYMM_VRAID) TYpe=power ;;
 vdisk) TYpe=vdisk ;;
 mpioosdisk) TYpe=mpioosdisk ;;
 MSYMM_VRAID) TYpe=MSYMM_VRAID ;;
esac
#SelectFree=
#Slect a free disk
 DisksInrootVG=$(lsvg -p rootvg | grep active | awk '{printf $1 " "}')
 #getconf BOOT_DEVICE
 NumRootvgDisks=$(echo $DisksInrootVG | wc -w | bc)
 DisksFrImage=$NumRootvgDisks
 if [[ $NumRootvgDisks -eq 2 ]]; then
     for hDisks in `echo $DisksInrootVG`
     do
      lspv -l $hDisks | grep hd5 && let BLV=$BLV+1
     done
   if [[ $BLV -lt 2 ]]; then
     PrintINFO "Rootvg is on a Single disk"
   else
     PrintINFO "Rootvg is on a Multiple \($BLV\) disks"
   fi
 fi 
#Multiple disks could be in rootvg
RootSize=0
for RootvgDisk in `echo $DisksInrootVG`
do
 DiskSize=$(bootinfo -s $RootvgDisk)
 let RootSize=$RootSize+$DiskSize      #Get total  root disk space
done
PrintINFO "Total rootvg size is $RootSize MB"

for RootvgDisk in `echo $DisksInrootVG`
do
 #RootSize=$(bootinfo -s `lsvg -p rootvg | grep hdisk | sed 1q | awk '{print $1}'`)
 ThisDiskType=$(lsdev -l $RootvgDisk -F type)
 if [[ $ThisDiskType == @(SYMM_VRAID*) ]]; then
   RootPowerDisk=$(odmget -q "value=$RootvgDisk AND attribute=pnpath" CuAt 2>/dev/null | grep name | sed 's/\"//g' | awk '{print $NF}')
   TYpe=power
 else
   RootPowerDisk=$RootvgDisk #Only power disks need to get the power path identification
 fi
   RootPDsize=$(bootinfo -s $RootPowerDisk)
 VGname=rootvg
 SetPViD=0
  lsdev -Cc disk -t $TYpe -F name | while read sDisk
  do
    DiskSize=$(bootinfo -s $sDisk)
    DiskOwner=$(ls -l /dev/r${sDisk} | grep -v root)
    if [[ X != X$DiskOwner ]]; then
     PrintINFO "Disk $sDisk is not owned by root. Cannot be selected for image_1"
     continue #Do not select the same disk for image
    fi
    if [[ $sDisk == $RootPowerDisk ]]; then
     #PrintINFO "$sDisk is same as rootdisk $RootPowerDisk. Looking for the next"
     continue #Do not select the same disk for image
    fi
    PViD=$(lsattr -E -a pvid -F value -l $sDisk)
     if [[ $PViD == none ]]; then
       DiskSize=$(bootinfo -s $sDisk)
         if [[ $SetPViD -lt $DisksFrImage ]]; then
          PrintINFO "$TYpe disk $sDisk does not have PVID, and size $DiskSize. check if size matches"
          if [[ $RootSize -eq $DiskSize ]]; then    #Check for a disk with same size
            PrintINFO "$sDisk size $DiskSize is free"
            chdev -l $sDisk -a pv=yes 2>/dev/null
            let SetPViD=$SetPViD+1
          #else
           #PrintWARN "Free $TYpe disk $sDisk does not match the root disk size"
          fi
         fi
      PViD=$(lsattr -E -a pvid -F value -l $sDisk)
    fi

    if [[ ! -z $PViD ]]; then
       VGname=$(odmget -q "value=$PViD AND attribute=pv" CuAt | grep -w name | sed 's/\"//g' | awk '{print $NF}')
    fi

   if [[ -z $VGname ]]; then
    DiskSize=$(getconf DISK_SIZE /dev/$sDisk 2>/dev/null) #There are disks with smaller size
    if [[ $DiskSize == $RootPDsize ]]; then
    PrintINFO "$sDisk is $DiskSize MB, and it is Free. It can be used for image_1"
     if [[ Y == "Y$ImageDisk" ]]; then
        ImageSize=$(bootinfo -s $sDisk)
        ImageDisk="$sDisk"
     else
        ImageSizeX=$(bootinfo -s $sDisk)
        ImageDisk="$ImageDisk $sDisk"
        let ImageSize=$ImageSize+$ImageSizeX
     fi
    fi
   else
    PrintINFO "$sDisk already used for $VGname. Looking for the next $TYpe disk"
    #ImageDisk=
   fi
   #Once enough disks slected break out of the loop
   NumSelectedDisks=$(echo $ImageDisk | wc -w | bc)
   if [[ $NumSelectedDisks == $NumRootvgDisks ]]; then
    if [[ $ImageSize -ge $RootSize ]]; then
      PrintINFO "Selected disk space is sufficient for image"
      break
    else
      PrintINFO "Selected disk space is not sufficient for image"
       if [[ $NumRootvgDisks -eq 1 ]]; then
         NumSelectedDisks=0
         ImageDisk=
       fi
    fi
   fi
 done
 [ X != "X$ImageDisk" ] && PrintINFO "Selected disk - $ImageDisk - to backup $DisksInrootVG"
done  #Limit search until number of disks matches the current rootvg

    #ImageDisk="$SelectFree"
    DisksWithoutSpace=$(echo $ImageDisk | sed 's/ //g')
    if [[ X != X$DisksWithoutSpace ]]; then
         PrintINFO "Selected $ImageDisk for alt_disk_image"
    else
         PrintERRO "No free disks available for alt_disk_image"
         ImageDisk="NONE"
    fi
} #SelectDiskForImage end here

#Current image name
ImageDisks=
altVGname=$(lsdev -Ct vgtype -Fname | egrep -w "altinst_rootvg|old_rootvg|image_1" | awk '{printf $0 " "}')
if [[ ! -z $altVGname ]]; then
 PrintINFO "Image backup exist in the syste with name $altVGname"
  if [[ "X$altVGname" == Ximage_1 ]]; then
    altVGname=image_1
  fi
  for line in `odmget -q "name=$altVGname AND attribute=pv" CuAt | grep value | sed 's/\"//g' | awk '{printf $NF " "}'`
  do
    CurrDisk=$(odmget -q "attribute=pvid AND value=$line" CuAt | grep name | sed 's/\"//g' | awk '{printf $NF}')
    ImageDisks="$ImageDisks $CurrDisk"
  done
 CurrImage1="`echo $ImageDisks | sed 's/^ //g'`"
else
 CurrImage1=
 altVGname=
fi

if [[ X == X$CurrImage1 ]]; then  #Getting a new disk(s)
 PrintINFO "There is no alt_disk in the system. Root disk type is $HdiskType , - $PowerDiskName , Sequence No. $BootPowerNumber."
  #For fresh install there is no image or altroot at this time
  #Select equal number of disks for image. Only relevent to scsd disks
 case $HdiskType in  #This is rootvg type
  @(power|SYMM_VRAID|Power) )
     SelectDiskForImage $HdiskType
     DisksWithoutSpace=$(echo $ImageDisk | sed 's/ //g')
     if [[ X != X$DisksWithoutSpace ]]; then
       [ "$ImageDisk" != NONE ] && GetPowerDiskName $ImageDisk #Get the PowerDiskName
       [ "$ImageDisk" != NONE ] && PrintINFO "Querrying for $ImageDisk devices for alt_disk_image"
     fi
      ;;
  @(scsd|sisarray) )  #Current rootvg is in scsd or sisarray disk
     PrintINFO "Checking for free SCSD / SISARRAY disks"
       FreeSCSD=
       TotalSCSDs=$(lsdev -Cc disk -t $HdiskType -S a -F name | awk '{printf $1 " "}')
       DisksInrootvg=$(lsvg -p rootvg | grep active | awk '{printf $1 " "}' )
       DisksForImage=`echo $DisksInrootvg | wc -w |bc`
       if [[ `echo $TotalSCSDs | wc -w | bc` -ge 2 ]]; then
         lsdev -Cc disk -t $HdiskType -F name | while read sDisk
         do
           VGname=
           #TotalSCSDs="$TotalSCSDs $sDisk"
           PViD=$(lsattr -E -a pvid -F value -l $sDisk)
           if [[ $PViD == none ]]; then
            PrintINFO "Disk $sDisk of type $HdiskType seem to be free"
             if [[ $SetPViD -lt $DisksForImage ]]; then
               PrintINFO "Setting PVID for free $HdiskType disk $sDisk to be used for image"
               chdev -l $sDisk -a pv=yes >/dev/null
               let SetPViD=$SetPViD+1
             fi
             PViD=$(lsattr -E -a pvid -F value -l $sDisk)
           fi

           if [[ X != X$PViD ]]; then
             VGname=$(odmget -q "value=$PViD AND attribute=pv" CuAt | grep -w name | sed 's/\"//g' | awk '{print $NF}')
           fi
           if [[ X == X$VGname ]]; then
             FreeSCSD="$FreeSCSD $sDisk"
           fi
         done
         TotalSCSDs=`print "$TotalSCSDs" |  sed -e 's/^[ \t]*//'`
         FreeSCSD=`print "$FreeSCSD" |  sed -e 's/^[ \t]*//'`

        PrintINFO "From all $HdiskType type disks $FreeSCSD seem to be free" #Now select disks
        if [[ $DisksForImage -lt 2 ]]; then
            [ `echo $TotalSCSDs |wc -w | bc` -ge 4 ] && PrintERRO "Rootvg is not mirrored. But disks are available" #What are free
        fi

          if [[ `echo $FreeSCSD |wc -w |bc` -lt $DisksForImage ]]; then
            PrintERRO "Not enough internal disks for root vg image"
            ImageDisk="NONE"
         else
            ImageDisk=$(echo $FreeSCSD | cut -d" " -f1-${DisksForImage})
         fi
         PrintINFO "Internal disks $ImageDisk has been selected for root vg image"
      else
         PrintERRO "Not enough internal disks for root vg image"
         ImageDisk="NONE"
      fi
      ;;
    @(vdisk|mpioosdisk|MSYMM_VRAID) )
        SelectDiskForImage $HdiskType           #This should get the next free vdisk for image
        GetPowerDiskName $ImageDisk #Get the PowerDiskName
        ;;
     * )
       PrintERRO "Cannot determine the image disk type. Aborting"
       ImageDisk=NONE
        ;;
   esac
  [ "$ImageDisk" != NONE ] && PrintINFO "$ImageDisk -- altvg  disk selection summery"

else    #System already have a image_1
  CurrImage11=$(echo $CurrImage1 | awk '{printf $1}')  #Take one disk for verification
  GetPowerDiskName $CurrImage11 #Get the PowerDiskName
  ImageDisk="${CurrImage1}"
  PrintINFO "Current Image is on ${CurrImage1} $HdiskType Ex. $PowerDiskName - $BackingDisks."
fi

[ "$ImageDisk" == @(*NONE*) ] && PrintINFO "ALT Root disk type is $HdiskType , -$PowerDiskName -- $ImageDisk "
#Clean existing image
# Confirm no alt_disks are online
chk4mount=`df -m|grep 'alt_inst'`
	if [ "$chk4mount" ]
	then
	PrintERRO "ALT_ROOT FILESYSTEMS CURRENTLY MOUNTED. QUITTING ALT_DISK FUNCTION"
	exit_function
	fi

  if [[ ! -z ${altVGname} ]]; then
   alt_rootvg_op -X "${altVGname}" 2>/dev/null #Do this after determining InageDisk
  fi

  if [[ $HdiskType != @(power|SYMM_VRAID|Power) ]]; then
    for hDisk in $ImageDisk
      do
       [ $hDisk != NONE ] && chpv -c $hDisk; chpv -C $hDisk
      done
    fi

  if [[ "${ImageDisk}" != @(*NONE*) ]]; then
    PrintINFO "Creating NEW alt disk on ${ImageDisk}"
    altVGname=$(lsdev -Ct vgtype -Fname | egrep -w "altinst_rootvg|old_rootvg|image_1")
    [ X == X${altVGname} ] || alt_rootvg_op -X ${altVGname}  #Clean the image, so that case is treated as new
    alt_disk_copy -B -d "${ImageDisk}"
    _CloneStatus=$?
  else
    PrintERRO "Could not select a disk for alt_disk. Check for free disks own by root"
    _CloneStatus=1
  fi
	if [ $_CloneStatus -eq 0 ]
	then
		PrintSUCC "ALT DISK APPEARS TO BE BOOTABLE ON ${ImageDisk}"
                PrintINFO "Ranaming new root disk copy as image_1"
           alt_rootvg_op -v image_1 -d ${ImageDisk}
	else
		PrintERRO "ALT ROOTVG MAY NOT BE CREATED, OR is not bootable"
	fi

#Set the boot list back to previos
    EBL=$(bootlist -m normal -o | awk '{printf $0", "}')
    PrintINFO "Ending boot list is ${EBL}"

}

#==================================================
altroot_postcheck() {
[ $T_FLAG == TRUE ] && set -x
ITM_flush
# check for image_1 vg
chk4image1=`lsvg|grep image_1`
if [ "$chk4image1" ]
then

   odmget -q "name=image_1 AND attribute=pv" CuAt | grep value | sed 's/\"//g' | awk '{print $NF}' | while read PVId Other
    do
     Iamge_Disk=$(odmget -q "value=$PVId AND attribute=pvid" CuAt | grep name | sed 's/\"//g' | awk '{printf $NF}' )
     image1disks="$image1disks $Iamge_Disk"
    done
   image1disks=`echo $image1disks | sed -e 's/^[ \t]*//'`
	#image1disks=$(lspv|grep image_1|awk '{printf $1 " "}') #lspv may consume time in large servers
          for _Disk in `echo $image1disks`
            do
              DiskBLV=$(lqueryvg -Lp $_Disk | grep -w hd5 )
              [ X != X$DiskBLV ] && PrintINFO "$_Disk BLV info -> $DiskBLV"
              [ X != X$DiskBLV ] && ( hk4boot=YES; break) || chk4boot=
           done

        if [ "$chk4boot" ]
        then
                PrintINFO "ALT DISK APPEARS TO HAVE BLV ON $image1disks"
        fi

  # check that image_1 is recent
	image1new=`find /dev -name "image_1" -ctime -1`
	if [ "$image1new" ]
	then 
		PrintSUCC "ALT ROOTVG IS LESS THAN ONE DAY OLD"	
	else
		PrintERRO "ALT ROOTVG IS MORE THAN ONE DAY OLD"
	fi 

else
	PrintERRO "IMAGE_1 VG DOES NOT EXIST. ALTDISK FAILED."
fi

  if [[ $SANimage == YES ]]; then
    PrintINFO " RootVG is on SAN disk. running pprootdev command"
    pprootdev fixback >/dev/null
    mkdev -l powerpath0 >/dev/null #cfgmgr 2>/dev/null
  fi
}
#===============================================================
chk4proc() {
# the purpose of this is to provide a quick exit in case there's another mksysb, alt_disk 
ITM_flush
chk4mksysbrunning=`ps -eaf| grep -v SPOT |egrep -i "[m]ksysb|[a]lt_disk"|grep -v grep`
if [ "$chk4mksysbrunning" ]
then
	PrintWARN "ANOTHER MKSYSB OR ALT DISK PROCESS IS RUNNING. sleep for 60 minutes"
	echo "$chk4mksysbrunning"	
	sleep 3600
	chk4mksysbrunning2=`ps -eaf|egrep -i "[m]ksysb|[a]lt_disk"|grep -v grep`

	if [ "$chk4mksysbrunning2" ]
	then
		PrintERRO "MKSYSB OR ALT DISK PROCESS IS  STILL RUNNING AFTER AN HOUR. ABORTING BACKUPOS. "
		exit_function
	fi
fi
}

dmzopt() {
ITM_flush
chk4mksysbu=`lsuser mksysbu`
if [ -z "$chk4mksysbu" ]
then
	PrintERRO "DMZ ACTIVATED. USER MKSYSBU NOT FOUND!"
	PrintINFO "CREATE USER MKSYSBU AND ADD HOSTNAME TO LIST in mksysb server"
else
################################
# Adding section to bring copy cfg2html so we can get it in the DMZ process -- Jun/10/2013 -- MWS
#####################
	cp -R /var/adm/cfg/${hostname}.* /mksysbfs
	chown mksysbu:staff /mksysbfs/${hostname}*
# 	chown mksysbu:staff /mksysbfs/${MksysbFile}* 
fi
}

exit_function() {
    #PrintINFO "EXIT FUNCTION ACTIVTATED."
    PrintINFO "CONVERTING LOGFILE to html; view at http://172.21.178.147/mksysb/"
    PrintINFO "COPY LOGFILE FUNCTION ACTIVATED"
    Verify_SCP
    PrintINFO " ----------------------- END -------------------- \n"
    html_logfile  #Create html log file
    copy_logfile 
    ITM_flush
    PrintINFO "LOG File /var/log/`uname -n`.osbackup.log"
exit 1
}

usage() {
print "\n ------------------------------- +++ -----------------------------"
PrintINFO "Existing mksysb $(ls -lrt /mksysbfs | grep mksysb | awk '{ printf $6" "$7 " " $NF }')"
CurrImage=$(lsdev -Ct vgtype -Fname | egrep -w "altinst_rootvg|old_rootvg|image_1")
PrintINFO "Existing image $CurrImage on $(lspv | grep "$CurrImage" | awk '{printf $1" "}')"
print "\n ------------------------------- +++ -----------------------------"
print ' backupos.ksh  is designed to do the following:
- Take a mksysb of the OS
- Upload the mksysb to a mksysb server
- take an alt_disk copy

/usr/local/scripts/backupos.ksh -B for both mksysb and alt_disk
FLAGS:
-B: BOTH - will run a mksysb and then an alt disk. Mksysb will be sent to the server
-m: Mksysb: will take a mksysb of the system, compress it and send it to the mksysb server
-a: Take alt_disk_copy and send the log file to mksysb server
-C: (Re)copy mksysb and logfile. This happens automatically. 
-L: (Re)copy log file to server
-D: DMZ. This flag is equivilant to -B without the option of files getting copied.
'
print "logfile: ${logFile}"
PrintINFO " ----------------------- NO OPTIONS SELCTED -------------------- \n"
}

run_mksysb() {
clean_slate
mksysb_precheck 
#PrepareRootVG
mksysb_command
mksysb_postcheck
compress_mksysb
}

#Execution starts here
RunFile=$(basename $0)
VERSION=$(what ${RunFile} | grep backupos-V)

if [[ ! -z $1 ]]; then
  case $1 in
    @(*B*|*D*)) echo "BEGINING BACKUPOS $VERSION on `hostname`" >${logFile}
                echo "BEGINING BACKUPOS $VERSION on `hostname`" ;;
  esac
 PrintINFO "BEGINNING BACKUP  PROCESS on `hostname` with option $1"
else
 echo "BACKUPOS $VERSION requires at least one option flag to work" | tee -a ${logFile}
 PrintWARN "BACKUPOS $VERSION requires at least one option flag to work"
fi
PrintINFO "VERSION $VERSION ${logFile}"

if [[ -e /usr/bin/scp ]]; then
   _CMDSCP='/usr/bin/scp'
elif [[ -e /usr/local/bin/scp ]]; then
   _CMDSCP='/usr/local/bin/scp'
else
   _CMDSCP=`which scp`
fi
_CMDSSH=$(which ssh)

CopyKey='/.ssh/mksysbukey'
SSHopt="-q -i ${CopyKey} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o ConnectionAttempts=3 -o ConnectTimeout=30 "

##Fil3 system
IsFS=$(lsfs /mksysbfs 2>/dev/null | grep jfs2)
if [[ -z ${IsFS} ]]; then
 mklv -y mksysblv -L mksysblv -t jfs2 rootvg 1 && crfs -v jfs2 -d mksysblv -m /mksysbfs -Ay -prw -a logname=INLINE
 chfs -a size=8G /mksysbfs
 mount /mksysbfs
  PrintINFO "CHECK File system - Created new /ksysbfs File system "
else
  PrintINFO "CHECK File system PASS"
fi

CronEntry='30 21 * * 0 /usr/local/scripts/backupos.ksh -B'
Crontab=$(cat /var/spool/cron/crontabs/root | grep backup)
if [[ -z ${Crontab} ]]; then
  echo "${CronEntry}" >> /var/spool/cron/crontabs/root
  CronResp=$(lsitab -a | grep cron | grep respawn)
  if [[ ! -z ${CronResp} ]]; then
   KillPID=$(ps -ef | grep -w cron | grep -v grep | awk '{print $2}')
   kill -9 $KillPID
  fi
  PrintINFO "CHECK Cron Entry - Added new cron entry"
else
  PrintINFO "CHECK Cron Entry - PASS"
fi

## Transmit ## 
CopyKey=/.ssh/mksysbukey
# serverfile=/mksysbfs/.server
# mksysbServer=`cat $serverfile|grep mksysbServer|awk -F= '{print $2}'`

DOMAINLOC=$(host `hostname` | awk -F. '{print $2}')
if [[ ! -z $DOMAINLOC ]]; then
  DM_Length=`echo $DOMAINLOC | wc -c`
  if [[ $DM_Length -ne 5 ]]; then
    DOMAINLOC=`ifconfig -au|grep inet|head -1|awk '{print $2}'|xargs -i nslookup {}|egrep -i -w 'Name'|awk '{print $NF}'|awk -F. '{print $2}'|head -1`
  fi
else
    DOMAINLOC=`ifconfig -au|grep inet|head -1|awk '{print $2}'|xargs -i nslookup {}|egrep -i -w 'Name'|awk '{print $NF}'|awk -F. '{print $2}'|head -1`
fi

case $DOMAINLOC in
        crdc|ivdc) mksysbServer="czabbsNUMe.crdc.kp.org";;
        ssdc) mksysbServer="szabbsNUMe.ssdc.kp.org";;
        nndc) mksysbServer="nzabbsNUMe.nndc.kp.org";;
        wcdc|wpoc|tic) mksysbServer="wzabbsNUMe.wcdc.kp.org";;
        bcdc) mksysbServer="draxbsNUMe.bcdc.kp.org";;
        pldc) mksysbServer="pzabbsNUMe.pldc.kp.org";;
        *) mksysbServer="wzabbsNUMe.wcdc.kp.org";;
esac

lastdigit=`echo $HNseq | sed 's/-/./g; s/_/./g' |sed 's/x//g' |awk -F. '{print $1}' |sed -e "s/^.*\(.\)$/\1/"`

#((modlastdigit=lastdigit%2))
modlastdigit=$(($lastdigit%2))
if [ $modlastdigit -eq 0 ]
then
  servernum=1
else
  servernum=2
fi

mksysbServer=`echo $mksysbServer|sed "s!NUM!$servernum!g"`
PrintINFO "SELECT destination server $mksysbServer for $hostname in $DOMAINLOC" 

IsUP=$(ping -w3 -c1 $mksysbServer 2>/dev/null | grep ttl)  #Ping over default route
if [[ ! -z ${IsUP} ]]; then
   PrintSUCC "$mksysbServer is up. File should be transferred to this repo"
else
   PrintERRO "$mksysbServer seem to be down. Backup interface may be down while route is set. Continuing.. "
fi

SSHCMD="$_CMDSSH  ${SSHopt} mksysbu@${mksysbServer}"
SCPCMD="$_CMDSCP ${SSHopt} -o BatchMode=yes"

PrintINFO "CHECK for local backup network for TARGET server $mksysbServer" 
#Get backup IP and see whether interface is configured
BackupInterface=
LinkState='Down'
IFUsed='BACKUP'
#Backup Lebel can be different on non standard host names. Following added on Oct 20, 2015
   hostnametrunc=`hostname |awk -F. '{print $1}' | sed 's/v1$//g; s/h$//g; s/v2$//g'`
   Length=$(echo $hostnametrunc | wc -c | bc)
   i=0
   CleanBHostName=
   DigitFound=No
      while [[ $i -lt $Length ]]; do
        let  i=$i+1
        Lett=$(echo $hostnametrunc | cut -c$i)
         #echo "$i -> $Lett $DigitFound  $CleanBHostName"
        Lettt=$(echo $Lett | tr -d '[a-z]')
           if [[ X != X$Lettt ]]; then
             DigitFound=Yes
           else
            if [[ $DigitFound == Yes ]]; then
              LastPart="e$(echo $hostnametrunc | cut -c${i}-${Length})"
              break
            fi
           fi
     CleanBHostName="${CleanBHostName}${Lett}"
 done
 BackupLebel="$CleanBHostName${LastPart}"
#echo "\nFinal host name $CleanBHostName${LastPart}"

  PrintINFO "DNS Name of local Backup interface is $BackupLebel "

#BackupIP=$(nslookup $BackupIPName | grep -v "#" | grep Address: | sed '$!d' | awk '{print $NF}')
  for Interface in `ifconfig -ul | sed 's/lo0//g'`
  do
    IP=$(ifconfig $Interface | grep inet |sed 1q | awk '{print $2}')
    RiverseIP=$(echo $IP | awk -F"." '{print $4"."$3"."$2"."$1}')
    FromDNS=$(nslookup $IP |  awk -v Ser=$RiverseIP '$0 ~ Ser {print $NF}')
      if [[ $FromDNS != @(*kp.org*) ]]; then
       FromDNS=$(nslookup $IP |  awk -v Ser=`uname -n | tr -d '[0-9]'` '$0 ~ Ser {print $NF}')
      fi
      IFtype=$(echo $FromDNS | sed 's/ie//g; s/new//g; s/old//g' | tr -d  -c e'[0-9]'e)  #Fails when server has XXnew as part of name
#Check whether the IP is backup one
    if [[ $FromDNS != @(*$BackupLebel*) ]]; then
      PrintINFO "Interface $Interface $IP does not match $BackupLebel"
      continue
    else
      BackupIP=$IP
      BackupInterface=$Interface
      PrintINFO "Backup interface $Interface has been configured. IP $IP matches $BackupLebel"
      FirstThreeBIP=$(echo ${BackupIP} | cut -d. -f1-3)
      break
    fi
 done

if [[ ! -z $BackupIP ]]; then
  if [[ -z $BackupInterface ]]; then
    BackupInterface=$(odmget -q "value=${BackupIP} AND attribute=netaddr" CuAt 2>/dev/null | grep name | sed 's/"//g' | awk '{print $NF}')
  fi
else
  PrintINFO "Backup IP has not been configured" 
fi

if [[ ! -z $BackupInterface ]]; then
  BackupNM=$(odmget -q "name=$BackupInterface AND attribute=netmask" CuAt | grep value | sed 's/"//g' | awk '{print $NF}')
  if [[ -z $BackupNM ]]; then
   BackupNM=$(lsattr -El $BackupInterface -a netmask -F value)
  fi
  PrintINFO "CHECKING route over local backup network " 
  BackupIFace="Backup IF $BackupInterface for $BackupIP configured"

 	set -A IParray `echo $BackupIP | sed 's/\./ /g'`
	set -A NMarray `echo $BackupNM | sed 's/\./ /g'`
	set -A NetArray
	typeset -i16 NuA
	typeset -i16 NuB
		i=0	
		while [[ $i -lt 4 ]]; do
  		  #echo "${IParray[$i]} \t\c"
  		  #echo "${NMarray[$i]} \t\c"
    		  IParray[$i]=`echo "obase=16;${IParray[$i]}"|bc`
    		  NMarray[$i]=`echo "obase=16;${NMarray[$i]}"|bc`
  		  #echo "${IParray[$i]} \t\c"
  		  #echo "${NMarray[$i]} \t\c"
    		  NuA="16#${IParray[$i]}"
    		  NuB="16#${NMarray[$i]}"
    		  #echo "$NuA $NuB"
  		  NetArray[$i]=$(($NuA&$NuB))
    		  let i=$i+1
		done

	BackupNW=$(echo ${NetArray[*]} | sed 's/ /\./g')
        BackupGW=$(echo "${BackupNW}" | sed 's/.0$/.1/g')

   if [[ -z $BackupGW ]]; then
     BackupNW=$(netstat -Cnr 2>&1 | grep $BackupIP | egrep -v ".255|127.0.0|"/"" | awk '{print $1}' | grep .0$ | sed 1q)
     BackupGW=$(echo "${BackupNW}" | sed 's/.0$/.1/g')
   else
      PrintINFO "BACKUP Network is ${BackupNW} ,IP is $BackupIP , Gateway is $BackupGW" 
   fi
  [ X != X${BackupGW} ] && FirstThreeBGW=$(echo ${BackupGW} | cut -d. -f1-3)

  LinkState=$(entstat -d $BackupInterface 2>&1 | awk '/Link Status/ {print $NF}')
    if [[ $LinkType != @(*Up*) ]]; then
      LinkType=$(entstat -d $BackupInterface 2>&1 | grep -i virtual | awk '/Device Type/ {print $3}' | sed '$!d')
      if [[ $LinkType != @(*Virtual*) ]]; then
       LinkState=Unknown
      else
       LinkState=Up
       PVID=$(entstat -d $BackupInterface 2>&1 | grep -i vlan | grep -v Invalid | awk -F : '{printf $NF " "}')
       PVID=$(printf "%s %s %s %s" $PVID Virtual )
      fi
      PrintINFO "IF $BackupInterface UP - PVID $PVID - bound to address $BackupIP. Testing connection" 
      #ping -w3 -c1 ${BackupGW} >/dev/null 2>&1
      PrintINFO "Backup gateway - "$(traceroute -m2 -w2 ${BackupGW} 2>&1 | sed '$!d' | grep ms || echo 'DOES NOT WORK. Servers may be on same netwrok or trace BLOCKED')""
    fi
fi

#With TSM routes in place there may not be a need to add separate route.
IsGWup=
RouteSet=No
NewRoute=No
XXX=0
TargetIP=`host ${mksysbServer} | awk '{printf $NF}'`

TestRoute() {
#set -x
let XXX=$XXX+1
  RepoSer=$1
  SourceIP=$2
  ShotRepoName=$(echo ${RepoSer} | cut -d . -f1)
  SerClient=$(traceroute -m12 -w2 ${RepoSer} 2>&1 | grep from | awk '{print $3 " " $4 " " $6}')  #$6 will be backup IP
  TargetHost=$(echo $SerClient | awk '{printf $1}')
  TargetIP=$(echo $SerClient | awk '{printf $2}' | sed 's/(//g; s/)//g')
  CSourceIP=$(echo $SerClient | awk '{printf $3}')
  [ X == X$SourceIP ] && SourceIP=$CSourceIP
  [ X != X$CSourceIP ] && FirstThreeSIP=$(echo $CSourceIP | cut -d . -f1-3)
   if [[ $TargetHost == @(${ShotRepoName}*) ]] && [[ ${SourceIP} == @(${FirstThreeSIP}*) ]]; then
    SerVerUP=Yes
    IsReaching=$(traceroute -m12 -w 2 ${mksysbServer} 2>&1  | grep ms | grep ${ShotRepoName})
    if [[ X != "X${IsReaching}" ]]; then
          PrintINFO "Test $XXX - Route seem to be set. Checking end to end link for SCP"
          IsGWup=Yes
          RouteSet=Yes
    else
          IsGWup=
          SerVerUP=
          PrintWARN "Test $XXX - Link over tested route is not usable. Default network may be used for file transfer"
    fi
   else
     PrintWARN "Test $XXX - Traffic does not use backup interface yet. Trying to set a new route if possible"
     RouteSet=No
   fi
}

SetNewRoute() {
#set -x
   TarGetIP=$1 #Host based route is the one only tested
   GateWay=$2
   PrintWARN "Route is NOT set for $TarGetIP over $GateWay. Checking whether gateway is active"
     IsGWup=$(ping -c1 -w5 -r -L -I ${BackupIP} -o ${BackupInterface} ${BackupGW} 2>/dev/null | grep ttl)  #Traceroute does not work in WDC
     CurrentGateway=$(netstat -Cnr | grep ${TarGetIP} | awk '{printf $2}')
     [ X != X$CurrentGateway ] && PrintINFO "`route delete ${TarGetIP} $CurrentGateway  2>/dev/null`"
      #Add new routes here
     if [[ X != "X${IsGWup}" ]]; then
       PrintINFO "Local backup gatway is UP. Setting a new route now"
       PrintINFO "NEW ROUTE to ${mksysbServer} ... `route add -host ${TarGetIP} ${GateWay} 2>/dev/null `"
       PrintINFO "Route command issued. Checking end to end link over new route"
       if [[ $NewRoute == No ]]; then TestRoute ${mksysbServer} ${BackupIP}; fi
       NewRoute=Yes
     else
       PrintERRO "Backup interface gateway is not accessible. Cannot set the route"
       IsGWup=
     fi
}

if [[ ! -z ${BackupGW} ]]; then
  PrintINFO "Tracing route to ${mksysbServer} over backup gateway"
  TestRoute ${mksysbServer} ${BackupIP} #Route may already been set
  TargetIP=`host ${mksysbServer} | awk '{printf $NF}'`
  if [[  $RouteSet == No ]]; then SetNewRoute ${TargetIP} ${BackupGW}; TestRoute ${mksysbServer} ${BackupIP}; fi #Route may already been set

    if [[ -z $IsGWup ]]; then 
       BackupNetwork="LOCAL Backup network NOT OK"
       PrintERRO "Please trobleshoot the backup interface "
       #SetNewRoute ${mksysbServer} ${BackupGW}
      SerVerUP=
      WaitTime=59 ; IFUsed='DEFAULT'
    else
      SerVerUP=Yes
      PrintSUCC "Now, Gateway ${BackupGW} can route mksysb file to the repo. Connection is good. "
      IFUsed='BACKUP' ; WaitTime=29
    fi

   #Bind="-o BindAddress=${BackupIP}"
   if [[ ! -z ${SerVerUP} ]]; then
    SerStatus="$mksysbServer reachable"
     KeyConn=$($SSHCMD 'date')
     sleep 1
     [ X == "X$KeyConn" ] && KeyConn=$($SSHCMD 'date')
     if [[ -z $KeyConn ]]; then
       SerStatus="Cannot ssh to $mksysbServer"
       PrintWARN "SSH does not work well between $mksysbServer. Checking .. " 
     fi 
  else
    PrintWARN "$mksysbServer NOT reacheable over backup network. Using default gateway to reach `echo $mksysbServer | sed 's/e././g'`" 
    mksysbServer=$(echo $mksysbServer | sed 's/e././g') #Make the mksysb server to transactional IP
    WaitTime=59 ; IFUsed='DEFAULT'
    SerStatus="$mksysbServer not reachable"
  fi
else
 BackupIFace="Backup IF for $BackupIP not configured"
 PrintERRO "NO Backup Interface has been configured. Using transactional interface" 
 mksysbServer=$(echo $mksysbServer | sed 's/e././g') #Make the mksysb server to transactional IP
 IFUsed='DEFAULT' ; WaitTime=59
 PrintWARN "Destination mksysb repository transactional interface selected"
 BackupIP=
fi

PrintINFO "Starting SCP test to ${mksysbServer}"

#Try linking the backup interface to mksysb server
#Copy a small file to test the connection
  if [[ -f ${logFile} ]]; then
    $SCPCMD -q ${logFile} mksysbu@${mksysbServer}:/mksysbfs; SCP_statues=`echo $?`
  fi
  sleep 4
  if [[ $SCP_statues != 0 ]]; then
    PrintFAIL "First attempt for SCPying files to ${mksysbServer} failed." 
  fi
  TestConn=$($SSHCMD 'date')
  [ ! -z $TestConn ] && LinkState='Up' || LinkState='Down'

if [[ $LinkState != @(*Down*) ]]; then
   PrintSUCC "End to end link is good. Check which network was selected"
   BackupNetwork="Backup network usable"
else
  mksysbServer=$(echo $mksysbServer | sed 's/e././g') #Make the mksysb server to transactional IP
  PrintINFO "SCP test failed. If file transfer fails, alt_disk will still be taken if option -a or -B selected"
  SSHCMD="$_CMDSSH ${SSHopt} mksysbu@${mksysbServer}"
  Bind=
  IFUsed='DEFAULT'
  BackupNetwork="Backup network Not usable"
fi

PrintINFO "Transfer files to ${mksysbServer} over $IFUsed interface" 
CpmleteStatus="`uname -n` --> ${SerStatus}. ${BackupNetwork}"

test_ssh_conn

#$SSHCMD "echo ${CpmleteStatus} >>/mksysbfs/ServerLinkStatus.log"
#PrintINFO "${CpmleteStatus}" 

# This part will check if other processes are running 
# Begin Flag detection
PROG_NAME=$(basename $0)
m_FLAG=FALSE # mksysb only
a_FLAG=FALSE # Alt disk only
C_FLAG=FALSE # Copy mksysb
L_FLAG=FALSE # Copy Logfile
B_FLAG=FALSE # BOTH flag
v_FLAG=FALSE # verify
D_FLAG=FALSE # DMZ flag
T_FLAG=FALSE #Debug option, move to the setion you want to test

while getopts BaCmLvD OPTION
do
    case ${OPTION} in
        m) m_FLAG=TRUE;;
        B) B_FLAG=TRUE;;
        a) a_FLAG=TRUE;;
        #a) a_FLAG=TRUE; T_FLAG=TRUE;;
        C) C_FLAG=TRUE;;
        L) L_FLAG=TRUE;;
        v) v_FLAG=TRUE;;
        D) D_FLAG=TRUE;;
       \?) usage
           exit 2;;
    esac
done

if [ "$B_FLAG" = TRUE ]
then
StartFucn='Clone and mksysb'
PrintINFO "STARTING ${StartFucn} PROCESS " 
	chk4proc 
	PrepareRootVG
	run_mksysb 
	copy_mksysb
	run_altrootvg_copy 
	altroot_postcheck
	verify_mksysb
	exit_function
fi

if [ "$m_FLAG" = TRUE ]
then
StartFucn='mksysb'
PrintINFO "STARTING ${StartFucn} PROCESS " 
	chk4proc 
	PrepareRootVG
	run_mksysb 
        if [[ $HdiskType == @(power|Power|SYMM_VRAID) ]]; then
          pprootdev fixback >/dev/null
        fi
	copy_mksysb 
	verify_mksysb
	exit_function
fi

if [ "$a_FLAG" = TRUE ]
then 
StartFucn='Clone'
PrintINFO "STARTING ${StartFucn} PROCESS " 
	chk4proc 
	PrepareRootVG
	run_altrootvg_copy 
	altroot_postcheck
	exit_function
fi

if [ "$C_FLAG" = TRUE ]
then
StartFucn='Copy mksysb'
PrintINFO "STARTING ${StartFucn} PROCESS " 
	copy_mksysb 
	verify_mksysb
	exit_function
fi

if [ "$L_FLAG" = TRUE ]
then
	exit_function
fi

if [ "$v_FLAG" = TRUE ]
then
StartFucn='Verify mksysb'
PrintINFO "STARTING ${StartFucn} PROCESS " 
	verify_mksysb
	exit_function
fi

if [ "$D_FLAG" = TRUE ]
then
StartFucn='Clone and mksysb for DMZ'
PrintINFO "STARTING ${StartFucn} PROCESS " 
	PrintINFO "DMZ FLAG ACTIVATED"
	chk4proc 
	PrepareRootVG
	run_mksysb 
	run_altrootvg_copy 
	altroot_postcheck
	dmzopt
	exit_function
fi


usage
