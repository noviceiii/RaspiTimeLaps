#!/bin/bash

#   Raspii Time Lapse from sunrise to sunset
#   Backup on remote linux server, upload to youtube
#   Version 2.3, March 23th by Oliver

# Calculate Sunrise/ Sunset with Lubos Rendek on linuxconfig chmod +x sunrise-sunset.sh
# youtube upload script https://github.com/tokland/youtube-upload

TDIR="/tmp"                                         # STRING. temporary directory
INTERVAL=2                                          # INT. take picture in that interval in seconds
RESW="2592"                                         # STRING. resolution width
RESH="1944"                                         # STRING. resolution height
LOCATION="SZXX0006"                                 # STRING. Location to set sunset/sunrise
offSTART=1                                          # INT. Offset Hour to start before sunrise
offEND=1                                            # INT. Offset Hour to quit after sunset
FPATH="/PATH/TO/Roboto-Regular.ttf"                 # STRING. full path to font file. Optain from google fonts
WFILE="/PATH/TO/timelapse/weather.txt"              # STRING. full path to file with weather information
DT=0.080					                        # FLOAT. Time to display one picture in seconds (0.040 is 25 frames per second)

# ----------------------------------------------------------------------------            

# timestamps
ts=`date +%Y-%m-%d_%H%M%S`
tsfriendly=`date +%d.%m.%Y`
tnow=$(date +%H:%M) 
stnow=`date +%s -d ${tnow}`

# working directory
wdir="$TDIR/$ts"   

# other init values
i=1
j=0
fin=1
resx="${RESW}x${RESH}"
fr=`echo 1/${DT} | bc`                              # frame rate from picture display time

# --- set time parameters ---

# Get sunrise and sunset raw data from weather.com
sun_times=$( curl -s  https://weather.com/weather/today/l/$LOCATION | sed 's/<span/\n/g' | sed 's/<\/span>/\n/g'  | grep -E "dp0-det
ails-sunrise|dp0-details-sunset" | tr -d '\n' | sed 's/>/ /g' | cut -d " " -f 4,8 )

# Extract sunrise and sunset times and convert to 24 hour format
sunrise=$(date --date="`echo $sun_times | awk '{ print $1}'` AM" +%R)
sunset=$(date --date="`echo $sun_times | awk '{ print $2}'` PM" +%R)

# to seconds
ssunrise=`date +%s -d ${sunrise}`
ssunset=`date +%s -d ${sunset}`
sstsart=$((offSTART*3600))
send=$((offEND*3600))

# format for drawtext. Escape :
fsunrise=`echo "${sunrise//:/$'\:'}"`
fsunset=`echo "${sunset//:/$'\:'}"`

# set offsets
sstsart=`expr ${ssunrise} - ${sstsart}`
send=`expr ${send} + ${ssunset}`

# wait until sunrise
if [ "$stnow" -le "$sstsart" ]; then
    swait=`expr ${sstsart} - ${stnow}`
    sleep $swait
fi

# --- do the visuals ---

# create working directory
mkdir "$wdir"

# first pic
raspistill -w $RESW -h $RESH -q 100 -o "$wdir/pic_inital.jpg"

# create an empty main vid
avconv -t 0 -s $resx -pix_fmt yuvj420p -t $DT -i "$wdir/pic_inital.jpg" \
-y "$wdir/mainvid_00000.mp4"

# remove initial pic
rm "$wdir/pic_inital.jpg" 

while [ $fin -eq 1 ]
do
    # current time
    tnow=$(date +%H:%M) 
    # to second
    stnow=`date +%s -d ${tnow}`

    # seconds since epoc at start of progressing
    sepoS=`date +%s`
    
    # format the counter
    n=`printf "%05d" $i`
    m=`printf "%05d" $j`

    # set hout and minutes for text overlay 
    cm=`date +%M`
    ch=`date +%H`

    # read weather file
    weather=`cat ${WFILE}`

    # full overlay text
    otext="${tsfriendly} \| ${ch}\:${cm} \| Sunrise\: ${fsunrise} \| Sunset\: ${fsunset} \| ${weather} \| ${n}"
    
    # take a first picture0
    raspistill -w $RESW -h $RESH -q 100 -o "$wdir/pic_$n.jpg"

    # create text on picture0
    avconv -i "$wdir/pic_$n.jpg" \
    -vf drawtext="fontfile=$FPATH: \
    text='$otext': fontcolor=white: fontsize=24: box=1: boxcolor=black@0.5: \
    boxborderw=5: x=w-tw-10: y=h-th-10" \
    -y "$wdir/pic_txt_$n.jpg"

    # create video1 from picture0 with txt 
    # -t seconds to display a picture, -s resolution, -qscale quality, -crf quality
    avconv -loop 1 -i "$wdir/pic_txt_$n.jpg" \
    -t $DT -s $resx -crf 18 \
    -y "$wdir/pic_txt_vid_$n.mp4"

    # join main -1 and picvideo0 into mainvid
    avconv -r $fr -i "$wdir/mainvid_$m.mp4" -i "$wdir/pic_txt_vid_$n.mp4" \
    -filter_complex "[0:v:0][1:v:0]concat=n=2:v=1[outv]" -map "[outv]" -crf 18 \
    -y "$wdir/mainvid_$n.mp4"

    # delete main picture
    rm "$wdir/pic_$n.jpg"

    # delete picture with text
    rm "$wdir/pic_txt_$n.jpg"

    # delete text overlay video
    rm "$wdir/pic_txt_vid_$n.mp4"

    # delete the previous maivideo from picture
    rm "$wdir/mainvid_$m.mp4"

    # seconds since epoc at end of progressing
    sepoE=`date +%s`

    # calculate the sleep time
    # to adjust with the durration of above progressing
    diffint=`expr ${sepoE} - ${sepoS}`
    newint=`expr ${INTERVAL} - ${diffint}`

    if [ "$newint" -lt 0 ]; then
        newint=0
    fi

    # wait for given second
    sleep $newint

    # add counter
    i=`expr 1 + ${i}`
    j=`expr 1 + ${j}`

    # see if sunset with offset has passed
    if [ "$stnow" -gt "$send" ]; then
        fin=0

        # rename the last video file
        mv "$wdir/mainvid_$n.mp4" "$wdir/MYVID_timelapse_$tsfriendly.mp4"
    fi
    
done  

# copy video file to backup
# scp "$wdir/MYVID_timelapse_$tsfriendly.mp4" USER@SERVERER:/PATH/PATH/

# TODO CUSTOM STRINGS. For now, change below
# upload to youtube
/usr/local/bin/youtube-upload \
  --title="MYVID Zeitraffer $tsfriendly" \
  --description=" "\
  --category="Travel & Events" \
  --tags="MYVID, Zeitraffer" \
  --default-language="de" \
  --default-audio-language="de" \
  --client-secrets="/home/pi/client_secrets.json" \
  --credentials-file="/home/pi/my_credentials.json" \
  --playlist="MYVID Zeitraffer" \
  --privacy public \
  --location latitude=47.2066136,longitude=7.5353353 \
  --embeddable=True \
  "$wdir/MYVID_timelapse_$tsfriendly.mp4"

rm -r "$wdir"
