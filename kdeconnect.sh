#!/usr/bin/env bash
#
# kdeconnect-fuzzel.sh
#
# A script to control KDE Connect devices using fuzzel.
#
# Dependencies:
# - kdeconnect-cli
# - fuzzel
# - notify-send
# - awk, grep, sed

# --- Dependency Check ---
for cmd in fuzzel kdeconnect-cli notify-send awk grep sed; do
  if ! command -v "$cmd" &>/dev/null; then
    err_msg="Error: Required command '$cmd' not found."
    # Try to show error in fuzzel if possible
    if command -v fuzzel &>/dev/null; then
      echo "$err_msg" | fuzzel -d -p "SCRIPT ERROR: "
    else
      echo "$err_msg" >&2
    fi
    exit 1
  fi
done

# --- Configuration ---
# Fuzzel options (customize as you like)
FUZZEL_OPTS="--dmenu -p 'KDE Connect: ' -l 10"

# --- Helper Function ---
# Function to send a desktop notification
notify_user() {
  # $1 = Device Name
  # $2 = Message
  notify-send "KDE Connect: $1" "$2"
}

# --- Step 1: Select Device ---

# Get a list of reachable devices in "Device Name: Device ID" format
DEVICE_LIST=$(kdeconnect-cli -l | grep 'reachable' | sed 's/^- //; s/ (paired, reachable)//')

if [ -z "$DEVICE_LIST" ]; then
  echo "No reachable devices found." | fuzzel $FUZZEL_OPTS -p "KDE Connect: "
  exit 1
fi

# Show device list in fuzzel and get user's choice
DEVICE_CHOICE=$(echo -e "$DEVICE_LIST" | fuzzel $FUZZEL_OPTS -p "Select Device: ")

# Exit if user cancelled (e.g., pressed Esc)
if [ -z "$DEVICE_CHOICE" ]; then
  exit 1
fi

# Parse the device name and ID from the choice
DEVICE_ID=$(echo "$DEVICE_CHOICE" | awk -F': ' '{print $2}')
DEVICE_NAME=$(echo "$DEVICE_CHOICE" | awk -F': ' '{print $1}')

# --- Step 2: Select Action ---

# Define the list of actions
ACTIONS="Ping
Ring Device
Lock Device
Request Photo
--- Media ---
Media: Play/Pause
Media: Next
Media: Previous
Media: Stop
--- Volume ---
Volume: Up
Volume: Down
--- Info ---
Show Battery"

# Show action list in fuzzel, with a prompt showing the selected device
ACTION_CHOICE=$(echo -e "$ACTIONS" | fuzzel $FUZZEL_OPTS -p "Action for $DEVICE_NAME: ")

# Exit if user cancelled
if [ -z "$ACTION_CHOICE" ]; then
  exit 1
fi

# --- Step 3: Execute Action ---

# Use a case statement to run the corresponding command
case "$ACTION_CHOICE" in
"Ping")
  kdeconnect-cli -d "$DEVICE_ID" --ping
  notify_user "$DEVICE_NAME" "Ping sent."
  ;;
"Ring Device")
  kdeconnect-cli -d "$DEVICE_ID" --ring
  notify_user "$DEVICE_NAME" "Ringing device..."
  ;;
"Lock Device")
  kdeconnect-cli -d "$DEVICE_ID" --lock
  notify_user "$DEVICE_NAME" "Lock command sent."
  ;;
"Request Photo")
  kdeconnect-cli -d "$DEVICE_ID" --request-photo
  notify_user "$DEVICE_NAME" "Requesting photo..."
  ;;
"Media: Play/Pause")
  kdeconnect-cli -d "$DEVICE_ID" --media-control --play-pause
  notify_user "$DEVICE_NAME" "Media: Play/Pause"
  ;;
"Media: Next")
  kdeconnect-cli -d "$DEVICE_ID" --media-control --next
  notify_user "$DEVICE_NAME" "Media: Next"
  ;;
"Media: Previous")
  kdeconnect-cli -d "$DEVICE_ID" --media-control --previous
  notify_user "$DEVICE_NAME" "Media: Previous"
  ;;
"Media: Stop")
  kdeconnect-cli -d "$DEVICE_ID" --media-control --stop
  notify_user "$DEVICE_NAME" "Media: Stop"
  ;;
"Volume: Up")
  kdeconnect-cli -d "$DEVICE_ID" --volume-up
  notify_user "$DEVICE_NAME" "Volume Up"
  ;;
"Volume: Down")
  kdeconnect-cli -d "$DEVICE_ID" --volume-down
  notify_user "$DEVICE_NAME" "Volume Down"
  ;;
"Show Battery")
  # Battery command outputs info directly, so we capture it
  BATTERY_INFO=$(kdeconnect-cli -d "$DEVICE_ID" --battery)
  notify_user "$DEVICE_NAME" "$BATTERY_INFO"
  ;;
*)
  # Handle separator lines or unexpected input
  if [[ ! "$ACTION_CHOICE" == "---"* ]]; then
    notify_user "$DEVICE_NAME" "Unknown action: $ACTION_CHOICE"
  fi
  ;;
esac

exit 0
