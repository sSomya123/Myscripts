#!/bin/bash

# Mobile Video Export Script with ProRes Color Fix
# Usage: ./mobile-export.sh <input-video-path>

# Check if input file is provided
if [ $# -eq 0 ]; then
  echo "Error: No input file specified"
  echo "Usage: ./mobile-export.sh <input-video-path>"
  echo "Example: ./mobile-export.sh /home/user/video.mov"
  exit 1
fi

INPUT_FILE="$1"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File '$INPUT_FILE' does not exist"
  exit 1
fi

# Get the directory and filename without extension
DIR=$(dirname "$INPUT_FILE")
FILENAME=$(basename "$INPUT_FILE")
NAME="${FILENAME%.*}"
EXT="${FILENAME##*.}"

# Create output filename
OUTPUT_FILE="${DIR}/${NAME}_mobile.mp4"

# Check if output file already exists
if [ -f "$OUTPUT_FILE" ]; then
  read -p "Output file already exists. Overwrite? (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Conversion cancelled"
    exit 0
  fi
fi

echo "Converting: $INPUT_FILE"
echo "Output: $OUTPUT_FILE"
echo "Starting conversion with ProRes color fix..."

# Run FFmpeg conversion with explicit color metadata for Pixel compatibility
ffmpeg -i "$INPUT_FILE" \
  -c:v libx264 \
  -profile:v main \
  -level 4.0 \
  -crf 23 \
  -preset medium \
  -pix_fmt yuv420p \
  -colorspace bt709 \
  -color_primaries bt709 \
  -color_trc bt709 \
  -color_range tv \
  -movflags +faststart \
  -c:a aac \
  -b:a 192k \
  "$OUTPUT_FILE"

# Check if conversion was successful
if [ $? -eq 0 ]; then
  echo "✓ Conversion successful!"
  echo "Mobile video saved to: $OUTPUT_FILE"

  # Show file sizes
  INPUT_SIZE=$(du -h "$INPUT_FILE" | cut -f1)
  OUTPUT_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
  echo "Original size: $INPUT_SIZE"
  echo "Mobile size: $OUTPUT_SIZE"
  echo ""
  echo "This video should now work on all phones including Pixel devices!"
else
  echo "✗ Conversion failed"
  exit 1
fi
