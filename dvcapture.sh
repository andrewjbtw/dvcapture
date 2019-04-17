#!/bin/bash

# tape capture directory
# this is where the video files are created by dvgrab
capture_dir=/home/dvcapture/Videos/dvgrabs

# file storage directory
# this is where files are stored after capture
storage_dir=/media/storage/dvgrabs

#enter technical defaults
CaptureDeviceSoftware="ffmpeg,dvcapture.sh, CHM version"
PlaybackDeviceManufacturer="Sony"
PlaybackDeviceModel="HVR-M15AU"
PlaybackDeviceSerialNo="011884"
Interface="IEEE 1394"

EXPECTED_NUM_ARGS=0

deps(){
        DEPENDENCIES="dvgrab dvanalyzer gnuplot ffmpeg md5deep dvcont xsltproc"
 
        deps_ok=YES
        for dep in $DEPENDENCIES ; do
                if [ ! "$(which "$dep")" ] ; then
                        echo -e "This script requires $dep to run but it is not installed"
                        echo -e "If you are running ubuntu or debian you might be able to install $dep with the following command"
                        echo -e "sudo apt install $dep"
                        deps_ok=NO
                fi
        done
        if [[ "$deps_ok" == "NO" ]]; then
                echo -e "Unmet dependencies   ^"
                echo -e "Aborting!"
                exit 1
        else
                return 0
        fi
}

ask(){
	# This function requires 3 arguments
	# 1) A prompt
	# 2) The label for the metadata value
    # This prompt is for a free text response
    read -erp "$1" response
    if [ -z "$response" ] ; then
    	ask "$1" "$2"
    else
    	echo "${2}: ${response}"
    fi
}

offerChoice(){
	# This function requires 3 arguments
	# 1) A prompt
	# 2) The label for the metadata value
	# 3) A vocabulary list
    # This function sets up a menu of options
	PS3="$1"
	label="$2"
    choices_csv=$3
    IFS=',' read -a choices <<< "$choices_csv"

	select option in "${choices[@]}"
	do
        if [ "$REPLY" -gt 0 2>/dev/null ] && [ "$REPLY" -le ${#choices[@]} 2>/dev/null ]
        then
        break
    else
        echo "You entered $REPLY" >&2
        echo "Please choose a number from the list." >&2
    fi	
	done
	   echo "${label}: ${option}"
}

yesorno(){
# this function prompts users to enter 'y' or 'n' until they do
while true
do
    read -rp "(y/n): " choice
    case "$choice" in
        y|Y ) echo "y"
            return ;;
        n|N ) echo "n"
            return ;;
        * ) continue ;;
    esac
done
}

errorExit(){

    message=$1
    echo "$message"
    echo "Exiting ..."
    exit 1
}

