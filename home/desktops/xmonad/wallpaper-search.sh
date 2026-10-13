#!/usr/bin/env bash
# Search wallhaven.cc from rofi, preview thumbnails, apply with feh.
#   wallpaper-search           search the internet
#   wallpaper-search --saved   pick from already downloaded wallpapers
set -u
SAVE="$HOME/Pictures/Wallpapers"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-search"
STATE="$HOME/.cache/wallpaper"
mkdir -p "$SAVE" "$CACHE" "$STATE"

ROFI_THEME='window {width: 80%;} listview {columns: 4; lines: 3; spacing: 12px;}
element {orientation: vertical; padding: 8px;} element-icon {size: 11em;}
element-text {horizontal-align: 0.5;}'

apply() {
  feh --bg-fill "$1" && printf '%s' "$1" > "$STATE/current"
}

if [ "${1:-}" = "--saved" ]; then
  mapfile -t files < <(find "$SAVE" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
  [ "${#files[@]}" -gt 0 ] || { notify-send "Wallpapers" "Nothing saved yet" 2>/dev/null; exit 0; }
  idx=$(for f in "${files[@]}"; do printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"; done |
    rofi -dmenu -i -show-icons -format i -p "saved" -theme-str "$ROFI_THEME") || exit 0
  apply "${files[$idx]}"
  exit 0
fi

query=$(rofi -dmenu -p "search wallpapers" -theme-str 'listview {lines: 0;}' < /dev/null) || exit 0
if [ -n "$query" ]; then sorting=relevance; else sorting=toplist; fi

json=$(curl -fsS -G "https://wallhaven.cc/api/v1/search" \
  --data-urlencode "q=$query" \
  --data-urlencode "categories=111" \
  --data-urlencode "purity=100" \
  --data-urlencode "sorting=$sorting" \
  --data-urlencode "atleast=1920x1080" \
  --data-urlencode "ratios=landscape") || { notify-send "Wallpapers" "Search failed (offline?)" 2>/dev/null; exit 1; }

rm -rf "$CACHE/thumbs"; mkdir -p "$CACHE/thumbs"
mapfile -t rows < <(printf '%s' "$json" | jq -r '.data[:24][] | [.id, .thumbs.large, .path, .resolution] | @tsv')
[ "${#rows[@]}" -gt 0 ] || { notify-send "Wallpapers" "No results for: $query" 2>/dev/null; exit 0; }

# download thumbnails in parallel
printf '%s\n' "${rows[@]}" | cut -f1,2 |
  xargs -P 8 -L 1 sh -c 'curl -fsS -o "'"$CACHE"'/thumbs/$0.jpg" "$1"'

idx=$(for r in "${rows[@]}"; do
  IFS=$'\t' read -r id _ _ res <<< "$r"
  printf '%s\0icon\x1f%s\n' "$res" "$CACHE/thumbs/$id.jpg"
done | rofi -dmenu -show-icons -format i -no-custom -p "$query" -theme-str "$ROFI_THEME") || exit 0

IFS=$'\t' read -r id _ url _ <<< "${rows[$idx]}"
ext="${url##*.}"
dest="$SAVE/$id.$ext"
[ -f "$dest" ] || curl -fsS -o "$dest" "$url" || exit 1
apply "$dest"
