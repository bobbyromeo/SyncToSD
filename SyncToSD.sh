#Sync files with SD card. Copy over new files, delete old files

######################################################
# Customize these variables before using this script
######################################################
# This is the full path to the local folder you want to
# sync with your SD card. Make sure to keep a trailing
# slash at the end
LPATH=""

# This is the IP address assigned to the WiFi card.
# Works with hostname also if you have proper DNS
# configured
PRUSA=""

# Path to the folder where python scripts for
# handling Toshiba API are stored
SPATH=/usr/local/bin
######################################################

DEBUG=0
#export PATH=/usr/local/bin:$PATH
export PATH=$SPATH:$PATH
SDLS=$(which sdls)
SDRM=$(which sdrm)
SDPUT=$(which sdput)
GREP=$(which grep)
AWK=$(which awk)
CUT=$(which cut)
REV=$(which rev)
SED=$(which sed)
WC=$(which wc)
LS=$(which ls)
GCODE="${LPATH}*.gcode"
PCMD=$(which ping)
PING="${PCMD} -q -c3 -W 10 "
cd $LPATH

#Check if printer is online
${PING} ${PRUSA} > /dev/null
if [ $? -ne 0 ]; then
	#echo "Printer Offline"
	osascript -e "display notification \"3D Printer offline\" with title \"Cannot upload models\""
	exit 0
fi


#sdls -sa | grep .gcode | rev | cut -d ' ' -f5- | sed -e 's/^[[:space:]]*//' | cut -d ' ' -f2- | rev

SDCOUNT=$(${SDLS} -sa | ${GREP} .gcode | ${WC} -l | ${AWK} '{print $1}')
LOCOUNT=$(${LS} -1 *.gcode | ${WC} -l | ${AWK} '{print $1}')

#SDCARD=$(${SDLS} -sa | ${GREP} .gcode | ${AWK} '{print $1}')
#LOCALF=$(${LS} -1 *.gcode)

#ADDLIST=$(comm -13 <(${SDLS} -sa | ${GREP} .gcode | ${AWK} '{print $1}') <(${LS} -1 *.gcode))
#DELLIST=$(comm -23 <(${SDLS} -sa | ${GREP} .gcode | ${AWK} '{print $1}') <(${LS} -1 *.gcode))
#ADDLIST=$(comm -13 <(${SDLS} -sa | ${GREP} .gcode | ${REV} | ${CUT} -d ' ' -f5- | ${SED} -e 's/^[[:space:]]*//' | ${CUT} -d ' ' -f2- | ${REV}) <(${LS} -1 *.gcode))
#DELLIST=$(comm -23 <(${SDLS} -sa | ${GREP} .gcode | ${REV} | ${CUT} -d ' ' -f5- | ${SED} -e 's/^[[:space:]]*//' | ${CUT} -d ' ' -f2- | ${REV}) <(${LS} -1 *.gcode))

REMOTELIST=$(${SDLS} -sa | ${GREP} .gcode | ${REV} | ${CUT} -d ' ' -f5- | ${SED} -e 's/^[[:space:]]*//' | ${CUT} -d ' ' -f2- | ${REV} | ${SED} -e 's/[[:space:]]*$//')
ADDLIST=$(comm -13 <(echo "${REMOTELIST}") <(${LS} -1 *.gcode | ${SED} -e 's/[[:space:]]*$//'))
DELLIST=$(comm -23 <(echo "${REMOTELIST}") <(${LS} -1 *.gcode | ${SED} -e 's/[[:space:]]*$//'))
SAMELIST=$(comm -12 <(echo "${REMOTELIST}") <(${LS} -1 *.gcode | ${SED} -e 's/[[:space:]]*$//'))

#ADDLIST=$(comm -13 <(${SDLS} -sa | ${GREP} .gcode | ${REV} | ${CUT} -d ' ' -f5- | ${SED} -e 's/^[[:space:]]*//' | ${CUT} -d ' ' -f2- | ${REV} | ${SED} -e 's/[[:space:]]*$//') <(${LS} -1 *.gcode | ${SED} -e 's/[[:space:]]*$//'))
#DELLIST=$(comm -23 <(${SDLS} -sa | ${GREP} .gcode | ${REV} | ${CUT} -d ' ' -f5- | ${SED} -e 's/^[[:space:]]*//' | ${CUT} -d ' ' -f2- | ${REV} | ${SED} -e 's/[[:space:]]*$//') <(${LS} -1 *.gcode | ${SED} -e 's/[[:space:]]*$//'))

ADDCOUNT=$(echo $ADDLIST | ${GREP} .gcode | ${WC} -l)
DELCOUNT=$(echo $DELLIST | ${GREP} .gcode | ${WC} -l)
SAMECOUNT=$(echo $SAMELIST | ${GREP} .gcode | ${WC} -l)

if [ $DEBUG == 1 ]; then
        echo "SDCOUNT: '${SDCOUNT}'"
        echo "LOCOUNT: '${LOCOUNT}'"
        echo "DELLIST: '${DELLIST}'"
        echo "ADDLIST: '${ADDLIST}'"
        echo "ADDCOUNT: '${ADDCOUNT}'"
        echo "DELCOUNT: '${DELCOUNT}'"
        echo "SAMECOUNT: '${SAMECOUNT}'"
        exit 0
fi

if [ $ADDCOUNT == 0 ] && [ $DELCOUNT == 0 ] && [ $SAMECOUNT == 0 ]; then
        #Nothing more to do. Exit!
        #echo Nothing to do
	osascript -e "display notification \"Nothing to do\" with title \"SD Card Sync\""
        exit 0
fi

if [ $LOCOUNT == 0 ] && [ $SDCOUNT != 0 ]; then
        #Local folder is empty - no files to be copied and all remote to be deleted
        osascript -e "display notification \"Clearing SD card\" with title \"SD Card Sync\""
        ${SDRM} "*.gcode"
        exit 0
fi

OIFS="$IFS"
IFS=$'\n'

if [ $DELCOUNT -gt 0 ]; then
        #Delete files on SD card that are not available locally
        osascript -e "display notification \"${DELLIST}\" with title \"Removing Files\""
        for FOO in $DELLIST ; do
		FOO_NS="$(echo -e "${FOO}" | sed -e 's/[[:space:]]*$//')"
		#echo $FOO_NS
        	#echo "Deleting '${FOO_NS}'"
		${SDRM} "${FOO_NS}"
        done
fi

if [ $ADDCOUNT -gt 0 ] ; then
        #Copy local files to remote
	osascript -e "display notification \"${ADDLIST}\" with title \"Adding Files\""
        for FOO in $ADDLIST ; do
		FOO_NS="$(echo -e "${FOO}" | sed -e 's/[[:space:]]*$//')"
		#echo "Adding '${LPATH}${FOO_NS}'"
        	${SDPUT} "${LPATH}${FOO_NS}"
        done
fi

if [ $SAMECOUNT -gt 0 ]; then
        now=$(date +"%m-%d-%Y")
        #Determine if existing files need to be re-uploaded
        for FOO in $SAMELIST ; do
                filedate=$(date -r "${FOO}" "+%m-%d-%Y")
                if [ $now ==  $filedate ]; then
                        osascript -e "display notification \"Updated ${FOO}\" with title \"SD Card Sync\""
                        FOO_NS="$(echo -e "${FOO}" | sed -e 's/[[:space:]]*$//')"
                        ${SDPUT} "${LPATH}${FOO_NS}"
                fi 
        done
fi

IFS="$OIFS" 

osascript -e "display notification \"Done!\" with title \"Adding Files\""
