#!/usr/bin/env zsh
# 🕹️ AutoGame Debug - Una sola iteración
set -euo pipefail

DEBUG="${DEBUG:-1}"
DEBUG_LOG() { echo "[DEBUG] $1"; }
log() { echo "[AutoGame] $1"; }

# Test 1: Verificar procesos de juegos
DEBUG_LOG "=== TEST 1: Procesos de juegos ==="
pgrep -a -f "SteamAppId=|steam_app_|\.exe$|wine|proton" 2>/dev/null | head -5 || DEBUG_LOG "No hay procesos de juego"

# Test 2: Verificar ventanas Hyprland
DEBUG_LOG "=== TEST 2: Ventanas Hyprland ==="
if command -v hyprctl &>/dev/null; then
    hyprctl clients -j 2>/dev/null | grep -o '"title":"[^"]*"' | head -5 || DEBUG_LOG "No se pudo leer ventanas"
else
    DEBUG_LOG "hyprctl no disponible"
fi

# Test 3: Variables de entorno
DEBUG_LOG "=== TEST 3: Variables de entorno ==="
echo "XDG_SESSION_DESKTOP=$XDG_SESSION_DESKTOP"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"

# Test 4: Comandos disponibles
DEBUG_LOG "=== TEST 4: Dependencias ==="
for cmd in notify-send hyprctl pgrep gamemoded; do
    if command -v "$cmd" &>/dev/null; then
        echo "✓ $cmd disponible"
    else
        echo "✗ $cmd NO disponible"
    fi
done