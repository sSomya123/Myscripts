#!/bin/bash
# Interactive Video Converter with Fuzzel
# Allows manual selection of input/output directories and format settings

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check dependencies
for cmd in fuzzel ffmpeg; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Error: $cmd is not installed.${NC}"
    exit 1
  fi
done

# Function to show fuzzel menu
fuzzel_menu() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | fuzzel --dmenu --width=100 --prompt="$prompt: "
}

# Function to browse directories
browse_directory() {
  local prompt="$1"
  local start_dir="${2:-$HOME}"

  # Use fuzzel with find to select directory
  local selected
  selected=$(find "$start_dir" -maxdepth 3 -type d 2>/dev/null | sort | fuzzel --dmenu --width=100 --prompt="$prompt: ")

  if [ -z "$selected" ]; then
    echo ""
    return 1
  fi

  echo "$selected"
  return 0
}

# Function to manually enter path
enter_path() {
  local prompt="$1"
  local default="$2"

  echo "$default" | fuzzel --dmenu --prompt="$prompt: "
}

echo -e "${BLUE}=== Interactive Video Converter ===${NC}"

# Step 1: Choose input directory method
echo -e "${YELLOW}Choose input directory method...${NC}"
INPUT_METHOD=$(fuzzel_menu "Input Directory" "Browse from Home" "Browse from Videos" "Browse from Documents" "Enter Path Manually")

case "$INPUT_METHOD" in
"Browse from Home")
  INPUT_DIR=$(browse_directory "Select Input Directory" "$HOME")
  ;;
"Browse from Videos")
  INPUT_DIR=$(browse_directory "Select Input Directory" "$HOME/Videos")
  ;;
"Browse from Documents")
  INPUT_DIR=$(browse_directory "Select Input Directory" "$HOME/Documents")
  ;;
"Enter Path Manually")
  INPUT_DIR=$(enter_path "Input Directory Path" "$HOME/Videos")
  ;;
*)
  echo -e "${RED}Cancelled.${NC}"
  exit 1
  ;;
esac

if [ -z "$INPUT_DIR" ] || [ ! -d "$INPUT_DIR" ]; then
  echo -e "${RED}Error: Invalid input directory.${NC}"
  exit 1
fi

echo -e "${GREEN}Input directory: $INPUT_DIR${NC}"

# Step 2: Choose input format
echo -e "${YELLOW}Choose input video format...${NC}"
INPUT_FORMAT=$(fuzzel_menu "Input Format" "mp4" "mov" "avi" "mkv" "webm" "flv" "All formats (*)")

case "$INPUT_FORMAT" in
"All formats (*)")
  INPUT_EXT="*"
  ;;
*)
  INPUT_EXT="$INPUT_FORMAT"
  ;;
esac

# Step 3: Choose output directory method
echo -e "${YELLOW}Choose output directory method...${NC}"
OUTPUT_METHOD=$(fuzzel_menu "Output Directory" "Browse from Home" "Browse from Videos" "Enter Path Manually" "Same as Input (subfolder)")

case "$OUTPUT_METHOD" in
"Browse from Home")
  OUTPUT_DIR=$(browse_directory "Select Output Directory" "$HOME")
  ;;
"Browse from Videos")
  OUTPUT_DIR=$(browse_directory "Select Output Directory" "$HOME/Videos")
  ;;
"Enter Path Manually")
  OUTPUT_DIR=$(enter_path "Output Directory Path" "$HOME/Videos/export")
  ;;
"Same as Input (subfolder)")
  OUTPUT_DIR="$INPUT_DIR/converted"
  ;;
*)
  echo -e "${RED}Cancelled.${NC}"
  exit 1
  ;;
esac

if [ -z "$OUTPUT_DIR" ]; then
  echo -e "${RED}Error: Invalid output directory.${NC}"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}Output directory: $OUTPUT_DIR${NC}"

# Step 4: Choose output codec
echo -e "${YELLOW}Choose output codec...${NC}"
CODEC=$(fuzzel_menu "Output Codec" "ProRes 422 HQ (MOV)" "ProRes 422 (MOV)" "ProRes 4444 (MOV)" "H.264 (MP4)" "H.265/HEVC (MP4)" "DNxHD (MOV)")

