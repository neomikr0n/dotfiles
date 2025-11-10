#!/bin/bash
# Actualiza en tiempo real el título de la canción actual

OUTFILE="$HOME/.cache/mangohud-song.txt"

while true; do
    SONG=$(playerctl metadata --format "{{artist}} - {{title}}" 2>/dev/null)
    echo "🎶 ${SONG:-No music playing}" > "$OUTFILE"
    sleep 2
done
