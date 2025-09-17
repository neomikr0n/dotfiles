#!/bin/bash

# ==============================================================================
# 🎬 Wallpaper Script for Hyprland with mpvpaper + hyprlock
# Author: n30
# Purpose: Play video wallpaper on DP-2, lock screen on focus loss, clean exit.
# ==============================================================================

set -euo pipefail  # 💡 Strict mode: fail on error, undefined vars, pipe failures

# --- CONFIGURACIÓN ---
wallpaper_dir="$HOME/dotfiles/share/wallpapers"
wallpaper_file="yellowmatrix.mp4"
wallpaper_path="$wallpaper_dir/$wallpaper_file"

# Opciones para mpvpaper (como array para evitar problemas de espacios)
mpvpaper_opts=(
  --no-audio
  --loop
  --gamma=-5
  --contrast=88
  --saturation=79
  --brightness=1
  --mute=yes
  --video-unscaled=no
  --panscan=.9999
)

# Output display (ajusta si usas otra pantalla)
display="DP-2"
layer="overlay"

# --- VALIDACIONES ---
if [[ ! -f "$wallpaper_path" ]]; then
  notify-send "❌ Error: Wallpaper no encontrado" \
    "El archivo de wallpaper no existe:\n$wallpaper_path"
  echo "❌ ERROR: Wallpaper no encontrado: $wallpaper_path" >&2
  exit 1
fi

# Verificar que mpvpaper esté instalado
if ! command -v mpvpaper &> /dev/null; then
  notify-send "❌ Error: mpvpaper no encontrado" \
    "Asegúrate de tener mpvpaper instalado.\nInstalación: yay -S mpvpaper-git"
  echo "❌ ERROR: mpvpaper no está instalado." >&2
  exit 1
fi

# Verificar que hyprlock esté instalado
if ! command -v hyprlock &> /dev/null; then
  notify-send "❌ Error: hyprlock no encontrado" \
    "Asegúrate de tener hyprlock instalado.\nInstalación: sudo pacman -S hyprlock"
  echo "❌ ERROR: hyprlock no está instalado." >&2
  exit 1
fi

# Verificar que jq esté disponible (para obtener workspace)
if ! command -v jq &> /dev/null; then
  echo "⚠️  Advertencia: jq no está instalado. No se mostrará el ID del workspace." >&2
  current_id="desconocido"
else
  if ! current_id=$(hyprctl activeworkspace -j | jq -r '.id' 2>/dev/null); then
    echo "⚠️  Advertencia: No se pudo obtener el workspace actual." >&2
    current_id="desconocido"
  fi
fi

# --- LÓGICA PRINCIPAL ---
echo "▶️  Iniciando mpvpaper con opciones:"
printf '   %s\n' "${mpvpaper_opts[@]}"

# Iniciar mpvpaper en segundo plano
mpvpaper \
  -vs \
  -o "${mpvpaper_opts[*]}" \
  --layer "$layer" \
  "$display" \
  "$wallpaper_path" &
mpvpaper_pid=$!

echo "✅ mpvpaper iniciado (PID: $mpvpaper_pid)"

# Bloquear la sesión (esto detiene la ejecución hasta que se desbloquee)
echo "🔒 Iniciando hyprlock..."
hyprlock

# Una vez desbloqueado, matar mpvpaper limpiamente
echo "⏹️  Desbloqueado. Finalizando mpvpaper..."
kill "$mpvpaper_pid" 2>/dev/null && echo "✅ mpvpaper finalizado correctamente." || \
  echo "⚠️  mpvpaper ya estaba muerto o no respondió."

# Notificación final
notify-send "✅ Sesión restaurada" \
  "Workspace $current_id restaurado exitosamente."

# Fin del script
exit 0