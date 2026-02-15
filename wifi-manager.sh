#!/bin/bash

# Fuzzy finder detection
if command -v fuzzel &>/dev/null; then
  LAUNCHER="fuzzel --dmenu --width=60"
  LAUNCHER_TYPE="fuzzel"
elif command -v rofi &>/dev/null; then
  LAUNCHER="rofi -dmenu -i"
  LAUNCHER_TYPE="rofi"
else
  echo "❌ Error: fuzzel or rofi not found"
  exit 1
fi

# Check for NetworkManager
if ! command -v nmcli &>/dev/null; then
  notify-send "❌ Network Error" "NetworkManager (nmcli) not found" "critical"
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

# Get password input
get_password() {
  local prompt="$1"
  local password=""

  if [ "$LAUNCHER_TYPE" = "rofi" ]; then
    password=$(rofi -dmenu -i -password -p "$prompt")
  else
    # For fuzzel, use regular input (no built-in password masking)
    password=$(fuzzel --dmenu --width=60 -p "$prompt")
  fi

  echo "$password"
}

# Get WiFi status
get_wifi_status() {
  local status=$(nmcli radio wifi)
  if [ "$status" = "enabled" ]; then
    echo "🟢 ON"
  else
    echo "🔴 OFF"
  fi
}

# Get current connection
get_current_connection() {
  local conn=$(nmcli -t -f NAME,TYPE connection show --active | grep wireless | cut -d':' -f1 | head -1)
  if [ -n "$conn" ]; then
    echo "$conn"
  else
    echo "Not connected"
  fi
}

# Get signal strength icon
get_signal_icon() {
  local signal=$1
  if [ "$signal" -ge 80 ]; then
    echo "📶"
  elif [ "$signal" -ge 60 ]; then
    echo "📶"
  elif [ "$signal" -ge 40 ]; then
    echo "📡"
  elif [ "$signal" -ge 20 ]; then
    echo "📡"
  else
    echo "📡"
  fi
}

# Get security icon
get_security_icon() {
  local security=$1
  if echo "$security" | grep -q "WPA"; then
    echo "🔒"
  elif echo "$security" | grep -q "WEP"; then
    echo "🔐"
  else
    echo "🔓"
  fi
}

# Scan for WiFi networks
scan_wifi() {
  notify "🔍 Scanning" "Scanning for WiFi networks..." "low"
  nmcli device wifi rescan 2>/dev/null
  sleep 2
}

# List available WiFi networks
list_wifi_networks() {
  local show_all="${1:-false}"

  # Get current connection
  local current_ssid=$(nmcli -t -f NAME connection show --active | head -1)

  nmcli -f SSID,SIGNAL,SECURITY,BARS device wifi list | tail -n +2 | while read -r line; do
    ssid=$(echo "$line" | awk '{print $1}')
    signal=$(echo "$line" | awk '{print $2}')
    security=$(echo "$line" | awk '{$1=$2=""; print $0}' | xargs)

    # Skip empty SSIDs
    if [ -z "$ssid" ] || [ "$ssid" = "--" ]; then
      continue
    fi

    # Mark current connection
    if [ "$ssid" = "$current_ssid" ]; then
      marker="🔵"
    else
      marker="⚪"
    fi

    # Get icons
    signal_icon=$(get_signal_icon "$signal")
    security_icon=$(get_security_icon "$security")

    echo "$marker $signal_icon $security_icon $ssid ($signal%)|$ssid"
  done | sort -t'(' -k2 -rn
}

# Connect to WiFi network
connect_wifi() {
  scan_wifi

  networks=$(list_wifi_networks)

  if [ -z "$networks" ]; then
    notify "❌ Error" "No WiFi networks found" "critical"
    return
  fi

  selected=$(echo -e "$networks\n---\n➕ Connect to Hidden Network\n🔄 Rescan" | $LAUNCHER -p "Select WiFi Network")

  case "$selected" in
  "➕ Connect to Hidden Network")
    connect_hidden_network
    return
    ;;
  "🔄 Rescan")
    connect_wifi
    return
    ;;
  "---" | "")
    return
    ;;
  esac

  ssid=$(echo "$selected" | cut -d'|' -f2)

  if [ -z "$ssid" ]; then
    return
  fi

  # Check if network is secured
  security=$(nmcli -f SSID,SECURITY device wifi list | grep "^$ssid" | awk '{$1=""; print $0}' | xargs)

  if echo "$security" | grep -q "WPA\|WEP"; then
    # Ask for password
    password=$(get_password "Password for $ssid")

    if [ -z "$password" ]; then
      notify "❌ Cancelled" "Connection cancelled" "low"
      return
    fi

    notify "📡 Connecting" "Connecting to $ssid..." "normal"

    if nmcli device wifi connect "$ssid" password "$password" 2>/dev/null; then
      notify "✅ Connected" "Connected to $ssid" "normal"
    else
      notify "❌ Failed" "Failed to connect to $ssid. Check password and try again." "critical"
    fi
  else
    # Open network
    notify "📡 Connecting" "Connecting to $ssid..." "normal"

    if nmcli device wifi connect "$ssid" 2>/dev/null; then
      notify "✅ Connected" "Connected to $ssid" "normal"
    else
      notify "❌ Failed" "Failed to connect to $ssid" "critical"
    fi
  fi
}

