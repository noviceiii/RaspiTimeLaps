# RaspiTimeLapse
Bash script for raspberry pi. 
It creates a timelapse video with weather text overlay and uploads it to youtube.

 - install avconf. Don't use ffmpeg. (sudo apt install libav-tools)
 - get a font e.g. from google fonts: https://fonts.google.com/specimen/Roboto
 - Copy main.sh it to your raspberry, make it executable (chmod +x main.sh)
 - adjust the paths/ variables in main.sh
 
 - To Upload to Youtube you need python3 and toklands script. Make sure its python3.
-> Follow the instructions on https://github.com/tokland/youtube-upload
 
 See examples of the final videos here:
 https://www.youtube.com/watch?v=Ff2tpp18Y3M&index=2&list=PLcnGcU-Z-RJ1uRxLbBiHb2feVr6tQzJVj
 
 
 You might be tempted to use raspistill to automatically create a series of pictures.<br>
 This would be feasible indeed... 
 However, I have made the experience, that the raspi isn't powerfull enought to create a timelapse video out of a few 100 pictures.
 This script creates the video after every picture taken. And it has the advantagae to add overlay text in real time.
