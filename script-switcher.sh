#!/bin/bash

# Script switcher using fuzzel
# Usage: Save this script and run it to select and run/edit scripts

SCRIPTS_DIR="$HOME/scripts"

# Check if fuzzel is installed
if ! command -v fuzzel &>/dev/null; then
  notify-send "Error" "fuzzel is not installed"
  exit 1
fi

# Get list of executable scripts
cd "$SCRIPTS_DIR" || exit 1
mapfile -t scripts < <(find . -maxdepth 1 -type f -executable -printf "%f\n" | sort)

if [ ${#scripts[@]} -eq 0 ]; then
  notify-send "No Scripts" "No executable scripts found in $SCRIPTS_DIR"
  exit 1
fi

# Let user select a script
selected=$(printf '%s\n' "${scripts[@]}" | fuzzel --dmenu --prompt "Select script: ")

# Exit if no selection
[ -z "$selected" ] && exit 0

# Ask what to do with the script
action=$(printf "Run\nEdit" | fuzzel --dmenu --prompt "Action: ")

case "$action" in
"Run")
  # Run the script directly
  "$SCRIPTS_DIR/$selected" &
  ;;
"Edit")
  # Edit with nvim in terminal
  if command -v alacritty &>/dev/null; then
    alacritty -e nvim "$SCRIPTS_DIR/$selected"
  elif command -v kitty &>/dev/null; then
    kitty -e nvim "$SCRIPTS_DIR/$selected"
  elif command -v foot &>/dev/null; then
    foot -e nvim "$SCRIPTS_DIR/$selected"
  else
    # Fallback
    nvim "$SCRIPTS_DIR/$selected"
  fi
  ;;
*)
  exit 0
  ;;
esac
