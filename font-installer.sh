#!/bin/bash
# Interactive Font Installer with Fuzzel
# Supports TTF, OTF, WOFF, WOFF2 formats
# Local or system-wide installation

# Detect if running in terminal
if [ ! -t 0 ]; then
  # Not running in terminal, relaunch in terminal
  # Try common terminal emulators
  if command -v kitty &>/dev/null; then
    kitty --hold bash "$0" "$@"
  elif command -v alacritty &>/dev/null; then
    alacritty --hold -e bash "$0" "$@"
  elif command -v gnome-terminal &>/dev/null; then
    gnome-terminal -- bash -c "$0 $*; echo ''; echo 'Press any key to exit...'; read -n1"
  elif command -v konsole &>/dev/null; then
    konsole --hold -e bash "$0" "$@"
  elif command -v xfce4-terminal &>/dev/null; then
    xfce4-terminal --hold -e "bash $0 $*"
  elif command -v xterm &>/dev/null; then
    xterm -hold -e bash "$0" "$@"
  elif command -v foot &>/dev/null; then
    foot bash -c "$0 $*; echo ''; echo 'Press any key to exit...'; read -n1"
  else
    # Fallback: try to find any terminal
    for term in terminator mate-terminal lxterminal rxvt urxvt st; do
      if command -v "$term" &>/dev/null; then
        "$term" -e "bash -c \"$0 $*; echo ''; echo 'Press any key to exit...'; read -n1\""
        exit 0
      fi
    done
    # No terminal found
    notify-send "Font Installer Error" "No terminal emulator found. Please run from terminal."
  fi
  exit 0
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check dependencies
if ! command -v fuzzel &>/dev/null; then
  echo -e "${RED}Error: fuzzel is not installed.${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 1
fi

if ! command -v fc-cache &>/dev/null; then
  echo -e "${RED}Error: fontconfig is not installed.${NC}"
  echo "Install with: sudo apt install fontconfig"
  echo "Press any key to exit..."
  read -n1
  exit 1
fi

# Function to show fuzzel menu
fuzzel_menu() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | fuzzel --dmenu --prompt="$prompt: "
}