# Set codec parameters
case "$CODEC" in
"ProRes 422 HQ (MOV)")
  OUTPUT_EXT="mov"
  CODEC_OPTS="-c:v prores_ks -profile:v 3 -qscale:v 9 -vendor apl0 -pix_fmt yuv422p10le -c:a pcm_s16le"
  SUFFIX="_prores_hq"
  ;;
"ProRes 422 (MOV)")
  OUTPUT_EXT="mov"
  CODEC_OPTS="-c:v prores_ks -profile:v 2 -qscale:v 9 -vendor apl0 -pix_fmt yuv422p10le -c:a pcm_s16le"
  SUFFIX="_prores"
  ;;
"ProRes 4444 (MOV)")
  OUTPUT_EXT="mov"
  CODEC_OPTS="-c:v prores_ks -profile:v 4 -qscale:v 9 -vendor apl0 -pix_fmt yuva444p10le -c:a pcm_s16le"
  SUFFIX="_prores_4444"
  ;;
"H.264 (MP4)")
  OUTPUT_EXT="mp4"
  CODEC_OPTS="-c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k"
  SUFFIX="_h264"
  ;;
"H.265/HEVC (MP4)")
  OUTPUT_EXT="mp4"
  CODEC_OPTS="-c:v libx265 -preset medium -crf 20 -c:a aac -b:a 192k"
  SUFFIX="_h265"
  ;;
"DNxHD (MOV)")
  OUTPUT_EXT="mov"
  CODEC_OPTS="-c:v dnxhd -profile:v dnxhr_hq -pix_fmt yuv422p -c:a pcm_s16le"
  SUFFIX="_dnxhd"
  ;;
*)
  echo -e "${RED}Cancelled.${NC}"
  exit 1
  ;;
esac

# Step 5: Choose resolution option
echo -e "${YELLOW}Choose resolution...${NC}"
RESOLUTION=$(fuzzel_menu "Output Resolution" "Keep Original" "1920x1080 (1080p)" "1280x720 (720p)" "3840x2160 (4K)" "2560x1440 (1440p)")

case "$RESOLUTION" in
"Keep Original")
  SCALE_OPTS=""
  ;;
"1920x1080 (1080p)")
  SCALE_OPTS="-vf scale=1920:1080:flags=lanczos"
  ;;
"1280x720 (720p)")
  SCALE_OPTS="-vf scale=1280:720:flags=lanczos"
  ;;
"3840x2160 (4K)")
  SCALE_OPTS="-vf scale=3840:2160:flags=lanczos"
  ;;
"2560x1440 (1440p)")
  SCALE_OPTS="-vf scale=2560:1440:flags=lanczos"
  ;;
esac

# Find and count files
echo -e "${BLUE}Searching for files...${NC}"
shopt -s nocaseglob nullglob

