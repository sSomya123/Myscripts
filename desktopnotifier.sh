#!/usr/bin/env bash

# Listen for workspace changes
socat -U - UNIX-CONNECT:/tmp/hypr/"$HYPRLAND_INSTANCE_SIGNATURE"/.socket2.sock |
  while read -r line; do
    # Look for workspace change event
    if [[ $line == "workspace>>"* ]]; then
      # Extract workspace name/number
      ws="${line#workspace>>}"
      # Send notification
      dunstify -r 9999 "🖥 Switched to Workspace $ws"
    fi
  done
