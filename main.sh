#!/bin/bash

#   Raspii Time Lapse from sunrise to sunset with text overlay,
#   Backup on remote linux server, upload to youtube.
#   Version 3.1, August 27th by Oliver.

#   Please see credits, sources and help on github.
#
#   Mind, for a 1k (HD) resolution, 1 second interval and 25 frames
#   it requires around 25GB of processing space.
#
#   Change below values according your needs.


INTERVAL=2                                          # INT. take picture in that interval in seconds
offSTART=1                                          # INT. Offset Hour to start before sunrise
offEND=1                                            # INT. Offset Hour to quit after sunset
RESW="1920"                                         # STRING. resolution width
RESH="1080"                                         # STRING. resolution height
DT=0.055					                                       # FLOAT. Time to display one picture in seconds (0.040 equals to 25 frames per second)
vidpref="MYFILE_Timelapse"                          # STRING. Prefix for final video name.
LOCATION="SZXX0006"                                 # STRING. Location to set sunset/sunrise
TDIR="/tmp"                                         # STRING. temporary directory
FPATH="/PATH/PATH/Roboto-Regular.ttf"               # STRING. full path to font file. Optain from google fonts
WFILE="/PATH/PATH/timelapse/weather.txt"            # STRING. full path to file with weather information
debug=0                                             # BOOLEAN. 1 to enable. Ignores time dependend start and stop.


# ------------------------------------------------------------------------------------------------------------------------------------------- 

#### INIT ####
echo "** INIT"
#    set parameters and init program

ts_path=`date +%Y-%m-%d_%H%M%S`             # time stamp for filenames and directories

wdir="$TDIR/$ts_path"                       # full path to temporary work directory
resxy="${RESW}x${RESH}"                     # image/video size in HEIGHTxWIDTH
fr=`echo 1/${DT} | bc`                      # calculate frame rate by the picture display time

fin=1                                       # exit parameter in loop
j=0                                         # counter for previous iteration 
i=1                                         # counter for current iteration

tnow1=$(date +%H:%M)                        # current time in HH:MM
snow1=$(date +%s -d "${tnow1}")             # current time in seconds

# Get sunrise and sunset raw data from weather.com
sun_times=$( curl -s  https://weather.com/weather/today/l/$LOCATION sed 's/<span/\n/g' | sed 's/<\/span>/\n/g'  |\
 grep -E "dp0-details-sunrise|dp0-details-sunset" | tr -d '\n' | sed 's/>/ /g' | cut -d " " -f 4,8 )

# Extract sunrise and sunset times and convert to 24 hour format
tsunrise=$(date --date="`echo $sun_times | awk '{ print $1}'` AM" +%R)
tsunset=$(date --date="`echo $sun_times | awk '{ print $2}'` PM" +%R)

# to seconds
ssunrise=`date +%s -d ${tsunrise}`
ssunset=`date +%s -d ${tsunset}`

# calculate when to start and end the script
# it is from sunrise to sunset plus/minus the offsets
sstart=$((offSTART*3600))
sstarttime=$(( ssunrise - sstart ))         # when to start the script in seconds
send=$((offEND*3600))
sendtime=$(( ssunset + send ))              # when to end the script in seconds

# wait until sunset minus offset to start, if needed
if [ $debug -eq 1 ]; then
    echo "Debugging mode is on. Starting imedately."
elif [ $snow1 -lt $sstart ]; then
    offwait=$(( sstarttime - snow1 )) 
    if [ $offwait -lt 0 ]; then
        offwait=0
    fi
    echo "Sunrise at $ssunrise. Offset $offSTART hrs. It is $tnow1. Waiting $offwait second(s)..."
    sleep $offwait
fi

### INIT END ##


#### INTRO ####
echo "** INTRO"
#    It requires an initial picture and video to begin with.

# create working directory
if mkdir -p "$wdir" ; then
    echo "Successfully created $wdir."
