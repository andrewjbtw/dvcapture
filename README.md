A set of bash scripts for transferring DV and HDV tape content to files on a Linux-based system.

# Summary

If you need to capture data from DV or HDV tape onto a computer using the Firewire connection, these scripts might help you out. They were created to make it possible to transfer tapes to files using the bash command-line to control the deck, capture the data, run a minimal set of QC processes using DV Analyzer, and create packages for archival storage.

# The scripts

There are four scripts in all, two of which are specific to the working context in which they were created (the Computer History Museum), and two of which I've tried to make as generalizable as possible. My hope is that anyone can run the core **control-deck.sh** and **dvanalyze.sh** scripts, which can be called from other scripts or run independently. 

The other two scripts (**dvcapture.sh** and **qc.sh**) are interactive and can be seen as wrappers around the core scripts. These would have to be modified to fit your environment, as they enforce certain local metadata and naming conventions. But they could be useful examples of what it is possible to do.

#### control-deck.sh
This controls the tape deck and uses dvgrab to capture data to a file. 

Usage : 

```
control-deck.sh -f <filename> -o <objects directory> -l <log directory> -p <preparation setting> [ -d <duration> ]
```

Required parameters:

*-f filename* (the name of the file to be created)

Do not include an extension with the filename. The script will attempt to capture DV to an MOV container by supplying the ".mov" extension in the dvgrab command. Based on testing, this seemed to be the most reliable container format to handle audio-video synchronization problems on tapes that have a large number of audio errors. Other containers such as MKV and AVI resulted in files with audio-video synchronization drift when tested on the same set of tapes. The container could potentially be made configurable in the future.

Additional notes on filenaming:

dvgrab will insert a numerical suffix into the filename. This seems to be done in order to handle situations where more than one file is created during the same capture process. There doesn't seem to be a way to prevent this, so you will have to modify the filename yourself in post-processing if you do not want the suffix.

If you do not set a duration, the script will attempt to capture from your starting point to the end of the tape in a single file. If you need multiple files and know the length of the clips you want, you can set a duration (see below) with the optional -d flag.

If the tape is HDV rather than DV, dvgrab will still try to capture the data, but the file will have an .m2t extension and use an MPEG2 codec. This seems to be hard-coded into how dvgrab works.

*-o object directory*

This is the directory where the video file should be created. The term "object" here comes from [Archivematica](http://www.archivematica.org "Archivematica home page")'s archival information package terminology, as the original goal in creating these scripts was to create archival packages for use with Archivematica.

*-l log directory*

Directory where the dvgrab log should be stored. 

*-p preparation setting*

Instructions on how the tape should be prepared before transfer. The options are:

- repack -- fast-forward to the end and then rewind
- rewind -- rewind from current position
- continue -- start from current position

Optional:

*-d duration*

Optionally, set a duration. This should take the form of HH:MM:SS. Note that this is a length of time to record, not a timestamp of the ending point.

#### dvanalyze.sh

Analyzes a DV file using [DV Analyzer](https://mediaarea.net/DVAnalyzer "DV Analyzer home page"). The file "dvanalyzer.xsl" must be included in the same directory as the script.

Usage: 
```
dvanalyze.sh capture_file log_directory
```

The analysis will produce both an XML file with the DV Analyzer output, and an SVG chart displaying where audio and video errors occur along the file's timeline. This can be quite useful for guiding where to focus QC efforts.

#### dvcapture.sh

This is an interactive script and should not be called with any arguments. Some of its features are highly specific to the Computer History Museum's environment, such as its handling of metadata, file-naming conventions, and folder structure. As such, you will need to modify it to adapt it to your own workflows.

This script takes a small number of inputs:

- Catalog number
- Tape number
- Tape brand and type
- Tape condition
- Preparation instructions (repack, rewind, or continue)
- (Optional) duration of capture, if not capturing a whole tape

and produces the following outputs:

- A package (folder structure) that corresponds to Archivematica's "[transfer](https://www.archivematica.org/en/docs/archivematica-1.9/user-manual/transfer/transfer/#transfer "Archivematica transfer documentation")" package structure, with subfolders for "metadata" and "objects"
- A copy of each video file
- Checksums for each video file
- Logs of the tape capture process
- For DV files, the dvanalyze.sh outputs for each file

If a multiple tapes are associated together under one catalog number, they are all arranged in the same package. If there is only one tape, the tape number will be "01".

#### qc.sh

This script eases the process of quality control checking. It requires the file being reviewed to have been captured using dvcapture.sh, as it relies on files being arranged according to the package structure that script creates.

To run qc.sh, you must supply a catalog number and a tape number. This can be done either interactively or on the command line:
```
qc.sh -c <catalog number> -t <tape number (zero padded)>
```

qc.sh will then:

- Check if DV Analyzer has already been run on the given file
- If not, check if the file is DV
- If the file is DV, run DV Analyzer
- If the file is not DV (i.e. it's HDV), explain why there's no dvanalyze.sh outputs to view
- Open the DV Analyzer output chart (if a DV file) for inspection 
- Open a CSV file for the reviewer to input QC information -- this file will be saved to the package
- Open the video file in VLC for viewing

Note: there is still a "legacy" option in the code to run DV Analyzer only and not proceed with the rest of QC. That's now been superceded by the separation of dvanalyze.sh into its own standalone script for this purpose. The option is likely to be removed soon.

# Dependencies

These scripts rely on a lot of other tools. The biggest dependency might be Linux. It's not clear if it's possible to run dvgrab on Mac OS X. It might be possible to run many of these scripts under a Linux subsystem on Windows 10, but that would depend on whether the Linux installation can access a Firewire connection under Windows. Also, Windows 10 doesn't support graphical applications under Linux, though it may in the future.

In any case, these scripts have only been tested on Ubuntu, versions 14.04, 16.04, and 18.04.

Additional dependencies:

To run control-deck.sh and dvanalyze.sh, you need

- dvgrab - to capture the tape
- dvcont - to control the deck
- dvanalyzer - to analyze the DV
- xsltproc - to process the DV Analyzer XML
- gnuplot - to create the DV analysis SVG

Additionally, to run dvcapture.sh and qc.sh, you need

- md5deep - to generate the checksum
- xmlstarlet - to process the museum's metadata XML export
- vlc - to view the video file

# Acknowledgements

These scripts are based on Dave Rice's earlier [dvcapture script](https://github.com/dericed/dvcapture "dericed's dvcapture github repository"). The commands to control the tape deck and parse the DV Analyzer output into an SVG chart are largely unchanged from that script. Most of the additions and changes have been for the purpose of adapting that script to the Computer History Museum's workflows.
