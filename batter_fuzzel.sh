#!/bin/bash

# Function to get battery info
get_battery_info() {
  # Get battery percentage
  battery_level=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)

  # Get charging status
  status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)

  # If battery info not found, try alternative method
  if [ -z "$battery_level" ]; then
    battery_level=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep percentage | awk '{print $2}' | tr -d '%')
    status=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep state | awk '{print $2}')
  fi

  echo "$battery_level|$status"
}

# Main loop
while true; do
  info=$(get_battery_info)
  battery_level=$(echo "$info" | cut -d'|' -f1)
  status=$(echo "$info" | cut -d'|' -f2)

  # Determine icon based on battery level and status
  if [[ "$status" == "Charging" || "$status" == "charging" ]]; then
    icon="🔌"
    status_text="Charging"
  elif [[ "$status" == "Discharging" || "$status" == "discharging" ]]; then
    icon="🔋"
    status_text="Discharging"
  elif [[ "$status" == "Full" || "$status" == "full" ]]; then
    icon="✅"
    status_text="Full"
  else
    icon="❓"
    status_text="$status"
  fi

  # Output current status
  echo "$icon Battery: $battery_level% - $status_text"

  # If not charging, exit after one iteration
  if [[ "$status" != "Charging" && "$status" != "charging" ]]; then
    break
  fi

  # Wait 2 seconds before updating (when charging)
  sleep 2
done | fuzzel --dmenu --prompt "Battery Status: "
