#!/usr/bin/env sh
# eco-aviso.sh — Avisa a n30 por notificacion de que Eco va a hacer algo
# perceptible en su escritorio: abrir ventanas, capturar pantalla, moverse de
# escritorio, cambiar volumen o brillo, lanzar o matar procesos visibles, etc.
#
# Regla asociada (2026-09-30): TODA accion perceptible se anuncia ANTES de
# ejecutarla. El aviso lleva el emoji de ballena como marca. Ver
# ~/.workbuddy-ai/MEMORY.md, seccion de avisos.
#
# Uso:
#   eco-aviso.sh "<que vas a hacer>" "<para que>" "<cuanto dura>" [urgencia] [titulo]
#
# Ejemplos:
#   eco-aviso.sh "abrir una ventana de kitty y capturar la pantalla" \
#                "medir el alpha real del fondo" "~5 s"
#
#   eco-aviso.sh "bajar el volumen al 40%" "probar el OSD del DAC" "~2 s" low
#
# Urgencia: low | normal | critical   (por defecto: normal)

set -u

QUE="${1:-}"
PARA="${2:-}"
DURA="${3:-}"
URG="${4:-normal}"
TITULO_EXTRA="${5:-}"

if [ -z "$QUE" ]; then
    echo "uso: eco-aviso.sh \"<que>\" \"<para que>\" \"<cuanto dura>\" [urgencia] [titulo]" >&2
    exit 2
fi

# El bus de sesion puede faltar en un shell no interactivo.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "/run/user/$(id -u)/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi

if ! command -v notify-send >/dev/null 2>&1; then
    echo "eco-aviso: notify-send no esta instalado" >&2
    exit 1
fi

# Marca fija: la ballena identifica un aviso de Eco de un vistazo.
BALLENA="🐋"

if [ -n "$TITULO_EXTRA" ]; then
    TITULO="$BALLENA Eco: $TITULO_EXTRA"
else
    TITULO="$BALLENA Eco va a usar tu escritorio"
fi

CUERPO="Voy a: $QUE"
[ -n "$PARA" ] && CUERPO="$CUERPO
Motivo: $PARA"
[ -n "$DURA" ] && CUERPO="$CUERPO
Duración: $DURA"

notify-send -a Eco -u "$URG" -t 8000 "$TITULO" "$CUERPO" || {
    echo "eco-aviso: notify-send fallo" >&2
    exit 1
}

# Trazabilidad: que se anuncio, cuando y con que texto.
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/eco-avisos.log"
printf '%s | %s | %s | %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$QUE" "$PARA" "$DURA" >>"$LOG" 2>/dev/null || true
