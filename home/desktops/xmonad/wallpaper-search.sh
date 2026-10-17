#!/usr/bin/env bash
# Wallpaper gallery + internet library (wallhaven.cc) in rofi.
#   wallpaper-search            gallery of saved wallpapers (+ random, + search the internet)
#   wallpaper-search --online   search the internet directly
set -u
SAVE="$HOME/Pictures/Wallpapers"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-search"
STATE="$HOME/.cache/wallpaper"
mkdir -p "$SAVE" "$CACHE/saved" "$STATE"

THEME="$HOME/.config/rofi/gallery.rasi"

note() { notify-send "Wallpapers" "$1" 2>/dev/null; }
apply() { feh --bg-fill "$1" && printf '%s' "$1" > "$STATE/current"; }
pick() { rofi -dmenu -i -show-icons -format i -p "$1" -theme "$THEME"; }

online() {
  local query page=1 json id url res ext dest idx
  query=$(rofi -dmenu -p "󰍉" -theme "$HOME/.config/rofi/launcher.rasi" -theme-str 'entry {placeholder: "Search wallpapers";} listview {lines: 0;}' < /dev/null) || return 0
  while :; do
    local sorting=relevance; [ -n "$query" ] || sorting=toplist
    json=$(curl -fsS -G "https://wallhaven.cc/api/v1/search" \
      --data-urlencode "q=$query" --data-urlencode "categories=111" \
      --data-urlencode "purity=100" --data-urlencode "sorting=$sorting" \
      --data-urlencode "atleast=1920x1080" --data-urlencode "ratios=landscape" \
      --data-urlencode "page=$page") || { note "Search failed (offline?)"; return 1; }
    mapfile -t rows < <(printf '%s' "$json" | jq -r '.data[:24][] | [.id, .thumbs.large, .path, .resolution] | @tsv')
    [ "${#rows[@]}" -gt 0 ] || { note "No results for: $query"; return 0; }
    rm -rf "$CACHE/thumbs"; mkdir -p "$CACHE/thumbs"
    printf '%s\n' "${rows[@]}" | cut -f1,2 |
      xargs -P 8 -L 1 sh -c 'curl -fsS -o "'"$CACHE"'/thumbs/$0.jpg" "$1"'
    idx=$({ for r in "${rows[@]}"; do
        IFS=$'\t' read -r id _ _ res <<< "$r"
        printf '%s\0icon\x1f%s\n' "$res" "$CACHE/thumbs/$id.jpg"
      done
      printf 'next page  \xe2\x96\xb6\n'
    } | pick "${query:-top} · p$page") || return 0
    if [ "$idx" -ge "${#rows[@]}" ]; then page=$((page + 1)); continue; fi
    IFS=$'\t' read -r id _ url _ <<< "${rows[$idx]}"
    ext="${url##*.}"; dest="$SAVE/$id.$ext"
    [ -f "$dest" ] || curl -fsS -o "$dest" "$url" || return 1
    apply "$dest"; return 0
  done
}

if [ "${1:-}" = "--online" ]; then online; exit 0; fi

mapfile -t files < <(find "$SAVE" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
# small cached thumbnails so the gallery opens fast
for f in "${files[@]}"; do
  t="$CACHE/saved/$(basename "$f").jpg"
  [ -f "$t" ] || magick "$f" -thumbnail '480x270^' -gravity center -extent 480x270 "$t" 2>/dev/null
done
idx=$({
  printf 'search the internet\0icon\x1fedit-find\n'
  printf 'random\0icon\x1fview-refresh\n'
  for f in "${files[@]}"; do printf '%s\0icon\x1f%s\n' "$(basename "${f%.*}")" "$CACHE/saved/$(basename "$f").jpg"; done
} | pick "gallery · ${#files[@]}") || exit 0
case "$idx" in
  0) online ;;
  1) [ "${#files[@]}" -gt 0 ] && apply "${files[RANDOM % ${#files[@]}]}" ;;
  *) apply "${files[$((idx - 2))]}" ;;
esac
