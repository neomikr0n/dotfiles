#!/usr/bin/env bash
# Alterna el VRR de DP-2. La config lo deja en 0 porque el OLED parpadea con el activo.
# Se sube solo mientras dura la partida y se vuelve a bajar.
set -euo pipefail

estado=$(hyprctl getoption misc:vrr | awk '/^int:/{print $2}')

if [ "${estado:-0}" = "0" ]; then
    hyprctl eval 'hl.config({ misc = { vrr = 2 } })' >/dev/null
    notify-send -a "VRR" "VRR activo" "Solo en pantalla completa. El OLED puede parpadear."
else
    hyprctl eval 'hl.config({ misc = { vrr = 0 } })' >/dev/null
    notify-send -a "VRR" "VRR desactivado" "Sin parpadeo del panel. Es el estado de la config."
fi
