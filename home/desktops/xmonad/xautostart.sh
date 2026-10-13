#!/usr/bin/env bash
# (Re)start compositor, notifications, tray and applets. Safe to run any time.
LOG="$HOME/.cache/xautostart.log"
: > "$LOG"
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY 2>/dev/null

pkill -x picom; pkill -x trayer; pkill -x xmobar; pkill -x dunst; pkill -x nm-applet
pkill -f blueman-applet; pkill -f udiskie; pkill -f polkit-gnome-authentication
sleep 0.4

picom -b >>"$LOG" 2>&1
setsid dunst >>"$LOG" 2>&1 &
xtheme bar
sleep 0.6
setsid nm-applet >>"$LOG" 2>&1 &
setsid blueman-applet >>"$LOG" 2>&1 &
setsid udiskie --tray >>"$LOG" 2>&1 &
setsid "$POLKIT_AGENT" >>"$LOG" 2>&1 &
if command -v kdeconnect-indicator >/dev/null; then setsid kdeconnect-indicator >>"$LOG" 2>&1 & fi
exit 0
