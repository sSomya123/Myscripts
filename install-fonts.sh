#!/bin/bash

# System-wide Font Installer for EndeavourOS/Arch Linux
# Usage: sudo ./install-fonts.sh [font-files-or-directory]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
  exit 1
fi

# System font directory
FONT_DIR="/usr/share/fonts/custom"

# Create font directory if it doesn't exist
if [ ! -d "$FONT_DIR" ]; then
  echo -e "${YELLOW}Creating font directory: $FONT_DIR${NC}"
  mkdir -p "$FONT_DIR"
fi

# Function to install fonts
install_fonts() {
  local source="$1"
  local count=0

  if [ -f "$source" ]; then
    # Single file
    if [[ "$source" =~ \.(ttf|otf|TTF|OTF|woff|woff2)$ ]]; then
      echo -e "${GREEN}Installing: $(basename "$source")${NC}" >&2
      cp "$source" "$FONT_DIR/"
      ((count++))
    else
      echo -e "${YELLOW}Skipping non-font file: $source${NC}" >&2
    fi
  elif [ -d "$source" ]; then
    # Directory
    echo -e "${YELLOW}Searching for fonts in: $source${NC}" >&2
    while IFS= read -r -d '' font; do
      echo -e "${GREEN}Installing: $(basename "$font")${NC}" >&2
      cp "$font" "$FONT_DIR/"
      ((count++))
    done < <(find "$source" -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.woff" -o -iname "*.woff2" \) -print0)
  else
    echo -e "${RED}Error: $source is not a valid file or directory${NC}" >&2
    return 1
  fi

  echo "$count"
}

# Main installation logic
total_fonts=0

if [ $# -eq 0 ]; then
  # No arguments - look in current directory
  echo -e "${YELLOW}No arguments provided. Searching current directory for fonts...${NC}"
  count=$(install_fonts ".")
  total_fonts=$count
else
  # Process each argument
  for arg in "$@"; do
    if [ -e "$arg" ]; then
      count=$(install_fonts "$arg")
      total_fonts=$((total_fonts + count))
    else
      echo -e "${RED}Error: $arg does not exist${NC}"
    fi
  done
fi

if [ $total_fonts -eq 0 ]; then
  echo -e "${RED}No fonts were installed${NC}"
  exit 1
fi

echo -e "${GREEN}Total fonts installed: $total_fonts${NC}"

# Update font cache
echo -e "${YELLOW}Updating font cache...${NC}"
fc-cache -f -v

echo -e "${GREEN}Font installation complete!${NC}"
echo -e "${YELLOW}You may need to restart applications to see the new fonts.${NC}"

# List installed fonts (optional)
echo -e "\n${YELLOW}Installed fonts in $FONT_DIR:${NC}"
ls -1 "$FONT_DIR"
