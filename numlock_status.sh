#!/bin/bash
# Save as ~/.config/hypr/scripts/numlock-notify.sh

while true; do
  current=$(cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | head -n1)
  if [ "$current" != "$previous" ]; then
    if [ "$current" = "1" ]; then
      notify-send -u low "Numlock" "ON" -t 1000
    else
      notify-send -u low "Numlock" "OFF" -t 1000
    fi
    previous=$current
  fi
  sleep 0.5
done
