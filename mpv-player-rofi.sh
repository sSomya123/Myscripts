#!/bin/bash

# Rofi MPV Player with Thumbnails
# A video player launcher using rofi with thumbnail preview

# Configuration
VIDEOS_DIR="$HOME/Videos"
CACHE_DIR="$HOME/.cache/rofi-mpv-thumbnails"
THUMBNAIL_SIZE="400x225" # 16:9 aspect ratio for better video preview
ROFI_ICON_SIZE=150       # Icon size in rofi (in pixels)

# Video file extensions to search for
VIDEO_EXTENSIONS="mp4|mkv|avi|mov|webm|flv|wmv|m4v|mpeg|mpg"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Function to generate thumbnail for a video
generate_thumbnail() {
  local video_path="$1"
  local video_name="$2"
  local thumb_path="$CACHE_DIR/$(echo "$video_name" | md5sum | cut -d' ' -f1).png"

  # Check if thumbnail already exists
  if [ ! -f "$thumb_path" ]; then
    # Generate thumbnail using ffmpeg at 10% of video duration
    ffmpeg -i "$video_path" -ss 00:00:03 -vframes 1 -vf "scale=$THUMBNAIL_SIZE:force_original_aspect_ratio=decrease" "$thumb_path" -y &>/dev/null

    # If ffmpeg fails, create a placeholder
    if [ ! -f "$thumb_path" ]; then
      convert -size 300x300 xc:gray -gravity center -pointsize 20 -annotate +0+0 "No Preview" "$thumb_path" 2>/dev/null
    fi
  fi

  echo "$thumb_path"
}

# Function to find video files recursively
find_videos() {
  cd "$VIDEOS_DIR" || exit 1
  find . -type f -regextype posix-extended -iregex ".*\.($VIDEO_EXTENSIONS)$" | sed 's|^\./||' | sort
}

# Function to create rofi entries with thumbnails
create_menu_entries() {
  local videos
  videos=$(find_videos)

  if [ -z "$videos" ]; then
    notify-send "Rofi MPV Player" "No video files found in $VIDEOS_DIR"
    exit 1
  fi

  while IFS= read -r video; do
    local video_path="$VIDEOS_DIR/$video"
    local thumb_path

    # Generate thumbnail in background for better performance
    thumb_path=$(generate_thumbnail "$video_path" "$video")

    # Output format: thumbnail_path\0video_name\0video_path
    echo -en "$video\0icon\x1f$thumb_path\n"
  done <<<"$videos"
}

# Function to display menu and get selection
show_menu() {
  create_menu_entries | rofi -dmenu -i \
    -p "Select Video" \
    -show-icons \
    -icon-theme "hicolor" \
    -eh 4 \
    -markup-rows \
    -theme-str 'element-icon { size: '"$ROFI_ICON_SIZE"'px; }' \
    -theme-str 'listview { columns: 2; lines: 3; }' \
    -theme-str 'window { width: 50%; }' \
    -format "s" \
    -no-custom
}

# Function to play video
play_video() {
  local selected="$1"

  if [ -n "$selected" ]; then
    local video_path="$VIDEOS_DIR/$selected"

    if [ -f "$video_path" ]; then
      # Play with mpv
      mpv "$video_path" &>/dev/null &

      # Show notification
      notify-send "Now Playing" "$selected"
    else
      notify-send "Error" "Video file not found: $selected"
    fi
  fi
}

# Function to check dependencies
check_dependencies() {
  local missing=()

  command -v rofi &>/dev/null || missing+=("rofi")
  command -v mpv &>/dev/null || missing+=("mpv")
  command -v ffmpeg &>/dev/null || missing+=("ffmpeg")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies: ${missing[*]}"
    notify-send "Rofi MPV Player" "Missing dependencies: ${missing[*]}"
    exit 1
  fi
}

# Main execution
main() {
  # Check dependencies
  check_dependencies

  # Check if Videos directory exists
  if [ ! -d "$VIDEOS_DIR" ]; then
    notify-send "Error" "Videos directory not found: $VIDEOS_DIR"
    exit 1
  fi

  # Show menu and get selection
  selected=$(show_menu)

  # Play selected video
  play_video "$selected"
}

# Run main function
main
