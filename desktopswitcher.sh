#!/bin/bash

# Fuzzy finder detection
if command -v fuzzel &>/dev/null; then
  LAUNCHER="fuzzel --dmenu --width=60"
elif command -v rofi &>/dev/null; then
  LAUNCHER="rofi -dmenu -i"
else
  echo "❌ Error: fuzzel or rofi not found"
  exit 1
fi

# Check if hyprctl is available
if ! command -v hyprctl &>/dev/null; then
  notify-send "❌ Hyprland" "hyprctl not found. Are you running Hyprland?" "critical"
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

# Get current workspace
get_current_workspace() {
  hyprctl activeworkspace -j | jq -r '.id'
}

# Get all workspaces with window count
get_workspaces() {
  hyprctl workspaces -j | jq -r '.[] | "\(.id)|\(.windows)|\(.name)"' | sort -n | while IFS='|' read -r id windows name; do
    # Mark current workspace
    current=$(get_current_workspace)
    if [ "$id" = "$current" ]; then
      marker="🔵"
    else
      marker="⚪"
    fi

    # Add window count indicator
    if [ "$windows" -gt 0 ]; then
      window_info="[$windows windows]"
    else
      window_info="[empty]"
    fi

    # Handle named workspaces
    if [ "$name" != "null" ] && [ -n "$name" ]; then
      echo "$marker Workspace $id: $name $window_info|$id"
    else
      echo "$marker Workspace $id $window_info|$id"
    fi
  done
}

# Get workspace names from config
get_workspace_names() {
  if [ -f ~/.config/hypr/workspaces.conf ]; then
    cat ~/.config/hypr/workspaces.conf
  fi
}

# Save workspace name
save_workspace_name() {
  local ws_id="$1"
  local ws_name="$2"

  mkdir -p ~/.config/hypr

  # Remove old entry if exists
  if [ -f ~/.config/hypr/workspaces.conf ]; then
    sed -i "/^$ws_id:/d" ~/.config/hypr/workspaces.conf
  fi

  # Add new entry
  echo "$ws_id:$ws_name" >>~/.config/hypr/workspaces.conf
}

# Switch to workspace
switch_workspace() {
  ws_list=$(get_workspaces)

  if [ -z "$ws_list" ]; then
    notify "❌ Error" "No workspaces found" "critical"
    return
  fi

  selected=$(echo "$ws_list" | $LAUNCHER -p "Switch to workspace")

  if [ -n "$selected" ]; then
    ws_id=$(echo "$selected" | cut -d'|' -f2)
    hyprctl dispatch workspace "$ws_id"
    notify "✅ Switched" "Moved to workspace $ws_id" "low"
  fi
}

# Create new workspace
create_workspace() {
  # Get next available workspace number
  existing_ws=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n | tail -1)
  next_ws=$((existing_ws + 1))

  input=$(echo -e "Create workspace $next_ws\nCreate with custom number\n◀️ Cancel" | $LAUNCHER -p "New Workspace")

  case "$input" in
  "Create workspace $next_ws")
    hyprctl dispatch workspace "$next_ws"
    notify "✅ Created" "Workspace $next_ws created" "normal"

    # Ask for name
    name=$(echo "" | $LAUNCHER -p "Name for workspace $next_ws (optional)")
    if [ -n "$name" ]; then
      save_workspace_name "$next_ws" "$name"
      notify "📝 Named" "Workspace $next_ws named: $name" "low"
    fi
    ;;
  "Create with custom number")
    custom_num=$(echo "" | $LAUNCHER -p "Enter workspace number")
    if [ -n "$custom_num" ] && [ "$custom_num" -gt 0 ] 2>/dev/null; then
      hyprctl dispatch workspace "$custom_num"
      notify "✅ Created" "Workspace $custom_num created" "normal"

      # Ask for name
      name=$(echo "" | $LAUNCHER -p "Name for workspace $custom_num (optional)")
      if [ -n "$name" ]; then
        save_workspace_name "$custom_num" "$name"
        notify "📝 Named" "Workspace $custom_num named: $name" "low"
      fi
    fi
    ;;
  esac
}