# Function to browse directories
browse_directory() {
  local prompt="$1"
  local start_dir="${2:-$HOME}"

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

# Function to validate font files
validate_fonts() {
  local dir="$1"
  local count=0

  shopt -s nocaseglob nullglob
  for ext in ttf otf woff woff2; do
    files=("$dir"/*."$ext")
    count=$((count + ${#files[@]}))
  done

  echo "$count"
}

clear
echo -e "${CYAN}╔════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Interactive Font Installer       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════╝${NC}"
echo ""

# Step 1: Choose font source directory
echo -e "${YELLOW}Step 1: Choose font source location${NC}"
SOURCE_METHOD=$(fuzzel_menu "Font Source" \
  "Browse from Downloads" \
  "Browse from Documents" \
  "Browse from Home" \
  "Browse from Desktop" \
  "Enter Path Manually")

case "$SOURCE_METHOD" in
"Browse from Downloads")
  FONT_SOURCE=$(browse_directory "Select Font Directory" "$HOME/Downloads")
  ;;
"Browse from Documents")
  FONT_SOURCE=$(browse_directory "Select Font Directory" "$HOME/Documents")
  ;;
"Browse from Home")
  FONT_SOURCE=$(browse_directory "Select Font Directory" "$HOME")
  ;;
"Browse from Desktop")
  FONT_SOURCE=$(browse_directory "Select Font Directory" "$HOME/Desktop")
  ;;
"Enter Path Manually")
  FONT_SOURCE=$(enter_path "Font Directory Path" "$HOME/Downloads")
  ;;
*)
  echo -e "${RED}Cancelled.${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 1
  ;;
esac

if [ -z "$FONT_SOURCE" ] || [ ! -d "$FONT_SOURCE" ]; then
  echo -e "${RED}Error: Invalid font source directory.${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 1
fi

echo -e "${GREEN}✓ Font source: $FONT_SOURCE${NC}"

# Check for font files
FONT_COUNT=$(validate_fonts "$FONT_SOURCE")

if [ "$FONT_COUNT" -eq 0 ]; then
  echo -e "${RED}Error: No font files found in the selected directory.${NC}"
  echo -e "${YELLOW}Supported formats: TTF, OTF, WOFF, WOFF2${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 1
fi

echo -e "${GREEN}✓ Found $FONT_COUNT font file(s)${NC}"
echo ""

# Step 2: Choose installation type
echo -e "${YELLOW}Step 2: Choose installation type${NC}"
INSTALL_TYPE=$(fuzzel_menu "Installation Type" \
  "Local (Current User Only)" \
  "System-Wide (All Users - Requires Sudo)")

case "$INSTALL_TYPE" in
"Local (Current User Only)")
  INSTALL_DIR="$HOME/.local/share/fonts"
  NEEDS_SUDO=false
  ;;
"System-Wide (All Users - Requires Sudo)")
  INSTALL_DIR="/usr/local/share/fonts"
  NEEDS_SUDO=true
  ;;
*)
  echo -e "${RED}Cancelled.${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 1
  ;;
esac

echo -e "${GREEN}✓ Installation type: $INSTALL_TYPE${NC}"
echo -e "${GREEN}✓ Target directory: $INSTALL_DIR${NC}"
echo ""

# Step 3: Choose font format filter
echo -e "${YELLOW}Step 3: Choose font formats to install${NC}"
FORMAT_CHOICE=$(fuzzel_menu "Font Formats" \
  "All Formats (TTF, OTF, WOFF, WOFF2)" \
  "TrueType Only (TTF)" \
  "OpenType Only (OTF)" \
  "Web Fonts Only (WOFF, WOFF2)" \
  "TTF and OTF Only")

case "$FORMAT_CHOICE" in
"All Formats (TTF, OTF, WOFF, WOFF2)")
  FORMATS=("ttf" "otf" "woff" "woff2")
  ;;
"TrueType Only (TTF)")
  FORMATS=("ttf")
  ;;
"OpenType Only (OTF)")
  FORMATS=("otf")
  ;;
"Web Fonts Only (WOFF, WOFF2)")
  FORMATS=("woff" "woff2")
  ;;
"TTF and OTF Only")
  FORMATS=("ttf" "otf")
  ;;
*)
  echo -e "${RED}Cancelled.${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 1
  ;;
esac

echo -e "${GREEN}✓ Formats: ${FORMATS[*]}${NC}"
echo ""

# Step 4: Choose subfolder organization
echo -e "${YELLOW}Step 4: Font organization${NC}"
ORGANIZATION=$(fuzzel_menu "Organize Fonts" \
  "Create Subfolder (By Source Name)" \
  "Install Directly (No Subfolder)")

if [[ "$ORGANIZATION" == "Create Subfolder (By Source Name)" ]]; then
  SUBFOLDER=$(basename "$FONT_SOURCE")
  FULL_INSTALL_DIR="$INSTALL_DIR/$SUBFOLDER"
else
  FULL_INSTALL_DIR="$INSTALL_DIR"
fi

echo -e "${GREEN}✓ Install to: $FULL_INSTALL_DIR${NC}"
echo ""

# Build file list
echo -e "${BLUE}Building font list...${NC}"
shopt -s nocaseglob nullglob
FONT_FILES=()

for ext in "${FORMATS[@]}"; do
  for file in "$FONT_SOURCE"/*."$ext"; do
    [ -f "$file" ] && FONT_FILES+=("$file")
  done
done

SELECTED_COUNT=${#FONT_FILES[@]}

if [ "$SELECTED_COUNT" -eq 0 ]; then
  echo -e "${RED}Error: No fonts found matching selected formats.${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 1
fi

# Show summary
echo ""
echo -e "${CYAN}╔════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Installation Summary           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════╝${NC}"
echo -e "${BLUE}Source:${NC}      $FONT_SOURCE"
echo -e "${BLUE}Destination:${NC} $FULL_INSTALL_DIR"
echo -e "${BLUE}Type:${NC}        $INSTALL_TYPE"
echo -e "${BLUE}Formats:${NC}     ${FORMATS[*]}"
echo -e "${BLUE}Font Files:${NC}  $SELECTED_COUNT"
if [ "$NEEDS_SUDO" = true ]; then
  echo -e "${YELLOW}Note: This will require sudo password${NC}"
fi
echo ""

# Confirm installation
CONFIRM=$(fuzzel_menu "Start Installation?" \
  "Yes - Install Fonts" \
  "No - Cancel")

if [[ "$CONFIRM" != "Yes - Install Fonts" ]]; then
  echo -e "${YELLOW}Installation cancelled.${NC}"
  echo "Press any key to exit..."
  read -n1
  exit 0
fi

echo ""
echo -e "${GREEN}Starting font installation...${NC}"
echo ""

# Create installation directory
if [ "$NEEDS_SUDO" = true ]; then
  echo -e "${YELLOW}Creating directory (requires sudo)...${NC}"
  sudo mkdir -p "$FULL_INSTALL_DIR"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create directory.${NC}"
    echo "Press any key to exit..."
    read -n1
    exit 1
  fi
else
  mkdir -p "$FULL_INSTALL_DIR"
fi

# Install fonts
INSTALLED=0
FAILED=0

for font_file in "${FONT_FILES[@]}"; do
  font_name=$(basename "$font_file")

  echo -e "${YELLOW}Installing: $font_name${NC}"

  if [ "$NEEDS_SUDO" = true ]; then
    sudo cp "$font_file" "$FULL_INSTALL_DIR/"
  else
    cp "$font_file" "$FULL_INSTALL_DIR/"
  fi

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Installed successfully${NC}"
    INSTALLED=$((INSTALLED + 1))
  else
    echo -e "${RED}  ✗ Installation failed${NC}"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo -e "${BLUE}Updating font cache...${NC}"

# Update font cache
if [ "$NEEDS_SUDO" = true ]; then
  sudo fc-cache -f -v "$INSTALL_DIR" 2>/dev/null
else
  fc-cache -f -v "$FULL_INSTALL_DIR" 2>/dev/null
fi

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Font cache updated${NC}"
else
  echo -e "${YELLOW}⚠ Warning: Font cache update may have failed${NC}"
fi

# Final summary
echo ""
echo -e "${CYAN}╔════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Installation Complete          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════╝${NC}"
echo -e "${GREEN}Successfully installed: $INSTALLED font(s)${NC}"
if [ "$FAILED" -gt 0 ]; then
  echo -e "${RED}Failed: $FAILED font(s)${NC}"
fi
echo -e "${BLUE}Location: $FULL_INSTALL_DIR${NC}"
echo ""

# Show installed fonts
echo -e "${YELLOW}Verifying installation...${NC}"
VERIFY=$(fuzzel_menu "List Installed Fonts?" \
  "Yes - Show Font List" \
  "No - Exit")

if [[ "$VERIFY" == "Yes - Show Font List" ]]; then
  echo ""
  echo -e "${CYAN}Installed fonts:${NC}"
  ls -1 "$FULL_INSTALL_DIR"
  echo ""
  echo -e "${GREEN}Installation verified!${NC}"
fi

echo ""
echo -e "${CYAN}Fonts are now available in your applications.${NC}"
echo -e "${YELLOW}You may need to restart applications to see new fonts.${NC}"
echo ""
echo -e "${GREEN}Press any key to exit...${NC}"
read -n1
