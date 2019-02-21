#!/bin/bash

# dvanalyzer analysis

capture_file=$1
log_dir=$2

# todo: validate file and folder input
if [ ! -d "$log_dir" ]
then
    echo "$log_dir" not found
    exit 1
fi

if ( echo "$capture_file" | grep "\.m2t$") # checks for ".m2t" extension
then
    echo "This is an .m2t file. Skipping dvanalyzer." # dvanalyzer doesn't run on .m2t
else
    scriptdir=$(dirname "$0")
    filename=$(basename "$capture_file")
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
	    set output '$outputdir/${filename%.*}_dvanalyzer.svg'
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
	    plot '' u (\$1/29.97):(\$3) title 'Channel 1 Audio Error (percentage)' lt 2 with impulses
	    plot '' u (\$1/29.97):(\$4) title 'Channel 2 Audio Error (percentage)' lt 3 with impulses 
	    set yrange [ -100:100 ]
	    plot '' u (\$1/29.97):(\$5) title 'Audio Error Head Difference' lt 4 with impulses" | gnuplot
	    echo Done
	    fi
    else
	    echo "ERROR - $capture_file is not a DV file"
    fi
fi
