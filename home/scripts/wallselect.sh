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
    theme_file="$HOME/.cache/wal/colors-rofi-light.rasi"
else
    theme_file="$HOME/.cache/wal/colors-rofi-dark.rasi"
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

# open rofi loading pywal theme + direct inline -theme-str layout overrides
selected=$(echo -e "$rofi_input" | rofi -dmenu -p "🎨 Wallpapers" -i -show-icons ${theme_file:+-theme "$theme_file"} -theme-str '
    window { width: 75%; height: 60%; border-radius: 20px; location: center; border: 2px; }
    mainbox { padding: 20px; children: [ inputbar, listview ]; }
    inputbar { margin: 0px 0px 16px 0px; padding: 12px 16px; border-radius: 12px; children: [ prompt, entry ]; }
    prompt { margin: 0px 12px 0px 0px; font: "Iosevka Bold 12"; }
    entry { placeholder: "Search wallpaper..."; font: "Iosevka 12"; }
    listview { columns: 4; lines: 2; spacing: 18px; cycle: true; dynamic: true; }
    element { orientation: vertical; padding: 14px; border-radius: 14px; }
    element-icon { size: 180px; horizontal-align: 0.5; }
    element-text { horizontal-align: 0.5; font: "Iosevka 11"; margin: 8px 0px 0px 0px; }
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

# maintain global light/dark mode state upon changing wallpaper
if [ "$current_scheme" = "'prefer-light'" ]; then
    wal -i "$selected_wall" -n -q -l
else
    wal -i "$selected_wall" -n -q -b 11111b
fi

# Extract exact color4 (pywalAccent used in QuickShell) to synchronize Hyprland active border
acc_color=$(grep "color4=" "$HOME/.cache/wal/colors.sh" 2>/dev/null | cut -d"'" -f2 | tr -d '#')
if [ -n "$acc_color" ]; then
    hyprctl keyword general:col.active_border "rgba(${acc_color}ee)"
fi

# reload quickshell systemd user service
systemctl --user restart quickshell || (pkill quickshell; nohup quickshell >/dev/null 2>&1 & disown)

if command -v notify-send > /dev/null; then
    notify-send "🎨 Wallpaper" "$(basename "$selected_wall")"
fi
