#!/bin/bash


# Program to create a movie from snapshots and upload it to youtube
# Requirement:
#   ffmpeg installed
#   raspistill installed
#   perl installed
#   upload script provided by youtube. See ankarres.de for details.
#
#   Credits to hagenfragen.de and to ankarres.de.
#
# v0.01     -- 16.01.2019   -- noviceiii   -- initial version

# ------------------------- SETTINGS -------------------------- #

TMPPICTR="/tmp/snapshots"                                       # path to folder where the snapshot picture is stored
TMPMOVIE="/tmp/movies"                                          # path to folder where the final movie file is stored

TSFILE=`date +"%Y-%m-%d_%H%M%S_%z_%a_%N"`                       # timestamp to add on file name
TSFOLDR=`date +"%Y-%m-%d-%N"`                                   # timestamp to add on folder name
TSMFILE=`date +"%Y-%m-%d-%N"`                                   # timestamp for movie file name
TSINFO=`date +"%A %m.%d.%Y"`                                    # timestamp to include in Video Description

INTERVAL=10000                                                  # interval of pictures taken in miliseconds: 10sec = 10000ms; 15min = 900000ms;
TIMESPAN=60000                                                  # time span how long the pictures shall be taken: 24h = 86400000ms; 1 min = 60000ms; 1h = 3600000


# -------------------------- PROGRAM -------------------------- #
DEBUG=" NONE "
CMD=""

# create folder for snapshot and movie
mkdir -p "$TMPPICTR/"
mkdir -p "$TMPMOVIE/"

# folder name for pictures work directory
WRKPICTR="$TMPPICTR/$TSFOLDR"

# create directory for pictures
mkdir -p "$WRKPICTR/"

# take picture. Use "raspistill 2>&1 | less" for help
raspistill --width 2592 --height 1944 -o $WRKPICTR/snapshot-%04d.jpg -ex auto -tl $INTERVAL -t $TIMESPAN


# folder name for movies output directry
WRKMOVIE="$TMPMOVIE/$TSFOLDR"

# create directory for movie
mkdir -p "$WRKMOVIE/"

# create movie file (with sound) 
ffmpeg -thread_queue_size 5000 -r 30 -f image2 -s 1920x1080 -i $WRKPICTR/snapshot-%04d.jpg -i /tmp/SandsOfMorocco.mp3 -vcodec libx264 -acodec copy -crf 25 -s 2592x1944 $WRKMOVIE/myprefix_$TSMFILE.mp4

# TODO
# verify that file has been created

# upload movie to youtube. See https://jankarres.de/2013/07/raspberry-pi-youtube-video-upload-server/ for further details
# python youtube_upload/youtube_upload.py --email=webmaster@jankarres.de --password="PASSWORD" --title="A NICE TITLE" --description="A NEAT DESCRIPTION" --category=TimeLaps $WRKMOVIE/myprefix_$TSMFILE.mp4

# remove pictures folder
rm -r "$TMPPICTR"

# remove ffmpeg movie
rm -r "$TMPMOVIE"

exit 0
