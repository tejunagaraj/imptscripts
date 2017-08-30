############################### Server Health check################"
###To perform server Health check"
### Created by DBQ SR UNIX IBM "
### Owner Ashokkumar P"
### Version 1.4"
### HC Template 7"
### Version 1.5 Mail alert added 
################################################"

>/tmp/IBMUNIXCC
>/tmp/IBMUNIXSR
>/tmp/ls_pvinfo
echo "1" >/tmp/HCSTATUS
lspv > /tmp/ls_pvinfo
CCINC=/tmp/IBMUNIXCC
SRWO=/tmp/IBMUNIXSR

USERID=`id | awk ' { print $1 }' | grep root`

if [ -z "$USERID" ]

then

   echo  "You must run this script as Root user\n"

   exit 1

fi

/usr/ios/cli/ioscli ioslevel > /dev/null
if [ $? = 0 ]
then
clear
echo "VIO Server"
fi

SERVER=`uname -n`
DATE=`date "+%d-%b-%Y-%H-%M"`
FILE_LO=`echo /tmp/$SERVER.precheck_validation.$DATE.html`
echo "                          Health check starts "
echo "*************************************************************************"
echo "Server               :"$SERVER
echo "Output file location :"$FILE_LO
echo "*************************************************************************"
 

html_header (){
echo "<Html>
<style>
table, th, td {
    border: 1px solid black;
    border-collapse: collapse;
}

td.fail {
   background-color: #ff5733;
}

td.pass {
    background-color: #4cff33;
}

td.warning {
    background-color: yellow;
}



td.h1 {
    background-color: #eef6ed;
}

td.h2 {
    background-color: #4dc3ff;
}

tr.h1 {
    background-color: #eef6ed;
}
</style>


<body>
<table>"
echo "<tr><td>1</td><td class="pass">(GO) NO Errors found please proceed with patching/change </td></tr>"
echo "<tr><td>2</td><td class="warning">(GO) To be fixed during patching/change</td></tr>"
echo "<tr><td>3</td><td class="fail">(NO GO) To be fixed during patching/change</td></tr>"
echo "<tr><td>4</td><td class="fail">(NO GO) To be fixed before patching/change</td></tr>"
echo "</table>"
echo "*********************************************************"
}

hc_satus () {
HCSTATUS=`cat /tmp/HCSTATUS`
echo "<table>"
case "$HCSTATUS" in
   "1") echo "<tr bgcolor=#00FFFF><td>Health Check status</td><td class=h1> $HCSTATUS </td></tr><tr><td class="pass"> GO </td><td> NO Errors found please proceed with patching/change</td></tr>" 
   ;;
   "2") echo "<tr bgcolor=#00FFFF><td>Health Check status</td><td class=h1> $HCSTATUS </td></tr><tr><td class="warning"> GO </td><td> But Errors has to be fixed during/post patching/change</td></tr>" 
   ;;
   "3") echo "<tr bgcolor=#00FFFF><td>Health Check status</td><td class=h1> $HCSTATUS </td></tr><tr><td class="fail"> NO GO </td><td> Errors has to be fixed during patching/change</td></tr>" 
   ;;
   "4") echo "<tr bgcolor=#00FFFF><td>Health Check status</td><td class=h1> $HCSTATUS </td></tr><tr><td class="fail"> NO GO </td><td> Errors has to be fixed before patching/change</td></tr>" 
   ;;
   "5") echo "<tr bgcolor=#00FFFF><td>Health Check status</td><td class=h1> 3,4 </td></tr><tr><td class="fail"> 3 : NO GO </td><td> Errors has to be fixed during patching/change</td></tr><tr><td class="fail"> 4 : NO GO </td><td> Errors has to be fixed before patching/change</td></tr>" 
   ;;
esac
echo "</table>"
}

