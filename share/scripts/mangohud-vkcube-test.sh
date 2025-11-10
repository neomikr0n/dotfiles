#!/bin/bash
# Script: mangohud-vkcube-test.sh
# Ejecuta vkcube con dos capas de MangoHud (estadísticas + canción)

HUD_MAIN="$HOME/.config/MangoHud/MangoHud.conf"
HUD_MUSIC="$HOME/.config/MangoHud/music.conf"

# Primera capa
MANGOHUD=1 MANGOHUD_CONFIGFILE="$HUD_MAIN" vkcube &
PID=$!

sleep 0.5

# Segunda capa (usando DLSYM para inyectar encima)
MANGOHUD=1 MANGOHUD_DLSYM=1 MANGOHUD_CONFIGFILE="$HUD_MUSIC" vkcube &

wait $PID
