#!/bin/env bash

# Check if a Rofi process is already running for the powermenu
if pgrep -x "rofi" >/dev/null; then
  # If Rofi is running, close it
  pkill rofi
else
  # If Rofi is not running, execute the powermenu script
  ~/scripts/wallpaper_switcher.sh
fi