precheck_validation () {
echo "<table style="width:100%" ><tr><td>Server Name</td><td>Date</td><td>Who performed the healthcheck</td> </tr>"
echo "<tr bgcolor="#00FFFF"><td>$SERVER</td><td>$DATE</td><td>$USER</td> </tr>"
echo "<tr class="h1"><td>Test</td><td>DATA</td><td>Passed/Failed</td><td>Description</td><td>Actionable</td><td>Remedy INC/WO </td><td>GO / NO GO Status</td></tr>"
echo "<tr><td>Server Uptime</td><td> `uptime` </td><td></td><td>It shows the uptime of the server</td><td>Nill</td></tr>" 

########OSLEVEL Validation######
oslevel=`oslevel -s`
if [ "$oslevel" = "7100-03-05-1524" ] || [ "$oslevel" = "6100-09-05-1524" ] || [ "$oslevel" = "7100-04-03-1642" ]; then
echo "<tr><td>AIX Version </td><td> `oslevel -s` </td><td class="pass">Passed</td><td>It shows the current os level ( oslevel -s )</td><td>Nill</td></tr>"
else
echo "<tr><td>AIX Version </td><td> `oslevel -s` </td><td class="fail">Failed</td><td>oslevel is not desired level.</td><td>ALT disk patching required.</td><td class="fail">Remedy INC</td><td class="warning"> GO </td></tr>"
fi



#################################################################NTP Status test#########
echo "<tr><td></td><td class="h2">NTP</td></tr>"
NTP_STAT=`lssrc -s xntpd | awk '{print $4}' | grep -v Status`
NTP_SYNC=`ntpq -c pe | grep -i "*" | awk '{print $2}'`
NTP_SYNC_count=`ntpq -c pe | grep -i "*" | awk '{print $2}'|wc -l`
NTP_SYNC_STAT=`ntpq -c as | grep -i sys.peer | awk '{print $8}'`

####
echo "<tr><td>Time Zone</td><td> Current TimeZone is $TZ</td></tr>"

#############
if [ "$NTP_STAT" = "active" ]; then 
echo "<tr><td>xntpd</td><td>$NTP_STAT</td><td class="pass">Passed</td><td>Status of NTP service </td><td>NIL</td></tr>"
else 
echo "<tr><td>xntpd</td><td>$NTP_STAT</td><td class="fail">Failed</td><td>Service is Not active </td><td>start the ntp service</td><td class="fail">Remedy INC</td><td class="warning"> GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 1 ]
then 
echo "2" >/tmp/HCSTATUS
fi
echo "NTP service is not active" >> $CCINC
fi
####

if [ "$NTP_SYNC_count" -ge 1 ]; then 
echo "<tr><td>NTP MASTER</td><td>$NTP_SYNC</td><td class="pass">Passed</td><td>Provide the status of synchronization with master server </td><td>NIL</td></tr>"
else 
echo "<tr><td>NTP MASTER</td><td>Not synchronized</td><td class="fail">Failed</td><td>Provide the status of synchronization with master server </td><td>create and assign an INC to IBM UNIX CC (unless one exists) </td><td class="fail">Remedy INC </td><td class="warning"> GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 1 ]
then 
echo "2" >/tmp/HCSTATUS
fi
echo "NTP Not synchronized with NTP master server" >> $CCINC
fi

####
if [ "$NTP_SYNC_STAT" = "reachable" ]; then 
echo "<tr><td>NTP MASTER Reachablity </td><td>$NTP_SYNC_STAT</td><td class="pass">Passed</td><td>Provide whether Master server is reachable or not </td><td>NIL</td></tr>"
else 
echo "<tr><td>NTP MASTER Reachablity </td><td>$NTP_SYNC_STAT</td><td class="fail">Failed</td><td>Provide whether Master server is reachable or not </td><td>Check the master server status and network connectivity ,create and assign an INC to IBM UNIX CC (unless one exists)</td><td class="fail">Remedy INC</td><td class="warning"> GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 1 ]
then 
echo "2" >/tmp/HCSTATUS
fi
echo " NTP master server Not Reachable " >> $CCINC
fi

#############################################
STRATUM=`lssrc -ls xntpd |grep -i 'Sys stratum:' | awk '{print $3}'`
if [ "$STRATUM" -le 4 ]; then
echo "<tr><td>NTP Sys stratum </td><td>$STRATUM</td><td class="pass">Passed</td><td>NTP Sys stratum value should be less than 5 </td><td>NIL</td></tr>"
else 
echo "<tr><td>NTP Sys stratum</td><td>$STRATUM</td><td class="fail">Failed</td><td>NTP Sys stratum value should be less than 5 </td><td>create and assign an INC to IBM UNIX CC (unless one exists)</td><td class="fail">Remedy INC</td><td class="warning"> GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 1 ]
then 
echo "2" >/tmp/HCSTATUS
fi
echo " NTP Sys stratum value should be less than 5 " >> $CCINC
fi





##################Rootvg information##################################################
echo "<tr><td></td><td class="h2">Rootvg Information</td></tr>"

>/tmp/rootdisk_path
BOOT_ORD=`bootlist -m normal -o | awk '{print $1}'`
BOOT_ORD_COUNT=`bootlist -m normal -o | grep -i blv |wc -l`
for i in `lsvg -p rootvg | egrep -v "rootvg:|PV_NAME" | awk '{print $1}'`
do
lspath -l $i >> /tmp/rootdisk_path
done 
ROOTVG_DISK_COUNT=`lslv hd4 | grep -i COPIES: | awk '{print $2}'`


if [ $BOOT_ORD_COUNT -ge $ROOTVG_DISK_COUNT ]; then 
echo "<tr><td>Boot list</td><td>$BOOT_ORD</td><td class="pass">Passed</td><td>It shows the next bootable device ( bootlsit -m normal -o ) </td><td>NIL</td></tr>"
else 
echo "<tr><td>Boot list</td><td>$BOOT_ORD</td><td class="fail">Failed</td><td> It shows the next bootable device ( bootlsit -m normal -o )</td><td>create boot image using altboot command and set the boot list again ,if the issue is not resolved then create and assign an INC to IBM UNIX CC (unless one exists)</td><td class="fail">Remedy INC/WO</td></tr>"
echo " Bootlist not properly set " >> $CCINC
fi

#####
CURR=`bootinfo -b`
CURR_COUNT=`bootinfo -b | wc -l`
LOCATION_CODE=`lscfg -l $CURR | awk '{print $1 , $2 }'`
if [ "$CURR_COUNT" -eq 1 ]; then 
echo "<tr><td>Bootdisk </td><td>$LOCATION_CODE</td><td class="pass">Passed</td><td>List the current Bootdisk along with physical location code </td><td>NIL</td></tr>"
else 
echo "<tr><td>Bootdisk </td><td>$LOCATION_CODE</td><td class="fail">Failed</td><td> List the current Bootdisk along with physical location code</td><td>Create and assign an INC to IBM UNIX CC </td><td class="fail">Remedy INC</td><td class="warning"> GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 1 ]
then 
echo "2" >/tmp/HCSTATUS
fi

echo " No Physical location found for Bootlist " >> $CCINC
fi

#####Alt-disk
if cat /var/log/`uname -n`.osbackup.log | egrep "SUCCESS: ALT DISK APPEARS TO BE BOOTABLE ON">/dev/null
then
ALT_DISK_=`cat /var/log/$SERVER.osbackup.log | egrep "SUCCESS: ALT DISK APPEARS TO BE BOOTABLE ON" | awk '{print $10,$11,$12,$13,$14,$15}'`
echo "<tr><td>Alt Disk </td><td>ALT DISK APPEARS TO BE BOOTABLE ON$ALT_DISK_</td><td class="pass">Passed</td><td>check the Alt disk status</td><td>NIL</td></tr>"
for i in $ALT_DISK_
do 
echo "<tr><td>Physical Location</td><td>`lscfg -l $i | awk '{print $1 , $2 }'` </td></tr>"
done
else 
echo "<tr><td>Alt Disk  </td><td>Error with Alt image </td><td class="fail">Failed</td><td> check the Alt disk status </td><td>create and assign an INC to IBM UNIX CC (unless one exists)</td><td class="fail">Remedy INC</td><td class="fail"> 4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 3 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo " Error with ALT image  " >> $CCINC
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

            echo "<tr><td>Rootvg mirror status </td><td><a href="#rmirror">Rootvg is properly mirrored </a></td><td class="pass">passed</td><td>All the LVs should have mirror copy except sysdumplv </td><td>NIL</td></tr>"

        else

            echo "<tr><td>Rootvg mirror status </td><td><a href="#rmirror">Rootvg is not properly mirrored </a></td><td class="fail">failed</td><td>All the LVs should have mirror copy except sysdumplv  </td><td>$VGMIRRO LVs are not properly mirrored,Create and assign an INC to IBM UNIX CC</td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo " $VGMIRRO LVs are not properly mirrored " >> $CCINC
        fi
else 
echo "<tr><td>Mirror status</td><td class="fail">Rootvg is not Mirrored</td><td class="warning">warning</td><td>Why rootvg is not mirred</td><td>Remedy INC</td><td class="warning">GO </td></tr>"
fi

##########################Rootvg stale pps

ROOTVG_STALE_COUNT=`lsvg rootvg | grep -i "STALE PPs:" | awk '{print $6}'`


        if [[ $ROOTVG_STALE_COUNT -eq 0 ]]

        then

            echo "<tr><td>Rootvg stale status </td><td></td><td class="pass">passed</td><td>No Stale </td><td>NIL</td></tr>"

        else

            echo "<tr><td>Rootvg stale status </td><td>No Stale PP's should be there in Rootvg</td><td class="fail">failed</td><td> Stale foud in rootvg </td><td>$ROOTVG_STALE_COUNT Stale PP's found in rootvg,Create and assign an INC to IBM UNIX CC</td><td class="fail">Remedy INC</td><td class="fail"> 4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 3 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo " $ROOTVG_STALE_COUNT PP's are in stale state " >> $CCINC

        fi


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
echo "<tr><td>System dump</td><td><a href="#sysdump">Sysdump Devices are $PSTATUS $SSTATUS  </a></td><td class="fail">failed</td><td>Primary and secondary dump devices should be on diffrent disk if rootvg is not a san boot </td><td>primary dump is on $PDISK and secondy is on $SDISK ,Create and assign an WO to DBQ SR  </td><td class="fail">Remedy WO</td><td class="warning">GO </td></tr>"
echo " Primary and secondary dump devices should be on diffrent disk if rootvg is not a san boot " >> $CCINC
else
echo "<tr><td>System dump </td><td><a href="#sysdump">Sysdump Devices are $PSTATUS $SSTATUS </a></td><td class="pass">passed</td><td>primary dump is on $PDISK and secondy is on $SDISK</td><td>NIL</td></tr>"
fi
else
echo "<tr><td>System dump </td><td><a href="#sysdump">Sysdump Devices are $PSTATUS $SSTATUS </a></td><td class="pass">passed</td><td>primary dump is on $PDISK and secondy is on $SDISK</td><td>NIL</td></tr>"
fi

if /usr/lib/ras/dumpcheck -p >/dev/null
then 
echo "<tr><td>System dump Size </td><td>Current Sysdump Device size is more then Estimated dump size</a></td><td class="pass">passed</td><td>Estimated dump size `sysdumpdev -e | awk '{print $7}'` Bytes</td><td>NIL</td></tr>"
else 
echo "<tr><td>System dump Size </td><td>Current Sysdump Device size is less then Estimated dump size `sysdumpdev -e | awk '{print $7}'` Bytes </a></td><td class="fail">failed</td><td></td><td>Open a WO with IBM UNIX DBQ SR to increase the Sysdump Device size </td><td class="fail">Remedy WO</td><td class="warning">GO </td></tr>"
echo "Current Sysdump Device size is less then Estimated dump size `sysdumpdev -e | awk '{print $7}'` Bytes " >> $CCINC
fi



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
                elif [[ "$mem2GB" -gt "4" && "$mem2GB" -lt "9" ]]; then
                        DESIREDSWAP=$(echo "$mem2GB * 1"|bc)
                elif [[ "$mem2GB" -gt "8" ]]; then
                        DESIREDSWAP=16
                fi
                DESIREDSWAPVAL=`echo "$DESIREDSWAP" |awk -F. '{ print $1 }'`
                #echo Desired Swap is "$DESIREDSWAPVAL"
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
                       echo "<tr><td>System Swap Size </td><td>Swap space is $swap2GB GB  which is less than Required Swap of $DESIREDSWAPVAL GB </a></td><td class="fail">failed</td><td><a href="http://unix.kp.org/ibmkp/ProcProced/aix_rootvg_default_filesystem_sizes.php">Check the KP Standard </a></td><td>create and assign an WO to DBQ SR team (unless one exists)</td><td class="fail">Remedy WO</td><td class="warning">GO </td></tr>"
			echo "Swap space is $swap2GB GB  which is less than Required Swap of $DESIREDSWAPVAL GB" >> $SRWO
                        
                elif [[ "$swap2GB" = "8" || "$swap2GB" -gt "8" ]];then
                        echo "<tr><td>System Swap Size </td><td>Swap space is $swap2GB GB which exceeds Required Swap of $DESIREDSWAPVAL GB </a></td><td class="warning">warning</td><td><a href="http://unix.kp.org/ibmkp/ProcProced/aix_rootvg_default_filesystem_sizes.php">Check the KP Standard </a></td><td>create and assign an WO to DBQ SR team (unless one exists)</td></tr>"

                elif [[ "$swap2GB" = "$DESIREDSWAPVAL" || "$swap2GB" -gt "$DESIREDSWAPVAL" ]];then
                        echo "<tr><td>System Swap Size </td><td>Swap space is $swap2GB GB matches Required Swap of $DESIREDSWAPVAL GB </a></td><td class="pass">passed</td><td><a href="http://unix.kp.org/ibmkp/ProcProced/aix_rootvg_default_filesystem_sizes.php">Check the KP Standard </a></td><td>NIL</td></tr>"
                fi
        fi

        if [[ "$APP" = "ORACLE" ]];then
                if [[ "$swap2GB" -lt "$DESIREDSWAPVAL" ]]; then
                        echo "<tr><td>System Swap Size </td><td>Swap space is $swap2GB GB whic is less than Required Swap of $DESIREDSWAPVAL GB </a></td><td class="fail">failed</td><td><a href="http://unix.kp.org/ibmkp/ProcProced/aix_rootvg_default_filesystem_sizes.php">Check the KP Standard </a></td><td>create and assign an WO to DBQ SR team (unless one exists)</td><td class="fail">Remedy WO</td><td class="warning">GO </td></tr>"
			echo "Swap space is $swap2GB GB  which is less than Required Swap of $DESIREDSWAPVAL GB" >> $SRWO                        
                elif [[ "$swap2GB" = "32" || "$swap2GB" -gt "32" ]];then
                        echo "<tr><td>System Swap Size </td><td>Swap space is $swap2GB GB which  exceeds Required Swap of $DESIREDSWAPVAL GB </a></td><td class="warning">warning</td><td><a href="http://unix.kp.org/ibmkp/ProcProced/aix_rootvg_default_filesystem_sizes.php">Check the KP Standard </a></td><td>create and assign an WO to DBQ SR team (unless one exists)</td></tr>"
                elif [[ "$swap2GB" = "$DESIREDSWAPVAL" || "$swap2GB" -gt "$DESIREDSWAPVAL" ]];then
                       echo "<tr><td>System Swap Size </td><td>Swap space is $swap2GB GB which matches Required Swap of $DESIREDSWAPVAL GB </a></td><td class="pass">passed</td><td><a href="http://unix.kp.org/ibmkp/ProcProced/aix_rootvg_default_filesystem_sizes.php">Check the KP Standard </a></td><td>NIL</td></tr>"
                fi
        fi
}

