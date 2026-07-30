#!/usr/bin/env bash

wall_dir="$HOME/Pictures/Wallpapers"
cache_dir="$HOME/.cache/wallselect_thumbs"

mkdir -p "$cache_dir"

if [ ! -d "$wall_dir" ] || [ -z "$(ls -A "$wall_dir" 2>/dev/null)" ]; then
    if command -v notify-send > /dev/null; then
        notify-send "🎨 Wallpapers" "Add your images to ~/Pictures/Wallpapers/"
    fi
    exit 1
fi

# build rofi icon grid input
rofi_input=""
while IFS= read -r img; do
    name=$(basename "$img")
    thumb="$cache_dir/${name}.png"
    
    if [ ! -f "$thumb" ]; then
        if command -v magick > /dev/null; then
            magick "$img" -thumbnail 256x256^ -gravity center -extent 256x256 "$thumb" 2>/dev/null || cp "$img" "$thumb"
        else
            thumb="$img"
        fi
    fi
    
    rofi_input="${rofi_input}${name}\x00icon\x1f${thumb}\n"
done < <(find "$wall_dir" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \))

# open rofi grid gallery
selected=$(echo -e "$rofi_input" | rofi -dmenu -p "🎨 Wallpapers" -i -show-icons -theme-str '
    window { width: 65%; height: 50%; border-radius: 16px; location: center; }
    listview { columns: 4; lines: 2; spacing: 14px; cycle: true; dynamic: true; }
    element { orientation: vertical; padding: 12px; border-radius: 12px; }
    element-icon { size: 140px; horizontal-align: 0.5; }
    element-text { horizontal-align: 0.5; font: "Inter 10"; }
')

if [ -z "$selected" ]; then
    exit 0
fi

selected_wall="$wall_dir/$selected"

# ensure daemon is alive
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon --format xrgb &
    sleep 0.2
fi

# smooth fast wallpaper transition
awww img "$selected_wall" --transition-type simple --transition-step 255 --transition-fps 120

# check current system mode (dark/light) to maintain global state
current_scheme=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null)

if [ "$current_scheme" = "'prefer-light'" ]; then
    wal -i "$selected_wall" -n -q -l
else
    wal -i "$selected_wall" -n -q -b 11111b
fi

# reload quickshell for instant palette update
pkill quickshell
quickshell &

if command -v notify-send > /dev/null; then
    notify-send "🎨 Wallpaper" "$(basename "$selected_wall")"
fi
