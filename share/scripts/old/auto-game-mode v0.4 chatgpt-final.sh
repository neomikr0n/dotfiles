#!/usr/bin/env bash
# 🕹️ Modo Juego Definitivo Profesional (sin root)
# Compatible: Arch Linux/Garuda, Hyprland, Steam, Lutris, Wine/Proton

SCRIPT_NAME=$(basename "$0")

# ---------------- EVITAR MULTIPLES INSTANCIAS ----------------
if pgrep -f "$SCRIPT_NAME" | grep -v $$ >/dev/null; then
    notify-send "Modo Juego ⚠️" "Ya hay una instancia corriendo, abortando duplicado."
    exit 0
fi

# ---------------- CONFIG ----------------
GAMES=("lutris" "wine" "proton" "game.exe" "game-other.exe")
CHECK_INTERVAL=5
PW_CONF="$HOME/.config/pipewire/pipewire.conf.d/99-game-mode.conf"
ML4W_FLAG="$HOME/.config/ml4w/settings/gamemode-enabled"

REQUIRED_SERVICES=("gamemoded.service" "notify-send" "hyprctl" "pipewire" "pipewire-pulse" "wireplumber")

# ---------------- FUNCIONES ----------------
log() { echo -e "\e[1;32m[AutoGame]\e[0m $1"; }

notify_modern() {
    local TITLE="$1"
    local MSG="$2"
    command -v notify-send >/dev/null && notify-send -u normal "$TITLE" "$MSG" -i dialog-information || true
}

check_packages() {
    MISSING=()
    for pkg in "${REQUIRED_SERVICES[@]}"; do
        if ! systemctl --user list-unit-files | grep -q "$pkg" && ! command -v "$pkg" >/dev/null 2>&1; then
            MISSING+=("$pkg")
        fi
    done
    if [ "${#MISSING[@]}" -gt 0 ]; then
        log "❌ Paquetes/servicios faltantes: ${MISSING[*]}"
        notify_modern "Modo Juego ❌" "Te faltan paquetes/servicios: ${MISSING[*]}"
        exit 1
    fi
}

# ---------------- DETECCION DE JUEGOS ----------------
is_game_running() {
    # Detectar juegos reales en Steam
    for pid in $(pgrep -x steam 2>/dev/null); do
        for child in $(pgrep -P $pid 2>/dev/null); do
            if grep -q "SteamAppId" /proc/$child/environ 2>/dev/null; then
                return 0
            fi
        done
    done

    # Detecta procesos definidos en GAMES
    for g in "${GAMES[@]}"; do
        if pgrep -x "$g" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

# ---------------- ACTIVAR MODO JUEGO ----------------
activate_mode() {
    log "🔹 Activando Modo Juego..."
    notify_modern "Modo Juego 🕹️" "¡Preparando tu sistema para jugar! 🚀"

    # Gamemoded maneja CPU / prioridad / I/O
    systemctl --user start gamemoded.service 2>/dev/null || log "⚠️ No se pudo iniciar gamemoded"

    # PipeWire baja latencia
    mkdir -p "$(dirname "$PW_CONF")"
    cat > "$PW_CONF" <<EOF
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 64
    default.clock.min-quantum   = 64
    default.clock.max-quantum   = 64
}
EOF
    systemctl --user restart pipewire pipewire-pulse wireplumber || true

    # Variables entorno optimizadas
    export __GL_THREADED_OPTIMIZATIONS=1
    export __GL_SHADER_DISK_CACHE=1
    export DXVK_ASYNC=1
    export MANGOHUD=1
    export SDL_VIDEODRIVER=wayland
    export MOZ_ENABLE_WAYLAND=1
    export vblank_mode=0

    # Hyprland gamemode visual
    if [ ! -f "$ML4W_FLAG" ]; then
        hyprctl --batch "\
            keyword animations:enabled 0;\
            keyword decoration:shadow:enabled 0;\
            keyword decoration:blur:enabled 0;\
            keyword general:gaps_in 0;\
            keyword general:gaps_out 0;\
            keyword general:border_size 1;\
            keyword decoration:rounding 0"
        mkdir -p "$(dirname "$ML4W_FLAG")"
        touch "$ML4W_FLAG"
        notify_modern "🎮 Gamemode Hyprland ON" "Animaciones y blur deshabilitados"
    fi

    # Cerrar mpvpaper si está activo
    pkill -f mpvpaper 2>/dev/null || true
}

# ---------------- RESTAURAR MODO NORMAL ----------------
restore_mode() {
    log "💤 Restaurando modo normal..."
    notify_modern "Modo Juego 💤" "Volviendo a la normalidad 🏡"

    # PipeWire default
    rm -f "$PW_CONF"
    systemctl --user restart pipewire pipewire-pulse wireplumber || true

    # Reset variables de entorno
    unset __GL_THREADED_OPTIMIZATIONS
    unset __GL_SHADER_DISK_CACHE
    unset DXVK_ASYNC
    unset MANGOHUD
    unset SDL_VIDEODRIVER
    unset MOZ_ENABLE_WAYLAND
    unset vblank_mode

    # Hyprland gamemode revert
    if [ -f "$ML4W_FLAG" ]; then
        hyprctl reload
        rm "$ML4W_FLAG"
        notify_modern "🎮 Gamemode Hyprland OFF" "Animaciones y blur habilitados"
    fi
}

# ---------------- LOOP PRINCIPAL ----------------
check_packages
notify_modern "Modo Juego 🚀" "Servicio iniciado correctamente. Detectando juegos..."

ACTIVE=0
GAME_PID=0

while true; do
    if is_game_running; then
        if [[ $ACTIVE -eq 0 ]]; then
            # Buscar PID del juego real
            GAME_PID=0
            # Steam real
            for pid in $(pgrep -x steam 2>/dev/null); do
                for child in $(pgrep -P $pid 2>/dev/null); do
                    if grep -q "SteamAppId" /proc/$child/environ 2>/dev/null; then
                        GAME_PID=$child
                        break 2
                    fi
                done
            done
            # Procesos GAMES si no encontramos Steam
            if [[ $GAME_PID -eq 0 ]]; then
                for g in "${GAMES[@]}"; do
                    if pid=$(pgrep -x "$g" 2>/dev/null | head -n1); then
                        GAME_PID=$pid
                        break
                    fi
                done
            fi

            # Activar Modo Juego
            activate_mode
            ACTIVE=1

            # Activar GameMode para el PID encontrado
            if [[ $GAME_PID -ne 0 ]]; then
                gamemoded -r "$GAME_PID" 2>/dev/null
                notify_modern "🎮 Gamemode ON" "Optimización activa para PID $GAME_PID"
            fi
        fi
    else
        if [[ $ACTIVE -eq 1 ]]; then
            # Desactivar Modo Juego
            restore_mode
            ACTIVE=0
            # Reiniciar PID
            if [[ $GAME_PID -ne 0 ]]; then
                gamemoded -r "$GAME_PID" 2>/dev/null
                notify_modern "🎮 Gamemode OFF" "Optimización desactivada"
                GAME_PID=0
            fi
        fi
    fi
    sleep $CHECK_INTERVAL
done
