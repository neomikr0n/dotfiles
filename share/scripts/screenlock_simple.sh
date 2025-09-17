#!/bin/bash

wallpaperDir="$HOME/dotfiles/share/wallpapers"
wallpaperFile="yellowmatrix.mp4"
wallpaper="$wallpaperDir/$wallpaperFile"

# Verifica que el archivo exista
if [[ ! -f "$wallpaper" ]]; then
  notify-send "❌ Error" "El archivo de wallpaper no existe: $wallpaper"
  echo "❌ Error: El wallpaper no existe: $wallpaper"
  exit 1
fi

# Obtén el workspace actual (opcional)
current=$(hyprctl activeworkspace -j | jq '.id')

mpvpaper \
-vs \
-o "no-audio loop --gamma=-5 --contrast=88 --saturation=79 --brightness=1 --mute=yes --video-unscaled=no --panscan=.9999" \
--layer overlay DP-2 $wallpaper & 

# Guarda el PID para poder matarlo después
mpvpaper_pid=$!

# Lanza hyprlock (bloquea hasta que se desbloquee)
hyprlock

# Una vez desbloqueado, mata mpvpaper
kill $mpvpaper_pid 2>/dev/null || true

echo "✅ Wallpaper detenido tras desbloqueo."  
notify-send "✅" "Sesión $current restaurada exitosamente"