else
    echo "Unable to create $wdir."
    exit
fi

# create initial picture from cam
raspistill -w $RESW -h $RESH -q 100 -o "$wdir/pic_inital.jpg" 
if [ $? -eq 0 ]; then
    echo "Successfully created $wdir/pic_inital.jpg."
else
    echo "Unable to create $wdir/pic_inital.jpg."
    exit
fi

# -- create initial video from picture
avconv -loglevel panic -t 0 -s $resxy -pix_fmt yuvj420p -t $DT -i "$wdir/pic_inital.jpg" \
-y "$wdir/mainvid_00000.mp4"
if [ $? -eq 0 ]; then
    echo "Successfully created $wdir/mainvid_00000.mp4."
    rm "$wdir/pic_inital.jpg" 
else
    echo "Unable to create $wdir/mainvid_00000.mp4."
    exit
fi

## INTRO END #


#### LOOP ####
echo "** LOOP"
#    ongoing picture and video creation.
#    Exits when sunset (plus offset time) is reached.

while [ $fin -eq 1 ]
do
    # current time in seconds
    tnow2=$(date +%H:%M) 
    snow2=$(date +%s -d "${tnow2}")
    sdiff=$(( snow2 - snow1 ))

    # wait for the interval time
    # minus the past processing time
    tsleep=$(( INTERVAL - sdiff ))
    if [ $tsleep -le $INTERVAL ]; then
        tsleep=0
    fi

    echo "Sleeping for $tsleep second(s)..."
    sleep $tsleep

    # format counters with leading zeros
    n=`printf "%05d" $i`
    m=`printf "%05d" $j`

    # read weather file
    weather=`cat ${WFILE}`

    # time
    tsoverlay=`date "+%d.%m.%Y %H:%M:%S"`

    # create overlay text and escape special chars 
    otext="$tsoverlay | Sunrise: $tsunrise | Sunset: $tsunset | $weather | $n"
    otext="${otext//:/\\:}"
    otext="${otext//|/\\|}"
    otext="${otext//°/\\°}"
    otext="${otext//%/\\\\%}"
    otext="${otext////\\/}"

    echo "Overlay Text -- $otext"

    # create a picture
    raspistill -w $RESW -h $RESH -q 100 -o "$wdir/pic_$n.jpg"
    if [ $? -eq 0 ]; then
        echo "Successfully created picture $i as $wdir/pic_$n.jpg."
    else
        echo "Unable to create pciture $i as $wdir/pic_$n.jpg."
        exit
    fi

    # add text to picture
    avconv -loglevel panic -i "$wdir/pic_$n.jpg" \
    -vf drawtext="fontfile=$FPATH: \
    text='$otext': fontcolor=white: fontsize=28: box=1: boxcolor=black@0.5: \
    boxborderw=5: x=w-tw-10: y=h-th-10" \
    -y "$wdir/pic_txt_$n.jpg"

    if [ $? -eq 0 ]; then
        echo "Successfully added text to picture $i as $wdir/pic_txt_$n.jpg."
        if [ $debug -eq 1 ]; then
            echo "Won't delete $wdir/pic_$n.jpg as debugging is enabled."
        else
            rm "$wdir/pic_$n.jpg"
        fi
    else
        echo "Unable to add text to picture $i as $wdir/pic_txt_$n.jpg."
        exit
    fi

    # create a video out of the picture with text.
    # -t seconds to display a picture, -s resolution, -qscale quality, -crf quality
    avconv -loglevel panic -loop 1 -i "$wdir/pic_txt_$n.jpg" \
    -t $DT -s $resxy -crf 18 \
    -y "$wdir/pic_txt_vid_$n.mp4"

    if [ $? -eq 0 ]; then
        echo "Successfully added picture pic_txt_$n.jpg to video $wdir/pic_txt_vid_$n.mp4."
        if [ $debug -eq 1 ]; then
            echo "Won't delete $wdir/pic_txt_$n.jpg as debugging is enabled."
        else
            rm "$wdir/pic_txt_$n.jpg"
        fi
    else
        echo "Unable to create video $wdir/pic_txt_vid_$n.mp4 from picture pic_txt_$n.jpg"
        exit
    fi

    # join the videos
    avconv -loglevel panic -r $fr -i "$wdir/mainvid_$m.mp4" -i "$wdir/pic_txt_vid_$n.mp4" \
    -filter_complex "[0:v:0][1:v:0]concat=n=2:v=1[outv]" -map "[outv]" -crf 18 \
    -y "$wdir/mainvid_$n.mp4"

    if [ $? -eq 0 ]; then
        echo "Successfully joined video $i $wdir/pic_txt_vid_$n.mp4 to video $j $wdir/mainvid_$m.mp4."
        if [ $debug -eq 1 ]; then
            echo "Won't delete $wdir/pic_txt_vid_$n.mp4 as debugging is enabled."
        else
            rm "$wdir/pic_txt_vid_$n.mp4"
        fi
    else
        echo "Unable to join video $i $wdir/pic_txt_vid_$n.mp4 to video $j $wdir/mainvid_$m.mp4."
        exit
    fi

    # just one more
    i=`expr 1 + ${i}`
    j=`expr 1 + ${j}`

    # set time at end of process
    tnow1=$(date +%H:%M)
    snow1=$(date +%s -d "${tnow2}")

    # set fin to 0 if end of day is reached. This will exit the loop.
    if [ $debug -eq 1 ]; then
        echo "Debugging mode is on. Current iteration: $i."
        if [ $i -eq 3 ]; then
            echo "Setting exit flag."
            fin=0
        fi
    elif [ $snow1 -gt $sendtime ]; then
        echo "$tnow1 is the time to exit the loop. Sunset at $tsunset. Offset $offEND hrs. Exit continious image creation."
        fin=0
    fi

