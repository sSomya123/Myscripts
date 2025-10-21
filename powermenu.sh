#!/bin/bash

# Rofi Power Menu
chosen=$(echo -e " Lock\n Logout\n Reboot\n Shutdown\n Suspend" |
  rofi -dmenu -i -p "Power" \
    -location 3 -yoffset 50 \
    -theme-str 'window {width: 15%; height: 16%;}')

confirm_exit() {
  echo -e "Yes\nNo" | rofi -dmenu -i -p "Confirm $1?" \
    -location 3 -yoffset 50 \
    -theme-str 'window {width: 15%; height: 9%;} listview {columns: 2; lines: 1;}'
}

case "$chosen" in
" Lock")
  hyprlock
  ;;
" Logout")
  confirm=$(confirm_exit "Logout")
  [[ "$confirm" == "Yes" ]] && pkill -KILL -u "$USER"
  ;;
" Reboot")
  confirm=$(confirm_exit "Reboot")
  [[ "$confirm" == "Yes" ]] && systemctl reboot
  ;;
" Shutdown")
  confirm=$(confirm_exit "Shutdown")
  [[ "$confirm" == "Yes" ]] && systemctl poweroff
  ;;
" Suspend")
  confirm=$(confirm_exit "Suspend")
  [[ "$confirm" == "Yes" ]] && systemctl suspend
  ;;
esac