if [ $# -ne $EXPECTED_NUM_ARGS ] ; then
   echo "dvcapture is meant to be run interactively. Please do not enter arguments on the command line."
   exit 0
fi

cleanUp(){
    if [ -f /tmp/dv_capture ]
    then
        echo -e "\ndvcapture.sh: Cleaning up temporary log file."
        rm -v /tmp/dv_capture
    fi
}

trap cleanUp EXIT


#deps

# check if DV deck is connected
echo "Checking for DV deck ..."
#dvcont status 1>/dev/null # Standard output is discarded because this is just a check for errors.
if [ "$?" = "1" ] ; then
	echo "The DV deck is not found. Make sure the FireWire is attached correctly and that the deck is on."
	exit 1
fi


# setting static process metadata
echo
echo "CaptureDeviceSoftware: $CaptureDeviceSoftware"
echo "PlaybackDeviceManufacturer: $PlaybackDeviceManufacturer"
echo "PlaybackDeviceModel: $PlaybackDeviceModel"
echo "PlaybackDeviceSerialNo: $PlaybackDeviceSerialNo"
echo "Interface: $Interface"
echo
answer=$(offerChoice "Do these values match your setup: " "setupcorrect" "Yes,No")
if [ "$answer" == "setupcorrect: No" ] ; then
    echo "Please edit these values in the header of $0 and rerun."
    exit
fi

# Create log in temporary location so log file isn't kept if script quits early
# TODO: clean up log file if early exit

tmplog=/tmp/dv_capture
touch "$tmplog"
echo "CaptureDeviceSoftware: $CaptureDeviceSoftware" > "$tmplog"
echo "PlaybackDeviceManufacturer: $PlaybackDeviceManufacturer" >> "$tmplog"
echo "PlaybackDeviceModel: $PlaybackDeviceModel" >> "$tmplog"
echo "PlaybackDeviceSerialNo: $PlaybackDeviceSerialNo" >> "$tmplog"
echo "Interface: $Interface" >> "$tmplog"

answer=$(ask "Please enter the Operator name: " "Operator")
echo "$answer" >> "$tmplog"
echo
answer=$(ask "Please enter the catalog number: " "catalog_number")
echo "$answer" >> "$tmplog"
catalog_number=$(echo "$answer" | cut -d: -f2 | sed 's/ //g')

# show basic descriptive metadata as a check against data entry errors
echo -e "\nSearching for descriptive metadata for $catalog_number : \n"
xmlstarlet sel -N x="urn:crystal-reports:schemas:report-detail" -t -m "x:CrystalReport/x:Details/x:Section[x:Field[@Name='IDNUMBER1']/x:Value = '$catalog_number']/x:Field" -v "concat(@Name,' : ',x:Value)" -n ingest-metadata.xml

echo -e "\nIs this the correct item?"
confirm_metadata=$(yesorno)
if [ "$confirm_metadata" == 'n' ]
then
    echo "Quitting."
    exit
fi

answer=$(ask "Please enter the tape number: " "Tape number")
echo "$answer" >> "$tmplog"
tape_number=$(echo "$answer" | cut -d: -f2 | sed 's/ //g')

# file name without extension
# extension will be determined when dvgrab runs
# extension could be "mov" or "m2t" depending on tape type
base_video_filename=${catalog_number}-02-${tape_number}-src

# objects directory where video files will be placed
# matches CHM folder structure for SIPs
object_dir="$capture_dir/$catalog_number/objects/$catalog_number" 
capture_base="$object_dir"/${base_video_filename}

# directory to keep logs
# matches metadata/submissionDocumentation structure from Archivematica SIP
log_dir="$capture_dir/$catalog_number/metadata/submissionDocumentation/${base_video_filename}"

# log for each run of dvcapture.sh
OPLOG=ingest_operator-${base_video_filename}.log

#check for existing file at same path
if [ -f "$capture_base.mov" ] || [ -f "$capture_base.m2t" ]
then
    echo "File(s) found with matching catalog number and tape number!"
    ls -lh "$object_dir"
    exit
fi

echo "Filename will be ${base_video_filename}.mov or ${base_video_filename}.m2t depending on the video format"
echo "File will be created at the following path: $capture_base.[extension]"
echo ""

answer=$(offerChoice "Please enter the tape format: " "SourceFormat" "DVCam,miniDV,DVCPRO")
echo "$answer" >> "$tmplog"
echo

answer=$(offerChoice "Please enter the tape cassette brand: " "CassetteBrand" "Sony,Panasonic,JVC,Maxell,Fujifilm")
echo "$answer" >> "$tmplog"
echo

answer=$(ask "Please enter the Cassette Product No. (example: DVM60, 124, 126L): " "CassetteProductNo")
echo "$answer" >> "$tmplog"
echo

answer=$(ask "Please enter the tape condition: " "CassetteCondition")
echo "$answer" >> "$tmplog"
echo

answer=$(offerChoice "How should the tape be prepared?: " "PrepareMethod" "Full repack then start,Rewind then start,Start from current position")
echo "$answer" >> "$tmplog"
prepanswer=$(echo "$answer" | cut -d: -f2)

startingtime=$(date +"%Y-%m-%dT%T%z")
echo -e "Adding tape $tape_number to ingest package for $catalog_number ...\n"

#set up package to match Archivematica ingest structure
mkdir -p "$object_dir" "$log_dir"

#copy log data to ingest package directory
mv "$tmplog" "$log_dir/$OPLOG"

# tape capture section
./control_deck.sh "$object_dir" "$base_video_filename" "$log_dir" "$prepanswer" || errorExit "Something went wrong during tape capture."

dvgrab_file="$(find "$object_dir" -type f -name "$base_video_filename*_*")"
if [ "$(echo "$dvgrab_file" | wc -l)" -ne 1 ] # check if dvgrab produced anything other than a single file
then
    echo "There was a problem with the files generated by dvgrab. Please check $object_dir"
    exit
fi

capture_file=${dvgrab_file/_001/}
echo "stripping suffix from dvgrab-generated filename"
mv -v "$dvgrab_file" "$capture_file"

endingtime=$(date +"%Y-%m-%dT%T%z")
echo "startingtime=$startingtime" >> "$log_dir/$OPLOG"
echo "endingtime=$endingtime" >> "$log_dir/$OPLOG"
echo "done with $capture_file"

# open subshell to cd into objects directory and run md5deep using relative path)
(cd "$object_dir" ; md5deep -el "$(basename "$capture_file")" > "$capture_dir/$catalog_number/metadata/submissionDocumentation/${base_video_filename}.md5")

# dvanalyzer analysis
./dvanalyze.sh "$capture_file" "$log_dir"

# rsync current capture files to storage directory
echo -e "\nCopying files to storage drive ..."
rsync -rvh --times --itemize-changes --progress "$capture_dir"/"$catalog_number" "$storage_dir"
