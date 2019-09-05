# RaspiTimeLapse
Bash script for raspberry pi. 
It creates a timelapse video with weather text overlay and uploads it to youtube.<br>
<br>
 - install ffmpeg. (sudo apt install ffmpeg)
 - install bc (sudo apt install bc)
 - get a font e.g. from google fonts: https://fonts.google.com/specimen/Roboto
 - Copy main.sh it to your raspberry, make it executable (chmod +x main.sh)
 - adjust the paths/ variables in main.sh<br>
 <br>
To be able to upload to Youtube you need python3, the api client and toklands script. <br>
 - install python-pip Make sure its python3. <br>
 - pip install google-api-python-client <br>
 - pip install --upgrade oauth2client <br>
 - then follow the installation and setup instructions on https://github.com/tokland/youtube-upload<br>
 <br>
 See examples of the final videos here:<br>
 https://www.youtube.com/watch?v=Ff2tpp18Y3M&index=2&list=PLcnGcU-Z-RJ1uRxLbBiHb2feVr6tQzJVj<br>
 <br>
 <br>
 You might be tempted to use raspistill pi3 to automatically create a series of pictures.<br>
 This would be feasible indeed... 
 However, I have made the experience, that the raspi isn't powerfull enought to create a timelapse video out of a few 100 pictures.
 This script creates the video after every picture taken. And it has the advantagae to add overlay text in real time.
 <br><br>
 A pi 4 has enough power to process 2k every 15sec in reasonable time.