echo "<tr><td></td><td class="h2">Swap space Information</td></tr>"
#Current Utilization
CURR_UTIL_SWAP=`lsps -s | grep -v Total |awk '{ print $2}' | cut -d % -f 1`
if [[ $CURR_UTIL_SWAP -ge 80 ]]
then
echo "<tr><td>Current Utilization </td><td> $CURR_UTIL_SWAP </td><td class="fail">Failed</td><td>Swap Utilization is above threshold level  </td><td> Inform APP/DB team to reduce the Utilization</td></tr>"
echo "Swap Utilization is above threshold level of 80% " >> $CCINC
else
echo "<tr><td>Current Utilization </td><td> $CURR_UTIL_SWAP</td><td class="pass">passed</td><td>Swap Utilization is under threshold level </td><td>NIL</td></tr>"
fi

                setvariables_Routine
                apptype_Routine
                convert2gb_Routine
                defineaixswap_Routine
                chkdesiredswap_Routine

#######################################################################END OF SWAP



######SYS0 attributs######
echo "<tr><td></td><td class="h2">SYS0 Attributes</td></tr>"
SYS_COUNT=`lsattr -El sys0 | wc -l`
if [ "$SYS_COUNT" -ge 5 ]; then 
echo "<tr><td>System sys0 details </td><td><a href="#sysattr">Attributes</a></td><td class="pass">passed</td><td>sys0 is the AIX kernel device which has many attributes associated with it  ( lsattr -El sys0 ) </td><td>NIL</td></tr>"
else 
echo "<tr><td>System sys0 details </td><td><a href="#sysattr">Attributes</a></td><td class="fail">failed</td><td>sys0 is the AIX kernel device which has many attributes associated with it  ( lsattr -El sys0 ) </td><td>error need manual check </td></tr>"
fi
######ipsec check######
echo "<tr><td></td><td class="h2">Ipsec check</td></tr>"
if lsdev -C -c ipsec | grep -i Available > /dev/null
then
echo "<tr><td>Ipsec Status </td><td>Ipsec is active</td><td class="warning">Warning</td><td>Check why Ipsec is active </td><td>Ipsec sdhould be in same status after reboot,check with patching team </td></tr>"
else 
echo "<tr><td>Ipsec Status </td><td>Ipsec is not active</td><td class="pass">Passed</td><td>Ipsec sdhould not be active </td><td>Nill</td></tr>"
fi



#####################################################DISK_CHECK_ASM###################################



DISK_CHECK () 
{
>/tmp/PRE_ALL_Disk_list
>/tmp/PRE_ASM_HEAD_Disk_list
>/tmp/PRE_ASM_Disk_list
>/tmp/PRE_NONASM_HEAD_Disk_list
>/tmp/PRE_NONASM_Disk_list
>/tmp/PRE_NONASM_OWNERERR
>/tmp/PRE_ASM_PVIDERR
>/tmp/PRE_ASM_OWNERERR
#>/tmp/ls_pvinfo
lsdev -Cc disk|grep -v PowerPath |grep -v EMC | awk '{print $1}' > /tmp/Disk_list
emcpadm getusedpseudos | grep -v pseudo | grep -v Major | grep -Ev "^$" | awk '{print $1}' >> /tmp/Disk_list

echo "--------------------------------------------ASM DISKS-----------------------------------------------------------------------------------------" >>/tmp/PRE_ASM_HEAD_Disk_list
echo "\tDISK\t\tDISK TYPE\t\tPVID\t\tDG NAME\t     RESERVE POLICY\tRAW DISK\tOWNERSHIP(RAW_DEVICE)\tERROR" >>/tmp/PRE_ASM_HEAD_Disk_list
echo "----------------------------------------------------------------------------------------------------------------------------------------------" >>/tmp/PRE_ASM_HEAD_Disk_list

echo "--------------------------------------------NON ASM DISKS--------------------------------------------------------------------------------------" >>/tmp/PRE_NONASM_HEAD_Disk_list
echo "\tDISK\t\tDISK TYPE\t\tPVID\t\tVG NAME\t     RESERVE POLICY\tRAW DISK\tOWNERSHIP(RAW_DEVICE)\tERROR" >>/tmp/PRE_NONASM_HEAD_Disk_list
echo "-----------------------------------------------------------------------------------------------------------------------------------------------" >>/tmp/PRE_NONASM_HEAD_Disk_list

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

cat /tmp/PRE_ASM_HEAD_Disk_list /tmp/PRE_ASM_Disk_list
cat /tmp/PRE_NONASM_HEAD_Disk_list /tmp/PRE_NONASM_Disk_list

}
> /tmp/PRE_DISK_CHECK
DISK_CHECK >> /tmp/PRE_DISK_CHECK

echo "<tr><td></td><td class="h2">DISK Infromation</td></tr>"

############################################ Multipath Information
pcmpath query version > /dev/null
if [ $? = 0 ]
then
echo "<tr><td>SDD PCM disk </td><td> Version  `pcmpath query version`</td></tr>" 
fi
powermt version | awk '{print $7}' > /dev/null
if [ $? = 0 ]
then
echo "<tr><td>EMC disk </td><td> Version  `powermt version | awk '{print $7}'`</td></tr>" 
echo /tmp/`uname -n`.emc_map_export.`date "+%d%b%Y%H"` > /tmp/FILE_LOC
FILE_LOC=`cat /tmp/FILE_LOC`
echo "<tr><td>EMC DISK MAPPING </td><td><a href="#emcmap">Map file location $FILE_LOC </a></td></tr>"
emcpadm export_mappings -x -f $FILE_LOC
fi

########################################DISK COUNT

#echo "<tr><td>List the disks </td><td><a href="#alldisk">List the disks TYPE,PVID,VG or DG NAME,RESERVE POLICY,OWNERSHIP(RAW_DEVICE)</a></td></tr>"    
###########ASM 
echo "<tr><td>ASM disks </td><td> `cat /tmp/PRE_ASM_Disk_list | wc -l ` </td></tr>"
ASM_ERR=`cat /tmp/PRE_ASM_PVIDERR /tmp/PRE_ASM_OWNERERR | wc -l`
if [ $ASM_ERR -eq 0 ]; then 
echo "<tr><td>List the ASM disk  </td><td><a href="#asmdisk">List of ASM disk  </a></td><td class="pass">passed</td><td>No PVID and ownership issue found for ASM disks </td><td>NIL</td></tr>"
else
echo "<tr><td>List the ASM disk with error </td><td><a href="#asmdiskf">List of ASM disk with PVID/ wrong ownership </a></td><td class="fail">Failed</td><td>PVID should not be assigned for ASM disk and OWNERSHIP should be oracle:dba OR root:oinstall </td><td>Work with DBA to fix the issue ,Create and assign an INC to IBM UNIX CC  </td><td class="fail">Remedy INC</td><td class="fail">3 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "3" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 4 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "PVID should not be assigned for ASM disk and OWNERSHIP should be oracle:dba OR root:oinstall " >> $CCINC
cat /tmp/PRE_ASM_PVIDERR /tmp/PRE_ASM_OWNERERR >> $CCINC
fi
###########NON ASM
echo "<tr><td>NON-ASM disks </td><td> `cat /tmp/PRE_NONASM_Disk_list | wc -l ` </td></tr>"
NONASM_ERR=`cat /tmp/PRE_NONASM_OWNERERR | wc -l`
if [ $NONASM_ERR -eq 0 ]; then 
echo "<tr><td>List the NON-ASM disk  </td><td><a href="#nonasmdisk">List of NON-ASM disk  </a></td><td class="pass">passed</td></tr>"
else
echo "<tr><td>List the NON ASM disk with error </td><td><a href="#nonasmdiskf">List of NON ASM disk with wrong ownership </a></td><td class="fail">Failed</td><td>Disk belongs to VG But it Raw disk having  oracle:dba OR root:oinstall ownership please check with DBA </td><td>Work with DBA to fix the issue ,Create and assign an INC to IBM UNIX CC  </td><td class="fail">Remedy INC</td><td class="fail">3 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "3" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 4 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "If A disk belongs to VG then its ownership has to be root:system" >> $CCINC
cat  /tmp/PRE_NONASM_OWNERERR >> $CCINC
fi

######################################################################################################


#########################################################LVM Configuration#################################################

echo "<tr><td></td><td class="h2">LVM Configuration</td></tr>"


######################LSPV


