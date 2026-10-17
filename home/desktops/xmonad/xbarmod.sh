#!/usr/bin/env bash
# Text for the polybar custom modules: xbarmod wifi|bt|vol|bat|clock
case "${1:-}" in
  wifi)
    s=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -c 14)
    echo "${s:-offline}" ;;
  bt)
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then echo on; else echo off; fi ;;
  vol)
    pamixer --get-volume-human ;;
  bat)
    tot=0; n=0
    for f in /sys/class/power_supply/BAT*/capacity; do
      [ -r "$f" ] || continue
      tot=$((tot + $(cat "$f"))); n=$((n + 1))
    done
    ac=""
    for a in /sys/class/power_supply/A*/online; do
      [ "$(cat "$a" 2>/dev/null)" = 1 ] && ac=" +"
    done
    if [ "$n" -gt 0 ]; then echo "$((tot / n))%$ac"; else echo "AC"; fi ;;
  clock)
    date '+%a %d %b  %H:%M' ;;
esac
