#!/bin/bash

# Fuzzy finder detection (fuzzel or rofi fallback)
if command -v fuzzel &>/dev/null; then
  LAUNCHER="fuzzel --dmenu --width=50"
elif command -v rofi &>/dev/null; then
  LAUNCHER="rofi -dmenu -i"
else
  LAUNCHER=""
fi

# Function to show notifications
notify() {
  local title="$1"
  local message="$2"
  local urgency="${3:-normal}"

  if command -v notify-send &>/dev/null; then
    notify-send -u "$urgency" "$title" "$message"
  fi
  echo -e "$title: $message"
}

# Function to use launcher or terminal input
get_choice() {
  local prompt="$1"
  local options="$2"

  if [ -n "$LAUNCHER" ]; then
    echo "$options" | $LAUNCHER -p "$prompt"
  else
    echo -e "$options"
    read -p "$prompt: " choice
    echo "$choice"
  fi
}

# Get bluetooth status with icon
get_bt_status() {
  local power_status=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
  local discoverable=$(bluetoothctl show | grep "Discoverable:" | awk '{print $2}')

  if [ "$power_status" = "yes" ]; then
    if [ "$discoverable" = "yes" ]; then
      echo "🔵 ON (Discoverable)"
    else
      echo "🔵 ON (Hidden)"
    fi
  else
    echo "⚫ OFF"
  fi
}

# Get connected devices count
get_connected_count() {
  local count=$(bluetoothctl devices Connected | wc -l)
  echo "$count"
}

# Check if bluetoothctl is installed
if ! command -v bluetoothctl &>/dev/null; then
  notify "❌ Bluetooth Error" "bluetoothctl is not installed. Install bluez package." "critical"
  exit 1
fi

# Interactive scan with progress
interactive_scan() {
  notify "🔍 Bluetooth" "Starting device scan..." "normal"

  # Start scan in background
  bluetoothctl scan on &
  SCAN_PID=$!

  # Show progress
  for i in {1..15}; do
    sleep 1
    if [ -n "$LAUNCHER" ]; then
      # Count devices found
      device_count=$(bluetoothctl devices | wc -l)
      notify "🔍 Scanning" "Found $device_count devices... ($i/15s)" "low"
    else
      echo -ne "\rScanning... $i/15s (Found $(bluetoothctl devices | wc -l) devices)"
    fi
  done

  # Stop scan
  bluetoothctl scan off
  kill $SCAN_PID 2>/dev/null

  echo ""
  notify "✅ Bluetooth" "Scan complete!" "normal"
}

# Enhanced device selection with details
select_device() {
  local device_type="$1"
  local action="$2"

  # Get devices based on type
  case $device_type in
  "paired")
    devices=$(bluetoothctl devices Paired)
    ;;
  "connected")
    devices=$(bluetoothctl devices Connected)
    ;;
  *)
    devices=$(bluetoothctl devices)
    ;;
  esac

  if [ -z "$devices" ]; then
    notify "❌ Bluetooth" "No $device_type devices found" "critical"
    return 1
  fi

  # Format device list with details
  formatted_devices=""
  while IFS= read -r device; do
    mac=$(echo "$device" | awk '{print $2}')
    name=$(echo "$device" | cut -d' ' -f3-)

    # Check if connected
    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
      status="🟢"
    else
      status="⚪"
    fi

    # Get device type icon
    device_info=$(bluetoothctl info "$mac")
    if echo "$device_info" | grep -q "Icon: audio"; then
      icon="🎧"
    elif echo "$device_info" | grep -q "Icon: input"; then
      icon="⌨️"
    elif echo "$device_info" | grep -q "Icon: phone"; then
      icon="📱"
    else
      icon="📡"
    fi

    formatted_devices+="$status $icon $name\n$mac\n"
  done <<<"$devices"

  # Show selection menu
  selected=$(echo -e "$formatted_devices" | grep -v "^$" | $LAUNCHER -p "$action")

  if [ -z "$selected" ]; then
    return 1
  fi

  # Extract MAC address
  if echo "$selected" | grep -qE "^([0-9A-F]{2}:){5}[0-9A-F]{2}$"; then
    echo "$selected"
  else
    # Get the next line (MAC address)
    echo -e "$formatted_devices" | grep -A1 "$selected" | tail -1
  fi
}

