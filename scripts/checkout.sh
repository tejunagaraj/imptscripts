#!/bin/ksh
####################################################################################################################
# Created By Ashokkumar P (UNIX) 										   #
# Version 1.0 													   #
# Collect all configuration data and will  be stored  data under /tmp/preckecks/postcheck<current adate and time>  #
# This file will be used to validate after reboot of server and will compare with the data collected after reboot #
# Version 1.1 (Ashok) 												   #
# Not more that 4 precheck data directories will we avilable on server						   #
# Version 1.2 (Ashok) 												   #
# Precheck data will be compresed and stored under /PRECHECK to aviod data loss after migration 		   #
# Version 1.3 (Ashok)												   #
# Auto selection of precheck and postcheck data 								   #
# ASM check ,Reservelock policy check and EMC mapping included  				                   #
####################################################################################################################
HOSTNAME=`uname -n`

SAVEDATE=`date +%d%B%Y_%H%M%S`



SAVEDIR="/tmp/precheck/postchecks.${SAVEDATE}"


echo "Started to gather postchecks info  on ${HOSTNAME}. If this hangs for any longer than 30 seconds,

probably worth running with ksh -x to see where script is hanging.\n"

[ ! -d ${SAVEDIR} ] && mkdir -p ${SAVEDIR}


chmod 700 ${SAVEDIR}


echo "Collecting ............/etc/filesystems"
cp -p /etc/filesystems ${SAVEDIR}/filesystems 

echo "Collecting ............/etc/inittab"
cp -p /etc/inittab ${SAVEDIR}/inittab

echo "Collecting ............/etc/motd"
cp -p /etc/motd ${SAVEDIR}/motd

echo "Collecting ............/etc/exports"
if [ -f /etc/exports ]; then

  cp -p /etc/exports ${SAVEDIR}/exports

fi

echo "Collecting ............NFS"
egrep -p nfs /etc/filesystems > ${SAVEDIR}/filesystems_nfs.out 2>/dev/null