# Move window to workspace
move_window() {
  ws_list=$(get_workspaces)

  selected=$(echo -e "$ws_list\n➕ Create new workspace" | $LAUNCHER -p "Move window to workspace")

  if [ "$selected" = "➕ Create new workspace" ]; then
    existing_ws=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n | tail -1)
    next_ws=$((existing_ws + 1))

    hyprctl dispatch movetoworkspace "$next_ws"
    notify "✅ Moved" "Window moved to new workspace $next_ws" "normal"
  elif [ -n "$selected" ]; then
    ws_id=$(echo "$selected" | cut -d'|' -f2)
    hyprctl dispatch movetoworkspace "$ws_id"
    notify "✅ Moved" "Window moved to workspace $ws_id" "normal"
  fi
}

# Move window to workspace and follow
move_window_follow() {
  ws_list=$(get_workspaces)

  selected=$(echo -e "$ws_list\n➕ Create new workspace" | $LAUNCHER -p "Move window and follow")

  if [ "$selected" = "➕ Create new workspace" ]; then
    existing_ws=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n | tail -1)
    next_ws=$((existing_ws + 1))

    hyprctl dispatch movetoworkspacesilent "$next_ws"
    hyprctl dispatch workspace "$next_ws"
    notify "✅ Moved" "Window moved to new workspace $next_ws" "normal"
  elif [ -n "$selected" ]; then
    ws_id=$(echo "$selected" | cut -d'|' -f2)
    hyprctl dispatch movetoworkspacesilent "$ws_id"
    hyprctl dispatch workspace "$ws_id"
    notify "✅ Moved" "Window moved to workspace $ws_id" "normal"
  fi
}

# Rename workspace
rename_workspace() {
  ws_list=$(get_workspaces)

  selected=$(echo "$ws_list" | $LAUNCHER -p "Select workspace to rename")

  if [ -n "$selected" ]; then
    ws_id=$(echo "$selected" | cut -d'|' -f2)

    # Get current name if exists
    current_name=$(grep "^$ws_id:" ~/.config/hypr/workspaces.conf 2>/dev/null | cut -d':' -f2)

    new_name=$(echo "$current_name" | $LAUNCHER -p "Enter new name for workspace $ws_id")

    if [ -n "$new_name" ]; then
      save_workspace_name "$ws_id" "$new_name"
      notify "📝 Renamed" "Workspace $ws_id renamed to: $new_name" "normal"
    fi
  fi
}

# Delete empty workspace
delete_workspace() {
  # Get empty workspaces
  empty_ws=$(hyprctl workspaces -j | jq -r '.[] | select(.windows == 0) | "\(.id)|\(.name)"' | while IFS='|' read -r id name; do
    if [ "$name" != "null" ] && [ -n "$name" ]; then
      echo "Workspace $id: $name [empty]|$id"
    else
      echo "Workspace $id [empty]|$id"
    fi
  done)

  if [ -z "$empty_ws" ]; then
    notify "ℹ️ Info" "No empty workspaces to delete" "low"
    return
  fi

  selected=$(echo "$empty_ws" | $LAUNCHER -p "Delete workspace")

  if [ -n "$selected" ]; then
    ws_id=$(echo "$selected" | cut -d'|' -f2)

    # Confirm deletion
    confirm=$(echo -e "Yes\nNo" | $LAUNCHER -p "Delete workspace $ws_id?")

    if [ "$confirm" = "Yes" ]; then
      # Remove from saved names
      sed -i "/^$ws_id:/d" ~/.config/hypr/workspaces.conf 2>/dev/null

      # Note: Hyprland doesn't have a direct delete command
      # Empty workspaces are automatically removed when switching away
      notify "🗑️ Deleted" "Workspace $ws_id will be removed" "normal"
    fi
  fi
}

# Navigate workspaces
navigate_workspaces() {
  current=$(get_current_workspace)

  menu="⬅️  Previous Workspace
➡️  Next Workspace
⬆️  Workspace +5
⬇️  Workspace -5
🔢 Go to specific workspace
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Navigate [Current: $current]")

  case "$choice" in
  "⬅️  Previous Workspace")
    hyprctl dispatch workspace e-1
    notify "⬅️ Moved" "Previous workspace" "low"
    ;;
  "➡️  Next Workspace")
    hyprctl dispatch workspace e+1
    notify "➡️ Moved" "Next workspace" "low"
    ;;
  "⬆️  Workspace +5")
    hyprctl dispatch workspace e+5
    notify "⬆️ Moved" "Workspace +5" "low"
    ;;
  "⬇️  Workspace -5")
    hyprctl dispatch workspace e-5
    notify "⬇️ Moved" "Workspace -5" "low"
    ;;
  "🔢 Go to specific workspace")
    ws_num=$(echo "" | $LAUNCHER -p "Enter workspace number")
    if [ -n "$ws_num" ] && [ "$ws_num" -gt 0 ] 2>/dev/null; then
      hyprctl dispatch workspace "$ws_num"
      notify "✅ Moved" "Workspace $ws_num" "low"
    fi
    ;;
  esac
}

