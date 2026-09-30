#!/usr/bin/env bash

# ============================================================
# STEAM + HYPRLAND — espera internet real y garantiza el escritorio 1
# ============================================================
#
# POR QUÉ EXISTE ESTE SCRIPT (medido el 2026-09-27, login de las 08:33):
#
#   El autostart lanzaba `steam` y, 5 s después, un refuerzo de UNA sola pasada
#   (`hl.dsp.window.move({ ... window = "class:steam" })`). La línea de tiempo
#   real de aquel arranque, sacada del log de Steam y de la marca de autostart:
#
#     08:33:15  arranca el handler de autostart (marca + astra-brillo)
#     08:33:19  se lanza steam (el ping fue inmediato: 4 s = sleeps 2 + 2)
#     08:33:20  ventana del ACTUALIZADOR: "Create window"
#     08:33:22  "Destroy window" y arranca el cliente principal
#     ~08:33:25 el refuerzo dispara: no hay ninguna ventana que mover -> no-op
#     08:33:22 - 08:33:40 el cliente sigue inicializando (CEF/Vulkan)
#
#   Es decir: el refuerzo caía justo en el hueco entre las dos ventanas, no
#   reintentaba y no avisaba (un `hyprctl dispatch` con un selector que no
#   resuelve no da error visible). La ventana aparecía después, en el escritorio
#   con FOCO (el 2, que es el que deja enfocado la última línea del autostart).
#   Y la ventana de promociones ("Special Offers: ...") llega MINUTOS más tarde,
#   así que ningún sleep fijo la habría cubierto nunca.
#
#   La GARANTÍA del escritorio es la regla de ventana "steam-ws1" del
#   hyprland.lua: se aplica en la CREACIÓN, sin importar qué PID cree la ventana
#   ni cuándo. Este script es la SEGUNDA capa: liga el lanzamiento a internet
#   real (HTTPS, no solo ICMP) y deja un veredicto en el journal que dice qué
#   capa hizo el trabajo, para no volver a diagnosticar a ciegas. Igual que en el
#   caso DSH (hyprland.lua:779-788), van las dos a propósito.
#
#   MEDIDO EL 2026-09-27 CON VENTANAS SONDA (kitty, con la config nueva cargada):
#     - La regla `workspace = "1 silent"` se aplica a ventanas NUEVAS y casa con
#       la clase real `steam`: una sonda `kitty --class steam` con el foco en el
#       ws 2 nació en el ws 1. No se creó ningún workspace llamado "1 silent",
#       así que el flag se parsea como flag y no como nombre.
#     - La exclusión `title = "negative:^(notificationtoasts)"` funciona: la
#       sonda con ese título se quedó en el escritorio con foco.
#     - PRECEDENCIA, y esto importa para leer los veredictos: cuando la ventana
#       hereda el `workspace` del `exec` (linaje de procesos intacto), ESE gana a
#       la regla de ventana. Comprobado: sonda con `{ workspace = "3 silent" }`
#       más regla "1 silent" -> acabó en el 3; la misma sonda sin el workspace del
#       exec -> en el 1. Con Steam pueden estar actuando las dos capas a la vez y
#       desde aquí NO se puede distinguir cuál, por eso el veredicto dice "sin
#       mover nada" en vez de atribuirlo a la regla.
#     - La ruta de movimiento del script está probada: sonda en el ws 3 ->
#       "movida a ws1" con el dispatcher `hl.dsp.window.move` por `address:`.
#
#   Solo se llama desde `hyprland.start` (con su marca por instancia). NO va en
#   `config.reloaded`: cada guardado de la config relanzaría Steam.
#
# Uso normal: lo llama el autostart. A mano, para probar:
#   STEAM_NO_LAUNCH=1 STEAM_WATCH_TIMEOUT=5 ./steam-open.sh
#
# Códigos de salida: 0 = todo en el escritorio destino; 1 = no apareció ventana;
# 2 = quedaron ventanas fuera; 3 = no se puede hablar con Hyprland.
#
# ============================================================

