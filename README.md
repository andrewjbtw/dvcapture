A set of bash scripts for transferring DV and HDV tape content to files on a Linux-based system.

# Introduction

If you need to capture data from DV or HDV tape onto a computer using the Firewire connection, these scripts might help you out. They were created to make it possible to transfer tapes to files using the bash command-line to control the deck, capture the data, run a minimal set of QC processes using DV Analyzer, and create packages for archival storage.

## The scripts

There are four scripts in all, two of which are specific to the working context in which they were created (the Computer History Museum), and two of which I've tried to make as generalizable as possible. My hope is that anyone can run the core *control-deck.sh* and *dvanalyze.sh* scripts, which can be called from other scripts or run independently. 

The other two scripts (*dvcapture.sh* and *qc.sh*) are interactive and can be seen as wrappers around the core scripts. These would have to be modified to fit your environment, as they enforce certain local metadata and naming conventions. But they could be useful examples of what it is possible to do.

### control-deck.sh
This controls the tape deck and uses dvgrab to capture data to a file. 

Usage : 

```
control-deck.sh -f <filename> -o <objects directory> -l <log directory> -p <preparation setting> [ -d <duration> ]
```

Required:

*-f filename* (the name of the file to be created)

Do not include an extension with the filename. The script will attempt to capture DV to an MOV container by supplying the ".mov" extension in the dvgrab command. Based on testing, this seemed to be the most reliable container format to handle audio-video synchronization problems on tapes that have large number of audio errors. Other containers such as MKV and AVI resulted in files with audio-video synchronization drift. This could potentially be made configurable in the future.

Additional notes:

dvgrab will insert a numerical suffix into the file name. This seems to be done in order to handle situations where more than one file is created during the same capture process. There doesn't seem to be a way to prevent this, so you will have to modify the file name yourself in post-processing if you do not want the suffix.

If you do not set a duration, the script will attempt to capture from your starting point to the end of the tape in a single file. If you need multiple files and know the length of the clips you want, you can set a duration (see below) with the optional -d flag.

If the tape is HDV rather than DV, dvgrab will still try to capture the data, but the file will have an .m2t extension and use an MPEG2 codec. This seems to be hard-coded into how dvgrab works.

*-o object directory*

This is the directory where the video file should be created. The term "object" here comes from Archivematica's archival information package terminology, as the original goal in creating these scripts was to create archival packages for use with Archivematica.

*-l log directory*

Directory where the dvgrab log should be stored. 

*-p preparation setting*

Instructions on how the tape should be prepared before transfer. The options are:

repack -- fast-forward to the end and then rewind
rewind -- rewind from current position
continue -- start from current position

Optional:

*-d duration*

Optionally, set a duration. This should take the form of HH:MM:SS. Note that this is a length of time to record, not a timestamp of the ending point.

### dvanalyze.sh

Analyzes a DV file using DV Analyzer. The file "dvanalyzer.xsl" must be included in the same directory.

Usage: dvanalyze.sh






# Acknowledgements

These scripts are based on Dave Rice's earlier [dvcapture script](https://github.com/dericed/dvcapture "dericed's dvcapture github repository"). The commands to control the tape deck and parse the DV Analyzer output into an SVG chart are largely unchanged from that script.