LSPVFAIL=`lsdev -Cc disk -S d | wc -l`
if [ $LSPVFAIL -eq 0 ]; then 
echo "<tr><td>List the Physical disk  </td><td><a href="#lspv">List of PV </a></td><td class="pass">passed</td><td>There should not be any PV in Defined state  </td><td>NIL</td></tr>"
else
echo "<tr><td>List the avilable disk paths </td><td><a href="#lspvfail">List of PVs in Defined state </a></td><td class="fail">Failed</td><td>There should not be any PV in Defined state </td><td>check the reason fix the Define PV </td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 3 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "There should not be any PV in Defined state ,check the reason and fix the Define PV" >> $CCINC
fi

######################Lspath
LSFAIL=`lspath | egrep "Failed|Missing" | wc -l`
if [ $LSFAIL -eq 0 ]; then 
echo "<tr><td>List the  disk paths </td><td><a href="#lspath">Active paths </a></td><td class="pass">passed</td><td>List the Multiple paths for the disks </td><td>NIL</td></tr>"
else
echo "<tr><td>List the  disk paths </td><td><a href="#lspathfail">Failed paths </a></td><td class="fail">Failed</td><td>List the failed paths  </td><td>fix the missing or failed paths on the server </td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "fix the missing or failed paths on the server" >> $CCINC
lspath | egrep "Failed|Missing" >> $CCINC
fi
#########LSVG##############
#echo "<tr><td class="h1">Volume Group Detail</td></tr>"
LSVG_COUNT=`lsvg | wc -l`
if [ "$LSVG_COUNT" -ge 1 ]; then 
echo "<tr><td>List of Volume Group </td><td><a href="#lsvg">VG list</a></td><td class="pass">passed</td><td>List of active and passive Volumegroup </td><td>NIL</td></tr>"
else 
echo "<tr><td>List of Volume Group </td><td><a href="#lsvg">VG list</a></td><td class="fail">failed</td><td>List of active and passive Volumegroup  </td><td>VG found problem with LVM </td><td class="fail">Remedy INC/WO</td></tr>"
fi
#######LSVG -o
LSVG_COUNT=`lsvg | grep -v hbvg | grep -v old_rootvg | grep -v image_ | wc -l`
LSVGO_COUNT=`lsvg -o | grep -v hbvg | grep -v old_rootvg | grep -v image_  | wc -l`
if [ "$LSVG_COUNT" = "$LSVGO_COUNT" ]; then 
echo "<tr><td>List of Volume Group </td><td><a href="#lsvgo">Active VG list</a></td><td class="pass">passed</td><td>List of active  Volumegroup </td><td>NIL</td></tr>"
else 
echo "<tr><td>List of Not Active Volume Group </td><td><a href="#lsvgof">Active VG list</a></td><td class="fail">failed</td><td>List of Not Active  Volumegroup </td><td>Find the reason why Not few Volume Groups are in varyon state other than image_1 </td></tr>"
fi
#######LVs of VG
LSVG_LI_COUNT=`lsvg -o | lsvg -li | grep -i closed | grep -v boot| wc -l`
if [ $LSVG_LI_COUNT -eq 0 ]; then 
echo "<tr><td>lsvg -o | lsvg -li  </td><td><a href="#lsvgo_li">List of LV of Volume Group </a></td><td class="pass">passed</td><td>Check whether all the LVs other than BLV is in open state </td><td>NIL</td></tr>"
else 
echo "<tr><td>lsvg -o | lsvg -li  </td><td><a href="#lsvgo_fli">List of LV  which is in closed state </a></td><td class="fail">failed</td><td>Check whether all the LVs other than BLV is in open state </td><td>Find the reason why few LV are in closed state other than BLV </td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
fi
#######PVs of VG
LSVG_PI_COUNT=`lsvg -o | lsvg -pi | egrep -i "missing|removed" | wc -l`
if [ $LSVG_PI_COUNT -eq 0 ]; then 
echo "<tr><td>lsvg -o | lsvg -pi  </td><td><a href="#lsvgo_pi">List of PVs of Volume Group </a></td><td class="pass">passed</td><td>Check whether all the PVs of VGs are in active state </td><td>NIL</td></tr>"
else 
echo "<tr><td>lsvg -o | lsvg -pi  </td><td><a href="#lsvgo_fpi">List of PVs  which is in closed state </a></td><td class="fail">failed</td><td>Check whether all the PVs of VGs are in active state  </td><td>  $LSVG_PI_COUNT are not in active state </td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
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
echo "<tr><td>Mounted Filesystems and Activy VG with automount state check </td><td><a href="#filesystem">Filesystem list</a></td><td class="pass">passed</td><td>List of mounted filesystem along with its logical volume </td><td>NIL</td></tr>"
else 
echo "<tr><td>Mounted Filesystems and Activy VG with automount state check </td><td><a href="#ffilesystem">Filesystem list</a></td><td class="fail">failed</td><td>List of mounted filesystem along with its logical volume </td><td>there is diffrence between /etc/filesystems entry and actually mounted filesystems</td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "there is diffrence between /etc/filesystems entry and actually mounted filesystems" >> $CCINC
cat /tmp/fscheck/log/after_result >> $CCINC
fi



########NFS
NFSFILE=`lsfs | grep -i nfs | grep -v cdrfs   | wc -l`
MNFS=`mount | grep -i nfs | grep -v cdrfs | grep -v swmount | wc -l`

if [ "$NFSFILE" = "$MNFS" ]; then 
echo "<tr><td>Mounted NFS Filesystems</td><td><a href="#nfsfilesystem">NFS Filesystem list</a></td><td class="pass">passed</td><td>List of NFS mounted filesystem along with its source server </td><td>NIL</td></tr>"
else 
echo "<tr><td>Mounted NFS Filesystems</td><td><a href="#nfsfilesystem">NFS Filesystem list</a></td><td class="fail">failed</td><td>List of NFS mounted filesystem along with its source server </td><td>there is diffrence between /etc/filesystems entry and actually mounted NFS  filesystems</td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "there is diffrence between /etc/filesystems entry and actually mounted NFS filesystems" >> $CCINC
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
echo "<tr><td>Filesystem High utilization </td><td>All Filesystems are below 85% Utilization</td><td class="pass">passed</td><td>List of filesystem whose utilization is more the 85%</td><td>NIL</td></tr>"
else 
echo "<tr><td>Filesystem High utilization</td><td><a href="#fshigh">Filesystem list</a></td><td class="fail">failed</td><td>List of filesystem whose utilization is more the 85% </td><td>Reduce the Utilization below 85%  </td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "Reduce the filesystem Utilization below 85%" >> $CCINC
cat /tmp/fshighoutput >> $CCINC
fi



####################################lsfs 

echo "<tr><td>lsfs output</td><td><a href="#lsfsl">List of Filesystem which have entry in /etc/filesystems </a></td><td></td><td>output of lsfs </td><td> NIL </td></tr>"



#############################################################################Network details##############
>/tmp/ifcon1_out
echo "<tr><td></td><td class="h2">Network Detail</td></tr>"
#####################Network Adapters
echo "<tr><td> Network Adapters </td><td><a href="#netadap">Adapter list and detailed configuration  </a></td></tr>"

#####################Ether channel
echo "<tr><td>Ether channel  </td><td><a href="#ether">Etherchannel list and its configuration </a></td></tr>"
############################ether cannal
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
echo "<tr><td>Ether channel </td><td>Below are the List of Ether channel configured in server </td><td class="pass">Passed</td><td>Validate the NIB and LACP configuration </td><td>NIL</td></tr>"
echo "<tr><td>NIB<td><td>`cat /tmp/NIB`<td></tr>"
echo "<tr><td>LACP<td><td>`cat /tmp/LACP`<td></tr>"
else
echo "<tr><td>Ether channel </td><td>Below are the List of Ether channel not configured properly in server </td><td class="Fail">Failed</td><td>Validate the NIB and LACP configuration</td><td>Check the below errors and fix it</td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
fi
echo "<tr><td>Ether channel not configured Properly <td><td>`cat /tmp/etherr`<td></tr>"
echo "Ether channel not configured Properly" >> $CCINC
cat /tmp/etherr >> $CCINC
fi 
rm -f /tmp/NIB
rm -f /tmp/LACP
rm -f /tmp/etherr



############################rfc1323
RFC=`no -L rfc1323| grep -i  rfc1323| awk '{print $2}'`
if [ $RFC -eq 0 ]; then 
echo "<tr><td>rfc1323 Value </td><td><a href="#rfc1323">rfc1323 current values </a></td><td class="fail">Failed</td><td>rfc1323 has to be 1 to prevent network flap  </td><td>Change the rfc1323 to 1 </td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "rfc1323 has to be 1 to prevent network flap" >> $CCINC
else
echo "<tr><td>rfc1323 Value </td><td><a href="#rfc1323">rfc1323 current values </a></td><td class="pass">passed</td><td>rfc1323 has to be 1 to prevent network flap</td><td>NIL</td></tr>"
fi

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
echo "<tr><td>IP and interface link status </td><td><a href="#enlinkstst">IP Address </a></td><td class="pass">passed</td><td>List of interface and its corresponding IP address </td><td>NIL</td></tr>"
else 
echo "<tr><td>IP and interface link status </td><td><a href="#fenlinkstst">List of link down Interfaces </a></td><td class="fail">failed</td><td>List of link down Interfaces  </td><td>Activate the interface </td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "Listed interface link status is in down state " >> $CCINC
cat /tmp/ifcon1_out >> $CCINC
fi
 
rm -f /tmp/ifcon_out 

