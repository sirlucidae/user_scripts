#!/bin/bash

# README
# Patch 2.0.4 (beta) prevents launching the game through steam on linux.
# Work-around to launch imperator directly from the executable with additional arguments.

# Check if steam is running
if pgrep -x "steam" > /dev/null
then
    echo "Starting imperator..." &
# Launch executable from default installed game directory
# Background process and hide terminal ouput
nohup mangohud ~/.steam/steam/steamapps/common/ImperatorRome/binaries/imperator &> /dev/null &disown
else
    echo "Process steam not running."
fi