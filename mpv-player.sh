#!/bin/bash

# MPV Music Player with Fuzzel Integration
# Usage: ./music-player.sh

MUSIC_DIR="/home/somya/Music"
SOCKET="/tmp/mpv-socket"
PLAYLIST="/tmp/mpv-playlist.txt"

# Kill any existing mpv instances using our socket
pkill -f "mpv.*$SOCKET" 2>/dev/null

# Function to play music
play_music() {
  local selected_file="$1"

  if [ -z "$selected_file" ]; then
    echo "No file selected"
    exit 1
  fi

  # Start mpv with IPC socket
  mpv --input-ipc-server="$SOCKET" \
    --no-video \
    --loop-playlist \
    --playlist="$PLAYLIST" \
    --playlist-start="$(grep -n "^$selected_file$" "$PLAYLIST" | cut -d: -f1 | head -1)" &

  echo "Playing: $(basename "$selected_file")"
}

# Function to control mpv
mpv_control() {
  local cmd="$1"

  if [ ! -S "$SOCKET" ]; then
    echo "MPV is not running"
    exit 1
  fi

  case "$cmd" in
  pause)
    echo '{"command": ["cycle", "pause"]}' | socat - "$SOCKET"
    ;;
  next)
    echo '{"command": ["playlist-next"]}' | socat - "$SOCKET"
    ;;
  stop)
    echo '{"command": ["quit"]}' | socat - "$SOCKET"
    ;;
  esac
}

# Main menu
case "${1:-menu}" in
menu | select)
  # Generate playlist
  find "$MUSIC_DIR" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.m4a" -o -iname "*.ogg" -o -iname "*.wav" -o -iname "*.opus" \) >"$PLAYLIST"

  if [ ! -s "$PLAYLIST" ]; then
    notify-send "Music Player" "No music files found in $MUSIC_DIR"
    exit 1
  fi

  # Use fuzzel to select music
  selected=$(cat "$PLAYLIST" | sed "s|$MUSIC_DIR/||" | fuzzel --dmenu --prompt "Select Music: ")

  if [ -n "$selected" ]; then
    full_path="$MUSIC_DIR/$selected"
    play_music "$full_path"
    notify-send "♪ Now Playing" "$(basename "$selected")"
  fi
  ;;

pause)
  mpv_control pause
  notify-send "Music Player" "Pause/Resume"
  ;;

next)
  mpv_control next
  sleep 0.2
  current=$(echo '{"command": ["get_property", "media-title"]}' | socat - "$SOCKET" | grep -o '"data":"[^"]*"' | cut -d'"' -f4)
  notify-send "♪ Next Track" "$current"
  ;;

stop)
  mpv_control stop
  notify-send "Music Player" "Stopped"
  ;;

*)
  echo "Usage: $0 {menu|pause|next|stop}"
  echo "  menu  - Select and play music"
  echo "  pause - Pause/Resume playback"
  echo "  next  - Next track"
  echo "  stop  - Stop playback"
  exit 1
  ;;
esac
