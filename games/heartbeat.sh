#!/bin/bash

#README
#Keep screen alive to prevent screensaver blanking while using a gamepad.

while sleep 55
do
    xscreensaver-command -deactivate
    #xdg-screensaver reset
    #xset s reset
done
