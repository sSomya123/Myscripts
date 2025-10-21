#!/usr/bin/env bash

Dir="$HOME/Videos/export/mp4/"

# Check if directory exists
if [ ! -d "$Dir" ]; then
  mkdir -p "$Dir"
  echo "Created directory: $Dir"
else
  echo "Directory already exists: $Dir"
fi

# Loop through all mp4 files and convert them
for file in *.mov; do
  ffmpeg -i "$file" -c:v libx265 -crf 28 -preset medium -c:a aac -b:a 192k "$Dir${file%.mov}.mp4"
done
