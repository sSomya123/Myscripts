#!/bin/bash

# Define the save directory (Change this to your preferred folder)
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

# Generate a filename with a timestamp
FILENAME="$SAVE_DIR/screenshot_$(date +'%Y%m%d_%H%M%S').png"

# The core command:
# 1. slurp gets the region
# 2. grim captures that region
# 3. satty opens the editor
# 4. the result is saved to FILENAME
grim -g "$(slurp)" - | satty --filename - --output-filename "$FILENAME"
