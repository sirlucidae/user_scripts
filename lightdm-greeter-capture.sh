#!/bin/bash
#    If they are not already installed, install the packages x11-apps/xwd and media-gfx/imagemagick.
#    Log out of the Desktop Environment so that the LightDM greeter screen is displayed.
#    Press Ctrl+Alt+F2 to switch to VT2.
#    Log in to you user account and enter the following command (do not wait for it to complete):
#    user $ sudo /home/user/lightdm-greeter-capture.sh
#    As soon as you have pressed Enter for the above command, press Ctrl+Alt+F7 to switch back to VT7.
#    Wait for at least 30 seconds to be sure the Bash script has made a snapshot of the LightDM greeter screen, then log in.
#    You should now find the file ~/greeter.png containing a snapshot of your LightDM greeter screen. 
sleep 30
DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/$DISPLAY xwd -root > /tmp/greeter.xwd
convert /tmp/greeter.xwd ~/greeter.png
