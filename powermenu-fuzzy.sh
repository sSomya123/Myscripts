#!/bin/bash

entries=" Lock\n Suspend\n Reboot\n Shutdown\n Logout"

selected=$(echo -e "$entries" | fuzzel --dmenu --prompt "Power: ")

case $selected in
" Lock")
  sh -c '(sleep 0s; hyprlock)' &
  disown
  ;; # Or swaylock if you use it
" Suspend") systemctl suspend ;;
" Reboot") systemctl reboot ;;
" Shutdown") systemctl poweroff ;;
" Logout") hyprctl dispatch exit ;;
esac
pkill fuzzel