# Connect to hidden network
connect_hidden_network() {
  ssid=$($LAUNCHER -p "Enter hidden network SSID")

  if [ -z "$ssid" ]; then
    return
  fi

  security=$(echo -e "WPA/WPA2\nWEP\nNone (Open)" | $LAUNCHER -p "Select security type")

  case "$security" in
  "WPA/WPA2")
    password=$(get_password "Password for $ssid")

    if [ -n "$password" ]; then
      notify "📡 Connecting" "Connecting to hidden network..." "normal"
      if nmcli device wifi connect "$ssid" password "$password" hidden yes 2>/dev/null; then
        notify "✅ Connected" "Connected to $ssid" "normal"
      else
        notify "❌ Failed" "Failed to connect to $ssid" "critical"
      fi
    fi
    ;;
  "None (Open)")
    notify "📡 Connecting" "Connecting to hidden network..." "normal"
    if nmcli device wifi connect "$ssid" hidden yes 2>/dev/null; then
      notify "✅ Connected" "Connected to $ssid" "normal"
    else
      notify "❌ Failed" "Failed to connect to $ssid" "critical"
    fi
    ;;
  *)
    notify "❌ Cancelled" "Connection cancelled" "low"
    ;;
  esac
}

# Disconnect from WiFi
disconnect_wifi() {
  current=$(get_current_connection)

  if [ "$current" = "Not connected" ]; then
    notify "ℹ️ Info" "Not connected to any network" "low"
    return
  fi

  confirm=$(echo -e "Yes\nNo" | $LAUNCHER -p "Disconnect from $current?")

  if [ "$confirm" = "Yes" ]; then
    nmcli connection down "$current"
    notify "🔌 Disconnected" "Disconnected from $current" "normal"
  fi
}

# Toggle WiFi
toggle_wifi() {
  status=$(nmcli radio wifi)

  if [ "$status" = "enabled" ]; then
    nmcli radio wifi off
    notify "🔴 WiFi OFF" "WiFi disabled" "normal"
  else
    nmcli radio wifi on
    notify "🟢 WiFi ON" "WiFi enabled" "normal"
  fi
}

# Saved connections
manage_saved_connections() {
  connections=$(nmcli -t -f NAME,TYPE connection show | grep wireless | cut -d':' -f1 | while read -r conn; do
    # Check if active
    if nmcli connection show --active | grep -q "$conn"; then
      echo "🟢 $conn|$conn"
    else
      echo "⚪ $conn|$conn"
    fi
  done)

  if [ -z "$connections" ]; then
    notify "ℹ️ Info" "No saved connections" "low"
    return
  fi

  menu="$connections
---
🗑️  Delete Connection
◀️  Back"

  selected=$(echo "$menu" | $LAUNCHER -p "Saved WiFi Networks")

  case "$selected" in
  "🗑️  Delete Connection")
    delete_saved_connection
    ;;
  "◀️  Back" | "---" | "")
    return
    ;;
  *)
    conn_name=$(echo "$selected" | cut -d'|' -f2)

    action=$(echo -e "📡 Connect\n📝 View Details\n🗑️  Delete\n◀️  Back" | $LAUNCHER -p "$conn_name")

    case "$action" in
    "📡 Connect")
      notify "📡 Connecting" "Connecting to $conn_name..." "normal"
      nmcli connection up "$conn_name"
      notify "✅ Connected" "Connected to $conn_name" "normal"
      ;;
    "📝 View Details")
      details=$(nmcli connection show "$conn_name" | grep -E "802-11-wireless|ipv4|ipv6")
      echo "$details" | $LAUNCHER -p "Connection Details: $conn_name"
      ;;
    "🗑️  Delete")
      confirm=$(echo -e "Yes\nNo" | $LAUNCHER -p "Delete $conn_name?")
      if [ "$confirm" = "Yes" ]; then
        nmcli connection delete "$conn_name"
        notify "🗑️ Deleted" "$conn_name deleted" "normal"
      fi
      ;;
    esac
    ;;
  esac
}

