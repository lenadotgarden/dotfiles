#!/usr/bin/env bash

# Power Mode switcher script
# Modes: 
#   performance (AC mode: 120Hz, animations, blur, shadows, high refresh rate)
#   eco         (Battery mode: 60Hz, no blur/shadows, animations off)
#   ultra-eco   (Ultra Battery mode: 48/60Hz, 15% brightness limit, animations off, kill heavy daemons/apps)

MODE="${1:-toggle}"
STATE_FILE="$HOME/.cache/power_mode"

if [ "$MODE" = "toggle" ]; then
    CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "performance")
    if [ "$CURRENT" = "performance" ]; then
        MODE="eco"
    elif [ "$CURRENT" = "eco" ]; then
        MODE="ultra-eco"
    else
        MODE="performance"
    fi
fi

apply_performance() {
    echo "performance" > "$STATE_FILE"
    
    # Hyprland High Performance / ProMotion
    hyprctl keyword monitor "eDP-1, 3024x1964@120, auto, 1.5625"
    hyprctl keyword decoration:blur:enabled true
    hyprctl keyword decoration:shadow:enabled true
    hyprctl keyword animations:enabled true
    hyprctl keyword misc:vfr true
    hyprctl keyword misc:vrr 1
    
    # Notify user
    if command -v notify-send > /dev/null; then
        notify-send -u low "⚡ Mode Performance" "Écran 120Hz ProMotion | Effets visuels activés"
    fi
}

apply_eco() {
    echo "eco" > "$STATE_FILE"
    
    # Hyprland Eco / 60Hz
    hyprctl keyword monitor "eDP-1, 3024x1964@60, auto, 1.5625"
    hyprctl keyword decoration:blur:enabled false
    hyprctl keyword decoration:shadow:enabled false
    hyprctl keyword animations:enabled false
    hyprctl keyword misc:vfr true
    hyprctl keyword misc:vrr 1
    
    # Baisser légèrement la luminosité si elle est très haute
    if command -v brightnessctl > /dev/null; then
        curr_b=$(brightnessctl get)
        max_b=$(brightnessctl max)
        percent=$(( curr_b * 100 / max_b ))
        if [ "$percent" -gt 60 ]; then
            brightnessctl set 50%
        fi
    fi

    # Notify user
    if command -v notify-send > /dev/null; then
        notify-send -u low "🔋 Mode Économie d'énergie" "Écran 60Hz | Ombrages & Flou désactivés"
    fi
}

apply_ultra_eco() {
    echo "ultra-eco" > "$STATE_FILE"
    
    # Hyprland Ultra Eco / 60Hz / Minimal render
    hyprctl keyword monitor "eDP-1, 3024x1964@60, auto, 1.5625"
    hyprctl keyword decoration:blur:enabled false
    hyprctl keyword decoration:shadow:enabled false
    hyprctl keyword animations:enabled false
    hyprctl keyword misc:vfr true
    hyprctl keyword misc:vrr 1

    # Couper bluetooth si actif
    if command -v bluetoothctl > /dev/null; then
        bluetoothctl power off 2>/dev/null || true
    fi

    # Réduire la luminosité à 15% max
    if command -v brightnessctl > /dev/null; then
        brightnessctl set 15%
    fi

    # Couper les processus gourmands d'arrière-plan optionnels
    pkill -f syncthing 2>/dev/null || true

    # Notify user
    if command -v notify-send > /dev/null; then
        notify-send -u normal "🪫 Mode Ultra Économie" "Luminosité 15% | Bluetooth désactivé | Processus secondaires coupés"
    fi
}

case "$MODE" in
    performance|ac)
        apply_performance
        ;;
    eco|battery)
        apply_eco
        ;;
    ultra-eco|ultra)
        apply_ultra_eco
        ;;
    *)
        echo "Usage: $0 {performance|eco|ultra-eco|toggle}"
        exit 1
        ;;
esac
