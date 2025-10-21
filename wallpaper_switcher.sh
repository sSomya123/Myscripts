#!/usr/bin/env bash

DIR="$HOME/scripts/wallpapers"

SELECTED=$(
  find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) |
    rofi -dmenu -i -p "Select Wallpaper" \
      -theme ~/.dotfiles/rofi/.config/rofi/launchers/type-1/style-2.rasi
)

if [[ -n "$SELECTED" ]]; then
  # Preload the selected wallpaper
  # hyprctl hyprpaper preload "$SELECTED"

  # Apply it to your monitor(s) (replace with your monitor name from `hyprctl monitors`)
  # hyprctl hyprpaper wallpaper eDP-1,"$SELECTED"
  swaybg -i "$SELECTED" &
  # Generate Material You palette with Matugen
  /usr/bin/matugen image "$SELECTED" >>~/.cache/matugen.log 2>&1
  swaync-client --reload-config && swaync-client --reload-css
  # OPTIONAL: Restart apps to apply new theme
  killall waybar 2>/dev/null && waybar &
  killall rofi 2>/dev/null
fi
