#!/usr/bin/env bash
# 🕹️ Modo Juego para Hyprland - versión final con control por PID y protección anti-instancias
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
CHECK_INTERVAL=5
PW_CONF="$HOME/.config/pipewire/pipewire.conf.d/99-game-mode.conf"
ML4W_FLAG="$HOME/.config/ml4w/settings/gamemode-enabled"
DEBUG="${DEBUG:-0}"

# ────────────────────────────────────────────────
# 🧠 Evitar múltiples instancias
# ────────────────────────────────────────────────
if pgrep -f "$SCRIPT_NAME" | grep -v "^$$\$" >/dev/null; then
    echo "[AutoGame] ⚠️ Ya hay una instancia corriendo."
    command -v notify-send &>/dev/null && notify-send "[AutoGame]" "⚠️ Ya hay una instancia corriendo."
    exit 1
fi

# 🧹 LIMPIEZA SEGURA
cleanup() {
    hyprctl setenv AUTO_GAME_ACTIVE 0 >/dev/null 2>&1 || true
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# 🧰 FUNCIONES DE UTILIDAD
log() { echo -e "\e[1;32m[AutoGame]\e[0m $1"; }
warn() { echo -e "\e[1;33m[⚠️ AutoGame]\e[0m $1" >&2; }
DEBUG_LOG() { [[ "$DEBUG" == "1" ]] && echo -e "\e[1;34m[DEBUG]\e[0m $1" || true; }

notify_modern() {
    local TITLE="$1" MSG="$2"
    command -v notify-send &>/dev/null && notify-send -u normal "$TITLE" "$MSG" -i dialog-information &
}

# 🧩 VALIDAR DEPENDENCIAS
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

# 🔍 DETECCIÓN DE JUEGOS
is_game_running() {
    DEBUG_LOG "Verificando procesos activos..."
    if pgrep -fa "Steam|steam_app_|gameoverlayui|wine|proton|lutris|\.exe$" >/dev/null 2>&1; then
        DEBUG_LOG "✓ Detectado: Proceso de juego (pgrep)"
        return 0
    fi
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]] && hyprctl clients -j 2>/dev/null | grep -qE '"class":"(steam_app_|steam|lutris|heroic|bottles)"'; then
        DEBUG_LOG "✓ Detectado: Steam App (Hyprland)"
        return 0
    fi
    DEBUG_LOG "✗ Sin juegos activos"
    return 1
}

# 🔍 OBTENER PID DEL JUEGO
get_game_pid() {
    local pid
    pid=$(pgrep -fa "Steam|steam_app_|gameoverlayui|wine|proton|lutris|\.exe$" 2>/dev/null | head -n1 || echo 0)
    [[ -n "$pid" ]] && echo "$pid" || echo 0
}

# 🚀 ACTIVAR MODO JUEGO
activate_mode() {
    local GAME_PID="$1"

    log "🎮 Activando Modo Juego para PID=$GAME_PID..."
    notify_modern "Modo Juego 🕹️" "Optimizando tu sistema para jugar 🚀"

    # Iniciar gamemoded
    command -v gamemoded &>/dev/null && systemctl --user start gamemoded.service 2>/dev/null || true
    DEBUG_LOG "✓ gamemoded iniciado"

    # Configurar PipeWire
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
    DEBUG_LOG "✓ PipeWire configurado"

    # Variables de entorno optimizadas
    export __GL_THREADED_OPTIMIZATIONS=1
    export __GL_SHADER_DISK_CACHE=1
    export DXVK_ASYNC=1
    export MANGOHUD=1
    export SDL_VIDEODRIVER=wayland
    export vblank_mode=0
    DEBUG_LOG "✓ Variables de entorno configuradas"

    # Optimizaciones Hyprland
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
            notify_modern "🎮 Gamemode Hyprland ON" "Animaciones y blur deshabilitados"
        fi
    fi

    # Cerrar mpvpaper si está corriendo
    pgrep -x mpvpaper >/dev/null 2>&1 && pkill -x mpvpaper && DEBUG_LOG "🛑 mpvpaper detenido para optimizar GPU"

    # Marcar variable global
    hyprctl setenv AUTO_GAME_ACTIVE 1 >/dev/null 2>&1 || true
}

# 💤 RESTAURAR MODO NORMAL
restore_mode() {
    log "💤 Restaurando modo normal..."
    notify_modern "Modo Juego 💤" "Volviendo a la normalidad 🏡"

    # Limpiar PipeWire
    rm -f "$PW_CONF"
    systemctl --user restart pipewire pipewire-pulse 2>/dev/null || true
    DEBUG_LOG "✓ PipeWire restaurado"

    # Limpiar entorno
    unset __GL_THREADED_OPTIMIZATIONS __GL_SHADER_DISK_CACHE DXVK_ASYNC MANGOHUD SDL_VIDEODRIVER vblank_mode 2>/dev/null || true

    # Detener gamemoded
    command -v gamemoded &>/dev/null && systemctl --user stop gamemoded.service 2>/dev/null || true

    # Restaurar Hyprland
    [[ -f "$ML4W_FLAG" ]] && hyprctl reload >/dev/null 2>&1 || true
    rm -f "$ML4W_FLAG" 2>/dev/null || true
    DEBUG_LOG "✓ Hyprland recargado"

    # Limpiar variable global
    hyprctl setenv AUTO_GAME_ACTIVE 0 >/dev/null 2>&1 || true
}

# 🔁 LOOP PRINCIPAL
main() {
    check_dependencies || exit 1
    hyprctl setenv AUTO_GAME_ACTIVE 0 >/dev/null 2>&1 || true

    notify_modern "Modo Juego 🚀" "Monitoreo iniciado. Detectando juegos..."
    log "✓ Monitoreo iniciado (intervalo: ${CHECK_INTERVAL}s)"
    local CURRENT_GAME_PID=0

    while true; do
        if is_game_running; then
            GAME_PID=$(get_game_pid)
            if [[ "$CURRENT_GAME_PID" != "$GAME_PID" && "$GAME_PID" != "0" ]]; then
                activate_mode "$GAME_PID"
                CURRENT_GAME_PID="$GAME_PID"
                notify_modern "🎮 Gamemode ON" "Optimización activa"
            fi
        else
            if [[ "$CURRENT_GAME_PID" != "0" ]]; then
                restore_mode
                CURRENT_GAME_PID=0
                notify_modern "🎮 Gamemode OFF" "Optimización desactivada"
            fi
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# 🚦 EJECUTAR
main "$@"