done

## LOOP END #


#### OUTRO ####
echo "** OUTRO"

# create final video
tsfriendly=`date +%d.%m.%Y`
finfile=${vidpref}_${tsfriendly}
mv "$wdir/mainvid_$n.mp4" "$wdir/$finfile.mp4"

if [ $? -eq 0 ]; then
    echo "Successfully created final video from $wdir/mainvid_$n.mp4 as $wdir/$finfile.mp4."
    if [ $debug -eq 1 ]; then
        echo "Won't delete $wdir/mainvid_$n.mp4 as debugging is enabled."
    else
        rm "$wdir/mainvid_$n.mp4"
    fi
else
    echo "Unable to create video from $wdir/mainvid_$n.mp4 as $wdir/$finfile.mp4."
    exit
fi

if [ $debug -eq 1 ]; then
    echo "Won't upload video as debugging is enabled."
else
    # copy video file to backup
    # scp "$wdir/$finfile.mp4" USEER@SERVER:/PATH/PATH/

    # youtube meta data
    YDESC="TimeLaps from $tsfriendly."

    # TODO: CUSTOM STRINGS. For now, change below
    # upload to youtube
    /usr/local/bin/youtube-upload \
    --title="Title Text $tsfriendly" \
    --description="$YDESC" \
    --tags="Timelaps, Tag" \
    --default-language="de" \
    --default-audio-language="de" \
    --client-secrets="/home/pi/client_secrets.json" \
    --credentials-file="/home/pi/my_credentials.json" \
    --playlist="PLAYLIST" \
    --privacy public \
    --location latitude=47.2066136,longitude=7.5353353 \
    --embeddable=True \
    "$wdir/$finfile.mp4"
fi

if [ $debug -eq 1 ]; then
    echo "Won't delete directory $wdir as debugging is enabled."
else
    echo "Deleting temp directory $wdir."
    rm -r "$wdir"
fi

echo "** All done. Like tears in the rain. **"