###############Netstat -rn Routing

DEFAULT=`netstat -rn | grep default | awk '{print $2}' | wc -l `

    if [[ $DEFAULT -gt 1 ]]

    then
    echo "<tr><td>Routing table</td><td><a href="#netstat_rn">Route Table </a></td><td class="fail">Failed</td><td>Route Table should countain only one default gateway IP </td><td>Raise a INC to IBM UNIX CC to fix the error </td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
fi
echo "Route Table should countain only one default gateway IP " >> $CCINC
     else
     echo "<tr><td>Routing table</td><td><a href="#netstat_rn">Route Table </a></td><td class="pass">Passed</td><td>Route Table should countain only one default gateway IP </td><td>NIL</td></tr>"

     fi
HOSTSUBNET=`nslookup $SERVER|grep Address |awk '{ print $2 }' |sed -n 2p|cut -d '.' -f1,2,3 `

ROUTSUBNET=`netstat -rn |grep default|awk '{ print $2 }'|cut -d '.' -f1,2,3`

        if [[ "$HOSTSUBNET" != "$ROUTSUBNET" ]]; then

        echo "<tr><td>Routing table</td><td><a href="#netstat_rn">Subnet check </a></td><td class="fail">Failed</td><td>Subnet of $SERVER - $HOSTSUBNET does not match subnet of Default route $ROUTSUBNET </td><td>If default gateway is different than the transactional IP address, the server become unresponsive.Create and assign an INC to IBM UNIX CC (unless one exists)</td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
fi
echo "Check DNS configured for the server or check the the subnet of primary ip and Default gateway should be same else fix it " >> $CCINC

        else

        echo "<tr><td>Routing table</td><td><a href="#netstat_rn">Subnet check </a></td><td class="pass">Passed</td><td>Subnet of $SERVER - $HOSTSUBNET matches subnet of Default route $ROUTSUBNET </td><td>NIL</td></tr>"
        fi


###############netsvcconf

echo "<tr><td>NETSVC confguration</td><td><a href="#netsvcconf">/etc/netsvc.conf </a></td></tr>"

###############resolvconf

echo "<tr><td>Name Resolution confguration</td><td><a href="#resolvconf">/etc/resolv.conf </a></td></tr>"

###############Network kernal perameters

echo "<tr><td>Network kernal perameters</td><td><a href="#no_a">Network kernal values </a></td><td></td><td>output of no -a</td><td> NIL </td></tr>"

####################Adapters
#echo "<tr><td class="h1"> Adapters </td></tr>"
DEF_ADAPTER=`lsdev -Cc adapter -S d | wc -l`
if [ $DEF_ADAPTER -eq 0 ]; then
echo "<tr><td>Network and FCS Adapters</td><td><a href="#adapter">List of Avilable Adapters </a></td><td class="pass">passed</td><td>All Adapters has to to be in Avilable state</td><td>NIL</td></tr>"
else
echo "<tr><td>Network and FCS Adapters</td><td><a href="#adapterfail">List of Adapters in Defined state </a></td><td class="fail">Failed</td><td>All Adapters has to to be in Avilable state </td><td>Make the defined Adapters to Avilable </td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "All Adapters has to to be in Avilable state " >> $CCINC
lsdev -Cc adapter -S d >> $CCINC

fi
####################Adapters_speed
#echo "<tr><td class="h1"> Adapters Media speed </td></tr>"
lsdev -Cc adapter |grep -i ^ent|egrep -vi "etherchannel|VLAN|Shared" |awk '{if(echo $3 == "Virtual"||echo $4 == "Virtual") print $1" " $2 " is virtual adapter" ;else system("echo "$1" "$2" `lsattr -El "$1"|grep -i media`")}' |awk '{print $1","$2","$3","$4}' >/tmp/Adapters_speed

echo "<tr><td>Adapters Media speed</td><td>List of  Adapters along with speed </td><td></td><td>Adapters speed should match with network switch speed,if any deviations found raise an WO with IBM DBQ SR unless one exists</td><td>NIL</td></tr>"

echo "<tr><td></td><td>`cat /tmp/Adapters_speed `</td></tr>"



###############lparstat
echo "<tr><td></td><td class="h2">Lpar Information</td></tr>"
echo "<tr><td>Lpar infomation</td><td><a href="#lparstat">Lpar configuration details </a></td><td></td><td>output of lpstat -i </td><td> NIL </td></tr>"

###########################################ERROR LOG
echo "<tr><td></td><td class="h2">ERROR LOG</td></tr>"
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
echo "<tr><td>Past Three days ERROR</td><td>NO Errors logged in past three days </td><td class="pass">passed</td><td>will list the error logged in past 3 days(HARDWARE,SOFTWARE,UNDETERMAIN)</td><td>NIL</td></tr>"
else
echo "<tr><td>Past Three days ERROR</td><td><a href="#errpt">$ERRCOUNT Errors logged in past three days  </a></td><td class="fail">Failed</td><td>will list the error logged in past 3 days(HARDWARE,SOFTWARE,UNDETERMAIN)</td><td>Fix the errors </td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 3 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "<tr><td>NO OF HARDWARE ERROR</td><td> $HWERRCOUNT </td></tr>"
echo "<tr><td>NO OF SOFTWARE ERROR</td><td> $SOFTRCOUNT </td></tr>"
echo "<tr><td>NO OF UNDETERMAIN ERROR</td><td> $UNDETERRCOUNT </td></tr>"
echo "Validate the errors logged in past 3 days and try to fix them up " >> $CCINC
fi

###############################################################################################

#########################################  VIO ##################
########################## IS VIO
/usr/ios/cli/ioscli ioslevel > /dev/null
if [ $? = 0 ]
then
echo "<tr><td></td><td class="h2">VIO Information</td></tr>"
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
echo "<tr><td>SEA </td><td><a href="#SEA_STAT">SEA Configuration  </a></td><td class="pass">passed</td><td>No error found in SEA (NO LIMBO, All SEA is set with AUTO failover,All SEA are online)</td><td>NIL</td></tr>"
else
echo "<tr><td>SEA </td><td><a href="#SEA_STAT">SEA Configuration  </a></td><td class="fail">Failed</td><td>SEA is not properlay configured or functioning </td><td>Fix the below errors before proceeding </td><td class="fail">Remedy INC</td><td class="fail"> 4 : No Go  </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 3 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "<tr><td> LIMBO </td><td>No.Of SEA in LIMBO State </td><td >`cat /tmp/LIMBO | wc -l`</td><td>The most common causes for an SEA to be in limbo state include (but are not limited to) the following:  </td><td>1,Link status went down for the underlying physical adapter.< br>2,SEA failover misconfiguration when using a dedicated control channel adapter <br>3,Problem on the network switch.</td></tr>"
echo "<tr><td> High Avilablity Mode</td><td>Not set in Auto </td><td >`cat /tmp/HA_MODE | wc -l`</td><td> SEA HA_mode has to be auto else failover is not possible if it is in standby mode  </td><td>chdev -dev ent# -attr ha_mode=auto </td></tr>"
echo "<tr><td> Link Status </td><td>No.Of SEA Links is in DOWN/ UNKNOWN status </td><td >`cat /tmp/SEA_LINK_STATUS | wc -l`</td><td>check the link status of SEA </td></tr>"
echo "Check the SEA LINK STATUS and HA_MODE property" >> $CCINC
fi
##############################    NPIV
NPIV_ERROR_COUNT=`/usr/ios/cli/ioscli lsmap -all -npiv -fmt , | grep -v ", ," | grep -i NOT_LOGGED_IN | wc -l`
if [ $NPIV_ERROR_COUNT = 0 ]; then 
echo "<tr><td>NPIV </td><td><a href="#NPIV_STAT">NPIV Configuration  </a></td><td class="pass">passed</td><td>No error found in NPIV configuration (ie all NPIV adapters are in LOGGED_IN  state)</td><td>NIL</td></tr>"
else
echo "<tr><td>NPIV  </td><td><a href="#NPIV_STAT_fail">NPIV Configuration  </a></td><td class="fail">Failed</td><td>$NPIV_ERROR_COUNT are in NOT_LOGGED_IN </td><td> Create and assign an INC to IBM UNIX CC ( unless one exists )</td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
echo "Check the NPIV STATUS because few adapters found to be in NOT_LOGGED_IN state " >> $CCINC
/usr/ios/cli/ioscli lsmap -all -npiv -fmt , | grep -v ", ," | grep -i NOT_LOGGED_IN >> $CCINC
fi
######################   network adapter

ENT_ERROR_COUNT=`/usr/ios/cli/ioscli lsmap -all -net -fmt , | grep -v ", ," | grep -v Available | wc -l`
if [ $ENT_ERROR_COUNT = 0 ]; then 
echo "<tr><td>Network Adapters </td><td><a href="#ent_STAT">Network Adapter list  </a></td><td class="pass">passed</td><td>All Networ Adapters are in avilable state</td><td>NIL</td></tr>"
else
echo "<tr><td>Network Adapters </td><td><a href="#ent_STAT_fail">Network Adapter list   </a></td><td class="fail">Failed</td><td>$ENT_ERROR_COUNT adapters are in Defined state </td><td> Create and assign an INC to IBM UNIX CC ( unless one exists )</td><td class="fail">Remedy INC</td><td class="warning">GO </td></tr>"
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
echo "<tr><td>Disk mapping and it status</td><td><a href="#vscsi_STAT">Disk mapping list  </a></td><td class="pass">passed</td><td>Disk Mapping detail is stored under $SaveTo in the server </td><td>NIL</td></tr>"
else
echo "<tr><td>Disk mapping and it status </td><td><a href="#vscsi_STAT_fail">Disk mapping list  </a></td><td class="fail">Failed</td><td>$VSCSI_ERROR_COUNT Mapped disk  are in Defined state </td><td> Create and assign an INC to IBM UNIX CC ( unless one exists ) </td><td class="fail">Remedy INC</td><td class="warning">(GO) but has to fix post patching/change  </td></tr>"
echo "$VSCSI_ERROR_COUNT Mapped disk  are in Defined state" >> $CCINC
fi




