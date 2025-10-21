#!/bin/bash

# --- Configuration ---
# Rofi prompt
rofi_prompt=" Power" # Using a power icon (requires a Nerd Font like JetBrains Mono Nerd Font)

# Menu options (displayed in Rofi) - Using icons for visual appeal
declare -A options=(
  [" Shutdown"]="systemctl poweroff"
  [" Reboot"]="systemctl reboot"
  [" Suspend"]="systemctl suspend"
  [" Logout"]="hyprctl dispatch exit" # Adjust for your WM/DE
  [" Lock"]="swaylock"                # Adjust for your locker
)

# --- Script Logic ---

# Generate the string of options for Rofi
# We only want the keys (the display text + icon)
display_options=$(printf "%s\n" "${!options[@]}")

# Rofi command with combined theme-str
chosen_option=$(echo -e "$display_options" | rofi -dmenu \
  -p "$rofi_prompt" \
  -theme-str "listview {columns: 5;} element-text {horizontal-align: 0.5;} element-icon {size: 1.5em; vertical-align: 0.5;} window {width: 450px; padding: 1em; border-radius: 1em;} inputbar {enabled: false;}" \
  -width 30 \
  -lines 1)

# Execute the command based on the chosen option
if [[ -n "$chosen_option" ]]; then # Check if an option was actually chosen
  # Find the command associated with the chosen display option
  action_cmd="${options["$chosen_option"]}"
  eval "$action_cmd" # Using eval to execute the command string
fi