set -uo pipefail   # sin -e: un fallo de hyprctl no debe abortar el script

# ------------------------------------------------------------
# CONFIGURACIÓN (todo se puede pisar por entorno)
# ------------------------------------------------------------

STEAM_WORKSPACE="${STEAM_WORKSPACE:-1}"                 # escritorio destino
STEAM_CLASS="${STEAM_CLASS:-steam}"                     # clase exacta de las ventanas del cliente
STEAM_TITLE_EXCLUDE="${STEAM_TITLE_EXCLUDE:-^notificationtoasts}"  # avisos: NO se tocan
STEAM_NET_URL="${STEAM_NET_URL:-https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/}"
STEAM_NET_TIMEOUT="${STEAM_NET_TIMEOUT:-120}"           # tope de espera de red (s)
STEAM_WATCH_TIMEOUT="${STEAM_WATCH_TIMEOUT:-120}"       # tope de vigilancia de ventanas (s)
STEAM_POLL="${STEAM_POLL:-1}"                           # intervalo de sondeo (s)
STEAM_NO_LAUNCH="${STEAM_NO_LAUNCH:-0}"                 # 1 = no lanzar Steam (modo prueba)
STEAM_LOG_TAG="${STEAM_LOG_TAG:-steam-open}"            # etiqueta de logger (rastro en el journal)
STEAM_LOG_FILE="${STEAM_LOG_FILE:-/tmp/steam-open.log}" # respaldo si logger no puede escribir

readonly STEAM_WORKSPACE STEAM_CLASS STEAM_TITLE_EXCLUDE STEAM_NET_URL
readonly STEAM_NET_TIMEOUT STEAM_WATCH_TIMEOUT STEAM_POLL STEAM_NO_LAUNCH
readonly STEAM_LOG_TAG STEAM_LOG_FILE

# ------------------------------------------------------------
# UTILIDADES
# ------------------------------------------------------------

log() {
    # El journal es el rastro que se consulta (`journalctl -t steam-open`). Si
    # logger no está o no puede escribir, queda el fichero: un veredicto perdido
    # en silencio es peor que un fichero de más.
    logger -t "$STEAM_LOG_TAG" -- "$*" 2>/dev/null \
        || printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$STEAM_LOG_FILE" 2>/dev/null
    [[ -t 2 ]] && printf '%s: %s\n' "$STEAM_LOG_TAG" "$*" >&2
    return 0
}