#############
fi

############################## END OF VIO #########################
#########################Cluster _ HACMP
echo "<tr><td></td><td class="h2">Cluster Information</td></tr>"



lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte > /dev/null

    if [[ $? -eq 0 ]]

    then
        CLNOT=1

        CLVERSION=`lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte |  awk '{print $2}' | head -1`

        echo "<tr><td>Cluster Version</td><td>$CLVERSION</a></td></tr>"

        CLSTATUS=`lssrc -ls clstrmgrES |  grep "Current state:" |  awk '{print $3}'`

        if [[ $CLSTATUS = "ST_STABLE" ]]

        then

            echo "<tr><td>Cluster Status</td><td>Cluster is Stable </td><td class="pass">passed</td><td>Cluster status is ST_STABLE </td><td>NIL</td></tr>"
            echo "<tr><td>Status of the cluster daemons</td><td><a href="#clshowsrv">Cluster daemons </a></td></tr>"
            echo "<tr><td>Detailed Cluster Configuration</td><td><a href="#cldump">Cluster Configuration </a></td></tr>"
            echo "<tr><td>network output</td><td><a href="#cllsif">Cluster network configuration </a></td></tr>"
            echo "<tr><td>Resource Group status </td><td><a href="#clrginfo">RG Status </a></td></tr>"
            echo "<tr><td>The scripts used during the Cluster takeover as below </td><td><a href="#cllsserv">Start and stop script </a></td></tr>"
            echo "<tr><td>The Cluster Log files are found as below</td><td><a href="#HACMPlogs">Cluster Logs </a></td></tr>"
                  

else

            echo "Cluster is Unstable.No output captured.Please verify " 
echo "<tr><td>Cluster Status</td><td><a href="#clstat">Cluster is Unstable / down </a></td><td class="fail">Failed</td><td>Cluster status is $CLSTATUS </td><td> cluster is not in stable state fix the issue </td><td class="fail">Remedy INC</td><td class="fail">3 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "3" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 4 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "HACMP Cluster status is $CLSTATUS,cluster is not in stable state fix the issue " >> $CCINC 

        fi

    else
echo "<tr><td>HACMP Not installed ?</td><td>Not A HACMP cluster node </td></tr>"

        

    fi

rm -f /tmp/pretmp


#########################################cl_verify
CURRENT_DATE=$(date +%b%-d)
SDATE=$(ls -al /var/hacmp/clverify/clverify.log |awk '{print $6$7}')
echo "<tr><td bgcolor=#00FF00>  Cluster Verifivation Status </td><td></td></tr> "
lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte > /dev/null

    if [[ $? -eq 0 ]];then
        if [ "$(/usr/es/sbin/cluster/utilities/clgetactivenodes -n $(hostname) | sort | head -1)" != "$SERVER" ];then
        ## Node is not a first node
               echo "<tr><td>Cluster verification Status</td><td>Check the other node</td><td class="warning">Warning</td><td>Node is not a first node in the cluster </td><td>Perform the cluster validation on the other node</td></tr>"
	 	else
		if [ "$SDATE" == "$CURRENT_DATE" ];then
              		STATE=$(grep "Check:" /var/hacmp/clverify/clverify.log |sort |uniq)
				if [ "$STATE" == "Check: PASSED" ];then
					echo "<tr><td>Cluster verification Status</td><td>Cluster verification succeed </td><td class="pass">passed</td><td> Cluster Verification is Passed on "$SERVER" server</td><td>NIL</td></tr>"
					else 
					echo "<tr><td>Cluster verification Status</td><td>Cluster verification failed </td><td class="fail">failed</td><td>Cluster verification ran with the error on "$SERVER" server </td><td> cluster is not in stable state fix the issue </td><td class="fail">Remedy INC</td><td class="fail">NO GO </td></tr>"
					echo " Cluster verification ran with the error on "$SERVER" server  " >> $CCINC
				fi
		else
		     echo "<tr><td>Cluster verification Status</td><td>Cluster verification failed </td><td class="fail">failed</td><td>No Latest Cluster verification happened on "$SERVER" server </td><td> find the reason why No Latest Cluster verification happened on this server </td><td class="fail">Remedy INC</td><td class="fail">NO GO </td></tr>"
		     echo " No Latest Cluster verification happened on server "$SERVER" ,The last verification happned on $SDATE " >> $CCINC
		fi
	fi	

    else       
	echo "<tr><td>HACMP  installed </td><td>Not A HACMP cluster node </td></tr>"
    fi
#########################################



#######################

#########################Cluster _ GPFS

echo "<tr><td></td><td class="h2">GPFS Cluster Information</td></tr>"


lslpp -l | grep -i gpfs.base > /dev/null

    if [[ $? -eq 0 ]]

    then
        GPFSNOT=1

        GPFSVERSION=`lslpp -l | grep -i gpfs.base |  awk '{print $2}' | head -1`

        echo "<tr><td>Cluster Version</td><td>$GPFSVERSION</a></td></tr>"

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

            echo "<tr><td>Cluster Status</td><td>Cluster is Stable </td><td class="pass">passed</td><td>Cluster status is active in all node </td><td>NIL</td></tr>"
            echo "<tr><td>Status of GPFS cluster daemons and configuration </td><td><a href="#mmlscluster">Cluster configurations  </a></td></tr>"
            echo "<tr><td>Nodes in cluster</td><td> <pre> `cat /tmp/GPF_PRE_Nodes` </pre> </td></tr>"

            echo "<tr><td>GPFS filesystems </td><td><a href="#gpfsfs">List of GPFS filesystems </a></td></tr>"
            echo "<tr><td>GPFS Disk </td><td><a href="#gpfspv">List of GPFS disks </a></td></tr>"
        else

            echo "Cluster is Unstable or is inactive in atleast one node .Please verify " 
echo "<tr><td>Cluster Status</td><td><a href="#gpsfstat">Cluster is Unstable / down </a></td><td class="fail">Failed</td><td>Cluster status is inactive in atleast one node  </td><td> cluster is not in stable state fix the issue </td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 3 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "GPFS Cluster status is inactive in atleast one node" >> $CCINC 

        fi

    else
echo "<tr><td>GPFS Not installed ?</td><td>Not A GPFS cluster node </td></tr>"

        

    fi

rm -f /tmp/pretmp
rm -f /tmp/GPF_PRE_Nodes
rm -f /tmp/GPF_PRE_STAT

##############################
echo "</table>"


############################   Disk Reserver Policy     ################
servername=`uname -n`


/usr/local/scripts/chk_rp.ksh > /tmp/test.reserve


echo "<table><tr><td></td><td class="h2">Disk Reserver Policy </td></tr>"
ISEMC=`cat /tmp/test.reserve | tail -n 50 | grep -ci "Issues   :" `
if [ $ISEMC -eq 0 ]; then
echo "<tr><td>Disk Reserver Policy</td><td><a href="#Dreserve"> No EMC DISK Found </a></td><td class="pass">passed</td><td>It shows the disk reservation policy on the disks 
</td><td>NIL</td></tr>"
else
ERROR_count=`cat /tmp/test.reserve | tail -n 50 | grep -i "Issues   :" | awk '{print $3}'`
if [ $ERROR_count -eq 0 ]; then
echo "<tr><td>Disk Reserver Policy</td><td><a href="#Dreserve"> No Issue Found </a></td><td class="pass">passed</td><td>It shows the disk reservation policy on the disks 
</td><td>NIL</td></tr>"
else
echo "<tr><td>Disk Reserver Policy</td><td><a href="#Dreserve">Issue Found in $ERROR_count Parent/child Disks </a></td><td class="fail">Failed</td><td>It shows the disk reservation policy on the disks </td><td>Remidate the disk reserve issue before proceeding </td><td class="fail">Remedy INC</td><td class="fail">3 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "3" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 4 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "Issue Found in $ERROR_count Parent/child Disks,Remidate the disk reserve policy issue " >> $CCINC
fi
fi
echo "<tr><td></td><td><pre>"
cat /tmp/test.reserve | tail -n 50 | grep -ip "Host     :" 
echo "</pre></td></tr></table>"


##########################################################


################################## OS BAckup ###########

