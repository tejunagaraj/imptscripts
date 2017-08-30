#!/bin/ksh
 
####################################################################################################################
# Created By Ashokkumar P (UNIX) 										   #
# Version 1.0 													   #
# Collect all configuration data and will  be stored  data under /tmp/preckecks/precheck<current adate and time>   #
# This file will be used to validate after reboot of server and cill compare with the data collected after reboot #
# Version 1.1 (Ashok) 												   #
# Not more that 4 precheck data directories will we avilable on server						   #
# Version 1.2 (Ashok) 												   #
# Precheck data will be compresed and stored under /PRECHECK to aviod data loss after migration                    #
####################################################################################################################

HOSTNAME=`uname -n`
SAVEDATE=`date +%d%B%Y_%H%M%S`

##############################
##Cleaning Precheck old data #
##############################
### Cleaning Empty or valide directory
for i in `ls /tmp/precheck`
do
ISEMPTY=`ls -l /tmp/precheck/$i | wc -l`
if [ $ISEMPTY -le 30 ]
then
rm -rf $i
fi
done


##################################################################
# Cleaning directories if no of directories count is more than 4 #
##################################################################

COUNT=`ls -ltr /tmp/precheck | grep -i precheck | wc -l`
while [ $COUNT -gt 4 ]
do
OLD_DATA=`ls -ltr /tmp/precheck | grep -i precheck | head -1 | awk '{print $9}'`
FOLDER=`echo "/tmp/precheck/$OLD_DATA"`
echo $FOLDER
rm -rf $FOLDER
COUNT=`ls -ltr /tmp/precheck | grep -i precheck | wc -l`
done

##########################################

SAVEDIR="/tmp/precheck/prechecks.${SAVEDATE}"

#SAVETAR="prechecks.${HOSTNAME}.${SAVEDATE}.tar.Z"

echo "Started to gather prechecks info  on ${HOSTNAME}. If this hangs for any longer than 30 seconds,

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

        echo "........................ NO SDD/PCM Drivers Found"

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
	echo "........................ Not a HACMP Cluster Node "

fi





# Now tar up the contents of SAVEDIR and output to SAVEDIRKEEP

SAVEDIRKEEP="/PRECHECKS/"

rm -rf ${SAVEDIRKEEP}*.tar.Z

[ ! -d ${SAVEDIRKEEP} ] && mkdir -p ${SAVEDIRKEEP}

chmod 700 ${SAVEDIRKEEP}

SAVETAR="prechecks.${HOSTNAME}.${SAVEDATE}.tar.Z"

tar -cvf - ${SAVEDIR} 2>/dev/null | compress > ${SAVEDIRKEEP}${SAVETAR}

echo " \n "
echo "=============================================================================================="
echo "Compressed data has been stored under ${SAVEDIRKEEP} upload this file in Checkin task"
echo "=============================================================================================="

echo " \n "
echo "=============================================================================================="
echo "Compressed data has been stored under ${SAVEDIRKEEP} use this file if there is no data under /tmp after migration"
echo "=============================================================================================="
echo " \n "
echo "=============================================================================================="
echo "Completed Checkin data collection. Check the following for information:\n${SAVEDIR}"
echo "=============================================================================================="

##

#





