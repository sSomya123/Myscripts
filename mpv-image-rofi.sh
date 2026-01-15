#!/bin/bash

# Rofi Image Viewer with Thumbnails
# An image viewer launcher using rofi with thumbnail preview

# Configuration
PICTURES_DIR="$HOME/Pictures"
CACHE_DIR="$HOME/.cache/rofi-image-thumbnails"
THUMBNAIL_SIZE="400x400" # Square thumbnails for images
ROFI_ICON_SIZE=150       # Icon size in rofi (in pixels)

# Image file extensions to search for
IMAGE_EXTENSIONS="jpg|jpeg|png|gif|bmp|webp|tiff|tif|svg|ico"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Function to generate thumbnail for an image
generate_thumbnail() {
  local image_path="$1"
  local image_name="$2"
  local thumb_path="$CACHE_DIR/$(echo "$image_name" | md5sum | cut -d' ' -f1).png"

  # Check if thumbnail already exists
  if [ ! -f "$thumb_path" ]; then
    # Generate thumbnail using convert (ImageMagick)
    convert "$image_path" -thumbnail "$THUMBNAIL_SIZE^" -gravity center -extent "$THUMBNAIL_SIZE" "$thumb_path" 2>/dev/null

    # If convert fails, try with ffmpeg (for some formats)
    if [ ! -f "$thumb_path" ]; then
      ffmpeg -i "$image_path" -vf "scale=$THUMBNAIL_SIZE:force_original_aspect_ratio=decrease" "$thumb_path" -y &>/dev/null
    fi

    # If both fail, create a placeholder
    if [ ! -f "$thumb_path" ]; then
      convert -size 400x400 xc:gray -gravity center -pointsize 20 -annotate +0+0 "No Preview" "$thumb_path" 2>/dev/null
    fi
  fi

  echo "$thumb_path"
}

# Function to find image files recursively
find_images() {
  cd "$PICTURES_DIR" || exit 1
  find . -type f -regextype posix-extended -iregex ".*\.($IMAGE_EXTENSIONS)$" | sed 's|^\./||' | sort
}

# Function to create rofi entries with thumbnails
create_menu_entries() {
  local images
  images=$(find_images)

  if [ -z "$images" ]; then
    notify-send "Rofi Image Viewer" "No image files found in $PICTURES_DIR"
    exit 1
  fi

  while IFS= read -r image; do
    local image_path="$PICTURES_DIR/$image"
    local thumb_path

    # Generate thumbnail
    thumb_path=$(generate_thumbnail "$image_path" "$image")

    # Output format: image_name with thumbnail icon
    echo -en "$image\0icon\x1f$thumb_path\n"
  done <<<"$images"
}

# Function to display menu and get selection
show_menu() {
  create_menu_entries | rofi -dmenu -i \
    -p "Select Image" \
    -show-icons \
    -icon-theme "hicolor" \
    -eh 4 \
    -markup-rows \
    -theme-str 'element-icon { size: '"$ROFI_ICON_SIZE"'px; }' \
    -theme-str 'listview { columns: 2; lines: 3; }' \
    -theme-str 'window { width: 40%; }' \
    -format "s" \
    -no-custom
}

# Function to open image
open_image() {
  local selected="$1"

  if [ -n "$selected" ]; then
    local image_path="$PICTURES_DIR/$selected"

    if [ -f "$image_path" ]; then
      # Open with default image viewer (you can change this to your preferred viewer)
      # Options: feh, sxiv, eog, gwenview, gimp, etc.
      if command -v feh &>/dev/null; then
        feh "$image_path" &
      elif command -v sxiv &>/dev/null; then
        sxiv "$image_path" &
      elif command -v eog &>/dev/null; then
        eog "$image_path" &
      elif command -v gwenview &>/dev/null; then
        gwenview "$image_path" &
      elif command -v xdg-open &>/dev/null; then
        xdg-open "$image_path" &
      else
        notify-send "Error" "No image viewer found. Please install feh, sxiv, or eog"
        exit 1
      fi

      # Show notification
      notify-send "Opening Image" "$selected"
    else
      notify-send "Error" "Image file not found: $selected"
    fi
  fi
}

# Function to check dependencies
check_dependencies() {
  local missing=()

  command -v rofi &>/dev/null || missing+=("rofi")
  command -v convert &>/dev/null || missing+=("imagemagick")

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies: ${missing[*]}"
    notify-send "Rofi Image Viewer" "Missing dependencies: ${missing[*]}"
    exit 1
  fi
}

# Main execution
main() {
  # Check dependencies
  check_dependencies

  # Check if Pictures directory exists
  if [ ! -d "$PICTURES_DIR" ]; then
    notify-send "Error" "Pictures directory not found: $PICTURES_DIR"
    exit 1
  fi

  # Show menu and get selection
  selected=$(show_menu)

  # Open selected image
  open_image "$selected"
}

# Run main function
main
