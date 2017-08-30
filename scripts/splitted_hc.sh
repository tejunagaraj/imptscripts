
lspv > /tmp/ls_pvinfo

if ! ls /tmp/HC >/dev/null
then
mkdir /tmp/HC
else
rm -rf /tmp/HC/*
fi
#################################################################NTP Status test#########
NTP_STAT=`lssrc -s xntpd | awk '{print $4}' | grep -v Status`
NTP_SYNC=`ntpq -c pe | grep -i "*" | awk '{print $2}'`
NTP_SYNC_count=`ntpq -c pe | grep -i "*" | awk '{print $2}'|wc -l`
NTP_SYNC_STAT=`ntpq -c as | grep -i sys.peer | awk '{print $8}'`

####
echo " Current TimeZone is $TZ "

#############
if [ "$NTP_STAT" = "active" ]; then 
echo " xntpd status is $NTP_STAT"
else 
echo "NTP service is not active" >> /tmp/HC/ntp_status
fi
####

if [ "$NTP_SYNC_count" -ge 1 ]; then 
echo "NTP MASTER is $NTP_SYNC "
else 
echo "NTP Not synchronized with NTP master server" >> /tmp/HC/ntp_status
fi

####
if [ "$NTP_SYNC_STAT" = "reachable" ]; then 
echo "NTP MASTER server is $NTP_SYNC_STAT"
else 
echo " NTP master server Not Reachable " >> /tmp/HC/ntp_status
fi

#############################################
STRATUM=`lssrc -ls xntpd |grep -i 'Sys stratum:' | awk '{print $3}'`
if [ "$STRATUM" -le 4 ]; then
echo "NTP Sys stratum is $STRATUM"
else 
echo " NTP Sys stratum value should be less than 5 " >> /tmp/HC/ntp_status
fi

##############################################################################################################END OF NTP


##################Rootvg information##################################################

>/tmp/rootdisk_path
BOOT_ORD=`bootlist -m normal -o | awk '{print $1}'`
BOOT_ORD_COUNT=`bootlist -m normal -o | grep -i blv |wc -l`
for i in `lsvg -p rootvg | egrep -v "rootvg:|PV_NAME" | awk '{print $1}'`
do
lspath -l $i >> /tmp/rootdisk_path
done 
ROOTVG_DISK_COUNT=`lslv hd4 | grep -i COPIES: | awk '{print $2}'`


if [ $BOOT_ORD_COUNT -ge $ROOTVG_DISK_COUNT ]; then 
echo "Boot order is $BOOT_ORD"
else 
echo "Boot disks are  $BOOT_ORD, Bootlist not properly set " >> /tmp/HC/Rootvg_info 
fi

#####
CURR=`bootinfo -b`
CURR_COUNT=`bootinfo -b | wc -l`
LOCATION_CODE=`lscfg -l $CURR | awk '{print $1 , $2 }'`
if [ "$CURR_COUNT" -eq 1 ]; then 
echo "List the current Bootdisk along with physical location code is $LOCATION_CODE"
else 
echo " No Physical location found for Bootlist " >> /tmp/HC/Rootvg_info
fi


##########################Rootvg Mirror
ROOTVG_DISK_COUNT=`lsvg -p rootvg | egrep -v "rootvg:|PV_NAME" | wc -l`
LV_COPIES=`lslv hd4 | grep -i COPIES: | awk '{print $2}'`

if [[ $LV_COPIES -gt 1 ]]

    then

        #checking if rootvg is mirrored

        VGMIRRO=$(lsvg -l rootvg | egrep -v "sysdump|:|TYPE" | awk '{ print $4/$3 }' | grep -v 2 | grep -v 3 | wc -l | awk '{ print $1 }')

        if [[ $VGMIRRO -eq 0 ]]

        then

            echo  " Rootvg is properly mirrored "

        else

            echo " Rootvg is not properly mirrored  " >> /tmp/HC/Rootvg_info
        fi
else 
echo "Rootvg is not Mirrored " >> /tmp/HC/Rootvg_info
fi

##########################Rootvg stale pps

ROOTVG_STALE_COUNT=`lsvg rootvg | grep -i "STALE PPs:" | awk '{print $6}'`


        if [[ $ROOTVG_STALE_COUNT -eq 0 ]]

        then

            echo "Rootvg has no stale "

        else

           echo " $ROOTVG_STALE_COUNT PP's are in stale state " >> /tmp/HC/Rootvg_info

        fi

###################################################################END OF ROOTVG

#############################################################################Alt-disk
SERVER=`uname -n`
if cat /var/log/`uname -n`.osbackup.log | egrep "SUCCESS: ALT DISK APPEARS TO BE BOOTABLE ON">/dev/null
then
ALT_DISK_=`cat /var/log/$SERVER.osbackup.log | egrep "SUCCESS: ALT DISK APPEARS TO BE BOOTABLE ON" | awk '{print $10,$11,$12,$13,$14,$15}'`
echo "ALT DISK APPEARS TO BE BOOTABLE ON $ALT_DISK_"
for i in $ALT_DISK_
do 
echo " Physical Location `lscfg -l $i | awk '{print $1 , $2 }'` "
done
else 
echo " Error with ALT image  " > /tmp/HC/alt_info
fi
###########################################################END OF ALT 


###############################sysdump
#echo "<tr><td class="h1">SYSTEM DUMP</td></tr>"
if [ `lslv hd4 | grep -i COPIES | awk '{print $2}'` -ge 2 ]
then 
MSTATUS=YES
else
MSTATUS=NO
fi
#echo $MSTATUS


PSTATUS=`sysdumpdev -l | grep -i primary | awk '{print $2}' | cut -f "3" -d / `
#echo $PSTATUS

#secondary 

SSTATUS=`sysdumpdev -l | grep -i secondary | awk '{print $2}' | cut -f "3" -d / `
#echo $SSTATUS


PDISK=`lslv -m $PSTATUS | tail -1 | awk '{print $3}'`

SDISK=`lslv -m $SSTATUS | tail -1 | awk '{print $3}'`


V_Stat=`lsdev -Cc disk -l $PDISK |awk '{print $3}'`
if [ "${V_Stat}" = Virtual ]
then 
ISVIRTUAL='YES'
else
ISVIRTUAL='NO'
fi

#echo $PDISK
#echo $SDISK
if [ "${MSTATUS}" = YES ]
then 
if [ "${PDISK}" = "${SDISK}" ]
then 
echo " Primary and secondary dump devices should be on diffrent disk if rootvg is not a san boot " >> /tmp/HC/sysdump_info
else
echo "System dump devices are  $PSTATUS $SSTATUS "
fi
else
echo "Sysdump Devices are $PSTATUS $SSTATUS "
fi

if /usr/lib/ras/dumpcheck -p >/dev/null
then 
echo "Current Sysdump Device size is more then Estimated dump size"
else 
echo "Current Sysdump Device size is less then Estimated dump size `sysdumpdev -e | awk '{print $7}'` Bytes " >> /tmp/HC/sysdump_info
fi


########################################################################END OF SYSDUMP


######################################################################################################################SWAP SAPCE INFORMATION####################

######
## DEFINE VARIABLES NEEDED TO DETERMINE IF THIS IS AN ORACLE SERVER
setvariables_Routine () {
                grephost=$(uname -n)
                greppmon=$(ps -ef | grep -v grep | grep -ic pmon)
                grepnode=$(cat /usr/tivoli/tsm/client/ba/bin64/dsmsched.log | grep -i "Node Name" |grep -ci DB)
                getoratab=$(cat /etc/oratab |  awk '{print $1}' | grep -v "#" | grep -v '^$'| wc -l)
                getswap=$(lsps -s | grep -v Total |awk -FMB '{ print $1 }')
                getmemory=$(prtconf | grep "Memory Size" |grep -v Good  | awk '{print $3}')
                DATE=`date '+%m-%d-%Y %H:%M'`
}
##
######

######
## Start App Type Check Routine
apptype_Routine () {

#  FIND OUT IF THIS IS AN ORACLE SERVER BY LOOKING FOR PMON RUNNING, THEN PRESENCE OF ORATAB, THEN 
#  If count of pmon procs is not zero, then App is Oracle
#  If nodename does contain DB, then App is Oracle.  Could also be another DB, like SYbase
#  If /etc/oratab exists, then App is Oracle
#  Otherwise, Generic.  We can add checks for WehSphere here.

        if [[ "$greppmon" != "0" ]]; then
                APP=ORACLE
        elif [[ "$grepnode" != "0" ]]; then
                APP=ORACLE
        elif [[ "$getoratab" -gt "1" ]]; then
                APP=ORACLE
        else
                APP=GENERIC
        fi

        
        SWAP="$getswap"
        MEMORY="$getmemory"
        
}
## End App Type Check Routine
######

######
## Start Convert Sizes to GB Routine
convert2gb_Routine () {

        swap2GB=$(echo "$SWAP / 1024"|bc)
        mem2GB=$(echo "$MEMORY / 1024"|bc)
        memx2=$(echo "$MEMORY * 2"|bc)
        #SWAP=$swap2GB
        #MEM=$mem2GB
        #echo Swap is  "$swap2GB" and Mem "$mem2GB"
}
######
## End Convert Sizes to GB Routine

######
## Start Define Desired Generic AIX Swap Routine
defineaixswap_Routine () {

#  Generic AIX Swap Standards
#  If memory = 1-4 GB, then swap = Memory x 1.5
#  If memory = 5-8 GB, then swap = Memory x 1
#  If memory = 9+ GB, then swap = Memory x .5
#  http://unix.kp.org/cgi-bin/view/Public/AIXRefAIXSizingStandards

       if [[ "$APP" = "GENERIC" ]];then
                if [[ "$mem2GB" -lt "5" ]]; then
                        DESIREDSWAP=$(echo "$mem2GB * 1.5"|bc)
                elif [[ "$mem2GB" -gt "4" && "$mem2GB" -lt "17" ]]; then
                        DESIREDSWAP=$(echo "$mem2GB * 1"|bc)
                elif [[ "$mem2GB" -gt "17" ]]; then
                        DESIREDSWAP=16
                fi
                DESIREDSWAPVAL=`echo "$DESIREDSWAP" |awk -F. '{ print $1 }'`
                echo Desired Swap is "$DESIREDSWAPVAL"
        fi

#  Oracle Swap Standards
# If memory = 1-8 GB, then swap = Memory * 2
# If memory = 8=31 GB, then swap = Memory * 1.5
# If memory = 32+, GB, then swap = not less than 32 GB

        if [[ "$APP" = "ORACLE" ]];then
                if [[ "$mem2GB" -lt "9" ]]; then 
                        DESIREDSWAP=$(echo "$mem2GB * 2"|bc)
                elif [[ "$mem2GB" -gt "9" && "$mem2GB" -lt "22" ]]; then
                        DESIREDSWAP=$(echo "$mem2GB * 1.5"|bc)
                elif [[ "$mem2GB" -gt "31" ]]; then
                        DESIREDSWAP=32
                fi
                DESIREDSWAPVAL=`echo "$DESIREDSWAP" |awk -F. '{ print $1 }'`
                #echo Desired Swap is "$DESIREDSWAPVAL"
        fi
}

## End Define Desired AIX Swap Routine
######


######
##  Start Desired Swap Check Routine

chkdesiredswap_Routine () {
#Next need to check if Swap is correct size, and alert if less than

        if [[ "$APP" = "GENERIC" ]];then
                if [[ "$swap2GB" -lt "$DESIREDSWAPVAL" ]]; then
                        
			echo "Swap space is $swap2GB GB  which is less than Required Swap of $DESIREDSWAPVAL GB" >> /tmp/HC/Swap_info
                        
                elif [[ "$swap2GB" = "8" || "$swap2GB" -gt "8" ]];then
                        echo "Swap space is $swap2GB GB which exceeds Required Swap of $DESIREDSWAPVAL GB "

                elif [[ "$swap2GB" = "$DESIREDSWAPVAL" || "$swap2GB" -gt "$DESIREDSWAPVAL" ]];then
                        echo "Swap space is $swap2GB GB matches Required Swap of $DESIREDSWAPVAL GB "
                fi
        fi

        if [[ "$APP" = "ORACLE" ]];then
                if [[ "$swap2GB" -lt "$DESIREDSWAPVAL" ]]; then
                        echo "Swap space is $swap2GB GB  which is less than Required Swap of $DESIREDSWAPVAL GB" >> /tmp/HC/Swap_info                       
                elif [[ "$swap2GB" = "32" || "$swap2GB" -gt "32" ]];then
                        echo "Swap space is $swap2GB GB which  exceeds Required Swap of $DESIREDSWAPVAL GB "
                elif [[ "$swap2GB" = "$DESIREDSWAPVAL" || "$swap2GB" -gt "$DESIREDSWAPVAL" ]];then
                       echo "Swap space is $swap2GB GB which matches Required Swap of $DESIREDSWAPVAL GB "
                fi
        fi
}

#Current Utilization
CURR_UTIL_SWAP=`lsps -s | grep -v Total |awk '{ print $2}' | cut -d % -f 1`
if [[ $CURR_UTIL_SWAP -ge 80 ]]
then
echo "<tr><td>Current Utilization </td><td> $CURR_UTIL_SWAP </td><td class="fail">Failed</td><td>Swap Utilization is above threshold level  </td><td> Inform APP/DB team to reduce the Utilization</td></tr>"
echo "Swap Utilization is  $CURR_UTIL_SWAP which is  above threshold level of 80% " >> /tmp/HC/Swap_info
else
echo "$CURR_UTIL_SWAP Swap Utilization is under threshold level </td><td>NIL</td></tr>"
fi

                setvariables_Routine
                apptype_Routine
                convert2gb_Routine
                defineaixswap_Routine
                chkdesiredswap_Routine

#######################################################################END OF SWAP

#####################################################DISK_CHECK_ASM###################################



DISK_CHECK () 
{
>/tmp/PRE_ALL_Disk_list
>/tmp/PRE_ASM_Disk_list
>/tmp/PRE_NONASM_Disk_list
>/tmp/PRE_NONASM_OWNERERR
>/tmp/PRE_ASM_PVIDERR
>/tmp/PRE_ASM_OWNERERR
lspv > /tmp/ls_pvinfo
lsdev -Cc disk|grep -v PowerPath |grep -v EMC | awk '{print $1}' > /tmp/Disk_list
emcpadm getusedpseudos | grep -v pseudo | grep -v Major | grep -Ev "^$" | awk '{print $1}' >> /tmp/Disk_list

for i in `cat /tmp/Disk_list`
do
disktyp=NULL
ERR_OR=
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
#################ASM 
if [[ $disktyp = ASM ]]
then

#lspv > /tmp/ls_pvinfo
pvinfo=`cat /tmp/ls_pvinfo |grep "$i "|awk {'print $2'}`
if [[ $pvinfo != none ]]
then
echo "PVID should not be assigned to ASM disk " $i >> /tmp/PRE_ASM_PVIDERR
ERR_OR=PVID
fi

policyinfo=`lsattr -El "$i"|grep reserve_policy|awk {'print $2'}`
DG_INFO=`lquerypv -h /dev/$i | grep -i 00000040 | sed -e 's/\|//g' | sed 's/.*\(........\)/\1/'`
DG_INFO=$DG_INFO`lquerypv -h /dev/$i | grep -i 00000050 | awk '{print $6$7}' | sed -e 's/\.//g' | sed -e 's/\|//g'`
DG_CHECK=`lquerypv -h /dev/$i | grep DG | tail -1 | awk '{print $6$7}'  | sed -e 's/\.//g' | sed -e 's/\|//g'|wc -l`
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
echo $i "ASM DISK OWNERSHIP SHOULD BE oracle:dba OR root:oinstall " >> /tmp/PRE_ASM_OWNERERR
ERR_OR=$ERR_OR,$OWNERSHIP
fi
fi
printf "%20s %10s %20s %20s %15s %15s %10s %10s %10s %10s \n" $i $disktyp $pvinfo $DG_INFO $policyinfo r$i $OWNERSHIP $ERR_OR>> /tmp/PRE_ASM_Disk_list
else
##############NON_ASM
disktyp=NON-ASM

pvinfo=`cat /tmp/ls_pvinfo |grep "$i "|awk {'print $2'}`
vginfo=`cat /tmp/ls_pvinfo | grep "$i "|awk {'print $3'}`
OWNERSHIP=`ls -l /dev/r$i | awk '{print $3,$4}'`
if [[ $vginfo != None ]]
then
if ls -l /dev/r$i | egrep "oracle|oinstall|dba" >/dev/null
then

ERR_OR=$OWNERSHIP
echo $i "Disk belongs to $vginfo But it Raw disk having  oracle:dba OR root:oinstall ownership please check with DBA" >> /tmp/PRE_NONASM_OWNERERR
fi
fi

policyinfo=`lsattr -El "$i"|grep reserve_policy|awk {'print $2'}`
printf "%20s %10s %20s %20s %15s %15s %10s %10s %10s %10s \n" $i $disktyp $pvinfo $vginfo $policyinfo r$i $OWNERSHIP $ERR_OR>> /tmp/PRE_NONASM_Disk_list
fi
done

cat  /tmp/PRE_ASM_Disk_list
cat  /tmp/PRE_NONASM_Disk_list

}
> /tmp/PRE_DISK_CHECK
DISK_CHECK >> /tmp/PRE_DISK_CHECK

###########ASM 
echo "<tr><td>ASM disks </td><td> `cat /tmp/PRE_ASM_Disk_list | wc -l ` </td></tr>"
ASM_ERR=`cat /tmp/PRE_ASM_PVIDERR /tmp/PRE_ASM_OWNERERR | wc -l`
if [ $ASM_ERR -eq 0 ]; then 
echo "No PVID and ownership issue found for ASM disks "
else
echo "PVID should not be assigned for ASM disk and OWNERSHIP should be oracle:dba OR root:oinstall " >> /tmp/HC/Disk_ASM_ERROR
cat /tmp/PRE_ASM_PVIDERR /tmp/PRE_ASM_OWNERERR >> /tmp/HC/Disk_ASM_ERROR
fi
###########NON ASM
echo "<tr><td>NON-ASM disks </td><td> `cat /tmp/PRE_NONASM_Disk_list | wc -l ` </td></tr>"
NONASM_ERR=`cat /tmp/PRE_NONASM_OWNERERR | wc -l`
if [ $NONASM_ERR -eq 0 ]; then 
echo "<tr><td>List the NON-ASM disk  </td><td><a href="#nonasmdisk">List of NON-ASM disk  </a></td><td class="pass">passed</td></tr>"
else
echo "If A disk belongs to VG then its ownership has to be root:system" >> /tmp/HC/Disk_ASM_ERROR
cat  /tmp/PRE_NONASM_OWNERERR >> /tmp/HC/Disk_NONASM_ERROR
fi

#####################################################################################End of ASM CHECK#############

#########################################################LVM Configuration#################################################

######################LSPV


LSPVFAIL=`lsdev -Cc disk -S d | wc -l`
if [ $LSPVFAIL -eq 0 ]; then 
echo "<No PVs in Defined state"
else
echo "There should not be any PV in Defined state ,check the reason and fix the Define PV" >> /tmp/HC/LVM_Disk_info
fi

######################Lspath
LSFAIL=`lspath | egrep "Failed|Missing" |grep -v ses| wc -l`
if [ $LSFAIL -eq 0 ]; then 
echo "<tr><td>List the  disk paths </td><td><a href="#lspath">Active paths </a></td><td class="pass">passed</td><td>List the Multiple paths for the disks </td><td>NIL</td></tr>"
else
echo "fix the missing or failed paths on the server" >> /tmp/HC/LVM_lspath_info
lspath | egrep "Failed|Missing"|grep -v ses >> /tmp/HC/LVM_lspath_info
fi
########################FIlesystem#######

if ! ls /tmp/fscheck/log/ >/dev/null
then
mkdir /tmp/fscheck
mkdir /tmp/fscheck/log/
fi

>/tmp/fscheck/log/after_result

fscheck_mount ()
{

lsfs | awk '{print $3}' | grep -v Mount > /tmp/fscheck/log/fs_list
cllsfs | awk '{print $2}'> /tmp/fscheck/log/cluster_fs_list
grep -Fvxf /tmp/fscheck/log/cluster_fs_list /tmp/fscheck/log/fs_list > /tmp/fscheck/log/noncluster_fs

lsvg >/tmp/fscheck/log/vg_list
cllsvg | awk '{print $2}' > /tmp/fscheck/log/cluster_vg_list
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

fscheck=`cat /tmp/fscheck/log/after_result | wc -l`


if [ "$fscheck" = 0 ]; then 
echo "Mounted Filesystems and Active VG with automount state check "
else 
echo "there is diffrence between /etc/filesystems entry and actually mounted filesystems" >> /tmp/HC/fs_info
cat /tmp/fscheck/log/after_result >> /tmp/HC/fs_info
fi



########NFS
NFSFILE=`lsfs | grep -i nfs | grep -v cdrfs   | wc -l`
MNFS=`mount | grep -i nfs | grep -v cdrfs | grep -v swmount | wc -l`

if [ "$NFSFILE" = "$MNFS" ]; then 
echo "Mounted NFS Filesystems have entry in /etc/filesystems"
else 
echo "there is diffrence between /etc/filesystems entry and actually mounted NFS filesystems" >> /tmp/HC/nfs_info
fi
######################################FS High utilization
> /tmp/fshighoutput
#df -g | grep -v Filesystem| grep -v ':/'  | awk '{print$7}' |grep -v /proc > /tmp/dfout
lsvg -l rootvg | grep -v "N/A" | grep -v "MOUNT" | grep -v "rootvg:" | awk '{print $7}' | grep -v /proc > /tmp/dfout



hcount=0

for i in `cat /tmp/dfout`

do

UTI=`df -g $i | grep -v Filesystem | grep -v ':/'  | awk '{print $4}' | cut -f "1" -d %`

if [ $UTI -ge 85 ]

then

hcount=`expr $hcount + 1`

FS=`df -g $i | grep -v Filesystem | grep -v ':/'  | awk '{print$7}'`

USED=`df -g $i | grep -v Filesystem | grep -v ':/'  | awk '{print$4}'`
echo $FS $USED >> /tmp/fshighoutput 

fi

done

if [ $hcount = 0 ]; then 
echo "All Filesystems are below 85% Utilization"
else 
echo "Reduce the filesystem Utilization below 85%" >> /tmp/HC/fs_Utilization_info
cat /tmp/fshighoutput >> /tmp/HC/fs_Utilization_info
fi
###################################################################################end fo FIlesystem
#############################################################################Network details##############
>/tmp/ifcon1_out
NIB=0
LACP=0
ETHERERR=0
>/tmp/etherr
>/tmp/NIB
>/tmp/LACP

for i in `lsdev -Cc adapter|grep EtherChannel |awk '{print $1}'`
do 
adapter_names=`lsattr -El $i -a adapter_names -F value`
backup_adapter=`lsattr -El $i -a backup_adapter -F value`
mode=`lsattr -El $i -a mode -F value`
hash_mode=`lsattr -El $i -a hash_mode -F value`

NIB=0
LACP=0

if [ $backup_adapter != NONE ]
then
echo $i >> /tmp/NIB
NIB=1 
fi

if [ $backup_adapter = NONE ]
then
if [ $mode = 8023ad ]  
then
if [ $hash_mode = src_dst_port ]  
then
echo $i >> /tmp/LACP
LACP=1
fi 
fi
fi

if [ $NIB = $LACP ]
then
echo $i >> /tmp/etherr  
ETHERERR=1
fi
done



if [ $ETHERERR -eq 0 ]
then 
echo "No Issue with ether channel"

else
echo "Ether channel not configured Properly check the switch port setting" >> /tmp/HC/etherchannel_info
cat /tmp/etherr >> /tmp/HC/etherchannel_info
fi 
rm -f /tmp/NIB
rm -f /tmp/LACP
rm -f /tmp/etherr

################################################################################################################

#############################IP and interface link status
ifconfig -a | grep -v lo0 | grep -i SIMPLEX | awk '{print $1}' > /tmp/ifcon_out

encount=0

for i in `cat /tmp/ifcon_out`

do

ISTAT=`ifconfig -a | grep -i $i | grep -v lo0 | grep -i SIMPLEX | awk '{print $2}'| cut -f 2 -d ,| cut -f 2 -d "<"`

if [ "$ISTAT" != "UP" ]

then

encount=`expr $encount + 1`

echo $i >> /tmp/ifcon1_out

fi

done


if [ $encount -eq 0 ]; then 
echo "All interfaces are in UP state"
else 
echo "Listed interface link status is in down state " >> /tmp/HC/ent_link_info
cat /tmp/ifcon1_out >> /tmp/HC/ent_link_info
fi
 
rm -f /tmp/ifcon_out 

###############Netstat -rn Routing

DEFAULT=`netstat -rn | grep default | awk '{print $2}' | wc -l `

    if [[ $DEFAULT -gt 1 ]]

    then
    echo "Route Table should countain only one default gateway IP " >> /tmp/HC/routing_info
     else
     echo "Route Table  countain only one default gateway IP "

     fi
HOSTSUBNET=`nslookup $SERVER|grep Address |awk '{ print $2 }' |sed -n 2p|cut -d '.' -f1,2,3 `

ROUTSUBNET=`netstat -rn |grep default|awk '{ print $2 }'|cut -d '.' -f1,2,3`

        if [[ "$HOSTSUBNET" != "$ROUTSUBNET" ]]; then

        echo "Check DNS configured for the server or check the the subnet of primary ip and Default gateway should be same else fix it " >> /tmp/HC/routing_info

        else

        echo "Subnet of $SERVER - $HOSTSUBNET matches subnet of Default route $ROUTSUBNET "
        fi


####################Adapters
DEF_ADAPTER=`lsdev -Cc adapter -S d | wc -l`
if [ $DEF_ADAPTER -eq 0 ]; then
echo "All Adapters are in Avilable state"
else
echo "All Adapters has to to be in Avilable state " >> /tmp/HC/fcs_ent_status_info
lsdev -Cc adapter -S d >> /tmp/HC/fcs_ent_status_info
fi
###################################################################END OF NETWORK
###########################################ERROR LOG
TODAY=`perl -MPOSIX -le 'print strftime( "%m%d0000%y" , localtime(time() ))'`
YESTERDAY=`perl -MPOSIX -le 'print strftime( "%m%d0000%y" , localtime(time() - 24 *60*60))'`
DAYBEFOREYES=`perl -MPOSIX -le 'print strftime( "%m%d0000%y" , localtime(time() - 48 *60*60))'`

ERRCOUNT=0
HWERRCOUNT=0
SOFTRCOUNT=0
UNDETERRCOUNT=0

HWERRCOUNT=`errpt -dH,U -T "PERM" -s $TODAY|wc -l`
HWERRCOUNT=$(($HWERRCOUNT+`errpt -dH,U -T "PERM" -s $YESTERDAY|wc -l`))
HWERRCOUNT=$(($HWERRCOUNT+`errpt -dH,U -T "PERM" -s $DAYBEFOREYES|wc -l`))

SOFTRCOUNT=`errpt -dS,U -T "PERM" -s $TODAY|wc -l`
SOFTRCOUNT=$(($SOFTRCOUNT+`errpt -dS,U -T "PERM" -s $YESTERDAY|wc -l`))
SOFTRCOUNT=$(($SOFTRCOUNT+`errpt -dS,U -T "PERM" -s $DAYBEFOREYES|wc -l`))

UNDETERRCOUNT=`errpt -dU,U -T "PERM" -s $TODAY|wc -l`
UNDETERRCOUNT=$(($UNDETERRCOUNT+`errpt -dU,U -T "PERM" -s $YESTERDAY|wc -l`))
UNDETERRCOUNT=$(($UNDETERRCOUNT+`errpt -dU,U -T "PERM" -s $DAYBEFOREYES|wc -l`))

ERRCOUNT=$(($HWERRCOUNT+$SOFTRCOUNT+$UNDETERRCOUNT))



if [ $ERRCOUNT -eq 0 ]; then
echo "NO Errors logged in past three days "
else
echo "Validate the errors logged in past 3 days and try to fix them up " >> /tmp/HC/past_3days_errpt
fi

###############################################################################################
#########################Cluster _ HACMP
lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte > /dev/null

    if [[ $? -eq 0 ]]

    then
        CLNOT=1

        CLVERSION=`lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte |  awk '{print $2}' | head -1`

        echo "Cluster Version $CLVERSION"

        CLSTATUS=`lssrc -ls clstrmgrES |  grep "Current state:" |  awk '{print $3}'`

        if [[ $CLSTATUS = "ST_STABLE" ]]

        then

            echo "Cluster status is ST_STABLE "
                              

else

echo "HACMP Cluster status is $CLSTATUS,cluster is not in stable state fix the issue " >> /tmp/HC/cluster_info

        fi

    else
echo "Not A HACMP cluster node "        

    fi

#########################################cl_verify
CURRENT_DATE=$(date +%b%-d)
SDATE=$(ls -al /var/hacmp/clverify/clverify.log |awk '{print $6$7}')
lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte > /dev/null
    if [[ $? -eq 0 ]];then
        if [ "$(/usr/es/sbin/cluster/utilities/clgetactivenodes -n $(hostname) | sort | head -1)" != "$SERVER" ];then
        ## Node is not a first node
               echo "Node is not a first node in the cluster "
	 	else
		if [ "$SDATE" == "$CURRENT_DATE" ];then
              		STATE=$(grep "Check:" /var/hacmp/clverify/clverify.log |sort |uniq)
				if [ "$STATE" == "Check: PASSED" ];then
					echo "Cluster verification succeed "
					else 
					echo " Cluster verification ran with the error on "$SERVER" server  " >> /tmp/HC/cluster_info
				fi
		else
		   	     echo " No Latest Cluster verification happened on server "$SERVER" ,The last verification happned on $SDATE " >> /tmp/HC/cluster_info
		fi
	fi	

    else       
	echo "Not A HACMP cluster node "
    fi
#########################################



#######################

#########################Cluster _ GPFS

lslpp -l | grep -i gpfs.base > /dev/null

    if [[ $? -eq 0 ]]

    then
        GPFSNOT=1

        GPFSVERSION=`lslpp -l | grep -i gpfs.base |  awk '{print $2}' | head -1`

        echo "Cluster Version $GPFSVERSION"

/usr/lpp/mmfs/bin/mmlscluster | grep -ip Daemon | awk '{print $2}' | grep -v Daemon | grep -Ev "^$" > /tmp/GPF_PRE_Nodes


#########STATUS CHECKING
/usr/lpp/mmfs/bin/mmgetstate -a | awk '{print $3}' | grep -v Node | grep -Ev "^$" > /tmp/GPF_PRE_STAT
STAT_ERR=0
for i in `cat /tmp/GPF_PRE_STAT`
do
if [[ $i != "active" ]] 
then
STAT_ERR=1
fi
done        

        if [[ $STAT_ERR = 0 ]]

        then

            echo "Cluster status is active in all node "
            
        else

echo "GPFS Cluster status is inactive in atleast one node" >> /tmp/HC/cluster_GPFS_info

        fi

    else
echo "Not A GPFS cluster node "

        

    fi

rm -f /tmp/pretmp
rm -f /tmp/GPF_PRE_Nodes
rm -f /tmp/GPF_PRE_STAT

##############################
###############Reserver lock check and create incident##########
>/var/log/reserve.log
> /tmp/HC/reserve_check.log
/usr/local/scripts/chk_rp.ksh -alert
cat /var/log/reserve.log |grep FAIL >> /tmp/HC/reserve_check.log
chmod 644 /tmp/HC/reserve_check.log
###############################################################











#########################################  VIO ##################
########################## IS VIO
/usr/ios/cli/ioscli ioslevel > /dev/null
if [ $? = 0 ]
then
echo "This is VIO server"
##################################################################
####################   SEA  #########################
######LIMBO
>/tmp/LIMBO
for i in `lsdev -Cc adapter |grep -i shared|awk '{print $1}'`
do
a=`entstat -d $i | grep -i State: | grep -v LAN | grep -v Actor | grep -v Partner | awk '{print $2}' `
if [ $a = LIMBO ]
then
echo $i >>/tmp/LIMBO
fi
done

######HA_MODE
>/tmp/HA_MODE
for i in `lsdev -Cc adapter |grep -i shared|awk '{print $1}'`
do
a=`entstat -d $i | egrep "High Availability Mode" | awk '{print $4}'`
if [ $a != Auto ]
then
echo $i >>/tmp/HA_MODE
fi
done

######SEA_LINK_STATUS
>/tmp/SEA_LINK_STATUS
for i in `lsdev -Cc adapter |grep -i shared|awk '{print $1}'`
do
a=`entstat -d $i |grep -i "Link Status" | awk '{print $4}'`
if [ $a != Up ]
then
echo $i >>/tmp/SEA_LINK_STATUS
fi
done

#################
SEA_ERROR_COUNT=`cat /tmp/LIMBO | wc -l`
SEA_ERROR_COUNT=$(($SEA_ERROR_COUNT+`cat /tmp/HA_MODE|wc -l`))
SEA_ERROR_COUNT=$(($SEA_ERROR_COUNT+`cat /tmp/SEA_LINK_STATUS | wc -l`))

if [ $SEA_ERROR_COUNT = 0 ]; then 
echo "<No error found in SEA (NO LIMBO, All SEA is set with AUTO failover,All SEA are online)"
else
echo "Check the SEA LINK STATUS and HA_MODE property" /tmp/HC/VIO_SEA_info
fi
##############################    NPIV
NPIV_ERROR_COUNT=`/usr/ios/cli/ioscli lsmap -all -npiv -fmt , | grep -v ", ," | grep -i NOT_LOGGED_IN | wc -l`
if [ $NPIV_ERROR_COUNT = 0 ]; then 
echo "No error found in NPIV configuration (ie all NPIV adapters are in LOGGED_IN  state)"
else
echo "Check the NPIV STATUS because few adapters found to be in NOT_LOGGED_IN state " >> /tmp/HC/VIO_NPIV_info
/usr/ios/cli/ioscli lsmap -all -npiv -fmt , | grep -v ", ," | grep -i NOT_LOGGED_IN >> /tmp/HC/VIO_NPIV_info
fi
######################   network adapter

ENT_ERROR_COUNT=`/usr/ios/cli/ioscli lsmap -all -net -fmt , | grep -v ", ," | grep -v Available | wc -l`
if [ $ENT_ERROR_COUNT = 0 ]; then 
echo "All Networ Adapters are in avilable state"
else
echo "Not All Adapters are in Avilable state" >> /tmp/HC/VIO_ent_info
fi




#############################  VSCSI

###################################################VIO Disk maping

Ext=$(date +%d%m%y%H%M)
SaveTo=/usr/local/scripts/`uname -n`_VSCSI_MAP.txt.${Ext}
SaveView='| tee -a $SaveTo'
Format='%-14s %-15s %-35s %-38s %-16s %-13s\n'
lsdev -Cc adapter -Fname:physloc | grep vhost | sed 's/:/  /g' | while read Vhost AdaptLoc Other
do
odmget -q parent=$Vhost CuDv | grep name | sed 's/"//g' | awk '{print $NF}' | while read vtdev
  do
   LUNID=$(odmget -q "name=$vtdev AND attribute=udid_info" CuAt | grep value | sed 's/"//g' | awk '{print $NF}' )
   LUNID1=$(echo $LUNID | sed 's/S.*p//g')
   PDisk=$(odmget -q "name=$vtdev AND attribute=aix_tdev" CuAt | grep value | sed 's/"//g' | awk '{print $NF}')
   if [[ -x /usr/sbin/powermt ]]; then
     ARRAY=$(powermt display dev=$PDisk | grep 'Symmetrix' | sed 's/=/   /g' | awk '{print $NF}')
   fi
   Vadapter=$(odmget -q "name="$Vhost"" CuVPD | grep -w vpd |  sed 's/\"//g; s/*//g' | cut -d"-" -f2-3 )
   printf "$Format" $vtdev  $Vhost  $AdaptLoc  $LUNID  `uname -n` $PDisk >>${SaveTo}
     done
done

##############################

VSCSI_ERROR_COUNT=`/usr/ios/cli/ioscli lsmap -all -field SVSA VTD Status Backing -fmt , | grep -i defined | wc -l`
if [ $VSCSI_ERROR_COUNT = 0 ]; then 
echo "Disk Mapping detail is stored under $SaveTo in the server "
else
echo "$VSCSI_ERROR_COUNT Mapped disk  are in Defined state" >> /tmp/HC/VIO_diskmapping_info
fi


#############
fi

############################## END OF VIO #########################


