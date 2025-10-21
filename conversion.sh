#!/usr/bin/env bash

Dir="$HOME/Videos/Conversion/"

# Check if directory exists
if [ ! -d "$Dir" ]; then
  mkdir -p "$Dir"
  echo "Created directory: $Dir"
else
  echo "Directory already exists: $Dir"
fi

# Loop through all mp4 files and convert them
for file in *.mp4; do
  ffmpeg -i "$file" -c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p -c:a alac "$Dir${file%.mp4}.mov"
done
