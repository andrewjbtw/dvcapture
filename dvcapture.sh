#!/bin/bash

#declare the label of the identifier associated with the ingest and resulting package. Other labels are declared directly in the use of the ask and offerChoice functions below.
sourceidlabel="SourceID"

#container format to use (use avi,mkv, or mov)
#choosing mov as default for capture because it seems to clear up potential audio sync issues that cpature to dv, avi, and mkv don't resolve
container="mov"

#declare directory for packages of dv files to be written to during processing

# commented out for testing
capture_dir=/home/dvcapture/Videos/dvgrabs

#CACHE_DIR=/tmp

#name of the log for user process data

#enter technical defaults
CaptureDeviceSoftware="ffmpeg,dv_capture.sh version 0.2"
PlaybackDeviceManufacturer="Sony"
PlaybackDeviceModel="HVR-M15AU"
PlaybackDeviceSerialNo="011884"
Interface="IEEE 1394"

EXPECTED_NUM_ARGS=0

deps(){
        DEPENDENCIES="dvgrab dvanalyzer gnuplot ffmpeg md5deep dvcont"
 
        deps_ok=YES
        for dep in $DEPENDENCIES ; do
                if [ ! $(which $dep) ] ; then
                        echo -e "This script requires $dep to run but it is not installed"
                        echo -e "If you are running ubuntu or debian you might be able to install $dep with the following command"
                        echo -e "sudo apt-get install $dep"
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
    read -ep "$1" response
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
	PS3="$1"
	label="$2"
	eval set "$3"
	select option in "$@"
	do
		break
	done
	echo "${label}: ${option}"
}

if [ $# -ne $EXPECTED_NUM_ARGS ] ; then
   echo "dvcapture is meant to be run interactively. Please do not enter arguments on the command line."
   exit 0
fi

deps

# check if DV deck is connected
dvstatus=$(dvcont status)
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
answer=`offerChoice "Do these values match your setup: " "setupcorrect" "'Yes' 'No'"`
if [ "$answer" == "setupcorrect: No" ] ; then
    echo "Please edit these values in the header of $0 and rerun."
    exit
fi

tmplog=/tmp/dv_capture
touch "$tmplog"
echo "CaptureDeviceSoftware: $CaptureDeviceSoftware" > "$tmplog"
echo "PlaybackDeviceManufacturer: $PlaybackDeviceManufacturer" >> "$tmplog"
echo "PlaybackDeviceModel: $PlaybackDeviceModel" >> "$tmplog"
echo "PlaybackDeviceSerialNo: $PlaybackDeviceSerialNo" >> "$tmplog"
echo "Interface: $Interface" >> "$tmplog"

answer=`ask "Please enter the Operator name: " "Operator"`
echo "$answer" >> "$tmplog"
echo
answer=`ask "Please enter the catalog number: " "catalog_number"`
echo "$answer" >> "$tmplog"
catalog_number=`echo "$answer" | cut -d: -f2 | sed 's/ //g'`
answer=`ask "Please enter the tape number: " "Tape number"`
echo "$answer" >> "$tmplog"
tape_number=`echo "$answer" | cut -d: -f2 | sed 's/ //g'`

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
log_dir="$capture_dir/$catalog_number/metadata/submissionDocumentation/capture-logs/${base_video_filename}"

# filenames for logs
DVLOG=dvgrab_capture-${base_video_filename}.log
OPLOG=ingest_operator-${base_video_filename}.log

#check for existing file at same path
if [ -f "$capture_base.mov" ] || [ -f "$capture_base.m2t" ]
then
    echo "File(s) found with matching catalog number and tape number!"
    ls -lh "$object_dir"
    exit
fi



echo "Filename will be ${base_video_filename}.${container}"
echo "File will be created at the following path: $capture_base.[extension]"
echo ""


answer=`offerChoice "Please enter the tape format: " "SourceFormat" "'DVCam' 'miniDV' 'DVCPRO'"`
echo "$answer" >> "$tmplog"
echo

answer=`offerChoice "Please enter the tape cassette brand: " "CassetteBrand" "'Sony' 'Panasonic' 'JVC' 'Maxell' 'Fujifilm'"`
echo "$answer" >> "$tmplog"
echo

answer=`ask "Please enter the Cassette Product No. (example: DVM60, 124, 126L): " "CassetteProductNo"`
echo "$answer" >> "$tmplog"
echo

answer=`ask "Please enter the tape condition: " "CassetteCondition"`
echo "$answer" >> "$tmplog"
echo

dvstatus=`dvcont status`
while [ "$dvstatus" = "Loading Medium" ] ; do 
    echo -n "Insert cassette: # ${id}, hit [q] to quit, or any key to continue. "
    read insert_response
    if [ "$insert_response" = "q" ] ; then
    	exit 1
    else
    	dvstatus=`dvcont status`
    fi
done

answer=`offerChoice "How should the tape be prepared?: " "PrepareMethod" "'Full repack then start' 'Rewind then start' 'Start from current position'"`
echo "$answer" >> "$tmplog"
prepanswer=`echo "$answer" | cut -d: -f2`
if [ "$prepanswer" = " Full repack then start" ] ; then
    dvcont stop
    echo "Fast Forwarding..."
    dvcont ff
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)
    echo "Rewinding..."
    dvcont rewind
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)

