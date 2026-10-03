#!/bin/bash
# media-keys-control.sh — manda un comando de playerctl al reproductor ADECUADO.
#
# Por qué existe en vez de llamar a `playerctl` a pelo desde el bind:
#   sin -p, playerctl usa «the first available player» (lo dice su propio --help), y ese
#   orden lo decide la enumeración de D-Bus, no el uso. Con varios reproductores vivos a
#   la vez —Cider y Zen cuando suena algo en el navegador— el resultado típico es: pulsas
#   play/pause, Cider sigue sonando y Zen arranca un vídeo.
#
# Regla:
#   1. si alguno está sonando (status = Playing), el comando va a ÉSE;
#   2. si ninguno suena, va al primero disponible, para que play/pause reanude el último;
#   3. si no hay ninguno, sale en silencio con rc=0: no hay nada que controlar, y eso no
#      es un error que deba sacar una notificación.
#
# Uso:  media-keys-control.sh play-pause | next | previous | stop
#       Vale cualquier comando de playerctl: los de sólo lectura (status, metadata) sirven
#       para probar la selección de reproductor SIN provocar ningún efecto.
#
# Medido el 2026-10-02: `playerctl -l` -> cider; `playerctl -p cider status` -> Stopped
# (un reproductor parado sigue apareciendo en la lista, así que el sondeo por status es
# fiable y es justo lo que hace falta aquí).

set -u

if [ "$#" -eq 0 ]; then
    set -- play-pause
fi

# 1) El que esté sonando.
elegido=""
lista=$(playerctl -l 2>/dev/null)
while IFS= read -r p; do
    [ -n "$p" ] || continue
    if [ "$(playerctl -p "$p" status 2>/dev/null)" = "Playing" ]; then
        elegido="$p"
        break
    fi
done <<EOF
$lista
EOF

# 2) Si ninguno suena, el primero disponible.
#    Se toma la primera línea con expansión de parámetros y no con `head`: así el script
#    no depende de ningún binario externo más que de playerctl, y no arranca un proceso
#    de más en cada pulsación de tecla.
if [ -z "$elegido" ]; then
    elegido="${lista%%$'\n'*}"
fi

# 3) Sin reproductores, no hay nada que hacer.
[ -n "$elegido" ] || exit 0

exec playerctl -p "$elegido" "$@"
