#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallselect_thumbs"

mkdir -p "$CACHE_DIR"

if [ ! -d "$WALL_DIR" ] || [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
    if command -v notify-send > /dev/null; then
        notify-send "🎨 Wallpapers" "Dépose tes images dans ~/Pictures/Wallpapers/"
    fi
    exit 1
fi

# 1. Générer le menu Rofi avec aperçu des miniatures
ROFI_INPUT=""
while IFS= read -r img; do
    name=$(basename "$img")
    thumb="$CACHE_DIR/${name}.png"
    
    # Créer la miniature si elle n'existe pas
    if [ ! -f "$thumb" ]; then
        if command -v magick > /dev/null; then
            magick "$img" -thumbnail 256x256^ -gravity center -extent 256x256 "$thumb" 2>/dev/null || cp "$img" "$thumb"
        else
            thumb="$img"
        fi
    fi
    
    ROFI_INPUT="${ROFI_INPUT}${name}\x00icon\x1f${thumb}\n"
done < <(find "$WALL_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \))

# 2. Ouvrir Rofi en mode grille d'images (Icon Grid View)
SELECTED=$(echo -e "$ROFI_INPUT" | rofi -dmenu -p "🎨 Wallpapers" -i -show-icons -theme-str '
    window { width: 65%; height: 50%; border-radius: 16px; location: center; }
    listview { columns: 4; lines: 2; spacing: 14px; cycle: true; dynamic: true; }
    element { orientation: vertical; padding: 12px; border-radius: 12px; }
    element-icon { size: 140px; horizontal-align: 0.5; }
    element-text { horizontal-align: 0.5; font: "Inter 10"; }
')

if [ -z "$SELECTED" ]; then
    exit 0
fi

SELECTED_WALL="$WALL_DIR/$SELECTED"

# 3. S'assurer que awww-daemon est lancé
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon --format xrgb &
    sleep 0.2
fi

# 4. Transition rapide ultra-fluide (120 FPS)
awww img "$SELECTED_WALL" --transition-type simple --transition-step 255 --transition-fps 120

# 5. Extraction de la palette Pywal en mode sombre à fort contraste
wal -i "$SELECTED_WALL" -n -q -b 11111b

# 6. Rechargement instantané de Quickshell
pkill quickshell
quickshell &

# 7. Notification discrète
if command -v notify-send > /dev/null; then
    notify-send "🎨 Nouveau Thème" "$(basename "$SELECTED_WALL")"
fi