# Delete saved connection
delete_saved_connection() {
  connections=$(nmcli -t -f NAME,TYPE connection show | grep wireless | cut -d':' -f1)

  if [ -z "$connections" ]; then
    notify "ℹ️ Info" "No saved connections" "low"
    return
  fi

  selected=$(echo "$connections" | $LAUNCHER -p "Select connection to delete")

  if [ -n "$selected" ]; then
    confirm=$(echo -e "Yes\nNo" | $LAUNCHER -p "Delete $selected?")

    if [ "$confirm" = "Yes" ]; then
      nmcli connection delete "$selected"
      notify "🗑️ Deleted" "$selected deleted" "normal"
    fi
  fi
}

# Network information
show_network_info() {
  # Get active connection info
  active_conn=$(nmcli -t -f NAME connection show --active | head -1)

  if [ -z "$active_conn" ]; then
    info="Status: Not connected"
  else
    info=$(nmcli connection show "$active_conn" | grep -E "GENERAL.STATE|IP4.ADDRESS|IP4.GATEWAY|IP4.DNS|802-11-wireless.ssid|GENERAL.DEVICES")

    # Get signal strength
    signal=$(nmcli -f SIGNAL device wifi list | grep "^\*" | awk '{print $2}')

    # Format info
    info="Connection: $active_conn
Signal: $signal%

$info"
  fi

  echo "$info" | $LAUNCHER -p "Network Information"
}

# IP Configuration
ip_configuration() {
  menu="📊 Show IP Address
🔄 Renew DHCP
📝 Set Static IP
🌐 DNS Settings
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "IP Configuration")

  case "$choice" in
  "📊 Show IP Address")
    ip_info=$(ip -4 addr show | grep inet | grep -v 127.0.0.1)
    echo "$ip_info" | $LAUNCHER -p "IP Addresses"
    ;;
  "🔄 Renew DHCP")
    device=$(nmcli -t -f DEVICE connection show --active | head -1)
    if [ -n "$device" ]; then
      notify "🔄 Renewing" "Renewing DHCP lease..." "normal"
      nmcli connection down "$device" && nmcli connection up "$device"
      notify "✅ Renewed" "DHCP lease renewed" "normal"
    fi
    ;;
  "📝 Set Static IP")
    set_static_ip
    ;;
  "🌐 DNS Settings")
    manage_dns
    ;;
  esac
}

# Set static IP
set_static_ip() {
  active_conn=$(nmcli -t -f NAME connection show --active | head -1)

  if [ -z "$active_conn" ]; then
    notify "❌ Error" "No active connection" "critical"
    return
  fi

  ip_addr=$($LAUNCHER -p "Enter IP address (e.g., 192.168.1.100/24)")

  if [ -z "$ip_addr" ]; then
    return
  fi

  gateway=$($LAUNCHER -p "Enter gateway (e.g., 192.168.1.1)")
  dns=$($LAUNCHER -p "Enter DNS (e.g., 8.8.8.8)")

  if [ -n "$ip_addr" ] && [ -n "$gateway" ]; then
    nmcli connection modify "$active_conn" ipv4.method manual ipv4.addresses "$ip_addr" ipv4.gateway "$gateway"

    if [ -n "$dns" ]; then
      nmcli connection modify "$active_conn" ipv4.dns "$dns"
    fi

    nmcli connection down "$active_conn"
    nmcli connection up "$active_conn"

    notify "✅ Updated" "Static IP configured" "normal"
  fi
}

