#!/usr/bin/env bash
# xtheme [toggle|dark|light|apply|tray] - dark/light mode for the xMonad desktop.
# Regenerates rofi/dunst/xmobar/kitty colours, flips the GTK preference, restarts the bar.
set -u
STATE="$HOME/.cache/theme"
mkdir -p "$STATE" "$HOME/.config/rofi" "$HOME/.config/dunst" "$HOME/.cache/wal"
cur=$(cat "$STATE/mode" 2>/dev/null || echo dark)

palette() {
  if [ "$1" = light ]; then   # Catppuccin Latte
    BG=#dce0e8 BASE=#eff1f5 SURFACE=#ccd0da FG=#4c4f69 DIM=#9ca0b0 ONACC=#eff1f5
    BLUE=#1e66f5 TEAL=#179299 YELLOW=#df8e1d GREEN=#40a02b MAUVE=#8839ef RED=#d20f39
    C0=#5c5f77 C8=#6c6f85 C5=#ea76cb C7=#acb0be C15=#bcc0cc
  else                         # Catppuccin Mocha
    BG=#11111b BASE=#1e1e2e SURFACE=#313244 FG=#cdd6f4 DIM=#6c7086 ONACC=#11111b
    BLUE=#89b4fa TEAL=#94e2d5 YELLOW=#f9e2af GREEN=#a6e3a1 MAUVE=#cba6f7 RED=#f38ba8
    C0=#45475a C8=#585b70 C5=#f5c2e7 C7=#bac2de C15=#a6adc8
  fi
}

start_tray() {
  pkill -x trayer 2>/dev/null
  palette "$cur"
  setsid trayer --edge bottom --align right --widthtype request --expand true \
    --height 36 --distance 0 --distancefrom bottom --margin 0 \
    --padding 8 --iconspacing 6 --SetDockType true --SetPartialStrut false \
    --transparent true --alpha 0 --tint "0x${BG#\#}" --monitor primary >>"$HOME/.cache/xautostart.log" 2>&1 &
}

case "${1:-toggle}" in
  toggle) if [ "$cur" = dark ]; then mode=light; else mode=dark; fi; restart=1 ;;
  dark|light) mode=$1; restart=1 ;;
  apply) mode=$cur; restart=0 ;;
  tray) start_tray; exit 0 ;;
  *) echo "usage: xtheme [toggle|dark|light|apply|tray]"; exit 1 ;;
esac

printf '%s' "$mode" > "$STATE/mode"
cur=$mode
palette "$mode"

cat > "$HOME/.config/rofi/colors.rasi" <<RASI
* { bg: ${BASE}ee; bg-alt: ${SURFACE}; fg: ${FG}; dim: ${DIM}; accent: ${BLUE}; on-accent: ${ONACC}; }
RASI

sed -e "s/@BG@/$BG/g" -e "s/@FG@/$FG/g" -e "s/@RED@/$RED/g" -e "s/@TEAL@/$TEAL/g" \
    -e "s/@YELLOW@/$YELLOW/g" -e "s/@GREEN@/$GREEN/g" -e "s/@MAUVE@/$MAUVE/g" \
    -e "s/@BLUE@/$BLUE/g" "$XMOBAR_TPL" > "$STATE/xmobarrc"

cat > "$HOME/.cache/wal/colors-kitty.conf" <<KITTY
foreground $FG
background $BASE
cursor $BLUE
selection_foreground $ONACC
selection_background $BLUE
color0 $C0
color8 $C8
color1 $RED
color9 $RED
color2 $GREEN
color10 $GREEN
color3 $YELLOW
color11 $YELLOW
color4 $BLUE
color12 $BLUE
color5 $C5
color13 $C5
color6 $TEAL
color14 $TEAL
color7 $C7
color15 $C15
KITTY

cat > "$HOME/.config/dunst/dunstrc" <<DUNST
[global]
font = Iosevka 11
origin = top-right
offset = (16, 16)
width = (260, 380)
corner_radius = 14
frame_width = 0
padding = 14
horizontal_padding = 16
gap_size = 8
icon_position = left
max_icon_size = 44
format = "<b>%s</b>\n%b"
mouse_left_click = close_current
[urgency_low]
background = "${BASE}ee"
foreground = "$FG"
timeout = 4
[urgency_normal]
background = "${BASE}ee"
foreground = "$FG"
frame_color = "$BLUE"
timeout = 6
[urgency_critical]
background = "${BASE}ee"
foreground = "$RED"
timeout = 0
DUNST

if [ "$mode" = light ]; then
  dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
  dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita'"
else
  dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
  dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
fi

pkill -USR1 kitty 2>/dev/null
pkill -USR1 nvim 2>/dev/null
if [ "$restart" = 1 ]; then
  dunstctl reload 2>/dev/null
  start_tray
  xmonad --restart
  notify-send "Theme" "$mode mode" 2>/dev/null
fi
exit 0
