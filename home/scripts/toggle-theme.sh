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

    # hyprland light active border & UI Design Best Practice: Soft warm-slate ambient shadow
    hyprctl keyword general:col.active_border "rgba(1e66f5ff)"
    hyprctl keyword general:col.inactive_border "rgba(00000015)"
    # Warm cool-slate tint (rgba 24, 32, 54 at ~12% & 5% alpha) for a soft natural lift (macOS / iOS / Tailwind UI standard)
    hyprctl keyword decoration:shadow:color "rgba(18203620)"
    hyprctl keyword decoration:shadow:color_inactive "rgba(1820360d)"
    hyprctl keyword decoration:shadow:range 28
    hyprctl keyword decoration:shadow:render_power 2

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

    # hyprland dark active border & dark shadow
    hyprctl keyword general:col.active_border "rgba(89b4faee)"
    hyprctl keyword general:col.inactive_border "rgba(1e1e2eaa)"
    hyprctl keyword decoration:shadow:color "rgba(11111b66)"
    hyprctl keyword decoration:shadow:color_inactive "rgba(11111b44)"

    # sync antigravity cli settings.json
    if [ -f "$HOME/.gemini/antigravity-cli/settings.json" ]; then
        sed -i 's/"colorScheme": *"light"/"colorScheme": "dark"/' "$HOME/.gemini/antigravity-cli/settings.json"
    fi

    # sync neovim open instances & config
    if command -v nvim > /dev/null; then
        pkill -USR1 nvim 2>/dev/null || true
    fi

    if command -v notify-send > /dev/null; then
        notify-send "🌙 Dark Mode" "System, Antigravity, Neovim & Quickshell updated to dark"
    fi
fi

# reload quickshell cleanly via systemd without aggressive pkill duplication
systemctl --user is-active --quiet quickshell.service && systemctl --user reload-or-restart quickshell.service || (systemctl --user start quickshell.service 2>/dev/null || nohup quickshell >/dev/null 2>&1 & disown)
