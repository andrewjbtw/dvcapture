#!/bin/bash

# Interactively generates a quality control log.
# Takes a single file path as an input and outputs a report as a csv text file in the submission documentation folder.

# path to location of previously captured files
capture_dir=/media/storage/dvgrabs

usage ()
{
    echo 'Usage : qc.sh -c <catalog id> -t <tape number (zero padded)> [--analyze-only] <version>'                                                                                                 
    exit
}

if [ "$#" -eq 0 ]
then
    echo "Enter the catalog number:"
    read -r catnum
    echo "Enter the tape number:"
    read -r tapenum
fi

while [ "$1" != "" ]
do
    case "$1" in
        -c )    shift
                catnum=$1
                ;;
        -t )    shift
                tapenum=$1
                ;;
        --analyze-only )    shift
                analyze_only=true
                ;;
    esac
    shift
done

package_path=$capture_dir/$catnum

# Check if file exists and if it is an 'mov' or an 'm2t'
if [ -f "$package_path/objects/$catnum/$catnum-02-$tapenum-src.mov" ]
then
    container="mov"
elif [ -f "$package_path/objects/$catnum/$catnum-02-$tapenum-src.m2t" ]
then
    container="m2t"
else
    echo "No file for catalog number $catnum, tape $tapenum found."
    exit 1
fi


# where all files from each set of tapes is stored
video_file=$package_path/objects/$catnum/$catnum-02-$tapenum-src.$container # path to file being QC-ed
documentation_path=$package_path/metadata/submissionDocumentation
capture_log_path=$documentation_path/$catnum-02-$tapenum-src
dvanalysis_path=$capture_log_path/$catnum-02-$tapenum-src_analysis
QC_log=$documentation_path/$catnum-qc.csv

    
# If the file is DV, check if dvanalyzer has been run and open the chart for QC
if [ "$container" = "m2t" ]
then
    echo "This is an m2t file. No dvanalyzer graph was created."
else
    if [ ! -d "$dvanalysis_path" ]
    then
        echo "dvanalyzer has not been run for $catnum-02-$tapenum-src.$container"
        if [ ! -d "$capture_log_path" ]
        then
            mkdir -pv "$capture_log_path"
        fi
        ./dvanalyze.sh "$video_file" "$capture_log_path"
        echo "Opening dvanalyzer graph for $video_file ..."
        xdg-open "$dvanalysis_path/$catnum-02-$tapenum-src_dvanalyzer.svg" 2>/dev/null
    else
        echo "Opening dvanalyzer graph for $video_file ..."
        xdg-open "$dvanalysis_path/$catnum-02-$tapenum-src_dvanalyzer.svg" 2</dev/null
    fi    
fi

# if --analyze-only selected, then quit here without launching QC spreadsheet or video file
if [ "$analyze_only" == "true" ]
then
    exit
fi

# Note significant errors that should be reviewed by a person (audible or visible issues)
# Examples: "Many audio errors found in first 10 minutes."
# Create QC log file. Log file will be one per package, not one per tape
if [ -f "$QC_log" ]
then
    echo "Opening existing QC log."
else
    echo "Catalog number,Tape number,DV Analyzer summary,A/V sync issues?,Notes" >> "$QC_log"
    echo "Opening QC log."
fi

xdg-open "$QC_log"

# Open video file
echo "Press any key and hit Enter to open the video file."
read -r placeholder
vlc "$video_file" 2>/dev/null
