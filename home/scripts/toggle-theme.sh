#!/usr/bin/env bash

# Lire le mode actuel depuis dconf
CURRENT_SCHEME=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null)

if [ "$CURRENT_SCHEME" = "'prefer-dark'" ]; then
    # Passage en Mode Clair
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
    dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita'"
    LAST_WALL=$(cat ~/.cache/wal/wal 2>/dev/null)
    if [ -n "$LAST_WALL" ] && [ -f "$LAST_WALL" ]; then
        wal -i "$LAST_WALL" -n -q -l
    fi
    if command -v notify-send > /dev/null; then
        notify-send "☀️ Mode Clair" "Système et navigateur configurés en mode clair"
    fi
else
    # Passage en Mode Sombre
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
    LAST_WALL=$(cat ~/.cache/wal/wal 2>/dev/null)
    if [ -n "$LAST_WALL" ] && [ -f "$LAST_WALL" ]; then
        wal -i "$LAST_WALL" -n -q -b 11111b
    fi
    if command -v notify-send > /dev/null; then
        notify-send "🌙 Mode Sombre" "Système et navigateur configurés en mode sombre"
    fi
fi

# Recharger Quickshell pour refléter le mode
pkill quickshell
quickshell &
