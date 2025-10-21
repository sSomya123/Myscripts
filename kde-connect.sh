#!/bin/bash

# Fuzzy finder detection
if command -v fuzzel &>/dev/null; then
  LAUNCHER="fuzzel --dmenu --width=60"
elif command -v rofi &>/dev/null; then
  LAUNCHER="rofi -dmenu -i"
else
  echo "❌ Error: fuzzel or rofi not found. Install one of them."
  exit 1
fi

# Check if kdeconnect-cli is installed
if ! command -v kdeconnect-cli &>/dev/null; then
  notify-send "❌ KDE Connect" "kdeconnect not installed" "critical"
  exit 1
fi

# Notification function
notify() {
  local title="$1"
  local message="$2"
  local urgency="${3:-normal}"

  if command -v notify-send &>/dev/null; then
    notify-send -u "$urgency" "$title" "$message"
  fi
}

# Get list of devices with status
get_devices() {
  kdeconnect-cli --list-available 2>/dev/null | grep -E "^-" | while read -r line; do
    device_name=$(echo "$line" | sed 's/^- \(.*\): .*/\1/')
    device_id=$(echo "$line" | sed 's/^.*: \(.*\) (.*/\1/')

    # Check if trusted
    if kdeconnect-cli -d "$device_id" --list-available 2>/dev/null | grep -q "paired and reachable"; then
      echo "🟢 $device_name|$device_id"
    else
      echo "🔴 $device_name|$device_id"
    fi
  done
}

# Get all devices (including unavailable)
get_all_devices() {
  kdeconnect-cli --list-devices 2>/dev/null | grep -E "^-" | while read -r line; do
    device_name=$(echo "$line" | sed 's/^- \(.*\): .*/\1/')
    device_id=$(echo "$line" | sed 's/^.*: \(.*\) (.*/\1/')

    # Check reachability
    if kdeconnect-cli -d "$device_id" --list-available 2>/dev/null | grep -q "reachable"; then
      echo "🟢 $device_name|$device_id"
    else
      echo "⚫ $device_name (offline)|$device_id"
    fi
  done
}

# Select a device
select_device() {
  local prompt="$1"
  local all_devices="${2:-false}"

  if [ "$all_devices" = "true" ]; then
    devices=$(get_all_devices)
  else
    devices=$(get_devices)
  fi

  if [ -z "$devices" ]; then
    notify "❌ KDE Connect" "No devices found" "critical"
    return 1
  fi

  selected=$(echo "$devices" | $LAUNCHER -p "$prompt")

  if [ -z "$selected" ]; then
    return 1
  fi

  # Extract device ID
  echo "$selected" | cut -d'|' -f2
}

# Send file to device
send_file() {
  device_id=$(select_device "Select device to send file")

  if [ -z "$device_id" ]; then
    return
  fi

  # Use file picker if available
  if command -v zenity &>/dev/null; then
    file=$(zenity --file-selection --title="Select file to send")
  elif command -v kdialog &>/dev/null; then
    file=$(kdialog --getopenfilename)
  else
    notify "❌ Error" "File picker not available. Install zenity or kdialog" "critical"
    return
  fi

  if [ -n "$file" ] && [ -f "$file" ]; then
    notify "📤 Sending" "Sending $(basename "$file")..." "normal"
    kdeconnect-cli -d "$device_id" --share "$file"
    notify "✅ Sent" "File sent successfully" "normal"
  fi
}

# Send text/URL to device
send_text() {
  device_id=$(select_device "Select device to send text")

  if [ -z "$device_id" ]; then
    return
  fi

  # Get clipboard content as default
  clipboard=""
  if command -v wl-paste &>/dev/null; then
    clipboard=$(wl-paste 2>/dev/null)
  elif command -v xclip &>/dev/null; then
    clipboard=$(xclip -o -selection clipboard 2>/dev/null)
  fi

  text=$(echo -e "$clipboard" | $LAUNCHER -p "Enter text or URL to send")

  if [ -n "$text" ]; then
    kdeconnect-cli -d "$device_id" --share-text "$text"
    notify "✅ Sent" "Text sent successfully" "normal"
  fi
}

# Ring device
ring_device() {
  device_id=$(select_device "Select device to ring")

  if [ -z "$device_id" ]; then
    return
  fi

  kdeconnect-cli -d "$device_id" --ring
  notify "🔔 Ringing" "Device is ringing..." "normal"
}

# Send SMS
send_sms() {
  device_id=$(select_device "Select device to send SMS")

  if [ -z "$device_id" ]; then
    return
  fi

  phone=$(echo "" | $LAUNCHER -p "Enter phone number")

  if [ -z "$phone" ]; then
    return
  fi

  message=$(echo "" | $LAUNCHER -p "Enter message")

  if [ -n "$message" ]; then
    kdeconnect-cli -d "$device_id" --send-sms "$message" --destination "$phone"
    notify "📱 SMS Sent" "Message sent to $phone" "normal"
  fi
}

