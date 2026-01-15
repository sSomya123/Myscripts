#!/bin/bash

# Script to reboot directly into Windows
# This script sets Windows as the next boot target and reboots

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script requires root privileges. Attempting to run with sudo..."
  sudo "$0" "$@"
  exit $?
fi

# Find Windows boot entry
echo "Finding Windows boot entry..."

# Get all menu entries from GRUB
WINDOWS_ENTRY=$(grep -i "menuentry.*windows" /boot/grub/grub.cfg | head -n 1 | sed -n "s/^menuentry '\([^']*\).*/\1/p")

if [ -z "$WINDOWS_ENTRY" ]; then
  echo "Error: Could not find Windows entry in GRUB config"
  echo "Checking alternative patterns..."

  # Try alternative search patterns
  WINDOWS_ENTRY=$(grep -i "menuentry.*Microsoft" /boot/grub/grub.cfg | head -n 1 | sed -n "s/^menuentry '\([^']*\).*/\1/p")
fi

if [ -z "$WINDOWS_ENTRY" ]; then
  echo "Error: Windows boot entry not found!"
  echo "Please run: grep -i windows /boot/grub/grub.cfg"
  echo "to find the exact entry name and edit this script."
  exit 1
fi

echo "Found Windows entry: $WINDOWS_ENTRY"

# Set Windows as next boot target
echo "Setting Windows as next boot target..."
grub-reboot "$WINDOWS_ENTRY"

if [ $? -ne 0 ]; then
  echo "Error: Failed to set boot target"
  exit 1
fi

echo "Boot target set successfully. Rebooting in 3 seconds..."
sleep 3

# Reboot the system
reboot
