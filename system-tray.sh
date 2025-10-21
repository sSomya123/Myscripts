#!/usr/bin/env bash
# Interactive system tray manager for Hyprland using Fuzzel
# Dependencies: fuzzel, swaybg/waybar notifications, playerctl, nmcli, pamixer, flatpak/xdg-open apps

# --- Define tray items ---
# Example tray items; extend this list with your favorite tray apps
tray_items=(
  "🎵 Music Player (Toggle Play/Pause)"
  "🔊 Volume Control"
  "🌐 Network Manager"
  "💡 Brightness Control"
  "🖥️ Open App Menu"
  "❌ Quit Tray Script"
)

# --- Show tray menu ---
selection=$(printf "%s\n" "${tray_items[@]}" | fuzzel --prompt "System Tray" --dmenu --lines 6)

# --- Handle selection ---
case "$selection" in
"🎵 Music Player (Toggle Play/Pause)")
  # Toggle music
  if playerctl status &>/dev/null; then
    playerctl play-pause
  else
    notify-send "No music player active"
  fi
  ;;
"🔊 Volume Control")
  # Open a simple volume control via pamixer
  pamixer --toggle-mute
  notify-send "Volume toggled mute/unmute"
  ;;
"🌐 Network Manager")
  # List Wi-Fi connections using nmcli and connect
  wifi=$(nmcli device wifi list | awk 'NR>1 {print $2}')
  selected_wifi=$(echo "$wifi" | fuzzel --prompt "Connect to Wi-Fi" --dmenu)
  if [ -n "$selected_wifi" ]; then
    nmcli device wifi connect "$selected_wifi"
    notify-send "Connecting to $selected_wifi"
  fi
  ;;
"💡 Brightness Control")
  # Toggle brightness between 50% and 100% for demo
  current=$(brightnessctl g)
  max=$(brightnessctl m)
  if [ "$current" -lt $((max / 2)) ]; then
    brightnessctl s 100%
  else
    brightnessctl s 50%
  fi
  ;;
"🖥️ Open App Menu")
  # Open Rofi/Fuzzel app launcher
  fuzzel --dmenu --prompt "Run: "
  ;;
"❌ Quit Tray Script")
  exit 0
  ;;
*)
  notify-send "No action assigned"
  ;;
esac
