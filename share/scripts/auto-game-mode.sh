#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURACIÓN ---
SCRIPT_NAME=$(basename "$0")
CHECK_INTERVAL=5
ML4W_FLAG="$HOME/.config/ml4w/settings/gamemode-enabled"

# ⚠️ LA SOLUCIÓN: Usamos 'all' en lugar de '*' para que un solo proceso maneje todo,
# o especificamos un monitor si prefieres. 
WALL_VIDEO="/ruta/a/tu/video.mp4"
WALL_OPTS="no-audio --loop"

# --- LOGGING ---
log() { printf "\e[1;32m[AutoGame]\e[0m %s\n" "$1"; }
warn() { printf "\e[1;33m[⚠️ AutoGame]\e[0m %s\n" "$1" >&2; }

# --- CONTROL DE INSTANCIAS DEL SCRIPT ---
LOCK_FILE="/tmp/${SCRIPT_NAME}.lock"
echo $$ > "$LOCK_FILE"

# --- LIMPIEZA RADICAL ---
kill_all_wallpapers() {
    pkill -9 -x mpvpaper 2>/dev/null || true
    sleep 0.5
}

# --- GESTIÓN ÚNICA DE MPVPAPER ---
manage_wallpaper() {
    local count
    count=$(pgrep -xc "mpvpaper" || echo 0)

    # Si hay 0, abrimos uno. Si hay más de 1, reseteamos a uno solo.
    if [[ "$count" -eq 0 || "$count" -gt 1 ]]; then
        [[ "$count" -gt 1 ]] && warn "Exceso detectado ($count). Limpiando..."
        kill_all_wallpapers
        
        log "🎞️ Iniciando instancia única de mpvpaper..."
        # Usamos 'all' para que un solo proceso cubra todos los monitores
        mpvpaper -o "$WALL_OPTS" all "$WALL_VIDEO" & 
    fi
}

is_game_running() {
    pgrep -E "SteamAppId=|wine$|proton|lutris|\.exe$" >/dev/null 2>&1 && return 0
    if [[ "${XDG_SESSION_DESKTOP:-}" == "Hyprland" ]]; then
        hyprctl clients -j 2>/dev/null | jq -e '.[] | select(.class | test("steam_app_"))' >/dev/null && return 0
    fi
    return 1
}

activate_mode() {
    log "🎮 Modo Juego: ON"
    kill_all_wallpapers
    if [[ "${XDG_SESSION_DESKTOP:-}" == "Hyprland" ]]; then
        hyprctl --batch "keyword animations:enabled 0; keyword decoration:blur:enabled 0" 2>/dev/null || true
        touch "$ML4W_FLAG"
    fi
}

restore_mode() {
    log "💤 Modo Juego: OFF"
    [[ -f "$ML4W_FLAG" ]] && rm -f "$ML4W_FLAG"
    hyprctl reload 2>/dev/null || true
    sleep 1
    manage_wallpaper
}

main() {
    # Limpieza inicial para empezar de cero
    kill_all_wallpapers
    
    local active=0
    while true; do
        if is_game_running; then
            if [[ $active -eq 0 ]]; then
                activate_mode
                active=1
            fi
        else
            if [[ $active -eq 1 ]]; then
                restore_mode
                active=0
            else
                # Vigilancia constante: si algo más abrió mpvpaper, lo corregimos
                manage_wallpaper
            fi
        fi
        sleep "$CHECK_INTERVAL"
    done
}

trap "rm -f $LOCK_FILE; kill_all_wallpapers; exit" SIGINT SIGTERM EXIT
main "$@"