# Run command on device
run_command() {
  device_id=$(select_device "Select device")

  if [ -z "$device_id" ]; then
    return
  fi

  # Get available commands
  commands=$(kdeconnect-cli -d "$device_id" --list-commands 2>/dev/null)

  if [ -z "$commands" ]; then
    notify "❌ Error" "No commands available for this device" "critical"
    return
  fi

  selected_cmd=$(echo "$commands" | $LAUNCHER -p "Select command")

  if [ -n "$selected_cmd" ]; then
    cmd_id=$(echo "$selected_cmd" | grep -oP '(?<=\()[^)]+(?=\))')
    kdeconnect-cli -d "$device_id" --execute-command "$cmd_id"
    notify "✅ Executed" "Command executed" "normal"
  fi
}

# Battery status
show_battery() {
  device_id=$(select_device "Select device to check battery")

  if [ -z "$device_id" ]; then
    return
  fi

  battery_info=$(kdeconnect-cli -d "$device_id" --list-available 2>/dev/null | grep -i battery)

  if [ -n "$battery_info" ]; then
    echo "$battery_info" | $LAUNCHER -p "Battery Status"
  else
    notify "❌ Error" "Battery info not available" "critical"
  fi
}

# Pair/Unpair device
manage_pairing() {
  device_id=$(select_device "Select device" "true")

  if [ -z "$device_id" ]; then
    return
  fi

  # Check current pairing status
  if kdeconnect-cli -d "$device_id" --list-available 2>/dev/null | grep -q "paired"; then
    action=$(echo -e "🔓 Unpair\n❌ Cancel" | $LAUNCHER -p "Device is paired")

    if [ "$action" = "🔓 Unpair" ]; then
      kdeconnect-cli -d "$device_id" --unpair
      notify "🔓 Unpaired" "Device unpaired successfully" "normal"
    fi
  else
    action=$(echo -e "🔒 Pair\n❌ Cancel" | $LAUNCHER -p "Device is not paired")

    if [ "$action" = "🔒 Pair" ]; then
      kdeconnect-cli -d "$device_id" --pair
      notify "🔒 Pairing" "Pairing request sent. Accept on device" "normal"
    fi
  fi
}

# Device info
show_device_info() {
  device_id=$(select_device "Select device to view info")

  if [ -z "$device_id" ]; then
    return
  fi

  info=$(kdeconnect-cli -d "$device_id" --list-available 2>/dev/null)

  if [ -n "$info" ]; then
    echo "$info" | $LAUNCHER -p "Device Information"
  else
    notify "❌ Error" "Could not get device info" "critical"
  fi
}

# Browse device filesystem
browse_filesystem() {
  device_id=$(select_device "Select device to browse")

  if [ -z "$device_id" ]; then
    return
  fi

  notify "📁 Mounting" "Mounting device filesystem..." "normal"

  # Mount the device
  kdeconnect-cli -d "$device_id" --list-available 2>/dev/null | grep -q "sftp"

  if [ $? -eq 0 ]; then
    # Open file manager
    if command -v dolphin &>/dev/null; then
      dolphin "kdeconnect://$device_id" &
    elif command -v nautilus &>/dev/null; then
      nautilus "kdeconnect://$device_id" &
    elif command -v thunar &>/dev/null; then
      thunar "kdeconnect://$device_id" &
    else
      notify "✅ Mounted" "Open your file manager and navigate to kdeconnect://$device_id" "normal"
    fi
  else
    notify "❌ Error" "SFTP not available for this device" "critical"
  fi
}

# Screenshot from device
take_screenshot() {
  device_id=$(select_device "Select device to take photo/screenshot")

  if [ -z "$device_id" ]; then
    return
  fi

  action=$(echo -e "📸 Take Photo\n🖼️ Screenshot\n❌ Cancel" | $LAUNCHER -p "Select action")

  case "$action" in
  "📸 Take Photo")
    kdeconnect-cli -d "$device_id" --photo ~/Pictures/kdeconnect_photo_$(date +%Y%m%d_%H%M%S).jpg
    notify "📸 Photo" "Photo captured and saved to ~/Pictures/" "normal"
    ;;
  "🖼️ Screenshot")
    kdeconnect-cli -d "$device_id" --photo ~/Pictures/kdeconnect_screenshot_$(date +%Y%m%d_%H%M%S).jpg
    notify "🖼️ Screenshot" "Screenshot saved to ~/Pictures/" "normal"
    ;;
  esac
}

# Clipboard sync
sync_clipboard() {
  device_id=$(select_device "Select device for clipboard sync")

  if [ -z "$device_id" ]; then
    return
  fi

  action=$(echo -e "📋 Send Clipboard\n📥 Receive Clipboard\n❌ Cancel" | $LAUNCHER -p "Clipboard Action")

  case "$action" in
  "📋 Send Clipboard")
    if command -v wl-paste &>/dev/null; then
      clipboard=$(wl-paste 2>/dev/null)
    elif command -v xclip &>/dev/null; then
      clipboard=$(xclip -o -selection clipboard 2>/dev/null)
    fi

    if [ -n "$clipboard" ]; then
      kdeconnect-cli -d "$device_id" --share-text "$clipboard"
      notify "📋 Sent" "Clipboard content sent" "normal"
    fi
    ;;
  "📥 Receive Clipboard")
    notify "📥 Info" "Clipboard will sync automatically when copied on device" "low"
    ;;
  esac
}

