for i in *.dsf; do ffmpeg -i "$i" -af "lowpass=24000, volume=6dB" -sample_fmt s16 -ar 48000 "${i%.*}.flac"; done
