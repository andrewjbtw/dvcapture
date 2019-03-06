#!/bin/bash

# inputs needed
# 1. destination directory for video file
# 2. filename base pattern
# 3. logging directory

object_dir=$1
base_video_filename=$2
log_dir=$3
prepanswer=$4
DVLOG=dvgrab_capture-${base_video_filename}.log

deps(){
        DEPENDENCIES="dvgrab dvanalyzer gnuplot ffmpeg md5deep dvcont"
 
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

# check for dependencies
deps

# check if DV deck is connected
dvstatus=$(dvcont status)
if [ "$?" = "1" ] ; then
	echo "The DV deck is not found. Make sure the FireWire is attached correctly and that the deck is on."
	exit 1
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

#answer=$(offerChoice "How should the tape be prepared?: " "PrepareMethod" "'Full repack then start' 'Rewind then start' 'Start from current position'")
#echo "$answer" >> "$tmplog"
#prepanswer=$(echo "$answer" | cut -d: -f2)

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

# tape capture section
echo "If the video on the tape ends AND the timecode stops incrementing below, then please press STOP on the deck to end the capture."
echo "Starting tape capture ..."

# enter subshell to change to object directory for tape transfer
# avoids encoding full path to file to DVLOG and makes it easier to read real-time stats during capture
(cd "$object_dir" ; dvgrab -f raw -showstatus -size 0 "${base_video_filename}_.mov" 2>&1 | tee "$log_dir/${DVLOG}")

echo "finished capturing tape..."
dvcont rewind &