# Refresh connections
refresh_devices() {
  kdeconnect-cli --refresh
  notify "🔄 Refreshed" "Scanning for devices..." "normal"
  sleep 2
  device_count=$(kdeconnect-cli --list-available 2>/dev/null | grep -c "^-")
  notify "✅ Complete" "Found $device_count available device(s)" "normal"
}

# Main menu
show_main_menu() {
  # Get device count
  available_count=$(kdeconnect-cli --list-available 2>/dev/null | grep -c "^-")
  total_count=$(kdeconnect-cli --list-devices 2>/dev/null | grep -c "^-")

  menu="📱 Devices [$available_count/$total_count available]
---
📤 Send File
📝 Send Text/URL
📋 Clipboard Sync
📱 Send SMS
---
🔔 Ring Device
📸 Take Photo/Screenshot
📁 Browse Filesystem
⚡ Run Command
---
🔋 Battery Status
ℹ️  Device Info
🔒 Pair/Unpair Device
---
🔄 Refresh Devices
📋 Show All Devices
⚙️  Settings
🚪 Exit"

  choice=$(echo "$menu" | $LAUNCHER -p "KDE Connect [$available_count devices]")

  case "$choice" in
  "📤 Send File")
    send_file
    ;;
  "📝 Send Text/URL")
    send_text
    ;;
  "🔔 Ring Device")
    ring_device
    ;;
  "📱 Send SMS")
    send_sms
    ;;
  "⚡ Run Command")
    run_command
    ;;
  "🔋 Battery Status")
    show_battery
    ;;
  "🔒 Pair/Unpair Device")
    manage_pairing
    ;;
  "ℹ️  Device Info")
    show_device_info
    ;;
  "📁 Browse Filesystem")
    browse_filesystem
    ;;
  "📸 Take Photo/Screenshot")
    take_screenshot
    ;;
  "📋 Clipboard Sync")
    sync_clipboard
    ;;
  "🔄 Refresh Devices")
    refresh_devices
    ;;
  "📋 Show All Devices")
    devices=$(get_all_devices)
    if [ -n "$devices" ]; then
      echo "$devices" | cut -d'|' -f1 | $LAUNCHER -p "All Devices"
    else
      notify "❌ Error" "No devices found" "critical"
    fi
    ;;
  "⚙️  Settings")
    settings_menu
    ;;
  "🚪 Exit")
    exit 0
    ;;
  "📱 Devices"*)
    device_menu
    ;;
  esac
}

# Device-specific menu
device_menu() {
  device_id=$(select_device "Select device")

  if [ -z "$device_id" ]; then
    return
  fi

  device_name=$(kdeconnect-cli --list-devices 2>/dev/null | grep "$device_id" | sed 's/^- \(.*\):.*/\1/')

  menu="📤 Send File
📝 Send Text
🔔 Ring
📱 Send SMS
📸 Photo/Screenshot
📁 Browse Files
⚡ Run Command
🔋 Battery
ℹ️  Info
🔒 Pair/Unpair
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "$device_name")

  case "$choice" in
  "📤 Send File")
    send_file
    ;;
  "📝 Send Text")
    send_text
    ;;
  "🔔 Ring")
    kdeconnect-cli -d "$device_id" --ring
    notify "🔔 Ringing" "$device_name is ringing" "normal"
    ;;
  "📱 Send SMS")
    send_sms
    ;;
  "📸 Photo/Screenshot")
    take_screenshot
    ;;
  "📁 Browse Files")
    browse_filesystem
    ;;
  "⚡ Run Command")
    run_command
    ;;
  "🔋 Battery")
    show_battery
    ;;
  "ℹ️  Info")
    show_device_info
    ;;
  "🔒 Pair/Unpair")
    manage_pairing
    ;;
  esac
}

# Settings menu
settings_menu() {
  menu="🔄 Restart KDE Connect
📊 Service Status
⚙️  Open KDE Connect Settings
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Settings")

  case "$choice" in
  "🔄 Restart KDE Connect")
    killall kdeconnectd 2>/dev/null
    kdeconnectd &
    notify "🔄 Restarted" "KDE Connect daemon restarted" "normal"
    ;;
  "📊 Service Status")
    status=$(systemctl --user status kdeconnectd 2>&1)
    echo "$status" | $LAUNCHER -p "Service Status"
    ;;
  "⚙️  Open KDE Connect Settings")
    if command -v kcmshell5 &>/dev/null; then
      kcmshell5 kcm_kdeconnect &
    elif command -v kdeconnect-settings &>/dev/null; then
      kdeconnect-settings &
    else
      notify "❌ Error" "Settings app not found" "critical"
    fi
    ;;
  esac
}

# Run main menu
show_main_menu
