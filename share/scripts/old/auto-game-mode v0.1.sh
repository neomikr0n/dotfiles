#!/usr/bin/env bash
# 🕹️ Modo Juego Automático Profesional (sin logging)
# Detecta juegos y aplica optimizaciones automáticamente
# Compatible con Arch Linux, Hyprland, Steam, Lutris

# ---------------- CONFIG ----------------
GAMES=("steam" "lutris" "wine" "proton" "game-name")
CHECK_INTERVAL=5  # segundos entre chequeos
PW_CONF="$HOME/.config/pipewire/pipewire.conf.d/99-game-mode.conf"

# ---------------- FUNCIONES ----------------
log() { echo -e "\e[1;32m[AutoGame]\e[0m $1"; }
notify() { command -v notify-send >/dev/null && notify-send "Modo Juego" "$1" || true; }

activate_mode() {
    log "🔹 Activando Modo Juego..."
    notify "Modo Juego ACTIVADO"

    # CPU performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > "$cpu" 2>/dev/null || true
    done

    # GameMode usuario
    systemctl --user start gamemoded.service 2>/dev/null || true

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

    # Variables entorno optimizadas para Wayland/Proton/MANGOHUD
    export __GL_THREADED_OPTIMIZATIONS=1
    export __GL_SHADER_DISK_CACHE=1
    export DXVK_ASYNC=1
    export MANGOHUD=1
    export SDL_VIDEODRIVER=wayland
    export MOZ_ENABLE_WAYLAND=1
    export vblank_mode=0
}

restore_mode() {
    log "💤 Restaurando modo normal..."
    notify "Modo Juego DESACTIVADO"

    # CPU a default
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo schedutil > "$cpu" 2>/dev/null || true
    done

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
}

# ---------------- LOOP PRINCIPAL ----------------
ACTIVE=0
while true; do
    FOUND=0
    for g in "${GAMES[@]}"; do
        if pgrep -x "$g" > /dev/null; then
            FOUND=1
            break
        fi
    done

    if [[ $FOUND -eq 1 && $ACTIVE -eq 0 ]]; then
        activate_mode
        ACTIVE=1
    elif [[ $FOUND -eq 0 && $ACTIVE -eq 1 ]]; then
        restore_mode
        ACTIVE=0
    fi

    sleep $CHECK_INTERVAL
done