# Manage DNS
manage_dns() {
  menu="8.8.8.8, 8.8.4.4 (Google)
1.1.1.1, 1.0.0.1 (Cloudflare)
9.9.9.9, 149.112.112.112 (Quad9)
📝 Custom DNS
🔄 Auto (DHCP)
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "DNS Settings")

  active_conn=$(nmcli -t -f NAME connection show --active | head -1)

  if [ -z "$active_conn" ]; then
    notify "❌ Error" "No active connection" "critical"
    return
  fi

  case "$choice" in
  *"Google"*)
    nmcli connection modify "$active_conn" ipv4.dns "8.8.8.8 8.8.4.4"
    nmcli connection down "$active_conn" && nmcli connection up "$active_conn"
    notify "✅ DNS Updated" "Using Google DNS" "normal"
    ;;
  *"Cloudflare"*)
    nmcli connection modify "$active_conn" ipv4.dns "1.1.1.1 1.0.0.1"
    nmcli connection down "$active_conn" && nmcli connection up "$active_conn"
    notify "✅ DNS Updated" "Using Cloudflare DNS" "normal"
    ;;
  *"Quad9"*)
    nmcli connection modify "$active_conn" ipv4.dns "9.9.9.9 149.112.112.112"
    nmcli connection down "$active_conn" && nmcli connection up "$active_conn"
    notify "✅ DNS Updated" "Using Quad9 DNS" "normal"
    ;;
  "📝 Custom DNS")
    custom_dns=$($LAUNCHER -p "Enter DNS servers (space separated)")
    if [ -n "$custom_dns" ]; then
      nmcli connection modify "$active_conn" ipv4.dns "$custom_dns"
      nmcli connection down "$active_conn" && nmcli connection up "$active_conn"
      notify "✅ DNS Updated" "Custom DNS configured" "normal"
    fi
    ;;
  "🔄 Auto (DHCP)")
    nmcli connection modify "$active_conn" ipv4.dns ""
    nmcli connection modify "$active_conn" ipv4.ignore-auto-dns no
    nmcli connection down "$active_conn" && nmcli connection up "$active_conn"
    notify "✅ DNS Updated" "Using DHCP DNS" "normal"
    ;;
  esac
}

# VPN Management
manage_vpn() {
  vpn_connections=$(nmcli -t -f NAME,TYPE connection show | grep vpn | cut -d':' -f1)

  if [ -z "$vpn_connections" ]; then
    notify "ℹ️ Info" "No VPN connections configured" "low"
    return
  fi

  menu="$vpn_connections
---
➕ Add VPN
◀️  Back"

  selected=$(echo "$menu" | $LAUNCHER -p "VPN Connections")

  case "$selected" in
  "➕ Add VPN")
    notify "ℹ️ Info" "Use nmcli or nm-connection-editor to add VPN" "low"
    ;;
  "◀️  Back" | "---" | "")
    return
    ;;
  *)
    action=$(echo -e "📡 Connect\n🔌 Disconnect\n🗑️  Delete" | $LAUNCHER -p "$selected")

    case "$action" in
    "📡 Connect")
      notify "📡 Connecting" "Connecting to VPN..." "normal"
      nmcli connection up "$selected"
      notify "✅ Connected" "VPN connected" "normal"
      ;;
    "🔌 Disconnect")
      nmcli connection down "$selected"
      notify "🔌 Disconnected" "VPN disconnected" "normal"
      ;;
    "🗑️  Delete")
      confirm=$(echo -e "Yes\nNo" | $LAUNCHER -p "Delete VPN $selected?")
      if [ "$confirm" = "Yes" ]; then
        nmcli connection delete "$selected"
        notify "🗑️ Deleted" "VPN deleted" "normal"
      fi
      ;;
    esac
    ;;
  esac
}

# Ethernet management
manage_ethernet() {
  eth_devices=$(nmcli device status | grep ethernet | awk '{print $1}')

  if [ -z "$eth_devices" ]; then
    notify "ℹ️ Info" "No ethernet devices found" "low"
    return
  fi

  menu="📊 Show Ethernet Status
🔄 Reconnect
📝 Configure
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Ethernet Management")

  case "$choice" in
  "📊 Show Ethernet Status")
    status=$(nmcli device show | grep -A 10 "GENERAL.TYPE.*ethernet")
    echo "$status" | $LAUNCHER -p "Ethernet Status"
    ;;
  "🔄 Reconnect")
    eth_conn=$(nmcli -t -f NAME,TYPE connection show | grep ethernet | cut -d':' -f1 | head -1)
    if [ -n "$eth_conn" ]; then
      nmcli connection down "$eth_conn"
      nmcli connection up "$eth_conn"
      notify "🔄 Reconnected" "Ethernet reconnected" "normal"
    fi
    ;;
  "📝 Configure")
    ip_configuration
    ;;
  esac
}

