#!/usr/bin/env bash

# Fetch system info
RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
STORAGE_USED=$(df -h / | awk 'NR==2 {print $3}')
STORAGE_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
UPTIME=$(uptime -p | sed 's/up //')
CPU_LOAD=$(awk '{print $1}' /proc/loadavg)

# Create menu entries
MENU="
󰍛  RAM: $RAM_USED / $RAM_TOTAL
󰋊  Storage: $STORAGE_USED / $STORAGE_TOTAL
󱑃  Uptime: $UPTIME
  CPU Load: $CPU_LOAD
---
  Open Terminal
  Open File Manager
󰍹  System Monitor
󰐥  Reboot
  Shutdown
󰗼  wlogout
"

# Use fuzzel to select
CHOICE=$(echo "$MENU" | fuzzel --dmenu --prompt "System Info  ")

# Actions
case "$CHOICE" in
*Terminal*) foot ;;
*File\ Manager*) pcmanfm ;;
*System\ Monitor*) gnome-system-monitor ;;
*Reboot*) systemctl reboot ;;
*Shutdown*) systemctl poweroff ;;
*wlogout*) wlogout -b 5 -c 1 -r 1 -m 1 ;;
*) exit 0 ;;
esac
