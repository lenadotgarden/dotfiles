#!/usr/bin/env bash

# Battery udev auto switcher script
# Triggered by udev on AC plug / unplug events

STATUS_FILE="/sys/class/power_supply/AC0/online"
if [ ! -f "$STATUS_FILE" ]; then
    STATUS_FILE=$(find /sys/class/power_supply/ -name "online" | head -n 1)
fi

if [ -f "$STATUS_FILE" ]; then
    ONLINE=$(cat "$STATUS_FILE")
    if [ "$ONLINE" -eq 1 ]; then
        /home/lena/dotfiles/home/scripts/power_save.sh performance
    else
        /home/lena/dotfiles/home/scripts/power_save.sh eco
    fi
fi
