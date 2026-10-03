#!/usr/bin/env sh
# ktimer-next-round.sh — Aviso de "siguiente ronda" para el bucle de KTimer.
#
# Que hace, en orden:
#   1. Reproduce share/sounds/scratchonix-dart-throw-380649.mp3 con
#      `play -q -v $VOLUMEN` (sox, la herramienta que usa hyprland.lua). Ojo: el
#      volumen NO es el 0.1 de hyprland.lua; se subio a peticion de n30.
#   2. Dispara el overlay propio de Quickshell (arriba a la izquierda, tarjeta
#      negra con borde naranja, entrando deslizando desde arriba).
#
# ── Por que NO manda una notificacion de escritorio ──────────────────────────
# Antes usaba `notify-send`. Se quito el 2026-10-02 por dos motivos medidos:
#
#   a) No se puede silenciar SOLO su popup. `notificationRules` de DMS es un
#      array y el IPC `dms ipc call settings set` rechaza objetos y arrays
#      ("Setting Objects and Arrays not supported"); editar settings.json a mano
#      no sirve porque DMS no lo relee y lo pisa al guardar. Y la urgencia no
#      filtra el popup (no hay ajuste de "ocultar urgencia baja"). Con
#      notify-send salian DOS avisos: el popup de DMS y este overlay.
#   b) El bucle de 75 s son ~48 notificaciones/hora, y el historial de DMS esta
#      topado en 50 entradas (notificationHistoryMaxCount): el KTimer echaba de
#      la lista a las notificaciones reales de otras aplicaciones.
#
# Consecuencia asumida: este aviso ya no queda en el historial del centro de
# notificaciones y no lo filtra «No molestar». Es un temporizador, no una
# notificacion; el sonido tampoco pasaba por DND.
#
# Pensado para el campo "Command line:" de una tarea de KTimer. KTimer parte la
# linea con QProcess::splitCommand y NO pasa por un shell, asi que un `;` o un
# `&&` en ese campo no funcionaria: toda la logica tiene que vivir aqui.
#
# Uso manual:  ./ktimer-next-round.sh
#
# Salida: 0 siempre que el sonido o el aviso hayan salido; 1 si no se pudo
# hacer ninguna de las dos cosas.

set -u

SONIDO="${HOME}/dotfiles/share/sounds/scratchonix-dart-throw-380649.mp3"
VOLUMEN="1.5"                                  # ganancia lineal: 15x el 0.1 de hyprland.lua (+23,5 dB)
ALERTA_DIR="${HOME}/.config/ktimer-alert"      # config de Quickshell del overlay
ALERTA_TARGET="ktimer-alert"
TITULO="KTimer"
MENSAJE="🦖🦕 Next round is up...!"

# KTimer puede lanzar esto sin el entorno de la sesion. El IPC de Quickshell no
# usa D-Bus: va por un socket dentro de XDG_RUNTIME_DIR.
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u)"
    export XDG_RUNTIME_DIR
fi

# --- 1. Sonido ---------------------------------------------------------------
# sox (`play`) es lo que usa la config activa; si no esta o falla, paplay
# (PipeWire/Pulse) como red de seguridad.
sonido_ok=1
if [ -f "$SONIDO" ]; then
    if command -v play >/dev/null 2>&1; then
        play -q -v "$VOLUMEN" "$SONIDO" >/dev/null 2>&1 && sonido_ok=0
    fi
    if [ "$sonido_ok" -ne 0 ] && command -v paplay >/dev/null 2>&1; then
        # paplay no admite mas de 1,0 lineal (65536), asi que con VOLUMEN>1 el
        # respaldo se queda en ese tope. Se calcula desde VOLUMEN para que las
        # dos vias no se desincronicen si alguien cambia la cifra.
        vol_pa=$(awk -v v="$VOLUMEN" 'BEGIN { n = v * 65536; if (n > 65536) n = 65536; printf "%d", n }')
        paplay --volume="$vol_pa" "$SONIDO" >/dev/null 2>&1 && sonido_ok=0
    fi
else
    echo "ktimer-next-round: no existe $SONIDO" >&2
fi

# --- 2. Aviso en pantalla ----------------------------------------------------
# El overlay lo sirve ktimer-alert.service. Se elige el config por RUTA (-p) y
# no por id: el "Shell ID" que aparece en el log NO es el instance id, y el pid
# cambia en cada reinicio del servicio. La ruta es estable.
aviso_ok=1
if command -v qs >/dev/null 2>&1; then
    # Se comprueba la RESPUESTA, no solo el codigo de salida: `qs ipc` sale con 0
    # aunque no ejecute nada (un nombre de funcion que choque con un subcomando
    # de `qs ipc` —show/call/wait/listen/prop— imprime el listado del target y
    # devuelve 0). Ver la nota en ktimer-alert/shell.qml.
    respuesta=$(qs -p "$ALERTA_DIR" ipc call "$ALERTA_TARGET" mostrar 2>/dev/null)
    [ "$respuesta" = "KTIMER_ALERT_SHOW_OK" ] && aviso_ok=0
fi

# Red de seguridad: si el overlay no esta levantado (servicio parado, Quickshell
# actualizado, config rota), el aviso no se pierde: sale como notificacion
# normal de DMS. Degradacion, no duplicado: solo entra si el IPC fallo.
if [ "$aviso_ok" -ne 0 ] && command -v notify-send >/dev/null 2>&1; then
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "/run/user/$(id -u)/bus" ]; then
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
        export DBUS_SESSION_BUS_ADDRESS
    fi
    echo "ktimer-next-round: el overlay no respondio; se usa notify-send" >&2
    notify-send -a "$TITULO" -u normal "$TITULO" "$MENSAJE" >/dev/null 2>&1 && aviso_ok=0
fi

[ "$sonido_ok" -eq 0 ] || [ "$aviso_ok" -eq 0 ] || exit 1
exit 0