# Instantánea de las ventanas de Steam que SÍ hay que vigilar, una por línea:
#   "<dirección> <workspace> <título>"
# Excluye los avisos (toasts): deben seguir saliendo donde esté el usuario.
steam_windows() {
    hyprctl clients -j 2>/dev/null | jq -r \
        --arg cls "$STEAM_CLASS" --arg ex "$STEAM_TITLE_EXCLUDE" \
        '.[]?
         | select(.class == $cls)
         | select((.title // "") | test($ex) | not)
         | "\(.address) \(.workspace.id) \(.title)"' 2>/dev/null || true
}

steam_running() {
    [[ -n "$(steam_windows)" ]] && return 0
    pgrep -x steam >/dev/null 2>&1 && return 0
    pgrep -f 'ubuntu12_32/steam' >/dev/null 2>&1 && return 0
    return 1
}

# Constructor del dispatcher en Lua. Los selectores por dirección son los únicos
# que no se confunden cuando hay DOS ventanas de Steam a la vez (principal +
# promociones): `window = "class:steam"` resolvería solo una.
lua_move() {
    printf 'hl.dsp.window.move({ workspace = %d, follow = false, window = "address:%s" })' \
        "$STEAM_WORKSPACE" "$1"
}

# Lee la instantánea por stdin y mueve al escritorio destino lo que esté fuera.
move_mismatched() {
    local addr ws title out
    while read -r addr ws title; do
        [[ -n "$addr" ]] || continue
        [[ "$ws" == "$STEAM_WORKSPACE" ]] && continue
        out=$(hyprctl dispatch "$(lua_move "$addr")" 2>&1)
        if [[ "$out" == ok* ]]; then
            log "ventana $addr '$title' estaba en ws$ws: movida a ws$STEAM_WORKSPACE"
        else
            log "FALLO al mover $addr '$title' (ws$ws): $out"
        fi
    done
    return 0
}

# Devuelve 0 si hay HTTPS contra el endpoint de Steam. Es la prueba que importa:
# ICMP puede responder con el acceso a servicios bloqueado o roto.
internet_ok() {
    curl -fsS -o /dev/null --max-time 4 "$STEAM_NET_URL" 2>/dev/null
}

wait_online() {
    local waited=0
    while (( waited < STEAM_NET_TIMEOUT )); do
        if internet_ok; then
            log "internet OK tras ${waited}s (HTTPS 200 en ${STEAM_NET_URL})"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    # Gracia deliberada, igual que la versión anterior del autostart: sin red se
    # lanza igualmente y Steam reintenta por su cuenta, antes que dejarte sin app.
    if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
        log "sin HTTPS tras ${STEAM_NET_TIMEOUT}s, pero ICMP responde: se lanza igual"
    else
        log "sin internet tras ${STEAM_NET_TIMEOUT}s: se lanza igual (Steam reintentará)"
    fi
    return 1
}

# ------------------------------------------------------------
# PRINCIPAL
# ------------------------------------------------------------

main() {
    command -v hyprctl >/dev/null 2>&1 || { log "falta hyprctl: nada que hacer"; return 3; }
    command -v jq      >/dev/null 2>&1 || { log "falta jq: nada que hacer";      return 3; }
    hyprctl version >/dev/null 2>&1    || { log "hyprctl no responde (¿Hyprland caído?): nada que hacer"; return 3; }

    wait_online || true   # el código solo distingue el camino, no aborta nada

    if [[ "$STEAM_NO_LAUNCH" == "1" ]]; then
        log "STEAM_NO_LAUNCH=1: no se lanza Steam (modo prueba)"
    elif steam_running; then
        log "Steam ya estaba corriendo: no se lanza otra instancia"
    elif ! command -v steam >/dev/null 2>&1; then
        log "no encuentro el binario steam en PATH: no se lanza"
    else
        log "lanzando steam (setsid, desacoplado del autostart)"
        setsid steam >/dev/null 2>&1 &
    fi

    local deadline=$((SECONDS + STEAM_WATCH_TIMEOUT))
    local snap="" seen=0 mism=0 first_ok=0

    while (( SECONDS < deadline )); do
        snap=$(steam_windows)
        if [[ -n "$snap" ]]; then
            seen=1
            mism=$(printf '%s\n' "$snap" | awk -v w="$STEAM_WORKSPACE" '$2 != w' | wc -l)
            if (( mism > 0 )); then
                printf '%s\n' "$snap" | move_mismatched
            elif (( first_ok == 0 )); then
                first_ok=1
                # Esta línea es la que dirá, en el próximo login, que la ventana
                # nació ya en el escritorio correcto y no hubo que moverla.
                log "ventana(s) de Steam ya en ws$STEAM_WORKSPACE sin mover nada (no hizo falta la red de seguridad): $(printf '%s\n' "$snap" | paste -sd'|')"
            fi
        fi
        sleep "$STEAM_POLL"
    done

    if (( seen == 0 )); then
        log "sin ventana de Steam tras ${STEAM_WATCH_TIMEOUT}s"
        return 1
    fi

    snap=$(steam_windows)
    mism=$(printf '%s\n' "$snap" | awk -v w="$STEAM_WORKSPACE" '$2 != w' | wc -l)
    if (( mism > 0 )); then
        log "aviso: $mism ventana(s) de Steam siguen fuera del ws$STEAM_WORKSPACE"
        return 2
    fi
    log "fin: todas las ventanas de Steam en ws$STEAM_WORKSPACE"
    return 0
}

main "$@"
exit $?
