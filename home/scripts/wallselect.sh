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

# detect current system mode (dark/light) to adapt rofi background and text contrast
current_scheme=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null)

# default fallback colors
bg_color="#181825"
fg_color="#ffffff"
accent_color="#89b4fa"
card_color="#1e1e2e"
selected_fg="#11111b"

# parse exact pywal colors from colors.sh
if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d "'\"" | xargs)
        if [[ "$line" == background=* ]]; then
            bg_color="${line#background=}"
        elif [[ "$line" == foreground=* ]]; then
            fg_color="${line#foreground=}"
        elif [[ "$line" == color4=* ]] || [[ "$line" == color6=* ]] || [[ "$line" == color1=* ]]; then
            [ -z "$found_accent" ] && accent_color="${line#*=}" && found_accent=1
        elif [[ "$line" == color8=* ]] || [[ "$line" == color0=* ]]; then
            card_color="${line#*=}"
        fi
    done < "$HOME/.cache/wal/colors.sh"
fi

if [ "$current_scheme" = "'prefer-light'" ]; then
    fg_color="#11111b"
    selected_fg="#ffffff"
else
    fg_color="#ffffff"
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

# open rofi grid gallery matching exact quickshell & hyprland dynamic pywal colors
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