elif [ "$prepanswer" = " Rewind then start" ] ; then
    dvcont stop
    echo "Rewinding..."
    dvcont rewind
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)
fi

packageid=`cat "$tmplog" | grep "$sourceidlabel" | cut -d: -f2 | sed 's/ //g'`

startingtime=$(date +"%Y-%m-%dT%T%z")
echo "Adding tape $tape_number to ingest package for $catalog_number ..."
echo ""
echo "If the video on the tape ends AND the timecode stops incrementing below, then please press STOP on the deck to end the capture."

#set up package to match Archivematica ingest structure
mkdir -p "$object_dir" "$log_dir"

#copy log data to ingest package directory
mv "$tmplog" "$log_dir/$OPLOG"

# tape capture section
echo "starting tape capture"

dvgrab -f raw -showstatus -size 0 "${capture_base}_.mov" 2>&1 | tee "$log_dir/${DVLOG}"
#trap '	
echo "finished capturing tape..."

dvgrab_file="$(find "$object_dir" -type f -name "$base_video_filename*")"
if [ "$(echo "$dvgrab_file" | wc -l)" -ne 1 ]
then
    echo "There was a problem with the files generated by dvgrab. Please check $object_dir"
    exit
fi

capture_file=${dvgrab_file/_001/}
echo "stripping suffix from dvgrab-generated filename"
mv -v "$dvgrab_file" "$capture_file"

dvcont rewind &
endingtime=$(date +"%Y-%m-%dT%T%z")
echo "startingtime=$startingtime" >> "$log_dir/$OPLOG"
echo "endingtime=$endingtime" >> "$log_dir/$OPLOG"
echo done with "$capture_file"

#md5deep on objects
md5deep -etl "$capture_file" > "$capture_dir/$catalog_number/metadata/submissionDocumentation/md5-${base_video_filename}.txt"

## script can be split here to separate capture from QC

# dvanalyzer analysis

if ( echo "$capture_file" | grep "\.m2t$") # checks for ".m2t" extension
then
    echo "This is an .m2t file. Skipping dvanalyzer." # dvanalyzer doesn't run on .m2t
else
    scriptdir=`dirname "$0"`
    filename=`basename "$capture_file"`
    if [ -f "$capture_file" ] ; then
	    outputdir="$log_dir/${filename%.*}_analysis"
            if [ ! -d "$outputdir" ] ; then
	    mkdir -p "$outputdir"
	    # plot graph
	    echo Analyzing DV stream...
	    dvanalyzer </dev/null --XML "$capture_file"  > "$outputdir/${filename%.*}_dvanalyzer.xml"
	    xsltproc "$scriptdir/dvanalyzer.xsl" "$outputdir/${filename%.*}_dvanalyzer.xml" > "$outputdir/${filename%.*}_dvanalyzer_summary.txt"
	    echo Plotting results...
	    echo "set terminal svg size 1920, 1080 enhanced background rgb 'white'
	    set border 0
	    set datafile separator ','
	    set output '$outputdir/${filename%.*}${count}_dvanalyzer.svg'
	    set multiplot layout 4, 1 title 'DV Analyzer Graphs of $filename'
	    set style fill solid border -1
	    set xrange [ 0: ]
	    set yrange [ 0:100 ]
	    set grid y
	    unset xtics
	    set xdata time
	    set timefmt '%S'
	    set xtics format '%H:%M:%S'
	    set xtics nomirror
	    plot '$outputdir/${filename%.*}_dvanalyzer_summary.txt' u (\$1/29.97):(\$2) title 'Video Error Concealment (percentage)' lt 1 with impulses 
	    plot '' u (\$1/30):(\$3) title 'Channel 1 Audio Error (percentage)' lt 2 with impulses
	    plot '' u (\$1/30):(\$4) title 'Channel 2 Audio Error (percentage)' lt 3 with impulses 
	    set yrange [ -100:100 ]
	    plot '' u (\$1/30):(\$5) title 'Audio Error Head Difference' lt 4 with impulses" | gnuplot
	    echo Done
	    fi
    else
	    echo "ERROR - $name is not a DV file"
    fi
fi
