#!/bin/bash

# File where the current song will be stored
CACHE_FILE="$HOME/.cache/mangohud-song.txt"

# Exit if another instance is already running
if pgrep -f "$(basename "$0")" | grep -v "$$" >/dev/null; then
    exit 0
fi

# Infinite loop querying MPRIS every 3 seconds
while true; do
    # Get artist and song using playerctl
    SONG=$(playerctl metadata --format "🎶 {{artist}} - {{title}}" 2>/dev/null)

    # Save result or "not playing"
    if [[ -n "$SONG" ]]; then
        echo "$SONG" > "$CACHE_FILE"
    else
        echo "🎵 (not playing)" > "$CACHE_FILE"
    fi

    sleep 3
done
