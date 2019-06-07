#!/bin/bash

# inputs needed
# 1. destination directory for video file
# 2. filename base pattern
# 3. logging directory

usage ()
{
    echo 'Usage : control-deck.sh -f <filename> -o <objects directory> -l <log directory> -p <preparation setting> [ -d <duration> ] '
    exit
}

if [ "$#" -eq 0 ]
then
    usage
fi

while [ "$1" != "" ]
do
    case "$1" in
        -f )    shift
                base_video_filename=$1
                ;;
        -o )    shift
                object_dir=$1
                ;;
        -l )    shift
                log_dir=$1
                ;;
        -p )    shift
                preparation=$1
                ;;
        -d )    shift
                duration=$1
                ;;
        * )     echo "Unknown option '$1' found! Quitting ..."
                exit
                ;;
    esac
    shift
done

# log for the dvgrab output
DVLOG=dvgrab_capture-${base_video_filename}.log

deps(){
        DEPENDENCIES="dvgrab dvanalyzer gnuplot md5deep dvcont"
 
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

errorExit(){

    message=$1
    echo "$message"
    echo "Exiting ..."
    exit 1
}

# check for dependencies
deps

# check if DV deck is connected
dvstatus=$(dvcont status)
if [ "$?" = "1" ] ; then
	echo "The DV deck is not found. Make sure the FireWire is attached correctly and that the deck is on."
	exit 1
fi

# check for object directory (i.e. where the video file will be created)
if [ ! -d "$object_dir" ]
then
    errorExit "Objects directory $object_dir not found!"
fi

if [ ! -d "$log_dir" ]
then
    errorExit "Log directory $log_dir not found!"
fi

# check if a duration has been supplied
if [ ! -z "$duration" ]
then
    has_duration=true
    # validate duration format
    if [[ "$duration" =~ ^[0-9][0-9]:[0-5][0-9]:[0-5][0-9]$ ]] 
    then
        echo "Capturing a duration of $duration"
    else
        errorExit "Duration $duration is not valid. Please enter duration as HH:MM:SS"
    fi
else
    has_duration=false
fi

dvstatus=$(dvcont status)
while [ "$dvstatus" = "Loading Medium" ] ; do 
    echo -n "Insert cassette, hit [q] to quit, or any key to continue. "
    read -r insert_response
    if [ "$insert_response" = "q" ] ; then
    	exit 1
    else
        dvstatus=$(dvcont status)
    fi
done

if [ "$preparation" = "repack" ] ; then
    dvcont stop
    echo "Fast Forwarding..."
    dvcont ff
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)
    echo "Rewinding..."
    dvcont rewind
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)

elif [ "$preparation" = "rewind" ] ; then
    dvcont stop
    echo "Rewinding..."
    dvcont rewind
    (stat=$(dvcont status); while [[ "$stat" != "Winding stopped" ]]; do sleep 2; stat=$(dvcont status); done)

elif [ "$preparation" = "continue" ] ; then
    dvcont stop
    echo "Starting from current position..."
fi

# tape capture section
echo "If the video on the tape ends AND the timecode stops incrementing below, then please press STOP on the deck to end the capture."
echo "Starting tape capture ..."

# enter subshell to change to object directory for tape transfer
# avoids encoding the full path to the file to DVLOG and makes it easier to read real-time stats during capture

if [ "$has_duration" == false ]
then
    echo "running without duration"
    (cd "$object_dir" && dvgrab -f raw -showstatus -size 0 "${base_video_filename}_.mov" 2>&1 | tee "$log_dir/${DVLOG}") || errorExit "Error: Video capture failed."
    dvcont rewind &
else
    (cd "$object_dir" && dvgrab -f raw -showstatus -size 0 -d "$duration" "${base_video_filename}_.mov" 2>&1 | tee "$log_dir/${DVLOG}") || errorExit "Error: Video capture failed."
fi

echo "finished capture ..."