echo "<table><tr><td></td></tr><tr><td></td></tr>"
echo "<tr><td></td><td class="h2">OS BACKUP STATUS</td></tr>"
CRONEN=`crontab -l | grep -v "^#" | grep backupos.ksh 2>/dev/null`
if [[ ! -z $CRONEN ]]; then
echo "<tr><td>Backup Configured in Cron?</td><td><a href="#backcron"> OS Backup has been configured in Cron</a></td><td class="pass">passed</td><td>OS backup has to be configured in a way like it has to be backup once in a week </td><td>NIL</td></tr>"
else 
echo "<tr><td>Backup Configured in Cron?</td><td>OS Backup has not been configured in Cron</td><td class="fail">failed</td><td>OS backup has to be configured in a way like it has to be backup once in a week  </td><td>30 21 * * 0 /usr/local/scripts/backupos.ksh -B make this enrty in root cron and refresh the cron service </td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
else 
if [ `cat /tmp/HCSTATUS` == 3 ]
then
echo "5" >/tmp/HCSTATUS
fi
fi
echo "OS backup has to be configured in a way like it has to be backup once in a week" >> $CCINC
fi
BSERVER=`uname -n`
echo "<tr><td></td><td class="h2">LASTEST OS BACKUP HAPPENED </td></tr>"
echo "<tr><td> Backup script version </td><td>`what /usr/local/scripts/backupos.ksh 2>/dev/null | sed '$!d'`</td></tr>"
echo "<tr><td>Remote server  </td><td>`cat /mksysbfs/.server 2>/dev/null | grep mksysbServer | cut -d"=" -f2`</td></tr>"
ls -l /mksysbfs/$BSERVER.* 2>/dev/null | grep -i .gz | awk '{print $6 " " $7 " at " $8 }' > /tmp/bdate
echo "<tr><td> Date backup taken </td><td>`cat /tmp/bdate`</td></tr>"
echo "<tr><td> Size of Backup file </td><td>`ls -l /mksysbfs/$BSERVER.* 2>/dev/null | grep -i .gz | awk '{print $5}'`  KB</td></tr>"
echo "<tr><td> File location</td><td>`ls -l /mksysbfs/$BSERVER.* 2>/dev/null | grep -i .gz | awk '{print $NF }'`</td></tr>"
echo "<tr><td class="h1"> Backup Status </td></tr>"
echo "<tr><td></td><td><pre>`cat /var/log/$BSERVER.osbackup.log | grep -i SUCCESS:`</pre></td></tr>"
BACKERR=`cat /var/log/$BSERVER.osbackup.log |awk '/ERROR/{print;getline;print;}'`
if [[ ! -z $BACKERR ]]; then
echo "<tr><td class="fail"> Backup Error/Warning </td><td class="fail">Remedy INC</td><td class="fail">4 : NO GO </td></tr>"
if [ `cat /tmp/HCSTATUS` -le 2 ]
then 
echo "4" >/tmp/HCSTATUS
fi
echo "<tr><td></td><td><pre>`cat /var/log/$BSERVER.osbackup.log |awk '/ERROR/{print;getline;print;}'`</pre></td></tr>"
fi

echo "</table>"

#########################################################


#################################################rootvg mirror status
echo "<h2 id="rmirror">Rootvg Mirror detail </h2>"
lsvg -l rootvg > /tmp/output 
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#################################################sysdump
echo "<h2 id="sysdump">System dump device configuration </h2>"
sysdumpdev -l > /tmp/output 
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################LSPV
echo "<h2 id="lspv">lspv</h2>"
lspv -u > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################LSPVfail
echo "<h2 id="lspvfail">List of PVs in Failed state</h2>"
lsdev -Cc disk -S d  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################EMC disk detail
echo "<h2 id="lspvfail">powermt display dev=all</h2>"
powermt display dev=all  > /tmp/output_powermt_display_all
#echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################EMC DISK MAPPING
echo "<h2 id="emcmap">ESM DISK MAPPING</h2>"
echo "<textarea rows=50 cols=200 >"
echo "<pre>`cat $FILE_LOC`</pre></textarea>"
echo "<a href="#">Go to top</a>"
####################### disk detail
#echo "<h2 id="alldisk">ASM And NON-ASM Desk details </h2>"
#echo "<pre>`cat /tmp/PRE_DISK_CHECK`</pre>"
#echo "<a href="#">Go to top</a>"
#rm -f /tmp/PRE_DISK_CHECK
####################### ASM disk detail
echo "<h2 id="asmdisk">ASM Desk details </h2>"
echo "<pre>`cat /tmp/PRE_ASM_HEAD_Disk_list  /tmp/PRE_ASM_Disk_list`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/PRE_ASM_Disk_list
####################### ASM disk detail error 
echo "<h2 id="asmdiskf">ASM disk error detail </h2>"
echo "<pre>`cat /tmp/PRE_ASM_PVIDERR`</pre>"
echo "<pre>`cat /tmp/PRE_ASM_OWNERERR`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/PRE_ASM_PVIDERR
rm -f /tmp/PRE_ASM_OWNERERR
####################### NON ASM disk detail
echo "<h2 id="nonasmdisk">NON-ASM Desk details </h2>"
echo "<pre>`cat /tmp/PRE_NONASM_HEAD_Disk_list /tmp/PRE_NONASM_Disk_list`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/PRE_NONASM_Disk_list
####################### NON ASM disk detail error
echo "<h2 id="nonasmdiskf">NON-ASM Desk wit Error </h2>"
echo "<pre>`cat /tmp/PRE_NONASM_OWNERERR`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/PRE_NONASM_OWNERERR
#######################LSVG
echo "<h2 id="lsvg">lsvg</h2>"
lsvg > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################LSVG -o 
echo "<h2 id="lsvgo">lsvg -o</h2>"
lsvg -o > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################LSVG -o  fail condition
echo "<h2 id="lsvgof">lsvg -o</h2>"
lsvg | grep -v hbvg | grep -v old_rootvg | grep -v image_ > /tmp/lsvg_1
lsvg -o > /tmp/lsvg_2
awk 'NR==FNR{a[$0];next} !($0 in a)' /tmp/lsvg_2 /tmp/lsvg_1 > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"


rm -f /tmp/output
rm -f /tmp/lsvg_2 
rm -f /tmp/lsvg_1

#######################lsvg -o | lsvg -li
echo "<h2 id="lsvgo_li">List of LVs of all VGs</h2>"
lsvg -o | lsvg -li > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################lsvg -o | lsvg -li|fail condition
echo "<h2 id="lsvgo_fli">List of LVs in closed state</h2>"
lsvg -o | lsvg -li | grep -i closed | grep -v boot > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################lsvg -o | lsvg -pi
echo "<h2 id="lsvgo_pi">List of PVs of all VGs</h2>"
lsvg -o | lsvg -pi > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################lsvg -o | lsvg -pi|fail condition
echo "<h2 id="lsvgo_fpi">List of LVs in closed state</h2>"
lsvg -o | lsvg -li | egrep -i "missing|removed" > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#################################################FIlestsems
echo "<h2 id="filesystem">Filesystem</h2>"
df -g > /tmp/output 
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#################################################FIlestsems
echo "<h2 id="ffilesystem">Filesystem or VG auto stste is disabled </h2>"
echo "<pre>`cat /tmp/fscheck/log/after_result`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/fscheck/log/after_result
#############################NFS FIlesystem
echo "<h2 id="nfsfilesystem">NFS Filesystem</h2>"
lsfs | grep -i nfs | grep -v cdrfs | awk '{print $1}' > /tmp/lsfs_nfs
mount | grep -i nfs | grep -v cdrfs | grep -v swmount | awk '{print $2}' > /tmp/mount_nfs
(cat /tmp/lsfs_nfs /tmp/mount_nfs)| sort | uniq -c | awk '$1==1 {print $2}' > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output /tmp/lsfs_nfs /tmp/mount_nfs
#############################FS High utilization
echo "<h2 id="fshigh">Filesystem with high Utilization</h2>"
echo "<pre>`cat /tmp/fshighoutput`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/fshighoutput
#############################lsfs
echo "<h2 id="lsfsl">lsfs output</h2>"
lsfs > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
##################################SYS0 Attributes
echo "<h2 id="sysattr">SYS0 Attributes</h2>"
lsattr -El sys0 > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output


#################################################################################################NETWORK
################Network Adapters
echo "<h2 id="netadap">List of Network adapters and its detailed configuration</h2>"
lsdev -Cc adapter | grep ent |  grep -v -i etherchannel  > /tmp/output
for i in `lsdev -Cc adapter | grep ent | grep -i -v etherchannel | awk '{print $1}'`

    do

        echo "Detailed configuration of $i ethernet adapter " >> /tmp/output

        echo "============================================== ">> /tmp/output

        entstat -d $i >> /tmp/output

        echo "----------------------------------------------------------------------------- " >> /tmp/output

    done
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output

################etherchannel
echo "<h2 id="ether">List of Etherchannel and its configuration</h2>"
lsdev -Cc adapter -s pseudo -t ibm_ech | awk '{print $1}'  > /tmp/output

    for i in `lsdev -Cc adapter -s pseudo -t ibm_ech | awk '{print $1}'`

    do

        echo "Settings for the adapter $i: ">> /tmp/output

        lsattr -El $i  >> /tmp/output

    done



    for i in `lsdev -Cc adapter -s pseudo -t ibm_ech | awk '{print $1}'`

    do

        echo "Detailed configuration for Adapter $i:" >> /tmp/output

        entstat -d $i  >> /tmp/output

    done

echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output

