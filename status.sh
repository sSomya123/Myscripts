#!/usr/bin/env bash
# Show system info and control music via Fuzzel
# Hyprland-compatible

# Dependencies: jq, playerctl, date, uptime, fuzzel, hyprctl

# --- Get active window title ---
active_window=$(hyprctl activewindow -j | jq -r '.title // "No active window"')

# --- Get current date & time ---

datetime=$(date +"%d %b %Y | %I:%M %p")

# --- Get currently playing song ---
if playerctl status &>/dev/null; then
  status=$(playerctl status)
  if [ "$status" = "Playing" ]; then
    song_text="🎵 Music: $(playerctl metadata artist) - $(playerctl metadata title)"
  elif [ "$status" = "Paused" ]; then
    song_text="⏸️ Music: $(playerctl metadata artist) - $(playerctl metadata title)"
  else
    song_text="⏹️ Music: No music playing"
  fi
else
  song_text="🎧 Music: No player active"
fi

# --- Get uptime ---
uptime_str=$(uptime -p | sed 's/up //')

# --- Build menu options ---
menu="\
🪟 Window:$active_window
🕓 Time:$datetime
$song_text
⏳ Uptime:$uptime_str
"

# --- Show menu and get selection ---
selected=$(echo "$menu" | fuzzel --dmenu --prompt "System Info" --no-icons --lines 5 --width 60)

# --- Handle selection ---
case "$selected" in
"$song_text")
  # Toggle music playback
  if playerctl status &>/dev/null; then
    playerctl play-pause
  fi
  ;;
*)
  # Nothing for other lines
  ;;
esac
