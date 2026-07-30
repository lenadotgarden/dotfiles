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

# detect current system mode (dark/light)
current_scheme=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null)

if [ "$current_scheme" = "'prefer-light'" ]; then
    # Mode Clair (Clean Light Theme matching macOS/Adwaita)
    bg_color="#ffffff"
    fg_color="#11111b"
    card_color="#f0f0f5"
    accent_color="#1e66f5"
    border_color="#d0d0da"
    selected_fg="#ffffff"
else
    # Mode Sombre (Clean Dark Theme matching Catppuccin Mocha/QS)
    bg_color="#181825"
    fg_color="#ffffff"
    card_color="#1e1e2e"
    accent_color="#89b4fa"
    border_color="#313244"
    selected_fg="#11111b"
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

# open rofi grid gallery using clean, solid UI palette
selected=$(echo -e "$rofi_input" | rofi -dmenu -p "🎨 Wallpapers" -i -show-icons -theme-str "
    * { background-color: transparent; text-color: ${fg_color}; font: \"Iosevka 11\"; }
    window { width: 68%; height: 52%; border-radius: 18px; location: center; background-color: ${bg_color}; border: 2px; border-color: ${accent_color}; }
    mainbox { padding: 18px; children: [ inputbar, listview ]; }
    inputbar { margin: 0 0 14px 0; padding: 10px 14px; border-radius: 10px; background-color: ${card_color}; children: [ prompt, entry ]; }
    prompt { margin: 0 10px 0 0; text-color: ${accent_color}; font: \"Iosevka Bold 11\"; }
    entry { text-color: ${fg_color}; placeholder: \"Search wallpaper...\"; }
    listview { columns: 4; lines: 2; spacing: 14px; cycle: true; dynamic: true; }
    element { orientation: vertical; padding: 12px; border-radius: 12px; background-color: ${card_color}; }
    element selected { background-color: ${accent_color}; border-radius: 12px; }
    element selected element-text { text-color: ${selected_fg}; font: \"Iosevka Bold 10\"; }
    element-icon { size: 140px; horizontal-align: 0.5; }
    element-text { horizontal-align: 0.5; font: \"Iosevka 10\"; margin: 6px 0 0 0; text-color: ${fg_color}; }
")

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

# maintain global light/dark mode state upon changing wallpaper
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
