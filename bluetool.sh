#!/bin/bash

clear

echo -e "\n\t\t#Modern Bluetooth Management Script\n"
echo -e "\t\033[1;31m/!\ Ensure Bluetooth hardware is enabled /!\ \033[0m \n\n"

# Check if bluetoothctl is installed
if ! command -v bluetoothctl &>/dev/null; then
  echo -e "\033[31mbluetoothctl is not installed.\033[0m"
  read -p "Do you want to install bluez? (y/n) " -n 1 check
  echo -e "\n"

  if [ "$check" = 'y' ] || [ "$check" = 'Y' ]; then
    sudo apt-get update && sudo apt-get install -y bluez
    echo -e "\nPlease re-run this script.\n"
  else
    echo -e "\nExiting script."
  fi
  exit 1
fi

echo -e "Bluetooth Manager for \033[1m$USER\033[0m on \033[1m$HOSTNAME\033[0m with \033[1m$SHELL\033[0m:"

while true; do
  sleep 1.5

  echo -e "\n\n\tMENU:"
  echo -e "\n1)\t\033[37mService: Status\033[0m"
  echo -e "2)\t\033[32mService: Start\033[0m"
  echo -e "3)\t\033[31mService: Stop\033[0m"
  echo -e "4)\t\033[36mService: Restart\033[0m"
  echo -e "5)\t\033[32mPower On Bluetooth\033[0m"
  echo -e "6)\t\033[31mPower Off Bluetooth\033[0m"
  echo -e "7)\t\033[32mMake Discoverable\033[0m"
  echo -e "8)\t\033[31mMake Non-Discoverable\033[0m"
  echo -e "9)\t\033[37mShow Controllers Info\033[0m"
  echo -e "10)\t\033[35mScan for Devices\033[0m"
  echo -e "11)\t\033[32mPair a Device\033[0m"
  echo -e "12)\t\033[36mConnect to Device\033[0m"
  echo -e "13)\t\033[33mDisconnect Device\033[0m"
  echo -e "14)\t\033[31mRemove/Unpair Device\033[0m"
  echo -e "15)\t\033[37mList Paired Devices\033[0m"
  echo -e "16)\t\033[36mOpen Blueman Manager (GUI)\033[0m"
  echo -e "17)\tExit\n"

  read -p "Choice ? " choice
  echo -e "\n"

  sleep 0.5

  case $choice in
  '1')
    systemctl status bluetooth
    ;;

  '2')
    sudo systemctl start bluetooth
    echo -e "\033[32mBluetooth service started.\033[0m"
    systemctl status bluetooth --no-pager
    ;;

  '3')
    sudo systemctl stop bluetooth
    echo -e "\033[31mBluetooth service stopped.\033[0m"
    systemctl status bluetooth --no-pager
    ;;

  '4')
    sudo systemctl restart bluetooth
    echo -e "\033[36mBluetooth service restarted.\033[0m"
    systemctl status bluetooth --no-pager
    ;;

  '5')
    bluetoothctl power on
    echo -e "\033[32mBluetooth powered on.\033[0m"
    ;;

  '6')
    bluetoothctl power off
    echo -e "\033[31mBluetooth powered off.\033[0m"
    ;;

  '7')
    bluetoothctl discoverable on
    echo -e "\033[32mDevice is now discoverable.\033[0m"
    ;;

  '8')
    bluetoothctl discoverable off
    echo -e "\033[31mDevice is now hidden.\033[0m"
    ;;

  '9')
    bluetoothctl show
    ;;

  '10')
    echo -e "\033[33mScanning for 15 seconds...\033[0m"
    bluetoothctl --timeout 15 scan on
    echo -e "\n\033[32mScan complete. Use option 15 to see discovered devices.\033[0m"
    ;;

  '11')
    bluetoothctl devices
    echo -e "\n"
    read -p "Enter device MAC address to pair: " mac_addr

    if [ -n "$mac_addr" ]; then
      echo -e "\033[33mPairing with $mac_addr...\033[0m"
      bluetoothctl pair "$mac_addr"
      echo -e "\033[32mAttempted to pair with device.\033[0m"
    else
      echo -e "\033[31mInvalid MAC address.\033[0m"
    fi
    ;;

  '12')
    bluetoothctl devices
    echo -e "\n"
    read -p "Enter device MAC address to connect: " mac_addr

    if [ -n "$mac_addr" ]; then
      echo -e "\033[33mConnecting to $mac_addr...\033[0m"
      bluetoothctl connect "$mac_addr"
    else
      echo -e "\033[31mInvalid MAC address.\033[0m"
    fi
    ;;

  '13')
    bluetoothctl devices
    echo -e "\n"
    read -p "Enter device MAC address to disconnect: " mac_addr

    if [ -n "$mac_addr" ]; then
      bluetoothctl disconnect "$mac_addr"
      echo -e "\033[33mDisconnected from device.\033[0m"
    else
      echo -e "\033[31mInvalid MAC address.\033[0m"
    fi
    ;;

  '14')
    bluetoothctl devices Paired
    echo -e "\n"
    read -p "Enter device MAC address to remove: " mac_addr

    if [ -n "$mac_addr" ]; then
      read -p "Are you sure you want to remove this device? (y/n) " -n 1 confirm
      echo -e "\n"

      if [ "$confirm" = 'y' ] || [ "$confirm" = 'Y' ]; then
        bluetoothctl remove "$mac_addr"
        echo -e "\033[32mDevice removed.\033[0m"
      else
        echo -e "\033[33mRemoval cancelled.\033[0m"
      fi
    else
      echo -e "\033[31mInvalid MAC address.\033[0m"
    fi
    ;;

  '15')
    echo -e "\033[37mPaired Devices:\033[0m"
    bluetoothctl devices Paired
    echo -e "\n\033[37mConnected Devices:\033[0m"
    bluetoothctl devices Connected
    ;;

  '16')
    if command -v blueman-manager &>/dev/null; then
      blueman-manager &
      echo -e "\033[32mBlueman Manager opened.\033[0m"
    else
      echo -e "\033[31mBlueman is not installed.\033[0m"
      read -p "Install blueman? (y/n) " -n 1 install
      echo -e "\n"
      if [ "$install" = 'y' ] || [ "$install" = 'Y' ]; then
        sudo apt-get install -y blueman
      fi
    fi
    ;;

  '17')
    echo -e "\nExiting script."
    sleep 1
    clear
    exit 0
    ;;

  *)
    echo -e "\033[31mInvalid choice.\033[0m\n"
    ;;
  esac
done