echo "Collecting ............VG infromation from /dev "
ls -al /dev/*vg* > ${SAVEDIR}/vg_major_numbers.out 2>/dev/null

echo "Collecting ............netstat -i"
netstat -i  > ${SAVEDIR}/netstat_i.out

echo            >> ${SAVEDIR}/netstat_i.out

echo "Collecting ............NTP status"
lssrc -s xntpd | awk '{print $1,$4}' > ${SAVEDIR}/xntp.out

echo "Collecting ............resolv.conf"
cp -p /etc/resolv.conf ${SAVEDIR}/resolv.conf 2>/dev/null

echo "Collecting ............netstat -in"           
netstat -in     > ${SAVEDIR}/netstat_in.out

echo "Collecting ............Routing table"
netstat -rn    > ${SAVEDIR}/netstat_r.out
cat ${SAVEDIR}/netstat_r.out | grep '^[0-9]' | awk '{print $1,$2,$3}'  > ${SAVEDIR}/netstat_r_v.out

echo "Collecting ............Bootlist (normal)"
bootlist -m normal -o >> ${SAVEDIR}/bootlist_normal.out

echo "Collecting ............Bootlist (Management)"
bootlist -m service -o >> ${SAVEDIR}/bootlist_service.out

echo "Collecting ............Boot log"
alog -o -t boot >> ${SAVEDIR}/alog_boot.out

echo "Collecting ............DF output"
df -gI         > ${SAVEDIR}/df.out

echo "Collecting ............Mount information"
mount            > ${SAVEDIR}/mount.out
cat ${SAVEDIR}/mount.out | grep -v vfs | grep -v ^- | awk '{print $1,$2,$3}'  > ${SAVEDIR}/mount_v.out

echo "Collecting ............LSFS infromation"
lsfs             > ${SAVEDIR}/lsfs.out


echo "Collecting ............exportfs info"
> ${SAVEDIR}/exportfs.out
exportfs         > ${SAVEDIR}/exportfs.out

echo "Collecting ............lspv"
lspv             > ${SAVEDIR}/lspv.out

echo "Collecting ............lsdev -Ccadapter "
lsdev -Ccadapter > ${SAVEDIR}/lsdev_Ccadapter.out 2>/dev/null

echo "Collecting ............lsdev -Ccdisk"
lsdev -Ccdisk    > ${SAVEDIR}/lsdev_Ccdisk.out 2>/dev/null

echo "Collecting .............lsdev -Ccdisk"
lsdev -Ccdisk    > ${SAVEDIR}/lsdev_Cctape.out 2>/dev/null

echo "Collecting ............lsdev -Cctty"
lsdev -Cctty     > ${SAVEDIR}/lsdev_Cctty.out 2>/dev/null

echo "Collecting ............hostname "
hostname         > ${SAVEDIR}/hostname.out

echo "Collecting ............uname -n"
uname -n         > ${SAVEDIR}/uname_n.out

echo "Collecting ............lsvg"
lsvg             > ${SAVEDIR}/lsvg.out

echo "Collecting ............active vg info"
lsvg -o          > ${SAVEDIR}/lsvg_o.out
cat ${SAVEDIR}/lsvg_o.out | grep -v root | grep -v alt   > ${SAVEDIR}/lsvg_o_v.out 2>/dev/null

echo "Collecting ............lscfg -vp "
lscfg -vp         > ${SAVEDIR}/lscfg.out

echo "Collecting ............prtconf "
prtconf          > ${SAVEDIR}/prtconf.out

echo "Collecting ............VG info"
touch              ${SAVEDIR}/vg_info.out

chmod 644          ${SAVEDIR}/vg_info.out

VGLOG="${SAVEDIR}/vg_info.out"

for i in `lsvg -o`

do

   lsvg $i    >> ${VGLOG} 2>/dev/null

   lsvg -p $i >> ${VGLOG} 2>/dev/null

   lsvg -l $i >> ${VGLOG} 2>/dev/null

   echo >> ${VGLOG}

   echo "#############################################" >> ${VGLOG}

   echo >> ${VGLOG}

done

for j in `lspv | grep -v None | awk '{print $1}'`

do

      lspv -l $j >> ${VGLOG}  2>/dev/null

done

if [[ -f /usr/sbin/pcmpath ]]

then
	echo "Collecting ............pcmpath"
        /usr/sbin/pcmpath query adapter > ${SAVEDIR}/pcmpath.out 2>/dev/null

        /usr/sbin/pcmpath query device  >> ${SAVEDIR}/pcmpath.out 2>/dev/null



elif [[ -f /usr/sbin/datapath ]]

then
	echo "Collecting ............datapath"
        /usr/sbin/datapath query adapter > ${SAVEDIR}/datapath.out 2>/dev/null

        /usr/sbin/datapath query device  >> ${SAVEDIR}/datapath.out 2>/dev/null

else

        echo ".......................NO SDD/PCM Drivers Found"

fi



##

echo "Collecting ............IP info"
ifconfig -a > ${SAVEDIR}/ifconfig_a.out

#installp -s > ${SAVEDIR}/installp_s.out 2>&1 >/dev/null

echo "Collecting ............FIX"
instfix -vi > ${SAVEDIR}/instfix_vi.out

echo "Collecting ............Runlevel info"
oslevel -r >  ${SAVEDIR}/oslevel_r.out

echo "Collecting ............vmo"
vmo -a > ${SAVEDIR}/vmo_a.out

echo "Collecting ............network kernal parameter"
no -a > ${SAVEDIR}/no_a.out

echo "Collecting ............lsattr -Elsys0"
lsattr -Elsys0 > ${SAVEDIR}/lsattr_Elsys0.out  2>/dev/null

echo "Collecting ............lsattr -Elaio0"
lsattr -Elaio0 > ${SAVEDIR}/lsattr_Elaio0.out 2>/dev/null

echo "Collecting ............lsattr -El inet0"
lsattr -El inet0 > ${SAVEDIR}/lsattr_Elinet0.out 2>/dev/null

echo "Collecting ............ps -ef "
ps -ef > ${SAVEDIR}/ps_ef.out

echo "Collecting ............ls -iFlater /dev"
ls -iFlater /dev > ${SAVEDIR}/dev_directory_list.out

echo "Collecting ............profile for root user"
[ -a ~root/.profile ] && cat ~root/.profile > ${SAVEDIR}/root_profile.out

echo "Collecting ............root's kshrc"
[ -a ~root/.kshrc ] && cat ~root/.kshrc > ${SAVEDIR}/root_kshrc.out


lslv -l hd5 > ${SAVEDIR}/lslv_lhd5.out

echo "Collecting ............/etc/profile"
[ -a /etc/profile ] && cat /etc/profile > ${SAVEDIR}/etc_profile.out

echo "Collecting ............/etc/environment "
[ -a /etc/environment ] && cat /etc/environment > ${SAVEDIR}/etc_environment.out
echo "Collecting ............/etc/hosts"
[ -a /etc/hosts ] && cat /etc/hosts > ${SAVEDIR}/hosts.out
echo "Collecting ............/etc/services"
[ -a /etc/services ] && cat /etc/services > ${SAVEDIR}/services.out
echo "Collecting ............/etc/inetd.conf"
[ -a /etc/inetd.conf ] && cat /etc/inetd.conf > ${SAVEDIR}/inetd.conf.out
echo "Collecting ............cron.allow"
[ -a /var/adm/cron/cron.allow ] && cat /var/adm/cron/cron.allow > ${SAVEDIR}/cron.allow.out
echo "Collecting ............rc.tcpip"
[ -a /etc/rc.tcpip ] && cat /etc/rc.tcpip > ${SAVEDIR}/rc.tcpip.out
echo "Collecting ............/etc/security/user"
[ -a /etc/security/user ] && cat /etc/security/user > ${SAVEDIR}/user.out
echo "Collecting ............/etc/security/limits"
[ -a /etc/security/limits ] && cat /etc/security/limits > ${SAVEDIR}/limits.out
############################################################


echo "Collecting ............lppchk"
lppchk -vm3 > ${SAVEDIR}/lppchk.out

echo $LIBPATH  > ${SAVEDIR}/LIBPATH.out


echo "Collecting ............env"
env > ${SAVEDIR}/env.out

echo "Collecting ............lsattr_SAN_DISKS"
lsdev -Cc disk|grep MPIO|awk '{print "lsattr -El "$1}'|sh >${SAVEDIR}/lsattr_SAN_DISKS.out

echo "Collecting ............powermt display"
powermt display > ${SAVEDIR}/powermt.out 2>/dev/null

echo "Collecting ............powermt display dev=all"
powermt display dev=all > ${SAVEDIR}/powermt_all.out 2>/dev/null


########################SSH confd and ssh keys###############




 

SSH_T=`lssrc -a | grep -i ssh |grep -i active| awk '{print $1}'`
>${SAVEDIR}/ssh_Ciphers_validation.out
if [ $SSH_T = sshd-quest ]
then
echo "Collecting ............Quest ssh info"
cat /etc/opt/quest/ssh/sshd_config |grep -i Ciph > ${SAVEDIR}/ssh_Ciphers_validation.out
cp -p /etc/opt/quest/ssh/ssh_host_dsa_key ${SAVEDIR}/quest_ssh_host_dsa_key.out 2>/dev/null
cp -p /etc/opt/quest/ssh/ssh_host_key ${SAVEDIR}/quest_ssh_host_key.out 2>/dev/null
cp -p /etc/opt/quest/ssh/ssh_host_rsa_key ${SAVEDIR}/quest_ssh_host_rsa_key.out 2>/dev/null
cp -p /etc/opt/quest/ssh/sshd_config ${SAVEDIR}/quest_sshd_config.out 2>/dev/null
else
echo "Collecting ............Open ssh info"
cat /etc/ssh/sshd_config |grep -i Ciph > ${SAVEDIR}/ssh_Ciphers_validation.out
cp -p /etc/ssh/ssh_host_dsa_key ${SAVEDIR}/open_ssh_host_dsa_key.out 2>/dev/null
cp -p /etc/ssh/ssh_host_key ${SAVEDIR}/open_ssh_host_key.out 2>/dev/null
cp -p /etc/ssh/ssh_host_rsa_key ${SAVEDIR}/open_ssh_host_rsa_key.out 2>/dev/null
cp -p /etc/ssh/sshd_config ${SAVEDIR}/sshd_config.out 2>/dev/null
fi
#############################


################Reserve policy  for IBM ###########
> ${SAVEDIR}/Reserve_policy_IBM.out
echo "Collecting ............Reserve policy  for non EMC disk"
for i in `lsdev -Cc disk -S A  | grep -i IBM | awk '{print $1}'`
do
POLICY=`lsattr -EHl $i | grep -i reserve_ | awk '{ print $2}'`
echo $i $POLICY >> ${SAVEDIR}/Reserve_policy_IBM.out
done
#########################################

#####################EMC MAPPING#######
echo "Collecting ............emcpadm export_mappings"
emcpadm export_mappings -x -f ${SAVEDIR}/emcpadm_export_list
#################################

echo "Collecting ............ODM info"
odmget CuAt > ${SAVEDIR}/cuat.out

odmget CuDv > ${SAVEDIR}/cudv.out

echo "Collecting ............lssrc -a"
lssrc -a > ${SAVEDIR}/lssrc_a.out

echo "Collecting ............Active services"
lssrc -a | grep -i active | awk '{print $1}' > ${SAVEDIR}/lssrc_a_v.out



###########################CLuster HACMP#######################

lslpp -l cluster.es.server.rte  2>/dev/null  |  grep  cluster.es.server.rte  

if [[ $? -eq 0 ]] ; then

	echo "Collecting ............HACMP cluster detail"
        echo "Cluster filesets installed "   >${SAVEDIR}/hacmp.out

        lslpp -l cluster.es.server.rte >>${SAVEDIR}/hacmp.out

        CLVER=`lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte |  awk '{print $2}' | head -1`

        echo "The installed Cluster Version is $CLVER " >> ${SAVEDIR}/hacmp.out

        CLSTATE=`lssrc -ls clstrmgrES |  grep "Current state:" |  awk '{print $3}'`

        echo "Cluster state is $CLSTATE"  >> ${SAVEDIR}/hacmp.out

        if [[ $CLSTATE = "ST_STABLE" ]] ; then

          CLRUN=0

          echo "  " >> ${SAVEDIR}/hacmp.out

          echo "Status of the cluster daemons as below" >> ${SAVEDIR}/hacmp.out

          echo "======================================================================== " >> ${SAVEDIR}/hacmp.out

          /usr/es/sbin/cluster/utilities/clshowsrv -v >> ${SAVEDIR}/hacmp.out

          echo "Detailed Cluster Configuration " >> ${SAVEDIR}/hacmp.out

          echo "======================================================================== " >> ${SAVEDIR}/hacmp.out

          /usr/es/sbin/cluster/utilities/cldump >> ${SAVEDIR}/hacmp.out

          echo "The scripts used during the Cluster takeover as below "  >> ${SAVEDIR}/hacmp.out

          echo "======================================================================== " >> ${SAVEDIR}/hacmp.out

          /usr/es/sbin/cluster/utilities/cllsserv  >> ${SAVEDIR}/hacmp.out

          echo "The Cluster Log files are found as below"  >> ${SAVEDIR}/hacmp.out

          echo "======================================================================== " >> ${SAVEDIR}/hacmp.out

          odmget HACMPlogs   >> ${SAVEDIR}/hacmp.out

          echo "The Resource group status  as below"  >> ${SAVEDIR}/hacmp.out

          echo "======================================================================== " >> ${SAVEDIR}/hacmp.out

          /usr/es/sbin/cluster/utilities/clRGinfo >> ${SAVEDIR}/hacmp.out

          echo "The network output as below"  >> ${SAVEDIR}/hacmp.out

          echo "======================================================================== " >> ${SAVEDIR}/hacmp.out

          /usr/es/sbin/cluster/utilities/cllsif >> ${SAVEDIR}/hacmp.out

        else

          echo "Cluster is Unstable.No output captured.Please verify "  >> ${SAVEDIR}/hacmp.out



        fi



else
        echo "Cluster Configuration does not Exists" >> ${SAVEDIR}/hacmp.out
	echo ".......................Not a HACMP Cluster Node "



fi


echo "===================================================================================="
echo "Completed checkout data collection. Check the following for information:\n${SAVEDIR}"
echo "===================================================================================="
#################################################################################
# This script verifies the latest Checkin and current Checkout output            #
# Input file:  post-Reboot Dir/*                                                #
#################################################################################


white=$(echo "\033[1;37m")
yellow=$(echo "\033[1;33m") yellowbg=$(echo "\033[1;43m")
green=$(echo "\033[1;32m") greenbg=$(echo "\033[1;42m")
blue=$(echo "\033[1;34m") bluebg=$(echo "\033[1;44m")
red=$(echo "\033[1;31m") redbg=$(echo "\033[1;41m")
normal=$(echo "\033[0m")
magenta=$(echo "\033[1;35m") magentabg=$(echo "\033[1;45m")
blackbg=$(echo "\033[0;40m") 
whitebg=$(echo "\033[0;47m")

START_DATE=`date`

STARTTIME=$(date +%s)

Program_Version="1.0"

DATE=`date "+%d-%b-%Y-%H-%M"`

SERVER=`uname -n`

LOGDIR="/tmp/PREPOST_REPORT"

LOGFILE="$LOGDIR/$SERVER"_"$DATE""_compare_report.txt"

TMPLOGFILE="$LOGDIR/tmp_compare_report.txt"

MAILREPORT="/tmp/CheckInOut.txt"

HOST=`hostname -s`

PERL="/usr/bin/perl"




export LOGDIR  PERL  HOST



[ ! -d ${LOGDIR} ] && mkdir -p ${LOGDIR}

cp /dev/null/ $LOGFILE

cp /dev/null/ $MAILREPORT

cp /dev/null/ $TMPLOGFILE





USERID=`id | awk ' { print $1 }' | grep root`

if [ -z "$USERID" ]

then

   echo  "You must run this script as Root user\n"

   exit 1

fi





##############################
###Cleaning report directories if number of directories count is more than 4
################

COMPAR_COUNT=`ls -ltr /tmp/PREPOST_REPORT | grep -v tmp_compare | wc -l`
while [ $COMPAR_COUNT -gt 4 ]
do
OLD_DATA=`ls -ltr /tmp/PREPOST_REPORT | grep -v tmp_compare | grep -v total | head -1 | awk '{print $9}'`
FOLDER=`echo "/tmp/PREPOST_REPORT/$OLD_DATA"`
echo $FOLDER
rm -rf $FOLDER
COMPAR_COUNT=`ls -ltr /tmp/PREPOST_REPORT | grep -v tmp_compare | grep -v total | wc -l`
done

##########################################




########################Validating the old data count


A=`ls -lrt /tmp/precheck | grep -i prechecks. | awk '{print $9}' | tail -4`
set -A OLD_DIR $A
File_count=`ls -lrt /tmp/precheck/${OLD_DIR[3]} | wc -l`
if [ $File_count -ge 50 ]; then
echo "Number of files in ${OLD_DIR[3]} is $File_count"
OLDDIR=/tmp/precheck/${OLD_DIR[3]}
else
echo "No Valide data in latest Precheck direcory ${OLD_DIR[3]} and number of files in it is $File_count"
File_count=`ls -lrt /tmp/precheck/${OLD_DIR[2]} | wc -l`
if [ $File_count -ge 50 ]; then
echo "Number of files in ${OLD_DIR[2]} is $File_count"
OLDDIR=/tmp/precheck/${OLD_DIR[2]}
else
echo "No Valide data in latest Precheck direcory ${OLD_DIR[2]} and number of files in it is $File_count"
File_count=`ls -lrt /tmp/precheck/${OLD_DIR[1]} | wc -l`
if [ $File_count -ge 50 ]; then
echo "Number of files in ${OLD_DIR[1]} is $File_count"
OLDDIR=/tmp/precheck/${OLD_DIR[1]}
else
echo "No Valide data in latest Precheck direcory ${OLD_DIR[1]} and number of files in it is $File_count"
File_count=`ls -lrt /tmp/precheck/${OLD_DIR[0]} | wc -l`
if [ $File_count -ge 50 ]; then
echo "Number of files in ${OLD_DIR[0]} is $File_count"
OLDDIR=/tmp/precheck/${OLD_DIR[0]}
else
echo "No Valide data in latest Precheck direcory ${OLD_DIR[0]} and number of files in it is $File_count"
exit 1
fi
fi
fi
fi

echo  $white $greenbg "the Location of Pre-Reboot  Directory : " $normal
echo $OLDDIR

echo  $white $magentabg "the Location of Post-Reboot Directory : " $normal

NEWDIR=/tmp/precheck/`ls -lrt /tmp/precheck | grep -i postchecks. | awk '{print $9}' | tail -1`
echo $NEWDIR

sleep 5



compare(){



        echo "$1 - Checking and comparing $2 file ... "

        

        diff  $OLDDIR/$2 $NEWDIR/$2

        RESULT=`echo $?`
        
	if [[ $RESULT -ge 1 ]] ; then
	echo "+++++++++++++++++++++++++++++$white$greenbg $3 $normal +++++++++++++++++++++++++++++"  >> "$TMPLOGFILE"
	echo $white $red >> "$TMPLOGFILE"
	diff  $OLDDIR/$2 $NEWDIR/$2 >> "$TMPLOGFILE"
	echo $normal >> "$TMPLOGFILE"
	else
	diff  $OLDDIR/$2 $NEWDIR/$2 >> "$TMPLOGFILE"
	fi
       
        if [[ $RESULT -ge 1 ]] ; then
                
 #               echo "$1 \t $3 \t ------- \t $white$red Differences Found $normal " >> "$LOGFILE"
	printf "%20s %30s %30s %20s \n" $1 $3 $white$red "Differences Found" $normal  >> "$LOGFILE"
	printf "%20s %30s %30s %20s \n" $1 $3 "***Differences Found****"   >> "$MAILREPORT"
        else
 #               echo "$1 \t $3 \t ------- \t $white$green No Differences Found $normal " >> "$LOGFILE"
	printf "%20s %30s %30s %20s \n" $1 $3 $white$green "No Differences Found" $normal  >> "$LOGFILE"
	printf "%20s %30s %30s %20s \n" $1 $3 "No Differences Found"  >> "$MAILREPORT"

        fi

}

#main

echo $white $bluebg "Validated on `date`" $normal > "$LOGFILE"
echo "Validated on `date`" > "$MAILREPORT"

echo $white $greenbg "PRE-REBOOT DIR  - $OLDDIR" $normal  >> "$LOGFILE"
echo "PRE-REBOOT DIR  - $OLDDIR"  >> "$MAILREPORT"

echo $white $magentabg"POST-REBOOT DIR  - $NEWDIR" $normal>> "$LOGFILE"
echo "POST-REBOOT DIR  - $NEWDIR" >> "$MAILREPORT"

echo "\n" >> "$LOGFILE"
echo "\n" >> "$MAILREPORT"

echo "\n" >> "$LOGFILE"
echo "\n" >> "$MAILREPORT"
echo "\n"

echo $white $yellowbg "========================================================================================" $normal >> "$LOGFILE"
echo "========================================================================================"  >> "$MAILREPORT"
echo $white $yellowbg "========================================================================================" $normal > "$TMPLOGFILE"

echo $white $yellowbg"            Detailed Information on the differences found after validation as below" $normal >> "$TMPLOGFILE"

echo $white $yellowbg "========================================================================================" $normal >> "$TMPLOGFILE"

#functions to check the previous and newer outputs

compare 01  	inittab  ETC_INITTAB

compare 02  	xntp.out NTP_Status

compare 03      filesystems     ETC_FILESYSTEMS

compare 04      ifconfig_a.out IFCONFIG_A

compare 05  	filesystems_nfs.out NFS_FS

compare 06  	lsfs.out LSFS

compare 07      exportfs.out    EXPORTS

compare 08      uname_n.out     UNAME_n

compare 09      hostname.out HOSTNAME

compare 10      lsattr_Elsys0.out LSATTR-SYS0

compare 11      services.out SERVICES

compare 12      ssh_Ciphers_validation.out SSH_CIPH_ENTRY

compare 13      oslevel_r.out OSLEVEL-R

compare 14      lsattr_Elinet0.out LSATTR-INET0

compare 15      lsattr_Elaio0.out LSATTR-AIO0

compare 16      inetd.conf.out INETD-CONF

compare 17      hosts.out HOSTS

compare 18      etc_profile.out ETC-PROFILE

compare 19      etc_environment.out     ETC-ENV

compare 20      LIBPATH.out     LIBPATH

compare 21      lsvg.out LSVG
compare 22      lsvg_o_v.out LSVG-O
compare 23      netstat_r_v.out   NETSTAT
compare 24      mount_v.out       MOUNT
compare 25      lssrc_a_v.out     LSSRC-A
compare 26      Reserve_policy_IBM.out IBM_RESERVE_POLICY
compare 27      cron.allow.out    CRON.ALLOW
compare 28	rc.tcpip.out 	RC.TCPIP
compare 29	user.out	USERS
compare 30	limits.out	LIMITS
compare 31	motd 		MOTD

if [ $SSH_T = sshd-quest ]
then
compare 32      ssh_Ciphers_validation.out QUEST_SSH_CIPHER_ENTRY
compare 33	quest_ssh_host_dsa_key.out QUEST_SSH_HOST_DSA_KEY
compare 34	quest_ssh_host_key.out	   QUEST_SSH_HOST_KEY
compare 35	quest_ssh_host_rsa_key.out QUEST_SSH_HOST_RSA_KEY
compare 36	quest_sshd_config.out 	   QUEST_SSHD_CONFIG
else
compare 32      ssh_Ciphers_validation.out OPEN_SSH_CIPH_ENTRY
compare 33	opent_ssh_host_dsa_key.out OPEN_SSH_HOST_DSA_KEY
compare 34	open_ssh_host_key.out	   OPEN_SSH_HOST_KEY
compare 35	open_ssh_host_rsa_key.out  OPEN_SSH_HOST_RSA_KEY
compare 36	open_sshd_config.out 	   OPEN_SSHD_CONFIG
fi


########################################################END of compare####

#####VAS

#ps -ef | grep -i vasd | grep -vc grep 

#################################VG AND FS AUTO MOUNT/VARY ON status
a=37
b=Auto-Mount_Auto-Varyon
DFERROR=0

echo "$a - Checking and comparing $b file ... "


echo  $white $bluebg "Validate the Auto mount and auto varyon vg status " $normal

echo "+++++++++++++++++++++++++++++$white$greenbg Validate the Auto mount and auto varyon vg status $normal +++++++++++++++++++++++++++++"  >> "$TMPLOGFILE"
if ! ls /tmp/fscheck/log/ >/dev/null
then
mkdir /tmp/fscheck
mkdir /tmp/fscheck/log/
fi

>/tmp/fscheck/log/after_result

fscheck_mount ()
{

lsfs | awk '{print $3}' | grep -v Mount > /tmp/fscheck/log/fs_list
cllsfs 2> /dev/null | awk '{print $2}'> /tmp/fscheck/log/cluster_fs_list
grep -Fvxf /tmp/fscheck/log/cluster_fs_list /tmp/fscheck/log/fs_list > /tmp/fscheck/log/noncluster_fs

lsvg >/tmp/fscheck/log/vg_list
cllsvg 2> /dev/null | awk '{print $2}' > /tmp/fscheck/log/cluster_vg_list
grep -Fvxf /tmp/fscheck/log/cluster_vg_list /tmp/fscheck/log/vg_list | grep -vE "image_1|rootvg|oldrootvg|altinst_rootvg"> /tmp/fscheck/log/noncluster_vg



df  | awk '{print $7}' | grep -v %Iused > /tmp/fscheck/log/after_reboot_fs


for i in `grep -Fvxf /tmp/fscheck/log/after_reboot_fs /tmp/fscheck/log/noncluster_fs`
do
echo ----------------------------------
echo $i "is not mounted ,it has to be mounted on " `lsfs $i | grep -i $i | awk '{print $1}'`
if lsfs $i | awk '{print $7}' | grep -v Options | grep -i no >/dev/null
then
echo "For the mount "$i "Auto mount is in disable mode kindly check"
fi	
echo ----------------------------------
done

lsvg -o >/tmp/fscheck/log/after_reboot_vg

for j in `grep -Fvxf /tmp/fscheck/log/after_reboot_vg /tmp/fscheck/log/noncluster_vg`
do
echo ----------------------------------
echo $j "is not varied on "
if lsvg -L $j | grep -i 'AUTO ON:' | awk '{print $6}' | grep -i no >/dev/null
then
echo "For the VG "$j "Auto varyon is in disable mode kindly check"
fi	
echo ----------------------------------
done

rm -rf /tmp/fscheck/log/fs_list /tmp/fscheck/log/cluster_fs_list /tmp/fscheck/log/cluster_vg_list /tmp/fscheck/log/cluster_vg_list /tmp/fscheck/log/noncluster_vg /tmp/fscheck/log/after_reboot_fs

}

fscheck_mount >>/tmp/fscheck/log/after_result

AUTO_MOUNT=`cat /tmp/fscheck/log/after_result | wc -l`

if [ $AUTO_MOUNT = 0 ]
then
printf "%20s %30s %30s %20s \n" $a $b  $white$green "NO ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b   "NO ISSUE FOUND"  >> "$MAILREPORT"
else 
printf "%20s %30s %30s %20s \n" $a $b  $white$red "ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b   "***ISSUE FOUND***"  >> "$MAILREPORT"
cat /tmp/fscheck/log/after_result >> "$TMPLOGFILE"
fi

echo "===================================" >> "$TMPLOGFILE"

##########################################################



#########################check out validation for DF#############

a=38
b=DF_COMMAND
DFERROR=0

echo "$a - Checking and comparing $b file ... "


echo  $white $bluebg "Check Mountpoint Validation(df command)....." $normal

echo "+++++++++++++++++++++++++++++$white$greenbg Check Mountpoint Validation(df command) $normal +++++++++++++++++++++++++++++"  >> "$TMPLOGFILE"

for i in `cat $OLDDIR/df.out| grep -v swmount| awk '{print $6}' | grep -v %Iused`
do 
for j in `cat $NEWDIR/df.out| grep -v swmount| awk '{print $6}' | grep -v %Iused`
do
if [ $i = $j ]
then
MOUNTED=1
fi
done
if [ $MOUNTED != 1 ]
then 
lsfs $i > /dev/null
if [ $? = 0 ]
then
echo $white $red $i "has to be mounted on " `cat $OLDDIR/df.out | grep -i $i | awk '{print $1}'` $normal >> "$TMPLOGFILE"
DFERROR=1
fi
fi
MOUNTED=0
done

if [ $DFERROR = 0 ]
then
echo "---------NO MOUNT MISSING AFTER REBOOT" >> "$TMPLOGFILE"
fi


############################New entry after reboot########

echo "+++++++++++++++++++++++++++++$white$greenbg IS NEW FILESYSTEM FOUND TO BE MOUNTED AFTER REBOOT $normal+++++++++++++++++++++++++++++" >> "$TMPLOGFILE"

for i in `cat $NEWDIR/df.out| grep -v swmount| awk '{print $6}' | grep -v %Iused`
do 
for j in `cat $OLDDIR/df.out| grep -v swmount| awk '{print $6}' | grep -v %Iused`
do
if [ $i = $j ]
then
MOUNTED=1
fi
done
if [ $MOUNTED != 1 ]
then 
lsfs $i > /dev/null
if [ $? = 0 ]
then
echo $white $red $i "has to be mounted on   " `cat $NEWDIR/df.out | grep -i $i | awk '{print $1}'` $normal >> "$TMPLOGFILE"
DFERROR=1
fi
fi
MOUNTED=0
done


if [ $DFERROR = 1 ]
then
printf "%20s %30s %30s %20s \n" $a $b  $white$red "Differences Found" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  "***Differences Found***"  >> "$MAILREPORT"
else 
echo "---------NO NEW FILESYSTEM FOUND TO BE MOUNTED AFTER REBOOT" >> "$TMPLOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  $white$green "NO Differences Found" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  "NO Differences Found"  >> "$MAILREPORT"
fi


##########################################End of DF command

##############################################################RLP###################################################################################################PENDING
a=39
b=RESERVELOCK_POLICY_CHECK
echo "$a -Reserv lock policy scan ... "

echo  $white $bluebg "Disk Reserv lock policy scan in progress ......" $normal
echo "+++++++++++++++++++++++++++++ $white$greenbg Disk Reserv lock policy scan in progress $normal +++++++++++++++++++++++++++++"  >> "$TMPLOGFILE"

/usr/local/scripts/chk_rp.ksh -alert | tail -n 50 | grep -ip "Host     :" >> "$TMPLOGFILE"

echo "===================================" >> "$TMPLOGFILE"

RLPERROR=`cat /var/log/reserve.log | grep -i FAIL | wc -l`


if [ $RLPERROR = 1 ]
then
printf "%20s %30s %30s %20s \n" $a $b  $white$red "ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b   "***ISSUE FOUND***"  >> "$MAILREPORT"
else 
printf "%20s %30s %30s %20s \n" $a $b  $white$green "NO ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b   "NO ISSUE FOUND"  >> "$MAILREPORT"
fi

#############################END of RLP


#######################ASM CHECK############
a=40
b='ASM_NONASM_DISK_CHECK'
ASMERROR=0
echo "$a -ASM DISK Ownership and PVID validation ... "

echo  $white $bluebg "ASM/NON-ASM Disk scan in progress ......" $normal
echo "+++++++++++++++++$white$greenbg ASM/NON-ASM Disk scan report (Errors makred based on PVID and Ownership) $normal ++++++++++++++++++++" >> "$TMPLOGFILE"
#####################################################DISK_CHECK_ASM###################################
white=$(echo "\033[1;37m")
yellow=$(echo "\033[1;33m") yellowbg=$(echo "\033[1;43m")
green=$(echo "\033[1;32m") greenbg=$(echo "\033[1;42m")
blue=$(echo "\033[1;34m") bluebg=$(echo "\033[1;44m")
red=$(echo "\033[1;31m") redbg=$(echo "\033[1;41m")
normal=$(echo "\033[0m")
magenta=$(echo "\033[1;35m")
blackbg=$(echo "\033[0;40m") whitebg=$(echo "\033[0;47m")
>/tmp/PRE_ALL_Disk_list
>/tmp/PRE_ASM_HEAD_Disk_list
>/tmp/PRE_ASM_Disk_list
>/tmp/PRE_NONASM_HEAD_Disk_list
>/tmp/PRE_NONASM_Disk_list
>/tmp/PRE_ASM_PVIDERR
>/tmp/PRE_ASM_OWNERERR
> /tmp/PRE_DISK_CHECK
lspv > /tmp/ls_pvinfo
disktyp=NULL
policyinfo=NULL
DG_INFO=NONE
count=0
DERR=0
pvinfo=none
lsdev -Cc disk|grep -v PowerPath |grep -v EMC | awk '{print $1}' > /tmp/PRE_ALL_Disk_list
lsdev -Cc disk|grep -i PowerPath |grep -v EMC | awk '{print $1}' >> /tmp/PRE_ALL_Disk_list
#emcpadm getusedpseudos | grep -v pseudo | grep -v Major | grep -Ev "^$" | awk '{print $1}' >> /tmp/PRE_ALL_Disk_list

echo "--------------------------------------------$white$greenbg ASM DISKS $normal-----------------------------------------------------------------------------------------" >>/tmp/PRE_ASM_HEAD_Disk_list
echo "\tDISK\t\tDISK TYPE\t\tPVID\t\tDG NAME\t\tRESERVE POLICY\tOWNERSHIP(RAW_DEVICE)\tERROR" >>/tmp/PRE_ASM_HEAD_Disk_list
echo "----------------------------------------------------------------------------------------------------------------------------------------------" >>/tmp/PRE_ASM_HEAD_Disk_list

echo "--------------------------------------------$white$greenbg NON ASM DISKS $normal--------------------------------------------------------------------------------------" >>/tmp/PRE_NONASM_HEAD_Disk_list
echo "\tDISK\t\tDISK TYPE\t\tPVID\t\tVG NAME\t\tRESERVE POLICY\tOWNERSHIP(RAW_DEVICE)\tERROR" >>/tmp/PRE_NONASM_HEAD_Disk_list
echo "-----------------------------------------------------------------------------------------------------------------------------------------------" >>/tmp/PRE_NONASM_HEAD_Disk_list

for i in `cat /tmp/PRE_ALL_Disk_list`
do
#Progress bar while collecting data
  let count+=1
if (( DERR == 0 )) ; then colourdot=$greenbg
else colourdot=$redbg
fi
  printf $white$colourdot"*"$normal
  if (( count % 10 == 0 )) ; then
    (( count % 50 == 0 )) && print $count || printf $((count % 100))
  fi
  #END progress bar code

DERR=0
PVIDERR=0
disktyp=NULL
DG_INFO=NONE
ERR_OR=`echo $white$green"NO_ERROR"$normal`
vginfo=`cat /tmp/ls_pvinfo | grep "$i "|awk {'print $3'}`
if [[ $vginfo == None ]]
then
if ls -l /dev/r$i | egrep "oracle|oinstall|dba" >/dev/null
then
disktyp=ASM
else
if lquerypv -h /dev/$i |grep ORCLDISK >/dev/null  >/dev/null
then
disktyp=ASM
fi
fi
fi
is_disk=`cat /tmp/ls_pvinfo | grep -i "$i" | wc -l `
if [[ $is_disk != 0 ]]
then
#################ASM 
if [[ $disktyp = ASM ]]
then
pvinfo=`cat /tmp/ls_pvinfo |grep "$i "|awk {'print $2'}`
	if [[ $pvinfo != none ]]
	then
	echo "PVID should not be assigned to ASM disk " $i >> /tmp/PRE_ASM_PVIDERR
	PVIDERR=1
	DERR=1
	ERR_OR=`echo $white$red"PVID"$normal`
	ASMERROR=1
	fi

policyinfo=`lsattr -El "$i"|grep reserve_policy|awk {'print $2'}`
DG_INFO=`lquerypv -h /dev/$i | grep -i 00000040 | sed -e 's/\|//g' | sed 's/.*\(........\)/\1/'`
DG_INFO=$DG_INFO`lquerypv -h /dev/$i | grep -i 00000050 | awk '{print $6$7}' | sed -e 's/\.//g' | sed -e 's/\|//g'`
DG_CHECK=`lquerypv -h /dev/$i | grep DG | tail -1 | awk '{print $6$7}'  | sed -e 's/\.//g' | sed -e 's/\|//g'|wc -l`
DG_CHECK=`lquerypv -h /dev/$i | grep DG | tail -1 | awk '{print $6$7}' | sed -e 's/\.//g' | sed -e 's/\|//g'|wc -l`
	if [[ $DG_CHECK -eq 0 ]]
	then
	DG_INFO=none
	fi	

OWNERSHIP=`ls -l /dev/r$i | awk '{print $3,$4}'`
	if ! ls -l /dev/r$i | egrep "oracle|oinstall|dba" >/dev/null
	then
echo $DG_INFO > /tmp/DG_CHECKING
ISGRID=`cat /tmp/DG_CHECKING | grep -i grid | wc -l`
if [[ $ISGRID -eq 0 ]]
then
	DERR=1
	echo $i "ASM DISK OWNERSHIP SHOULD BE oracle:dba OR root:oinstall OR oracle:oinstall " 
		if [[ $PVIDERR = 1 ]]
		then
		ERR_OR=`echo $white$red"PVID",$OWNERSHIP$normal`
		ASMERROR=1
		else
		ERR_OR=`echo $white$red$OWNERSHIP$normal`
		ASMERROR=1
		fi
	fi
fi
printf "%20s %10s %20s %20s %15s %15s %15s %10s\n" $i $disktyp $pvinfo $DG_INFO $policyinfo $OWNERSHIP $ERR_OR>> /tmp/PRE_ASM_Disk_list
else
##############NON_ASM
disktyp=NON-ASM
pvinfo=`cat /tmp/ls_pvinfo |grep "$i "|awk {'print $2'}`
vginfo=`cat /tmp/ls_pvinfo | grep "$i "|awk {'print $3'}`
policyinfo=`lsattr -El "$i"|grep reserve_policy|awk {'print $2'}`
OWNERSHIP=`ls -l /dev/r$i | awk '{print $3,$4}'`
if [[ $vginfo != None ]]
then
if ls -l /dev/r$i | egrep "oracle|oinstall|dba" >/dev/null
then
ERR_OR=$OWNERSHIP
ASMERROR=1
echo $i "Disk belongs to $vginfo But it's Raw disk having  oracle:dba OR root:oinstall ownership please check with DBA"
fi
fi
printf "%20s %10s %20s %20s %15s %15s %10s %20s\n" $i $disktyp $pvinfo $vginfo $policyinfo $OWNERSHIP $ERR_OR>> /tmp/PRE_NONASM_Disk_list
fi
fi
done

cat /tmp/PRE_ASM_HEAD_Disk_list /tmp/PRE_ASM_Disk_list >> "$TMPLOGFILE"
cat /tmp/PRE_NONASM_HEAD_Disk_list /tmp/PRE_NONASM_Disk_list >> "$TMPLOGFILE"


if [ $ASMERROR = 1 ]
then
printf "%20s %30s %30s %20s \n" $a $b  $white$red "ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  "***ISSUE FOUND***"  >> "$MAILREPORT"
else 
printf "%20s %30s %30s %20s \n" $a $b  $white$green "NO ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  "NO ISSUE FOUND" >> "$MAILREPORT"
fi

###########Cleanup
rm -rf /tmp/PRE_ALL_Disk_list
rm -rf /tmp/PRE_ASM_HEAD_Disk_list
rm -rf /tmp/PRE_ASM_Disk_list
rm -rf /tmp/PRE_NONASM_HEAD_Disk_list
rm -rf /tmp/PRE_NONASM_Disk_list
rm -rf /tmp/PRE_ASM_PVIDERR
rm -rf /tmp/PRE_ASM_OWNERERR
rm -rf  /tmp/PRE_DISK_CHECK
#############################################end of ASM Check



######################################EMC MAPPING or Renaming validation
echo "\n"
a=41
b='EMC_DISK_NAME'
EMCDERROR=0
echo "$a -EMC DISK MAPPING and Naming validation ... "
echo "+++++++++++++++++++++++++++++ $white$greenbg EMC DISK MAPPING and Naming validation $normal +++++++++++++++++++++++++++++"  >> "$TMPLOGFILE"
echo "\n"
emcpadm check_mappings -v -x -f $OLDDIR/emcpadm_export_list >/tmp/PRE_EMSMAPPING_LIST
echo "result stored in /tmp/PRE_EMSMAPPING_LIST  " >> "$TMPLOGFILE"

NAME_CHANGE=`cat /tmp/PRE_EMSMAPPING_LIST | grep -i remaps: | wc -l`
if [ $NAME_CHANGE != 0 ]
then
EMCDERROR=1
echo $white $red "EMC DISK NAME FOUND TO BE CHANGED AFTER REBOOT BY COMPARING THE PRE_REBOOT DATA IN $OLDDIR/emcpadm_export_list " $normal >> "$TMPLOGFILE"
echo $white $red "Use emcpadm import_mappings command to correct the error" $normal >> "$TMPLOGFILE"
echo $white $redbg "Check the Validation result in /tmp/PRE_EMSMAPPING_LIST "$normal >> "$TMPLOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  $white$red "ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  "***ISSUE FOUND***" >> "$MAILREPORT"
else
echo $white $green "EMC DISK NAMES ARE FOUND TO BE SAME BEFORE AND AFTER REBOOT BY COMPARING THE PRE_REBOOT DATA IN $OLDDIR/emcpadm_export_list " $normal >> "$TMPLOGFILE"
echo $white $greenbg "Check the Validation result in /tmp/PRE_EMSMAPPING_LIST "$normal >> "$TMPLOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  $white$green "NO ISSUE FOUND" $normal >> "$LOGFILE"
printf "%20s %30s %30s %20s \n" $a $b  "NO ISSUE FOUND" >> "$MAILREPORT"
fi

#########################################################

echo "\n Check the Log in $LOGFILE" >> "$MAILREPORT"

cat $TMPLOGFILE >> $LOGFILE

echo "\n" >> $LOGFILE

echo "\n Check the Log in $LOGFILE"



echo "\n"

########################MAIL
DATE=`date "+%Y-%m-%d"`

HOSTNAME=`uname -n`

export MAILTO="kp_unix_sr@wwpdl.vnet.ibm.com"

export FROM=$HOSTNAME"@kp.com"

export CONTENT="/tmp/CheckInOut.txt"

export SUBJECT="CheckIN CheckOut validation report- ${DATE} for server $HOSTNAME"

(

echo "Subject: $SUBJECT"

echo "MIME-Version: 1.0"

#echo "Content-Type: text/html"

#echo "Content-Disposition: inline"

cat $CONTENT

) | /usr/sbin/sendmail -f $FROM $MAILTO