#######################ifconfig -a
echo "<h2 id="enlinkstst">List of Interface with IP</h2>"
ifconfig -a > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################ifconfig -a fail
echo "<h2 id="fenlinkstst">List of Interface in down status</h2>"
echo "<pre>`cat /tmp/ifcon1_out`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/ifcon1_out
#######################Netstat -rn
echo "<h2 id="netstat_rn">Routing Table</h2>"
netstat -rn > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################rfc1323
echo "<h2 id="rfc1323">rfc1323 </h2>"
no -L rfc1323 > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################/etc/netsvc.conf
echo "<h2 id="netsvcconf">/etc/netsvc.conf </h2>"
echo "<pre>`cat /etc/netsvc.conf`</pre>"
echo "<a href="#">Go to top</a>"
#######################/etc/resolv.conf
echo "<h2 id="resolvconf">Network kernal perameters </h2>"
echo "<pre>`cat /etc/resolv.conf`</pre>"
echo "<a href="#">Go to top</a>"
#######################Network kernal perameters
echo "<h2 id="no_a">Network kernal perameters </h2>"
no -a > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################lspath 
echo "<h2 id="lspath">List of Active Disk paths</h2>"
lspath | egrep "Enabled|Available"> /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################lspath fail
echo "<h2 id="lspathfail">List of Missing or failed Disk paths</h2>"
lspath | egrep "Failed|Missing" > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output

#######################Adapters
echo "<h2 id="adapter">Adapters in Avilable state </h2>"
lsdev -Cc adapter -S a > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################Adapters_defined
echo "<h2 id="adapterfail">Adapters in Defined state </h2>"
lsdev -Cc adapter -S d  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################ALL_Devices
echo "<h2 >All Devices in the server </h2>"
lsdev  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################lscfg
echo "<h2 >lscfg output </h2>"
lscfg  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################lparstat
echo "<h2 id="lparstat">Lpar information </h2>"
lparstat -i  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################/dev output
echo "<h2 id="dev-l">/dev </h2>"
ls -l /dev > /tmp/dev-l-output
echo "<pre>Check the file /tmp/dev-l-output </pre>"
echo "<a href="#">Go to top</a>"
####################Errpt -a
echo "<h2 id="errpt">errpt -a with uniq errors </h2>"
errpt | sort -uk1,1 > /tmp/output 
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
####################Disk Reserver Policy
echo "<h2 id="Dreserve">Reserver Policy </h2>"
echo "<pre>`cat /tmp/test.reserve`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/test.reserve






#########################################  VIO ##################
########################## IS VIO
/usr/ios/cli/ioscli ioslevel >/dev/null
if [ $? = 0 ]
then

#######################     SEA
echo "<h2 id="SEA_STAT">SEA List and configuration </h2>"
lsdev -Cc adapter |grep -i shared|awk '{print $1}'|while read m;do echo $m `entstat -d $m |egrep "State|Bridge Mode|VID shared|High Availability Mode|Priority"`;done > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output

###########LIMBO
echo "<h2 >SEA in LIMBO state </h2>"
echo "<pre>`cat /tmp/LIMBO`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/LIMBO
##########HA mode 
echo "<h2 >SEA High Avilablity Mode is not Auto  </h2>"
echo "<pre>`cat /tmp/HA_MODE`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/HA_MODE
##########Link status
echo "<h2 >SEA Link status is Down/Unknow </h2>"
echo "<pre>`cat /tmp/SEA_LINK_STATUS`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/SEA_LINK_STATUS
##########NPIV
echo "<h2 id="NPIV_STAT">NPIV Adapters </h2>"
/usr/ios/cli/ioscli lsmap -all -npiv -fmt , | grep -v ", ," > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<h2 id="NPIV_STAT">LSNPORTS output </h2>"
/usr/ios/cli/ioscli lsnports > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output 
##########NPIV fail
echo "<h2 id="NPIV_STAT_fail">NPIV Adapters in NOT_LOGGED_IN state </h2>"
/usr/ios/cli/ioscli lsmap -all -npiv -fmt , | grep -v ", ," | grep -i NOT_LOGGED_IN  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
##########Networ interface
echo "<h2 id="ent_STAT">Network Adapters </h2>"
/usr/ios/cli/ioscli lsmap -all -net -fmt , | grep -v ", ," > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
##########Networ interface fail
echo "<h2 id="ent_STAT_fail">Network Adapters in defined state  </h2>"
/usr/ios/cli/ioscli lsmap -all -net -fmt , | grep -v ", ," | grep -v Available > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
##########Vscsi
echo "<h2 id="vscsi_STAT">Disk mapping Details</h2>"
echo "<pre>`cat $SaveTo`</pre>"
echo "<a href="#">Go to top</a>"
##########vscsi  fail
echo "<h2 id="vscsi_STAT_fail">Disk mapping and it status which is in Defined state  </h2>"
/usr/ios/cli/ioscli lsmap -all -field SVSA VTD Status Backing -fmt , | grep -i defined  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output

#########################
fi






#######################################################################HACMP################

lslpp -l cluster.es.server.rte |  grep  cluster.es.server.rte > /dev/null

    if [[ $? -eq 0 ]]

    then

######################Cluster##########
#######################Cluster daemons
echo "<h2 id="clshowsrv">Status of the cluster daemons  </h2>"
/usr/es/sbin/cluster/utilities/clshowsrv -v  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################Cluster Configuration
echo "<h2 id="clshowsrv">Cluster Configuration </h2>"
/usr/es/sbin/cluster/utilities/cldump  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################Cluster network configuration 
echo "<h2 id="cllsif">Cluster network configuration </h2>"
/usr/es/sbin/cluster/utilities/cllsif  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################RG Status
echo "<h2 id="clrginfo">Resource Group status </h2>"
/usr/es/sbin/cluster/utilities/clRGinfo  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################Scripts
echo "<h2 id="cllsserv">Start and Stop Script </h2>"
/usr/es/sbin/cluster/utilities/cllsserv > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################HACMPlogs
echo "<h2 id="HACMPlogs">The Cluster Log files </h2>"
odmget HACMPlogs  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
####################
fi



#######################################################################GPFS ################

lslpp -l | grep -i gpfs.base > /dev/null

    if [[ $? -eq 0 ]]

    then

######################Cluster##########
#######################Cluster Configuration
echo "<h2 id="mmlscluster">Cluster configurations  </h2>"
/usr/lpp/mmfs/bin/mmlscluster > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
####################### List of GPFS filesystems 
echo "<h2 id="gpfsfs">List of GPFS filesystems  </h2>"
 /usr/lpp/mmfs/bin/mmlsmount all  > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################List of GPFS disks 
echo "<h2 id="gpfspv">List of GPFS disks </h2>"
#lspv |grep nsd* > /tmp/output
cat /tmp/ls_pvinfo |grep nsd* > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
#######################Cluster status 
echo "<h2 id="gpsfstat">Cluster status</h2>"
/usr/lpp/mmfs/bin/mmgetstate -a > /tmp/output
echo "<pre>`cat /tmp/output`</pre>"
echo "<a href="#">Go to top</a>"
rm -f /tmp/output
####################
fi




echo "</body></Html>"


}

html_header > /tmp/html_header
precheck_validation > /tmp/precheck_validation
hc_satus > /tmp/hc_satus

cat /tmp/html_header >> $FILE_LO
cat /tmp/hc_satus >> $FILE_LO
cat /tmp/precheck_validation >> $FILE_LO



rm -f /tmp/rootdisk_path
rm -f /tmp/PRE_NONASM_HEAD_Disk_list
rm -f /tmp/PRE_ASM_PVIDERR
rm -f /tmp/PRE_ASM_OWNERERR
rm -f /tmp/PRE_ASM_HEAD_Disk_list
rm -f /tmp/PRE_ASM_Disk_list
rm -f /tmp/PRE_ALL_Disk_list
rm -f /tmp/Disk_list
rm -f /tmp/PRE_NONASM_Disk_list
rm -f /tmp/PRE_DISK_CHECK
rm -f /tmp/FILE_LOC
rm -f /tmp/dfout
rm -f /tmp/ifcon1_out
rm -f /tmp/fshighoutput
rm -f /tmp/HCSTATUS
rm -f /tmp/html_header
rm -f /tmp/precheck_validation
rm -f /tmp/hc_satus


########################MAIL TO CC##########

CCER_COUNT=`cat /tmp/IBMUNIXCC | wc -l `
SRER_COUNT=`cat /tmp/IBMUNIXSR | wc -l `


if [ $CCER_COUNT != 0 ]; then

########################
DATE=`date "+%Y-%m-%d"`

HOSTNAME=`uname -n`

export MAILTO="kp-ss-unix@wwpdl.vnet.ibm.com"

export FROM=$HOSTNAME"@kp.com"

export CONTENT="/tmp/IBMUNIXCC"

export SUBJECT="Health check validation report- ${DATE} for server $HOSTNAME"

(

echo "Subject: $SUBJECT"

echo "MIME-Version: 1.0"

#echo "Content-Type: text/html"

#echo "Content-Disposition: inline"

cat $CONTENT

) | /usr/sbin/sendmail -f $FROM $MAILTO
fi

if [ $SRER_COUNT != 0 ]; then

########################
DATE=`date "+%Y-%m-%d"`

HOSTNAME=`uname -n`

export MAILTO="kp_unix_sr@wwpdl.vnet.ibm.com"

export FROM=$HOSTNAME"@kp.com"

export CONTENT="/tmp/IBMUNIXSR"

export SUBJECT="Health check validation report- ${DATE} for server $HOSTNAME"

(

echo "Subject: $SUBJECT"

echo "MIME-Version: 1.0"

#echo "Content-Type: text/html"

#echo "Content-Disposition: inline"

cat $CONTENT

) | /usr/sbin/sendmail -f $FROM $MAILTO
fi



