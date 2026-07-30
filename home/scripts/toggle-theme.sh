#!/usr/bin/env bash

MODE="$1"

if [ "$MODE" = "light" ]; then
    # Mode Clair
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
    wal -i "$HOME/Pictures/Wallpapers" -n -q -l
    notify-send "☀️ Mode Clair" "Système et navigateur configurés en mode clair"
else
    # Mode Sombre (Par défaut)
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    # Utiliser la dernière image de wallpaper si présente
    LAST_WALL=$(cat ~/.cache/wal/wal 2>/dev/null)
    if [ -n "$LAST_WALL" ] && [ -f "$LAST_WALL" ]; then
        wal -i "$LAST_WALL" -n -q -b 11111b
    fi
    notify-send "🌙 Mode Sombre" "Système et navigateur configurés en mode sombre"
fi

# Recharger Quickshell pour refléter le mode
pkill quickshell
quickshell &
