#!/usr/bin/env bash
# 🕹️ Modo Juego para Hyprland - Optimizado
# Context: context/linux_rules.md

set -euo pipefail

# Configuración
SCRIPT_NAME=$(basename "$0")
CHECK_INTERVAL=5
ML4W_FLAG="$HOME/.config/ml4w/settings/gamemode-enabled"
DEBUG="${DEBUG:-0}"

# Logging
log() { printf "\e[1;32m[AutoGame]\e[0m %s\n" "$1"; }
warn() { printf "\e[1;33m[⚠️ AutoGame]\e[0m %s\n" "$1" >&2; }
debug() { [[ "$DEBUG" == "1" ]] && printf "\e[1;34m[DEBUG]\e[0m %s\n" "$1" || true; }

# Notificaciones
notify_modern() {
    local TITLE="$1" MSG="$2"
    if command -v notify-send &>/dev/null; then
        timeout 2 notify-send -t 7000 -u normal "$TITLE" "$MSG" -i input-gaming 2>/dev/null &
    fi
}

# Control de Instancias
if [[ $(pgrep -fc "$SCRIPT_NAME") -gt 1 ]]; then
    notify_modern "🎮 Ya Estoy Aquí" "Ya estoy cazando juegos 🎯"
    warn "Ya hay una instancia de $SCRIPT_NAME corriendo"
    exit 0
fi

# Trap para limpieza
cleanup() {
    exit 0
}
trap cleanup SIGTERM SIGINT EXIT

# Validar dependencias
check_dependencies() {
    local REQUIRED=("notify-send" "hyprctl" "pgrep" "jq")
    local MISSING=()
    
    for cmd in "${REQUIRED[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            MISSING+=("$cmd")
        fi
    done
    
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        warn "Dependencias faltantes: ${MISSING[*]}"
        warn "Instala 'jq' para una detección precisa: yay -S jq"
        return 1
    fi
    
    log "✓ Dependencias validadas"
    return 0
}

# Detección de Juegos
is_game_running() {
    debug "Verificando procesos activos..."
    
    # 1. Búsqueda por procesos (Steam, Wine, Proton, Lutris)
    if pgrep -E "SteamAppId=|wine$|proton|lutris|\.exe$" >/dev/null 2>&1; then
        debug "✓ Detectado: Proceso de juego (pgrep)"
        return 0
    fi
    
    # 2. Detección precisa en Hyprland usando jq
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        if hyprctl clients -j 2>/dev/null | jq -e '.[] | select(.class | test("steam_app_"))' >/dev/null; then
            debug "✓ Detectado: Steam App (Hyprland JSON)"
            return 0
        fi
    fi
    
    debug "✗ Sin juegos activos"
    return 1
}

# Obtener PID (para info)
get_game_pid() {
    local pid
    
    # Intento 1: pgrep
    pid=$(pgrep -E "SteamAppId=|wine$|proton|lutris|\.exe$" 2>/dev/null | head -n1)
    if [[ -n "$pid" ]]; then
        echo "$pid"
        return 0
    fi
    
    # Intento 2: Hyprland JSON
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        pid=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class | test("steam_app_")) | .pid' | head -n1)
        if [[ -n "$pid" ]]; then
            echo "$pid"
            return 0
        fi
    fi
    
    echo "0"
}

# Activar Modo Juego
activate_mode() {
    log "🎮 Activando Modo Juego..."
    
    # 1. Iniciar gamemoded
    if command -v gamemoded &>/dev/null; then
        systemctl --user start gamemoded.service 2>/dev/null || true
        debug "✓ gamemoded iniciado"
    fi
    
    # 2. Optimizaciones Hyprland (Visuales)
    if [[ "$XDG_SESSION_DESKTOP" == "Hyprland" ]]; then
        mkdir -p "$(dirname "$ML4W_FLAG")"
        if [[ ! -f "$ML4W_FLAG" ]]; then
            # Desactivar efectos costosos
            hyprctl --batch "
                keyword animations:enabled 0;
                keyword decoration:shadow:enabled 0;
                keyword decoration:blur:enabled 0;
                keyword general:gaps_in 0;
                keyword general:gaps_out 0;
                keyword general:border_size 1;
                keyword decoration:rounding 0" 2>/dev/null || true
            
            touch "$ML4W_FLAG"
            debug "✓ Hyprland optimizado (Efectos desactivados)"
        fi
    fi
    
    # 3. Matar mpvpaper (ahorra recursos de GPU)
    pkill -f mpvpaper 2>/dev/null || true
    debug "✓ mpvpaper cerrado"
}

# Restaurar Modo Normal
restore_mode() {
    log "💤 Restaurando modo normal..."
    
    # 1. Detener gamemoded
    if command -v gamemoded &>/dev/null; then
        systemctl --user stop gamemoded.service 2>/dev/null || true
        debug "✓ gamemoded detenido"
    fi
    
    # 2. Recargar Hyprland
    if [[ -f "$ML4W_FLAG" ]]; then
        hyprctl reload 2>/dev/null || true
        rm -f "$ML4W_FLAG"
        debug "✓ Hyprland recargado"
    fi
}

# Loop Principal
main() {
    check_dependencies || exit 1
    
    notify_modern "🎮 Game Hunter Activado" "¡Modo cazador de juegos iniciado! 🎯\nReactividad: cada ${CHECK_INTERVAL}s ⚡"
    log "✓ Monitoreo iniciado (intervalo: ${CHECK_INTERVAL}s)"
    
    local active=0
    local game_pid
    
    while true; do
        if is_game_running; then
            if [[ $active -eq 0 ]]; then
                game_pid=$(get_game_pid)
                debug "Juego detectado: PID=$game_pid"
                activate_mode
                active=1
                notify_modern "🚀 ¡A Jugar!" "Modo turbo activado 🔥\nPID: $game_pid"
            fi
        else
            if [[ $active -eq 1 ]]; then
                restore_mode
                debug "Juego finalizado"
                notify_modern "😴 GG WP" "Volviendo al modo zen 🧘\nModo gaming desactivado"
                active=0
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

main "$@"