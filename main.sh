#!/bin/bash

# First obtain a location code from: https://weather.codes/search/
# Lubos Rendek on linuxconfig chmod +x sunrise-sunset.sh

# requires ffmpeg and youtube upload python script on remote server and sshfs on local computer


LOCATION="SZXX0006"              # STRING. Insert your location. For example SZXX0006 is a location code for Bern, Switzerland. Requiret to calculate sunrise and sunset time.
tDIRSNAPS="/mnt/MYDIR"           # STRING. Path to temporary directory for snapshots. No tailing slash. Can be in the below mount dir.
tDIRVID="/mnt/MYDIR"             # STRING. Path to temporary directory for the videos. No tailing slash. Can be in below mount dir.

WARP=1                           # HOURS.  hours to start before sunrise and to run after sunset. Set to 0 for no waitin time. Full numbers only.
INTERVAL=2                       # MINUTES. Takes a snapshot every x minutes.
HOURFRM=1                        # MINUTES. How long one hour shall take in minutes

REMOTEUSR="USER"                 # STRING. Remote user name
REMOTESRV="SERVER"               # STRING. Remote sever address or name
REMOTDIR="REMOTDIR"              # STRING. Remote directory to put the files into no tailing slash
LOCALMNT="PATH TO LOCAL MOUNT"   # STRING. Local path to the remote directory (mounting point)

# -------------------------- PROGRAM -------------------------- #

# set some values required to run
ts=`date +%Y-%m-%d_%H%M%S_%s`                # timestamp 2019-11-28_153244_123456
tnow=$(date +%H:%M)                          # current time
tfriend=`date +%d.%m.%Y`                     # frindly name
swait=0                                      # init the waiting time
hourfrm=`expr 60 / ${INTERVAL} / ${HOURFRM}` # calculate the frame rate

# DEBUG !!
# tnow="17:21" 

echo "$ts: ----- Starting program -----"

# mount remote driectory
echo "$ts: Mounting remote directory $REMOTEUSR@$REMOTESRV:$REMOTDIR $LOCALMNT"
sshfs $REMOTEUSR@$REMOTESRV:$REMOTDIR $LOCALMNT

# see if temp direcory is there
if [ -d "$tDIRSNAPS" ]; then
    echo "$ts: Temporary directory tDIRSNAPS is available as $tDIRSNAPS"
else
    echo "$ts: ERROR - Temporary directory tDIRSNAPS is not available as $tDIRSNAPS"
    exit 1
fi

if [ -d "$tDIRVID" ]; then
    echo "$ts: Temporary directory tDIRVID is available as $tDIRVID"
else
    echo "$ts: ERROR - Temporary directory tDIRVID is not available as $tDIRVID"
    exit 1
fi


#
# -- Set sunrise and sunset based on script from Lubos Rendek
#

echo "$ts: -- Request sunrise and sunset"

# Get sunrise and sunset raw data from weather.com
sun_times=$( curl -s  https://weather.com/weather/today/l/$LOCATION | sed 's/<span/\n/g' | sed 's/<\/span>/\n/g'  | grep -E "dp0-details-sunrise|dp0-details-sunset" | tr -d '\n' | sed 's/>/ /g' | cut -d " " -f 4,8 )

# Extract sunrise and sunset times and convert to 24 hour format
sunrise=$(date --date="`echo $sun_times | awk '{ print $1}'` AM" +%R)
sunset=$(date --date="`echo $sun_times | awk '{ print $2}'` PM" +%R)

echo "$ts: Sunrise at $sunrise"
echo "$ts: Sunset at $sunset"

#
# -- Init the snapshot mechanism
#

echo "$ts: -- Init the snapshotting"
echo "$ts: Current time is $tnow, start and end by $WARP h"


# convert all to seconds
ssunrise=`date +%s -d ${sunrise}`
ssunset=`date +%s -d ${sunset}`
stnow=`date +%s -d ${tnow}`
swarp=$((WARP*3600))

# calculate a new time by adding the the current time to the waiting warp time
swnow=`expr ${swarp} + ${stnow}`

echo "$ts: The values in seconds are: sunrise $ssunrise, sunset $ssunset, now $stnow, warp $swarp and now and warp $swnow."

# if the current is in between sunset and sunrise
# set sleep to 0. If not, set the waiting time
if [ "$ssunrise" -le "$swnow" -a "$swnow" -le "$ssunset" ]; then
    echo "$ts: It the right time to start."
else

    # if the current time is smaller than sunrise, its today and we'll wait until sunrise (minus the WARP)
    if [ "$stnow" -le "$ssunrise" ]; then

        # Get the dfference
        swait=`expr ${ssunrise} - ${swnow}`
        echo "$ts: It is too early to start."

    fi

fi

echo "$ts: Set sleep to wait for $swait s. This is from $tnow until $sunrise minus $WARP h. No error handling for hours after sunset. Good for testing as you are programming after sunset anyways..."
sleep $swait           # sleep in seconds


#
# -- take snapshots
#
echo "$ts: -- Take snapshots"

# create the working directory
dirsnap="$tDIRSNAPS/$ts"
echo "$ts: Snapshots temporary directory is set to $dirsnap"
mkdir -p "$dirsnap"

rightnow=$(date +%H:%M)
echo "$ts: Start taking snapshots at $rightnow"

# calculate the time period in seconds
# => sunset + warp - sunrise + warp
duration=`expr ${ssunset} + ${swarp} - ${ssunrise} + ${swarp}`

echo "$ts: We'll take snapshots for $duration seconds, every $INTERVAL minute(s)."

# convert to miliseconds
msduration=$((duration*1000))       # seconds to ms
msinterval=$((INTERVAL*60000))      # minutes to ms

# DEBUG !!
# msduration=120000

raspistill -tl $msinterval -t $msduration -o $dirsnap/snapshot-%04d.jpg
# tl interval, t for how long. All values in milliseconds


#
# -- do the video
#
echo "$ts: -- Do the video"

# copy the snapshots
dirvid="$tDIRVID/$ts"
rempath="$REMOTDIR/$ts"
snapfiles="$rempath/snapshot-%04d.jpg"
vidsfile="$rempath/MYTimeLapse_$ts.mp4"

# create video by executing ffmpeg on the remote server. Mind to use the remote servers paths.
echo "$ts: Create video on $REMOTESRV. Use snapshots $snapfiles to create $vidsfile in local $rempath, remote $rempath with framerate $hourfrm (Interval $INTERVAL, length of an hour $HOURFRM)"
ssh -t $REMOTEUSR@$REMOTESRV "ffmpeg -report -thread_queue_size 5000 -r $hourfrm -f image2 -s 2592x1944 -i $snapfiles -vcodec libx264 $vidsfile"


if [ -f "$dirvid/Solothurn_TimeLapse_$ts.mp4" ]; then
    echo "$ts: Video has ben created as $dirvid/Solothurn_TimeLapse_$ts.mp4, remote $rempath"

    # Video exists, upload to youtube. Command executed on remote machine
    echo "$ts: Start upload video youtube script on remote machine."
    ssh -t $REMOTEUSR@$REMOTESRV "python3 upload_video.py --title='TITLE' --description='TEXT' --category=19 --privacyStatus='unlisted' --noauth_local_webserver --file='$vidsfile'"

    rm -r "$dirsnap"

else
    echo "$ts: ERROR - Unable to find Video $vidsfile, remote $rempath, local $dirvid"
    exit 1
fi
