#!/bin/bash

# Remove embedded album art and padding from FLACs recursively

for D in ./*
  do
    if [ -d "$D" ]; then
       cd "$D"
          echo Current Directory: "$D" | sed 's/\.\///g'
          for i in *.flac
             do
                if [ "$i" == "*.flac" ]; then
                        echo "No FLACs found"
                        echo ""
                else
                        echo Removing Picture and Padding Block: "$i"
                        metaflac --remove --block-type=PICTURE --dont-use-padding "$i"
                        metaflac --remove --block-type=PADDING --dont-use-padding "$i"
                        metaflac --add-padding=8192 "$i"
                        echo ""
                fi
             done
       cd ..
     fi
   done