if [ "$INPUT_EXT" = "*" ]; then
  mapfile -t files < <(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.webm" -o -iname "*.flv" \))
else
  mapfile -t files < <(find "$INPUT_DIR" -maxdepth 1 -type f -iname "*.$INPUT_EXT")
fi

file_count=${#files[@]}

if [ "$file_count" -eq 0 ]; then
  echo -e "${YELLOW}No files found matching the criteria.${NC}"
  exit 0
fi

# Show summary and confirm
echo -e "${BLUE}=== Conversion Summary ===${NC}"
echo -e "Input:  $INPUT_DIR (*.$INPUT_EXT)"
echo -e "Output: $OUTPUT_DIR"
echo -e "Codec:  $CODEC"
echo -e "Files:  $file_count"
echo -e "${BLUE}=========================${NC}"

CONFIRM=$(fuzzel_menu "Start Conversion?" "Yes - Start Converting" "No - Cancel")

if [[ "$CONFIRM" != "Yes - Start Converting" ]]; then
  echo -e "${YELLOW}Conversion cancelled.${NC}"
  exit 0
fi

# Check if already running in a terminal
if [ -t 0 ]; then
  # Already in terminal, proceed
  TERMINAL_MODE=true
else
  # Not in terminal, launch one
  TERMINAL_MODE=false
fi

# If not in terminal, relaunch in terminal for conversion
if [ "$TERMINAL_MODE" = false ]; then
  # Detect available terminal emulator and user shell
  TERMINAL=""
  USER_SHELL="${SHELL:-/bin/bash}"

  if command -v foot &>/dev/null; then
    TERMINAL="foot"
  elif command -v kitty &>/dev/null; then
    TERMINAL="kitty"
  elif command -v alacritty &>/dev/null; then
    TERMINAL="alacritty -e"
  elif command -v wezterm &>/dev/null; then
    TERMINAL="wezterm start --"
  elif command -v gnome-terminal &>/dev/null; then
    TERMINAL="gnome-terminal --"
  elif command -v konsole &>/dev/null; then
    TERMINAL="konsole -e"
  elif command -v xterm &>/dev/null; then
    TERMINAL="xterm -e"
  else
    echo -e "${RED}Error: No terminal emulator found.${NC}"
    exit 1
  fi

  # Create temporary script to run conversion
  TEMP_SCRIPT=$(mktemp --suffix=.sh)
  cat >"$TEMP_SCRIPT" <<'CONVERSION_SCRIPT'
#!/usr/bin/env bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INPUT_DIR="$1"
OUTPUT_DIR="$2"
CODEC_OPTS="$3"
SCALE_OPTS="$4"
SUFFIX="$5"
OUTPUT_EXT="$6"
shift 6

files=("$@")
file_count=${#files[@]}

echo -e "${GREEN}Starting conversion of $file_count file(s)...${NC}"
current=0

for input_file in "${files[@]}"; do
  current=$((current + 1))
  base=$(basename "$input_file")
  filename="${base%.*}"
  output_file="$OUTPUT_DIR/${filename}${SUFFIX}.$OUTPUT_EXT"
  
  echo -e "${YELLOW}[$current/$file_count] Converting: $base${NC}"
  
  ffmpeg -i "$input_file" $SCALE_OPTS $CODEC_OPTS "$output_file" -hide_banner -loglevel error -stats
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully converted: $(basename "$output_file")${NC}"
  else
    echo -e "${RED}✗ Failed to convert: $base${NC}"
  fi
  echo "-----------------------------------"
done

echo -e "${GREEN}Conversion complete!${NC}"
echo "Output files are located in: $OUTPUT_DIR"

output_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
echo "Total output size: $output_size"

echo ""
echo -e "${YELLOW}Press Enter to close...${NC}"
read
CONVERSION_SCRIPT

  chmod +x "$TEMP_SCRIPT"

  # Launch terminal with conversion script (using user's shell)
  $TERMINAL "$USER_SHELL" -c "exec bash '$TEMP_SCRIPT' '$INPUT_DIR' '$OUTPUT_DIR' '$CODEC_OPTS' '$SCALE_OPTS' '$SUFFIX' '$OUTPUT_EXT' ${files[*]@Q}; exec $USER_SHELL"

  # Clean up temp script after a delay (terminal needs time to read it)
  (
    sleep 2
    rm -f "$TEMP_SCRIPT"
  ) &
  exit 0
fi

# Convert files (if already in terminal)
echo -e "${GREEN}Starting conversion of $file_count file(s)...${NC}"
current=0

for input_file in "${files[@]}"; do
  current=$((current + 1))
  base=$(basename "$input_file")
  filename="${base%.*}"
  output_file="$OUTPUT_DIR/${filename}${SUFFIX}.$OUTPUT_EXT"

  echo -e "${YELLOW}[$current/$file_count] Converting: $base${NC}"

  # Build ffmpeg command
  ffmpeg -i "$input_file" $SCALE_OPTS $CODEC_OPTS "$output_file" -hide_banner -loglevel error -stats

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully converted: $(basename "$output_file")${NC}"
  else
    echo -e "${RED}✗ Failed to convert: $base${NC}"
  fi
  echo "-----------------------------------"
done

echo -e "${GREEN}Conversion complete!${NC}"
echo "Output files are located in: $OUTPUT_DIR"

# Show total output size
output_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
echo "Total output size: $output_size"

echo ""
echo -e "${YELLOW}Press Enter to close...${NC}"
read
