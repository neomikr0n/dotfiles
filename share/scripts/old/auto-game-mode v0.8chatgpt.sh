#!/usr/bin/env bash
# 🕹️ Modo Juego para Hyprland - Versión con notify-send y pausa de mpvpaper
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
CHECK_INTERVAL=5
PW_CONF="$HOME/.config/pipewire/pipewire.conf.d/99-game-mode.conf"
ML4W_FLAG="$HOME/.config/ml4w/settings/gamemode-enabled"
DEBUG="${DEBUG:-0}"

# 🧹 LIMPIEZA SEGURA
cleanup() {
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# 🧰 FUNCIONES DE UTILIDAD
log() { echo -e "\e[1;32m[AutoGame]\e[0m $1"; }
warn() { echo -e "\e[1;33m[⚠️ AutoGame]\e[0m $1" >&2; }
DEBUG_LOG() { [[ "$DEBUG" == "1" ]] && echo -e "\e[1;34m[DEBUG]\e[0m $1" || true; }

notify_modern() {
    local TITLE="$1" MSG="$2"
    if command -v notify-send &>/dev/null; then
        notify-send -u normal "$TITLE" "$MSG" -i dialog-information &
    fi
}

# 🧩 VALIDAR DEPENDENCIAS
check_dependencies() {
    local REQUIRED=("notify-send" "hyprctl" "pgrep")
    local MISSING=()
    for cmd in "${REQUIRED[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            MISSING+=("$cmd")
        fi
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        warn "Dependencias faltantes: ${MISSING[*]}"
        return 1
    fi
    log "✓ Dependencias validadas"
    return 0
}

# 🎮 DETECCIÓN DE JUEGOS
is_game_running() {
    DEBUG_LOG "Verificando procesos activos..."
    if pgrep -E "SteamAppId=|steam_app_|wine$|proton|lutris|\.exe$" >/dev/null 2>&1; then
        DEBUG_LOG "✓ Detectado: Proceso de juego (pgrep)"
        return 0
    fi
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        if hyprctl clients -j 2>/dev/null | grep -q "steam_app_"; then
            DEBUG_LOG "✓ Detectado: Steam App (Hyprland)"
            return 0
        fi
    fi
    DEBUG_LOG "✗ Sin juegos activos"
    return 1
}

# 🔍 OBTENER PID DEL JUEGO
get_game_pid() {
    local pid=0
    if pid=$(pgrep -E "SteamAppId=|steam_app_|wine$|proton|lutris|\.exe$" 2>/dev/null | head -n1); then
        echo "$pid"
        return 0
    fi
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        pid=$(hyprctl clients -j 2>/dev/null | grep -o '"pid":[0-9]*' | grep -o '[0-9]*' | head -n1)
        if [[ -n "$pid" ]]; then
            echo "$pid"
            return 0
        fi
    fi
    echo "0"
}

# 🚀 ACTIVAR MODO JUEGO
activate_mode() {
    log "🎮 Activando Modo Juego..."
    notify_modern "Modo Juego 🕹️" "¡Preparando tu sistema para jugar! 🚀"

    # 1. Iniciar gamemoded (si existe)
    if command -v gamemoded &>/dev/null; then
        systemctl --user start gamemoded.service 2>/dev/null || true
        DEBUG_LOG "✓ gamemoded iniciado"
    fi

    # 2. Configurar PipeWire para baja latencia
    mkdir -p "$(dirname "$PW_CONF")"
    cat > "$PW_CONF" <<'EOF'
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 64
    default.clock.min-quantum   = 64
    default.clock.max-quantum   = 64
}
EOF
    systemctl --user restart pipewire pipewire-pulse 2>/dev/null || true
    sleep 1
    DEBUG_LOG "✓ PipeWire configurado"

    # 3. Variables de entorno optimizadas
    export __GL_THREADED_OPTIMIZATIONS=1
    export __GL_SHADER_DISK_CACHE=1
    export DXVK_ASYNC=1
    export MANGOHUD=1
    export SDL_VIDEODRIVER=wayland
    export vblank_mode=0
    DEBUG_LOG "✓ Variables de entorno configuradas"

    # 4. Optimizaciones Hyprland
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
                keyword decoration:rounding 0" 2>/dev/null || true
            touch "$ML4W_FLAG"
            DEBUG_LOG "✓ Hyprland optimizado"
            notify_modern "🎮 Gamemode Hyprland ON" "Animaciones y blur deshabilitados"
        fi
    fi

    # 5. Detener mpvpaper si está corriendo
    if pgrep -x mpvpaper >/dev/null 2>&1; then
        pkill -TERM mpvpaper 2>/dev/null || true
        DEBUG_LOG "🛑 mpvpaper detenido para optimizar GPU"
        notify_modern "🎮 Modo Juego" "mpvpaper detenido temporalmente"
    fi
}

# 💤 RESTAURAR MODO NORMAL
restore_mode() {
    log "💤 Restaurando modo normal..."
    notify_modern "Modo Juego 💤" "Volviendo a la normalidad 🏡"

    # 1. Limpiar configuración PipeWire
    rm -f "$PW_CONF"
    systemctl --user restart pipewire pipewire-pulse 2>/dev/null || true
    sleep 1
    DEBUG_LOG "✓ PipeWire restaurado"

    # 2. Limpiar variables de entorno
    unset __GL_THREADED_OPTIMIZATIONS 2>/dev/null || true
    unset __GL_SHADER_DISK_CACHE 2>/dev/null || true
    unset DXVK_ASYNC 2>/dev/null || true
    unset MANGOHUD 2>/dev/null || true
    unset SDL_VIDEODRIVER 2>/dev/null || true
    unset vblank_mode 2>/dev/null || true

    # 3. Detener gamemoded
    if command -v gamemoded &>/dev/null; then
        systemctl --user stop gamemoded.service 2>/dev/null || true
    fi

    # 4. Recargar Hyprland (esto reanuda mpvpaper y todo lo visual)
    if [[ -f "$ML4W_FLAG" ]]; then
        hyprctl reload 2>/dev/null || true
        rm -f "$ML4W_FLAG"
        DEBUG_LOG "✓ Hyprland recargado"
        notify_modern "🎮 Gamemode Hyprland OFF" "Configuración restaurada"
    fi
}

# 🔁 LOOP PRINCIPAL
main() {
    check_dependencies || exit 1
    notify_modern "Modo Juego 🚀" "Monitoreo iniciado. Detectando juegos..."
    log "✓ Monitoreo iniciado (intervalo: ${CHECK_INTERVAL}s)"

    ACTIVE=0
    while true; do
        if is_game_running; then
            if [[ $ACTIVE -eq 0 ]]; then
                GAME_PID=$(get_game_pid)
                DEBUG_LOG "Juego detectado: PID=$GAME_PID"
                activate_mode
                ACTIVE=1
                notify_modern "🎮 Gamemode ON" "Optimización activa"
            fi
        else
            if [[ $ACTIVE -eq 1 ]]; then
                restore_mode
                DEBUG_LOG "Juego finalizado"
                notify_modern "🎮 Gamemode OFF" "Optimización desactivada"
                ACTIVE=0
            fi
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# 🚦 EJECUTAR
main "$@"
