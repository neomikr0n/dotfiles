#!/usr/bin/env bash
# 🕹️ Modo Juego Definitivo - Versión Producción (Garuda/Hyprland)
set -euo pipefail

SCRIPT_NAME=$(basename "$0")
SCRIPT_PID=$$

# CONFIG
CHECK_INTERVAL=5
PW_CONF="$HOME/.config/pipewire/pipewire.conf.d/99-game-mode.conf"
ML4W_FLAG="$HOME/.config/ml4w/settings/gamemode-enabled"
DEBUG="${DEBUG:-0}"

# TRAP LIMPIEZA
cleanup() {
    DEBUG_LOG "🧹 Limpiando (PID: $$)..."
    if [[ ${ACTIVE:-0} -eq 1 ]]; then
        restore_mode
    fi
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# FUNCIONES UTILIDAD
log() { echo -e "\e[1;32m[AutoGame]\e[0m $1"; }
warn() { echo -e "\e[1;33m[⚠️ AutoGame]\e[0m $1" >&2; }
error() { echo -e "\e[1;31m[❌ AutoGame]\e[0m $1" >&2; exit 1; }
DEBUG_LOG() { [[ "$DEBUG" == "1" ]] && echo -e "\e[1;34m[DEBUG]\e[0m $1" || true; }

notify_modern() {
    local TITLE="$1" MSG="$2"
    if command -v notify-send &>/dev/null; then
        notify-send -u normal "$TITLE" "$MSG" -i dialog-information 2>/dev/null || true
    fi
}

# VALIDAR DEPENDENCIAS
check_dependencies() {
    local REQUIRED=("notify-send" "hyprctl" "pgrep" "pactl" "gamemoded")
    local MISSING=()
    
    for cmd in "${REQUIRED[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            MISSING+=("$cmd")
        fi
    done
    
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        error "Dependencias faltantes: ${MISSING[*]}\nInstala con: yay -S gamemode"
    fi
    
    # Validar gamemoded como servicio
    if ! systemctl --user list-unit-files 2>/dev/null | grep -q "gamemoded"; then
        warn "⚠️ gamemoded no está como servicio --user, intentando instalación..."
        systemctl --user enable --now gamemoded.service 2>/dev/null || warn "No se pudo habilitar gamemoded"
    fi
    
    log "✓ Todas las dependencias validadas"
}

# DETECCIÓN DE JUEGOS MEJORADA
is_game_running() {
    DEBUG_LOG "Verificando procesos activos..."
    
    # Método 1: Búsqueda de procesos por nombre/cmdline
    if pgrep -E "SteamAppId=|wine$|proton|lutris|\.exe$" >/dev/null 2>&1; then
        DEBUG_LOG "✓ Detectado: Proceso de juego (pgrep)"
        return 0
    fi
    
    # Método 2: Detectar steam_app_XXXXX por Hyprland (para juegos nativos Steam)
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        if hyprctl clients -j 2>/dev/null | grep -q "steam_app_"; then
            DEBUG_LOG "✓ Detectado: Steam App (Hyprland)"
            return 0
        fi
    fi
    
    DEBUG_LOG "✗ Sin juegos activos"
    return 1
}

# OBTENER PID DEL JUEGO
get_game_pid() {
    local pid=0
    
    # Método 1: Por procesos
    if pid=$(pgrep -E "SteamAppId=|wine$|proton|lutris|\.exe$" 2>/dev/null | head -n1); then
        echo "$pid"
        return 0
    fi
    
    # Método 2: Por Hyprland steam_app_XXXXX (obtener PID del cliente)
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        if pid=$(hyprctl clients -j 2>/dev/null | grep -o '"pid":[0-9]*' | grep -o '[0-9]*' | head -n1); then
            if hyprctl clients -j 2>/dev/null | grep -B2 '"pid":'$pid | grep -q "steam_app_"; then
                echo "$pid"
                return 0
            fi
        fi
    fi
    
    echo "0"
}

# VALIDAR CONFIGURACIÓN PIPEWIRE
validate_pipewire_config() {
    if [[ ! -f "$PW_CONF" ]]; then
        return 1
    fi
    
    # Sintaxis básica
    if ! grep -q "context.properties" "$PW_CONF"; then
        return 1
    fi
    
    return 0
}

# ACTIVAR MODO JUEGO
activate_mode() {
    log "🎮 Activando Modo Juego..."
    notify_modern "Modo Juego 🕹️" "¡Preparando tu sistema para jugar! 🚀"
    
    # 1. Iniciar gamemoded
    if ! systemctl --user start gamemoded.service 2>/dev/null; then
        warn "⚠️ No se pudo iniciar gamemoded"
    fi
    
    # 2. Configurar PipeWire latencia baja
    mkdir -p "$(dirname "$PW_CONF")"
    cat > "$PW_CONF" <<'EOF'
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 64
    default.clock.min-quantum   = 64
    default.clock.max-quantum   = 64
    default.position            = "TLLB"
}
EOF
    
    if ! validate_pipewire_config; then
        warn "⚠️ Config PipeWire inválida, usando default"
        rm -f "$PW_CONF"
    else
        DEBUG_LOG "✓ PipeWire config escrita"
        systemctl --user restart pipewire pipewire-pulse 2>/dev/null || true
        sleep 1
    fi
    
    # 3. Variables entorno juego
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
                keyword decoration:rounding 0" 2>/dev/null || warn "hyprctl falló"
            
            touch "$ML4W_FLAG"
            DEBUG_LOG "✓ Hyprland optimizado"
            notify_modern "🎮 Gamemode Hyprland ON" "Animaciones y blur deshabilitados"
        fi
    fi
    
    # 5. Matar fondos
    pkill -f mpvpaper 2>/dev/null || true
    
    ACTIVE=1
}

