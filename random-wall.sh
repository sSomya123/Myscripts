#!/bin/bash

# Folder with wallpapers
wallpaper_dir="$HOME/scripts/wallpapers/"

# Pick one at random
random_wall=$(find "$wallpaper_dir" -type f | shuf -n 1)

# Save chosen wallpaper path for hyprlock
echo "$random_wall" >~/.cache/current_wallpaper

# Save symlink for hyprlock
cp "$random_wall" ~/.cache/current_wallpaper.png

# Generate Material You theme from wallpaper
matugen image ~/.cache/current_wallpaper.png >>~/.cache/matugen.log 2>&1

# Kill any existing hyprpaper instance
pkill hyprpaper
pkill swaybg
# Start hyprpaper with the random wallpaper
hyprpaper &

# Give hyprpaper a moment to initialize
sleep 0.5

# Apply the wallpaper
#hyprctl hyprpaper preload "$random_wall"
#hyprctl hyprpaper wallpaper ",$random_wall"
swaybg -i "$random_wall" -m fill &
swaync-client --reload-config && swaync-client --reload-css

# # Generate Material You theme from wallpaper
# matugen image $random_wall --apply