# Hotspot management
manage_hotspot() {
  menu="🔥 Create Hotspot
🔌 Stop Hotspot
📊 Hotspot Status
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Mobile Hotspot")

  case "$choice" in
  "🔥 Create Hotspot")
    ssid=$($LAUNCHER -p "Enter hotspot name (SSID)")

    if [ -z "$ssid" ]; then
      return
    fi

    password=$(get_password "Enter password (min 8 chars)")

    if [ -z "$password" ]; then
      return
    fi

    notify "🔥 Creating" "Creating hotspot..." "normal"
    nmcli device wifi hotspot ssid "$ssid" password "$password"
    notify "✅ Active" "Hotspot created: $ssid" "normal"
    ;;
  "🔌 Stop Hotspot")
    nmcli connection down Hotspot 2>/dev/null
    notify "🔌 Stopped" "Hotspot stopped" "normal"
    ;;
  "📊 Hotspot Status")
    status=$(nmcli connection show Hotspot 2>/dev/null)
    if [ -n "$status" ]; then
      echo "$status" | $LAUNCHER -p "Hotspot Status"
    else
      notify "ℹ️ Info" "No active hotspot" "low"
    fi
    ;;
  esac
}

# Network diagnostics
network_diagnostics() {
  menu="🏓 Ping Test
🌐 DNS Test
📊 Speed Test
🔍 Trace Route
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Network Diagnostics")

  case "$choice" in
  "🏓 Ping Test")
    host=$(echo -e "8.8.8.8 (Google DNS)\n1.1.1.1 (Cloudflare)\nCustom" | $LAUNCHER -p "Select host to ping")

    case "$host" in
    *"Google"*)
      result=$(ping -c 4 8.8.8.8 2>&1)
      echo "$result" | $LAUNCHER -p "Ping Results"
      ;;
    *"Cloudflare"*)
      result=$(ping -c 4 1.1.1.1 2>&1)
      echo "$result" | $LAUNCHER -p "Ping Results"
      ;;
    "Custom")
      custom=$($LAUNCHER -p "Enter host to ping")
      if [ -n "$custom" ]; then
        result=$(ping -c 4 "$custom" 2>&1)
        echo "$result" | $LAUNCHER -p "Ping Results"
      fi
      ;;
    esac
    ;;
  "🌐 DNS Test")
    result=$(nslookup google.com 2>&1)
    echo "$result" | $LAUNCHER -p "DNS Test Results"
    ;;
  "📊 Speed Test")
    if command -v speedtest-cli &>/dev/null; then
      notify "📊 Testing" "Running speed test..." "normal"
      result=$(speedtest-cli --simple 2>&1)
      echo "$result" | $LAUNCHER -p "Speed Test Results"
    else
      notify "❌ Error" "speedtest-cli not installed" "critical"
    fi
    ;;
  "🔍 Trace Route")
    host=$($LAUNCHER -p "Enter host for traceroute")
    if [ -n "$host" ]; then
      notify "🔍 Tracing" "Running traceroute..." "normal"
      result=$(traceroute "$host" 2>&1)
      echo "$result" | $LAUNCHER -p "Traceroute Results"
    fi
    ;;
  esac
}

# Main menu
show_main_menu() {
  wifi_status=$(get_wifi_status)
  current_conn=$(get_current_connection)

  menu="📡 WiFi: $wifi_status | Connected: $current_conn
---
🔄 Connect to WiFi
🔌 Disconnect
🔵 Toggle WiFi ON/OFF
🔍 Scan Networks
---
💾 Saved Networks
ℹ️  Network Information
⚙️  IP Configuration
🌐 DNS Settings
---
🔥 Mobile Hotspot
🔒 VPN Management
🔌 Ethernet
🏥 Network Diagnostics
---
🚪 Exit"

  choice=$(echo "$menu" | $LAUNCHER -p "Network Manager")

  case "$choice" in
  "🔄 Connect to WiFi")
    connect_wifi
    ;;
  "🔌 Disconnect")
    disconnect_wifi
    ;;
  "🔵 Toggle WiFi ON/OFF")
    toggle_wifi
    ;;
  "🔍 Scan Networks")
    scan_wifi
    networks=$(list_wifi_networks)
    echo "$networks" | $LAUNCHER -p "Available Networks"
    ;;
  "💾 Saved Networks")
    manage_saved_connections
    ;;
  "ℹ️  Network Information")
    show_network_info
    ;;
  "⚙️  IP Configuration")
    ip_configuration
    ;;
  "🌐 DNS Settings")
    manage_dns
    ;;
  "🔥 Mobile Hotspot")
    manage_hotspot
    ;;
  "🔒 VPN Management")
    manage_vpn
    ;;
  "🔌 Ethernet")
    manage_ethernet
    ;;
  "🏥 Network Diagnostics")
    network_diagnostics
    ;;
  "🚪 Exit")
    exit 0
    ;;
  esac
}

# Run main menu
show_main_menu