# RESTAURAR MODO NORMAL
restore_mode() {
    log "💤 Restaurando modo normal..."
    notify_modern "Modo Juego 💤" "Volviendo a la normalidad 🏡"
    
    # 1. Limpiar config PipeWire
    rm -f "$PW_CONF"
    systemctl --user restart pipewire pipewire-pulse 2>/dev/null || true
    sleep 1
    DEBUG_LOG "✓ PipeWire restaurado"
    
    # 2. Limpiar variables entorno
    unset __GL_THREADED_OPTIMIZATIONS 2>/dev/null || true
    unset __GL_SHADER_DISK_CACHE 2>/dev/null || true
    unset DXVK_ASYNC 2>/dev/null || true
    unset MANGOHUD 2>/dev/null || true
    unset SDL_VIDEODRIVER 2>/dev/null || true
    unset vblank_mode 2>/dev/null || true
    
    # 3. Restaurar Hyprland (setting por setting, no reload)
    if [[ -f "$ML4W_FLAG" ]]; then
        hyprctl --batch "
            keyword animations:enabled 1;
            keyword decoration:shadow:enabled 1;
            keyword decoration:blur:enabled 1;
            keyword general:gaps_in 5;
            keyword general:gaps_out 8;
            keyword general:border_size 2;
            keyword decoration:rounding 10" 2>/dev/null || warn "hyprctl restore falló"
        
        rm -f "$ML4W_FLAG"
        DEBUG_LOG "✓ Hyprland restaurado"
        notify_modern "🎮 Gamemode Hyprland OFF" "Animaciones y blur habilitados"
    fi
    
    # 4. Detener gamemoded
    systemctl --user stop gamemoded.service 2>/dev/null || true
    
    ACTIVE=0
}

# LOOP PRINCIPAL
main() {
    check_dependencies
    notify_modern "Modo Juego 🚀" "Servicio iniciado. Detectando juegos..."
    log "✓ Monitoreo iniciado (intervalo: ${CHECK_INTERVAL}s, latencia máx: ${CHECK_INTERVAL}s)"
    
    ACTIVE=0
    LAST_PID=0
    
    while true; do
        if is_game_running; then
            if [[ $ACTIVE -eq 0 ]]; then
                GAME_PID=$(get_game_pid)
                DEBUG_LOG "Juego detectado: PID=$GAME_PID"
                
                activate_mode
                
                if [[ $GAME_PID -ne 0 ]]; then
                    gamemoded -r "$GAME_PID" 2>/dev/null || true
                    notify_modern "🎮 Gamemode ON" "Optimización activa para PID $GAME_PID"
                fi
            fi
        else
            if [[ $ACTIVE -eq 1 ]]; then
                restore_mode
                DEBUG_LOG "Juego finalizado"
                notify_modern "🎮 Gamemode OFF" "Optimización desactivada"
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# EJECUTAR
main "$@"