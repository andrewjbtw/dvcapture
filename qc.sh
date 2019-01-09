#!/bin/bash

# Interactively generates a quality control log.
# Takes a single file path as an input and outputs a report as a text file in the submission documentation folder.

# base path to location for captured files
capture_dir=/storage/dvgrabs

echo "Enter the catalog number:"
read catnum
echo "Enter the tape number:"
read tapenum
echo "Enter the container [generally "mov" or "m2t"]:"
read container

package_path=$capture_dir/$catnum # where all files from each set of tapes is stored
video_file=$package_path/objects/$catnum/$catnum-02-$tapenum-src.$container # path to file being QC-ed
file_name=$catnum-02-$tapenum-src.$container # name of file being QC-ed
documentation_path=$package_path/metadata/submissionDocumentation/$catnum-02-$tapenum-src 
dvanalysis_path=$documentation_path/$catnum-02-$tapenum-src_analysis


if [ ! -f "$video_file" ]
then
    echo "No video file found for catalog number "$catnum", tape "$tapenum"."
    echo "$video_file"
    exit 1
fi
    
if [ "$container" = "m2t" ]
then
    echo "This is an m2t file. No dvanalyzer graph was created."
else
    if [ ! -d "$dvanalysis_path" ]
    then
        echo "dvanalyzer has not been run for $catnum-02-$tapenum-src.$container"
        exit 1
    else
        echo "Opening dvanalyzer graph ..."
        xdg-open "$dvanalysis_path/$catnum-02-$tapenum-src_dvanalyzer.svg"
    fi    
fi
    
    


# Note significant errors to check for
# Examples: "Many 
# Open video file

# 
