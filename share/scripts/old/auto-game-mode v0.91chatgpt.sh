#!/usr/bin/env bash
# 🕹️ AutoGame para Hyprland - versión final robusta
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
CHECK_INTERVAL=5
ML4W_FLAG="$HOME/.config/ml4w/settings/gamemode-enabled"
DEBUG="${DEBUG:-0}"

# ───────────────────────────────
# Evitar múltiples instancias
# ───────────────────────────────
if pgrep -f "$SCRIPT_NAME" | grep -v "^$$\$" >/dev/null; then
    echo "[AutoGame] ⚠️ Ya hay una instancia corriendo."
    notify-send "[AutoGame]" "⚠️ Ya hay una instancia corriendo."
    exit 1
fi

# ───────────────────────────────
# Limpieza segura
# ───────────────────────────────
cleanup() {
    hyprctl setenv AUTO_GAME_ACTIVE 0 >/dev/null 2>&1 || true
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# ───────────────────────────────
# Funciones de utilidad
# ───────────────────────────────
log() { echo -e "\e[1;32m[AutoGame]\e[0m $1"; }
warn() { echo -e "\e[1;33m[⚠️ AutoGame]\e[0m $1" >&2; }
DEBUG_LOG() { [[ "$DEBUG" == "1" ]] && echo -e "\e[1;34m[DEBUG]\e[0m $1" || true; }

# ───────────────────────────────
# Validar dependencias
# ───────────────────────────────
check_dependencies() {
    local REQUIRED=("notify-send" "hyprctl" "pgrep")
    local MISSING=()
    for cmd in "${REQUIRED[@]}"; do
        command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        warn "Dependencias faltantes: ${MISSING[*]}"
        return 1
    fi
    log "✓ Dependencias validadas"
}

# ───────────────────────────────
# Detección robusta de juegos
# ───────────────────────────────
is_game_running() {
    DEBUG_LOG "Verificando procesos activos..."

    local GAME_PROCESSES
    GAME_PROCESSES=$(pgrep -a -f "SteamAppId=|steam_app_|\.exe$|wine|proton" 2>/dev/null | \
        grep -Ev "steamwebhelper|steam.sh|steam$|steam-service|steamapps|cider|easyeffects|protontricks")

    if [[ -n "$GAME_PROCESSES" ]]; then
        DEBUG_LOG "✓ Detectado: proceso de juego real"
        return 0
    fi

    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        if hyprctl clients -j 2>/dev/null | grep -q "\"title\":.*steam_app_"; then
            DEBUG_LOG "✓ Detectado: ventana de juego (Hyprland)"
            return 0
        fi
    fi

    DEBUG_LOG "✗ Sin juegos activos"
    return 1
}

# ───────────────────────────────
# Activar modo juego
# ───────────────────────────────
activate_mode() {
    log "🎮 Activando Modo Juego..."
    notify-send "Modo Juego 🕹️" "Optimizando tu sistema para jugar 🚀"

    # Iniciar gamemoded si existe
    command -v gamemoded &>/dev/null && systemctl --user start gamemoded.service 2>/dev/null || true
    DEBUG_LOG "✓ gamemoded iniciado"

    # Variables de entorno GPU
    export __GL_THREADED_OPTIMIZATIONS=1
    export __GL_SHADER_DISK_CACHE=1
    export DXVK_ASYNC=1
    export MANGOHUD=1
    export SDL_VIDEODRIVER=wayland
    export vblank_mode=0
    DEBUG_LOG "✓ Variables de entorno GPU configuradas"

    # Optimización Hyprland
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        mkdir -p "$(dirname "$ML4W_FLAG")"
        if [[ ! -f "$ML4W_FLAG" ]]; then
            hyprctl --batch "
                keyword animations:enabled 0;
                keyword decoration:shadow:enabled 0;
                keyword decoration:blur:enabled 0;
                keyword general:gaps_in 0;
                keyword general:gaps_out 0;
                keyword general:border_size 1;
                keyword decoration:rounding 0" >/dev/null 2>&1 || true
            touch "$ML4W_FLAG"
            DEBUG_LOG "✓ Hyprland optimizado"
            notify-send "🎮 Gamemode Hyprland ON" "Animaciones y blur deshabilitados"
        fi
    fi

    # Cerrar mpvpaper
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        pkill -x mpvpaper
        DEBUG_LOG "🛑 mpvpaper detenido para optimizar GPU"
    fi

    hyprctl setenv AUTO_GAME_ACTIVE 1 >/dev/null 2>&1 || true
}

# ───────────────────────────────
# Restaurar modo normal
# ───────────────────────────────
restore_mode() {
    log "💤 Restaurando modo normal..."
    notify-send "Modo Juego 💤" "Volviendo a la normalidad 🏡"

    unset __GL_THREADED_OPTIMIZATIONS __GL_SHADER_DISK_CACHE DXVK_ASYNC MANGOHUD SDL_VIDEODRIVER vblank_mode 2>/dev/null || true

    command -v gamemoded &>/dev/null && systemctl --user stop gamemoded.service 2>/dev/null || true

    if [[ -f "$ML4W_FLAG" ]]; then
        hyprctl reload >/dev/null 2>&1 || true
        rm -f "$ML4W_FLAG" 2>/dev/null || true
        DEBUG_LOG "✓ Hyprland recargado"
        notify-send "🎮 Gamemode Hyprland OFF" "Configuración restaurada"
    fi

    hyprctl setenv AUTO_GAME_ACTIVE 0 >/dev/null 2>&1 || true
}

# ───────────────────────────────
# Loop principal con flag interno
# ───────────────────────────────
main() {
    check_dependencies || exit 1
    hyprctl setenv AUTO_GAME_ACTIVE 0 >/dev/null 2>&1 || true

    notify-send "Modo Juego 🚀" "Monitoreo iniciado. Detectando juegos..."
    log "✓ Monitoreo iniciado (intervalo: ${CHECK_INTERVAL}s)"
    local CURRENT_GAME_ACTIVE=0

    while true; do
        if is_game_running; then
            if [[ "$CURRENT_GAME_ACTIVE" == "0" ]]; then
                activate_mode
                CURRENT_GAME_ACTIVE=1
                notify-send "🎮 Gamemode ON" "Optimización activa"
            fi
        else
            if [[ "$CURRENT_GAME_ACTIVE" == "1" ]]; then
                restore_mode
                CURRENT_GAME_ACTIVE=0
                notify-send "🎮 Gamemode OFF" "Optimización desactivada"
            fi
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# ───────────────────────────────
# Ejecutar
# ───────────────────────────────
main "$@"
