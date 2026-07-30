#!/usr/bin/env bash

# read current scheme setting
current_scheme=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null)
last_wall=$(cat ~/.cache/wal/wal 2>/dev/null)

if [ -z "$last_wall" ] || [ ! -f "$last_wall" ]; then
    last_wall=$(find "$HOME/Pictures/Wallpapers" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) 2>/dev/null | head -n 1)
fi

if [ "$current_scheme" = "'prefer-dark'" ]; then
    # switch to light mode
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
    dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita'"
    
    if [ -n "$last_wall" ]; then
        wal -i "$last_wall" -n -q -l
    fi

    # hyprland light active border
    hyprctl keyword general:col.active_border "rgba(1e66f5ff)"
    hyprctl keyword general:col.inactive_border "rgba(bcc0ccaa)"

    # sync antigravity cli settings.json
    if [ -f "$HOME/.gemini/antigravity-cli/settings.json" ]; then
        sed -i 's/"colorScheme": *"dark"/"colorScheme": "light"/' "$HOME/.gemini/antigravity-cli/settings.json"
    fi

    if command -v notify-send > /dev/null; then
        notify-send "☀️ Light Mode" "System, Antigravity & Quickshell updated to light"
    fi
else
    # switch to dark mode
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
    
    if [ -n "$last_wall" ]; then
        wal -i "$last_wall" -n -q -b 11111b
    fi

    # hyprland dark active border
    hyprctl keyword general:col.active_border "rgba(89b4faee)"
    hyprctl keyword general:col.inactive_border "rgba(1e1e2eaa)"

    # sync antigravity cli settings.json
    if [ -f "$HOME/.gemini/antigravity-cli/settings.json" ]; then
        sed -i 's/"colorScheme": *"light"/"colorScheme": "dark"/' "$HOME/.gemini/antigravity-cli/settings.json"
    fi

    if command -v notify-send > /dev/null; then
        notify-send "🌙 Dark Mode" "System, Antigravity & Quickshell updated to dark"
    fi
fi

# reload quickshell systemd user service
systemctl --user restart quickshell || (pkill quickshell; nohup quickshell >/dev/null 2>&1 & disown)