# Quick connect to last device
quick_connect() {
  local last_device=$(bluetoothctl devices Paired | head -1 | awk '{print $2}')

  if [ -n "$last_device" ]; then
    device_name=$(bluetoothctl devices Paired | head -1 | cut -d' ' -f3-)
    notify "📡 Connecting" "Connecting to $device_name..." "normal"

    result=$(bluetoothctl connect "$last_device" 2>&1)

    if echo "$result" | grep -q "Connection successful"; then
      notify "✅ Connected" "$device_name is connected!" "normal"
    else
      notify "❌ Connection Failed" "Could not connect to $device_name" "critical"
    fi
  else
    notify "❌ Bluetooth" "No paired devices found" "critical"
  fi
}

# Toggle bluetooth power
toggle_bluetooth() {
  local current_status=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')

  if [ "$current_status" = "yes" ]; then
    bluetoothctl power off
    notify "⚫ Bluetooth" "Bluetooth turned OFF" "normal"
  else
    bluetoothctl power on
    notify "🔵 Bluetooth" "Bluetooth turned ON" "normal"
  fi
}

# Main menu with dynamic status
show_menu() {
  local bt_status=$(get_bt_status)
  local connected_count=$(get_connected_count)

  local menu_options="🔄 Toggle Bluetooth [$bt_status]
📊 Service Status
⚡ Quick Connect (Last Device)
---
🔍 Scan for Devices (15s)
🔗 Pair New Device
📡 Connect to Device
🔌 Disconnect Device
🗑️  Remove/Unpair Device
---
📋 Show Paired Devices [$connected_count connected]
👁️  Toggle Discoverable
ℹ️  Controller Info
---
⚙️  Start Service
⏹️  Stop Service
🔄 Restart Service
---
🖥️  Open Blueman Manager
🚪 Exit"

  choice=$(get_choice "Bluetooth Menu [$bt_status]" "$menu_options")

  case "$choice" in
  *"Toggle Bluetooth"*)
    toggle_bluetooth
    ;;

  *"Service Status"*)
    if [ -n "$LAUNCHER" ]; then
      status=$(systemctl status bluetooth --no-pager 2>&1)
      echo "$status" | $LAUNCHER -p "Service Status"
    else
      systemctl status bluetooth
    fi
    ;;

  *"Quick Connect"*)
    quick_connect
    ;;

  *"Scan for Devices"*)
    interactive_scan
    devices=$(bluetoothctl devices | awk '{print $2 " " substr($0, index($0,$3))}')
    if [ -n "$devices" ]; then
      echo "$devices" | $LAUNCHER -p "Discovered Devices ($(echo "$devices" | wc -l) found)"
    fi
    ;;

  *"Pair New Device"*)
    notify "🔍 Bluetooth" "Scanning for devices..." "normal"
    interactive_scan

    mac_addr=$(select_device "all" "Select device to pair")

    if [ -n "$mac_addr" ]; then
      device_name=$(bluetoothctl devices | grep "$mac_addr" | cut -d' ' -f3-)
      notify "🔗 Pairing" "Pairing with $device_name..." "normal"

      result=$(bluetoothctl pair "$mac_addr" 2>&1)

      if echo "$result" | grep -q "Pairing successful"; then
        notify "✅ Paired" "$device_name paired successfully!" "normal"

        # Ask to connect
        connect_choice=$(get_choice "Connect now?" "Yes\nNo")
        if [ "$connect_choice" = "Yes" ]; then
          bluetoothctl connect "$mac_addr"
          notify "📡 Connected" "Connected to $device_name" "normal"
        fi
      else
        notify "❌ Pairing Failed" "Could not pair with $device_name" "critical"
      fi
    fi
    ;;

  *"Connect to Device"*)
    mac_addr=$(select_device "paired" "Select device to connect")

    if [ -n "$mac_addr" ]; then
      device_name=$(bluetoothctl devices | grep "$mac_addr" | cut -d' ' -f3-)
      notify "📡 Connecting" "Connecting to $device_name..." "normal"

      result=$(bluetoothctl connect "$mac_addr" 2>&1)

      if echo "$result" | grep -q "Connection successful"; then
        notify "✅ Connected" "$device_name is connected!" "normal"
      else
        notify "❌ Connection Failed" "Could not connect to $device_name" "critical"
      fi
    fi
    ;;

  *"Disconnect Device"*)
    mac_addr=$(select_device "connected" "Select device to disconnect")

    if [ -n "$mac_addr" ]; then
      device_name=$(bluetoothctl devices | grep "$mac_addr" | cut -d' ' -f3-)
      bluetoothctl disconnect "$mac_addr"
      notify "🔌 Disconnected" "Disconnected from $device_name" "normal"
    fi
    ;;

  *"Remove/Unpair"*)
    mac_addr=$(select_device "paired" "Select device to remove")

    if [ -n "$mac_addr" ]; then
      device_name=$(bluetoothctl devices | grep "$mac_addr" | cut -d' ' -f3-)
      confirm=$(get_choice "Remove $device_name?" "Yes\nNo")

      if [ "$confirm" = "Yes" ]; then
        bluetoothctl remove "$mac_addr"
        notify "🗑️ Removed" "$device_name removed successfully" "normal"
      else
        notify "❌ Cancelled" "Removal cancelled" "low"
      fi
    fi
    ;;

  *"Show Paired"*)
    paired=$(bluetoothctl devices Paired)
    connected=$(bluetoothctl devices Connected)

    output="=== PAIRED DEVICES ===\n$paired\n\n=== CONNECTED DEVICES ===\n$connected"

    if [ -n "$LAUNCHER" ]; then
      echo -e "$output" | $LAUNCHER -p "Device List"
    else
      echo -e "$output"
    fi
    ;;

  *"Toggle Discoverable"*)
    discoverable=$(bluetoothctl show | grep "Discoverable:" | awk '{print $2}')
    if [ "$discoverable" = "yes" ]; then
      bluetoothctl discoverable off
      notify "🔒 Bluetooth" "Device is now hidden" "normal"
    else
      bluetoothctl discoverable on
      notify "👁️ Bluetooth" "Device is now discoverable" "normal"
    fi
    ;;

  *"Controller Info"*)
    info=$(bluetoothctl show)
    if [ -n "$LAUNCHER" ]; then
      echo "$info" | $LAUNCHER -p "Controller Information"
    else
      echo "$info"
    fi
    ;;

  *"Start Service"*)
    sudo systemctl start bluetooth
    notify "✅ Service" "Bluetooth service started" "normal"
    ;;

  *"Stop Service"*)
    sudo systemctl stop bluetooth
    notify "⏹️ Service" "Bluetooth service stopped" "normal"
    ;;

  *"Restart Service"*)
    sudo systemctl restart bluetooth
    notify "🔄 Service" "Bluetooth service restarted" "normal"
    ;;

  *"Blueman Manager"*)
    if command -v blueman-manager &>/dev/null; then
      blueman-manager &
      notify "🖥️ Blueman" "Manager opened" "low"
    else
      notify "❌ Error" "Blueman is not installed" "critical"
    fi
    ;;

  *"Exit"*)
    notify "👋 Bluetooth" "Goodbye!" "low"
    exit 0
    ;;

  *)
    if [ -n "$choice" ]; then
      notify "❌ Error" "Invalid choice" "critical"
    fi
    ;;
  esac
}

# Run in loop if terminal, single run if launcher
if [ -n "$LAUNCHER" ]; then
  show_menu
else
  clear
  echo -e "\n\t\t#Modern Bluetooth Management Script\n"
  echo -e "\t\033[1;31m/!\ Ensure Bluetooth hardware is enabled /!\ \033[0m \n\n"
  echo -e "Bluetooth Manager for \033[1m$USER\033[0m on \033[1m$HOSTNAME\033[0m"

  while true; do
    echo -e "\n"
    show_menu
    read -p "Press Enter to continue..."
  done
fi