# Special workspaces (scratchpad)
special_workspaces() {
  menu="📌 Toggle Special Workspace
➕ Move to Special Workspace
🔍 Show Special Workspace
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Special Workspaces")

  case "$choice" in
  "📌 Toggle Special Workspace")
    hyprctl dispatch togglespecialworkspace
    notify "📌 Toggled" "Special workspace toggled" "low"
    ;;
  "➕ Move to Special Workspace")
    hyprctl dispatch movetoworkspace special
    notify "➕ Moved" "Window moved to special workspace" "normal"
    ;;
  "🔍 Show Special Workspace")
    hyprctl dispatch workspace special
    notify "🔍 Shown" "Showing special workspace" "low"
    ;;
  esac
}

# Workspace overview
workspace_overview() {
  # Get detailed workspace information
  overview=$(hyprctl workspaces -j | jq -r '.[] | 
        "Workspace \(.id): \(.windows) windows" +
        (if .name != null and .name != "" then " [\(.name)]" else "" end) +
        (if .monitor != "" then " on \(.monitor)" else "" end)' | sort -n)

  # Add current workspace indicator
  current=$(get_current_workspace)
  overview=$(echo "$overview" | sed "s/Workspace $current:/🔵 Workspace $current:/")

  # Add summary
  total_ws=$(echo "$overview" | wc -l)
  total_windows=$(hyprctl workspaces -j | jq '[.[].windows] | add')

  summary="═══ WORKSPACE OVERVIEW ═══
Total Workspaces: $total_ws
Total Windows: $total_windows
Current: $current

$overview"

  echo "$summary" | $LAUNCHER -p "Workspace Overview"
}

# Workspace rules
workspace_rules() {
  menu="📌 Pin Window (all workspaces)
🔒 Lock to Current Workspace
🌐 Make Floating
⬜ Make Tiled
🖥️  Fullscreen
📺 Toggle Maximize
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Window Rules")

  case "$choice" in
  "📌 Pin Window (all workspaces)")
    hyprctl dispatch pin
    notify "📌 Pinned" "Window pinned to all workspaces" "normal"
    ;;
  "🔒 Lock to Current Workspace")
    hyprctl dispatch pin
    notify "🔒 Locked" "Window locked to workspace" "normal"
    ;;
  "🌐 Make Floating")
    hyprctl dispatch togglefloating
    notify "🌐 Floating" "Window set to floating" "low"
    ;;
  "⬜ Make Tiled")
    hyprctl dispatch togglefloating
    notify "⬜ Tiled" "Window set to tiled" "low"
    ;;
  "🖥️  Fullscreen")
    hyprctl dispatch fullscreen
    notify "🖥️  Fullscreen" "Fullscreen toggled" "low"
    ;;
  "📺 Toggle Maximize")
    hyprctl dispatch fullscreen 1
    notify "📺 Maximize" "Maximize toggled" "low"
    ;;
  esac
}

# Monitor management
monitor_management() {
  monitors=$(hyprctl monitors -j | jq -r '.[] | "\(.name): \(.width)x\(.height)@\(.refreshRate)Hz"')

  menu="🖥️  Show Monitors
🔄 Move Workspace to Monitor
🎯 Focus Monitor
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Monitor Management")

  case "$choice" in
  "🖥️  Show Monitors")
    echo "$monitors" | $LAUNCHER -p "Connected Monitors"
    ;;
  "🔄 Move Workspace to Monitor")
    current_ws=$(get_current_workspace)
    monitor=$(echo "$monitors" | cut -d':' -f1 | $LAUNCHER -p "Move workspace $current_ws to monitor")

    if [ -n "$monitor" ]; then
      hyprctl dispatch moveworkspacetomonitor "$current_ws" "$monitor"
      notify "🔄 Moved" "Workspace moved to $monitor" "normal"
    fi
    ;;
  "🎯 Focus Monitor")
    monitor=$(echo "$monitors" | cut -d':' -f1 | $LAUNCHER -p "Focus monitor")

    if [ -n "$monitor" ]; then
      hyprctl dispatch focusmonitor "$monitor"
      notify "🎯 Focused" "Focused on $monitor" "low"
    fi
    ;;
  esac
}

