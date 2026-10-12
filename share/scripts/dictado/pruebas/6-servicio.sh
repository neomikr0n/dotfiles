#!/usr/bin/env bash
# Comprueba el servicio residente TAL Y COMO QUEDA DESPLEGADO en la maquina, no la logica.
# La suite 4 prueba la logica del servidor y aisla la config del usuario a proposito. Esta mira
# lo que hay de verdad, si el servicio esta habilitado, si esta activo, si la URL que la config
# declara responde, y si algo lo arranca al iniciar sesion. Es la comprobacion que pide la
# mejora 1 de la autocritica, mas el guardian del arranque medido el 2026-10-11.
#
# No abre ventanas ni reproduce sonido. Si la config NO declara servidor, no hay nada que
# comprobar y la suite pasa, porque usar solo el binario es una configuracion legitima.
#
# Una caida aqui es un rojo de verdad y no ruido de entorno. La config AFIRMA que hay servidor.
# Si el servicio esta caido, dictado.sh cae al binario en silencio y tu pierdes la mejora de
# latencia sin enterarte, que es justo lo que conviene que salte.
set -u
S="$(cd "$(dirname "$0")/.." && pwd)/dictado.sh"
WAV="$HOME/.local/share/dictado/corpus/m1-comando.wav"
UNIDAD="dictado-servidor.service"

ok=0; mal=0
comprobar() { if [ "$2" = "$3" ]; then echo "  OK   $1"; ok=$((ok + 1)); else echo "  MAL  $1"; echo "        esperado [$3]"; echo "        obtenido [$2]"; mal=$((mal + 1)); fi; }
caso() { if printf '%s' "$2" | grep -qE -- "$3"; then echo "  OK   $1"; ok=$((ok + 1)); else echo "  MAL  $1"; echo "        no casa /$3/"; mal=$((mal + 1)); fi; }

CONF="${DICTADO_CONF:-$HOME/.config/dictado.conf}"
URL=""
if [ -r "$CONF" ]; then
    # shellcheck source=/dev/null
    . "$CONF"
    URL="${DICTADO_SERVIDOR:-}"
fi

echo "=== A. la config del usuario declara un servidor ==="
if [ -z "$URL" ]; then
    echo "  OK   no hay servidor en la config. Se usa el binario, no hay nada que comprobar"
    echo
    echo "RESUMEN: 1 correctos, 0 fallidos"
    exit 0
fi
echo "  config  $CONF"
echo "  URL     $URL"
ok=$((ok + 1))

echo
echo "=== B. el servicio esta habilitado ==="
e="$(systemctl --user is-enabled "$UNIDAD" 2>&1)"
comprobar "is-enabled -> enabled" "$e" "enabled"

echo
echo "=== C. el servicio esta activo ==="
a="$(systemctl --user is-active "$UNIDAD" 2>&1)"
comprobar "is-active -> active" "$a" "active"

echo
echo "=== D. la URL configurada responde ==="
# Compara la URL de la config con lo que hay escuchando. Si el puerto del servicio y el de la
# config se separan, esto lo caza aunque el servicio siga activo.
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "${URL}/" 2>/dev/null)"
comprobar "GET ${URL}/ -> 200" "$code" "200"

echo
echo "=== E. con la config real, el dictado sale por el servidor ==="
# Aqui NO se aisla la config, al contrario que en la suite 4. La gracia es probar el camino tal
# cual queda en la maquina, config incluida.
r="$(bash -c "
    source <(head -n -1 '$S')
    if servidor_vivo; then echo -n 'vivo: '; else echo -n 'muerto: '; fi
    WAV='$WAV'
    transcribir" 2>&1)"
case "$r" in
"vivo: "*[Tt]ranscribe\ esto*) echo "  OK   respondio el servidor con la config real: ${r:0:60}"; ok=$((ok + 1));;
*) echo "  MAL  respuesta inesperada: [$r]"; mal=$((mal + 1));;
esac

echo
echo "=== F. la unidad se arranca desde hyprland.lua ==="
# `enabled` NO basta. La unidad cuelga de graphical-session.target, y en este Hyprland ese
# target no se activa nunca. Medido el 2026-10-11: estaba `enabled` y `inactive`, y sin servidor
# cada dictado pagaba la carga del modelo (0,79 s) sin que nada lo dijera. Quien la arranca de
# verdad es el autostart de hyprland.lua, así que si esa línea desaparece, esto tiene que salir
# en rojo. Es la lección de la skill systemd-usuario-no-arranca-hyprland.
LUA="$HOME/dotfiles/.config/hypr/hyprland.lua"
if [ -r "$LUA" ]; then
    caso "hay un exec_cmd que arranca el servicio" "$(cat "$LUA")" \
         "start[[:space:]]+dictado-servidor\.service"
else
    echo "  MAL  no encuentro $LUA"; mal=$((mal + 1))
fi

echo
echo "RESUMEN: $ok correctos, $mal fallidos"
[ "$mal" -eq 0 ]
