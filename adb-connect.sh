#!/usr/bin/env bash

# Check if adb is installed
if ! command -v adb &>/dev/null; then
  echo "adb is not installed. Please install Android Platform Tools."
  exit 1
fi

# Function to list devices
list_devices() {
  echo "Connected devices:"
  adb devices | awk 'NR>1 {print $1 " [" $2 "]"}'
}

# Function to pair a device (for ADB over Wi-Fi)
pair_device() {
  echo "Enter device IP and port (example: 192.168.1.100:5555):"
  read device_ip
  echo "Enter pairing code shown on your device:"
  read pairing_code
  adb pair "$device_ip" <<<"$pairing_code"
}

# Function to connect to a paired device
connect_device() {
  echo "Enter device IP and port to connect (example: 192.168.1.100:5555):"
  read device_ip
  adb connect "$device_ip"
}

# Function to disconnect a device
disconnect_device() {
  echo "Enter device IP and port to disconnect:"
  read device_ip
  adb disconnect "$device_ip"
}

# Function to show menu
while true; do
  echo "========================="
  echo "ADB Device Manager"
  echo "1) List connected devices"
  echo "2) Pair device (Wi-Fi)"
  echo "3) Connect to device (Wi-Fi)"
  echo "4) Disconnect device"
  echo "5) Exit"
  echo "========================="
  read -p "Select an option: " choice

  case $choice in
  1) list_devices ;;
  2) pair_device ;;
  3) connect_device ;;
  4) disconnect_device ;;
  5) exit ;;
  *) echo "Invalid option" ;;
  esac
done