# Batch operations
batch_operations() {
  menu="🗑️  Close All Windows in Workspace
📦 Collect All Floating Windows
🔀 Merge with Another Workspace
◀️  Back"

  choice=$(echo "$menu" | $LAUNCHER -p "Batch Operations")

  case "$choice" in
  "🗑️  Close All Windows in Workspace")
    current=$(get_current_workspace)
    confirm=$(echo -e "Yes\nNo" | $LAUNCHER -p "Close all windows in workspace $current?")

    if [ "$confirm" = "Yes" ]; then
      # Get all windows in current workspace
      hyprctl clients -j | jq -r --arg ws "$current" '.[] | select(.workspace.id == ($ws|tonumber)) | .address' | while read -r addr; do
        hyprctl dispatch closewindow "address:$addr"
      done
      notify "🗑️ Closed" "All windows closed in workspace $current" "normal"
    fi
    ;;
  "📦 Collect All Floating Windows")
    current=$(get_current_workspace)
    hyprctl clients -j | jq -r --arg ws "$current" '.[] | select(.workspace.id == ($ws|tonumber) and .floating == true) | .address' | while read -r addr; do
      hyprctl dispatch togglefloating "address:$addr"
    done
    notify "📦 Collected" "All floating windows tiled" "normal"
    ;;
  "🔀 Merge with Another Workspace")
    current=$(get_current_workspace)
    ws_list=$(get_workspaces | grep -v "Workspace $current")

    target=$(echo "$ws_list" | $LAUNCHER -p "Merge current workspace into")

    if [ -n "$target" ]; then
      target_id=$(echo "$target" | cut -d'|' -f2)

      # Move all windows from current to target
      hyprctl clients -j | jq -r --arg ws "$current" '.[] | select(.workspace.id == ($ws|tonumber)) | .address' | while read -r addr; do
        hyprctl dispatch movetoworkspacesilent "$target_id,address:$addr"
      done

      hyprctl dispatch workspace "$target_id"
      notify "🔀 Merged" "Workspace $current merged into $target_id" "normal"
    fi
    ;;
  esac
}

# Main menu
show_main_menu() {
  current_ws=$(get_current_workspace)
  total_ws=$(hyprctl workspaces -j | jq 'length')

  menu="🔵 Current: Workspace $current_ws
---
🔄 Switch Workspace
➕ Create New Workspace
📝 Rename Workspace
🗑️  Delete Empty Workspace
---
🚚 Move Window to Workspace
🚀 Move Window & Follow
📌 Special Workspace (Scratchpad)
---
⬅️ ➡️ Navigate Workspaces
📊 Workspace Overview [$total_ws total]
---
🎨 Window Rules
🖥️  Monitor Management
⚙️  Batch Operations
---
🚪 Exit"

  choice=$(echo "$menu" | $LAUNCHER -p "Hyprland Workspaces")

  case "$choice" in
  "🔄 Switch Workspace")
    switch_workspace
    ;;
  "➕ Create New Workspace")
    create_workspace
    ;;
  "📝 Rename Workspace")
    rename_workspace
    ;;
  "🗑️  Delete Empty Workspace")
    delete_workspace
    ;;
  "🚚 Move Window to Workspace")
    move_window
    ;;
  "🚀 Move Window & Follow")
    move_window_follow
    ;;
  "📌 Special Workspace (Scratchpad)")
    special_workspaces
    ;;
  "⬅️ ➡️ Navigate Workspaces")
    navigate_workspaces
    ;;
  "📊 Workspace Overview"*)
    workspace_overview
    ;;
  "🎨 Window Rules")
    workspace_rules
    ;;
  "🖥️  Monitor Management")
    monitor_management
    ;;
  "⚙️  Batch Operations")
    batch_operations
    ;;
  "🚪 Exit")
    exit 0
    ;;
  esac
}

# Run main menu
show_main_menu
