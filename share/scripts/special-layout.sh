#!/usr/bin/env bash
# ============================================================
# special-layout.sh
#
# Restaura en el espacio especial `special` el diseno fijo:
#
#   +---------------------+------------------+
#   |  grupo: NvTop+BTop  |                  |
#   +---------------------+      CIDER       |
#   |       ZapZap        |                  |
#   +---------------------+------------------+
#
# Medidas objetivo (leidas de la sesion de n30 el 2026-10-10):
#   grupo  819 x 720   en (0, 0)
#   ZapZap 819 x 720   en (0, 720)
#   CIDER 2621 x 1440  en (819, 0)
#
# POR QUE UN SCRIPT Y NO UNA REGLA
#   La geometria se podria fijar con hl.window_rule (float + size + move), pero
#   n30 NO quiere ventanas flotantes. En mosaico la FORMA del arbol (quien queda
#   al lado de quien) la decide el orden de creacion y la direccion del split, y
#   con `preserve_split = true` esa direccion queda fijada al crear la ventana.
#   Ademas la config no toca `force_split`, asi que vale 0 = "el split sigue al
#   raton": el lado donde cae una ventana nueva NO es determinista.
#   => Este script manda en el arranque de las cuatro apps, para que el orden
#      sea determinista, y despues ajusta los repartos.
#
# MEDIDO EL 2026-10-10 (esto es lo que hace que funcione):
#
#   1) hl.dsp.window.resize({ x, y, window }) NO aterriza el tamano pedido en
#      ventanas EN MOSAICO. Probado en esta sesion: con solo `y` no hace nada;
#      con `x` e `y` se comporta como un delta. La equivalencia que documenta
#      lua_resize() de genymotion-open.sh vale para SU caso, no para un split vertical
#      cualquiera. NO usar resize aqui.
#
#   2) LO QUE SI FUNCIONA es el mensaje de layout de dwindle:
#          hl.dsp.layout("splitratio <r> exact")
#      aplicado sobre la ventana ENFOCADA, cambia el reparto de SU split padre.
#      Con `exact`, r es absoluto y r=1.0 es reparto 50/50.
#      Medido: el hermano se queda con r/2 y el enfocado con 1 - r/2.
#
#   3) Enfocar una ventana que esta en un espacio especial OCULTO lo REVELA.
#      Por eso al final se vuelve a ocultar si estaba oculto al empezar.
#
# Convenciones del repo: `set -uo pipefail` (sin -e, porque un fallo de hyprctl no debe
# abortar el arranque), log con logger + fallback a /tmp, veredicto al final.
#
# Este script NO se auto-avisa por eco-aviso.sh: corre en el arranque que n30
# configuro a proposito. Si se lanza a mano, avisar antes.
# ============================================================

set -uo pipefail

TAG="special-layout"
LOG="/tmp/${TAG}.log"
WS="special"

CIDER_CLASS='^(cider)$'
ZAP_CLASS='^com\.rtosta\.zapzap$'
BTOP_CLASS='^(btop)$'
NVTOP_CLASS='^nvtop-fluid$'

# Reparto horizontal: la columna izquierda ocupa 819 de 3440 -> fraccion 0.2381.
# El hermano (columna izquierda) se queda con r/2, asi que r = 2 * 0.2381.
RATIO_H="0.4762"
# Reparto vertical de la columna izquierda: 50/50 (r = 1.0).
RATIO_V="1.0"

: >"$LOG"
exec > >(tee -a "$LOG") 2>&1

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }

hypr() { hyprctl "$@" 2>&1; }

lua_focus()      { printf 'hl.dsp.focus({ window = "address:%s" })' "$1"; }
lua_splitratio() { printf 'hl.dsp.layout("splitratio %s exact")' "$1"; }
lua_preselect()  { printf 'hl.dsp.layout("preselect %s")' "$1"; }
lua_exec_ws()    { printf 'hl.dsp.exec_cmd("%s", { workspace = "%s silent" })' "$1" "$WS"; }

# Agrupa BTop (anfitrion) + NvTop (miembro). Idempotente por address.
# Forma medida en lua_group_player() de genymotion-open.sh: los despachadores de grupo IGNORAN
# los selectores de cadena, solo aceptan el OBJETO de ventana.
lua_group_btop_nvtop() {
    cat <<'LUA'
local function _w(c)
  local t = hl.get_windows({ class = c })
  if type(t) == "table" and #t > 0 then return t[1] end
  return nil
end
local q = _w("btop")
local p = _w("nvtop-fluid")
if q == nil or p == nil then return end
if q.group == nil then
  hl.dispatch(hl.dsp.group.toggle({ window = q }))
  q = _w("btop")
  if q == nil or q.group == nil then return end
end
local m = q.group.members
if type(m) == "table" then
  for _, w in ipairs(m) do
    if w.address == p.address then return end
  end
end
q.group:add(p)
LUA
}

addr_of() {
    hyprctl clients -j 2>/dev/null | jq -r --arg c "$1" --arg t "${2:-}" '
        [ .[] | select(.class | test($c)) | select($t == "" or (.title | test($t))) ]
        | (.[0].address // empty)'
}

geom_of() {
    hyprctl clients -j 2>/dev/null | jq -r --arg a "$1" '
        .[] | select(.address == $a)
        | "at=\(.at[0]),\(.at[1]) size=\(.size[0])x\(.size[1])"'
}

special_visible() {
    local id
    id="$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].specialWorkspace.id // 0')"
    [[ -n "$id" && "$id" != "0" ]] && return 0
    return 1
}

# Espera a que exista la ventana. Imprime SOLO la direccion por stdout.
wait_window() {
    local c="$1" t="${2:-}" timeout="${3:-45}" i n a
    n=$(( timeout * 4 ))
    for (( i = 0; i < n; i++ )); do
        a="$(addr_of "$c" "$t")"
        if [[ -n "$a" ]]; then printf '%s\n' "$a"; return 0; fi
        sleep 0.25
    done
    return 1
}

# Enfoca una ventana y fija el reparto de su split padre. Comprueba el resultado.
set_split() {
    local addr="$1" ratio="$2" label="$3"
    [[ -z "$addr" ]] && return 1
    hypr dispatch "$(lua_focus "$addr")" >/dev/null
    sleep 0.3
    hypr dispatch "$(lua_splitratio "$ratio")" >/dev/null
    sleep 0.5
    log "   $label: ratio $ratio -> $(geom_of "$addr")"
}

log "=== special-layout $(date) ==="

# ------------------------------------------------------------
# 0. Esperar al compositor y anotar si `special` estaba oculto
# ------------------------------------------------------------
ready=0
for _ in $(seq 1 60); do
    hyprctl version >/dev/null 2>&1 && { ready=1; break; }
    sleep 0.5
done
if [[ "$ready" -eq 0 ]]; then
    log "ERROR: Hyprland no responde. Salgo."
    exit 1
fi

started_hidden=0
special_visible || started_hidden=1
log "special visible al empezar: $(( 1 - started_hidden ))"

# ------------------------------------------------------------
# 1. CIDER (primero: queda solo, a pantalla completa)
# ------------------------------------------------------------
cid="$(addr_of "$CIDER_CLASS")"
if [[ -z "$cid" ]]; then
    log "Lanzo CIDER en $WS"
    hypr dispatch "$(lua_exec_ws 'cider')" >/dev/null
    cid="$(wait_window "$CIDER_CLASS" '' 60)" || { log "ERROR: CIDER no aparecio en 60s. Salgo."; exit 1; }
fi
log "CIDER: $cid"

# ------------------------------------------------------------
# 2. ZapZap -> a la IZQUIERDA de CIDER (preselect l)
# ------------------------------------------------------------
zap="$(addr_of "$ZAP_CLASS")"
if [[ -z "$zap" ]]; then
    log "Espero red para ZapZap (max 45s)"
    for _ in $(seq 1 45); do ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && break; sleep 1; done
    hypr dispatch "$(lua_focus "$cid")" >/dev/null
    hypr dispatch "$(lua_preselect l)" >/dev/null
    log "Lanzo ZapZap en $WS (preselect l)"
    hypr dispatch "$(lua_exec_ws 'env QT_QUICK_BACKEND=software zapzap')" >/dev/null
    zap="$(wait_window "$ZAP_CLASS" '' 60)" || { log "ERROR: ZapZap no aparecio en 60s. Salgo."; exit 1; }
fi
log "ZapZap: $zap"

# ------------------------------------------------------------
# 3-4. BTop -> ARRIBA de ZapZap.
#    Se estrecha la columna izquierda ANTES de abrirlo. Con la columna ya mas
#    alta que ancha, el split que haga BTop sera por fuerza arriba/abajo.
#    Esto solo se hace si BTop NO existe todavia, para que re-ejecutar el script
#    no descoloque una columna que ya tiene las dos mitades repartidas.
# ------------------------------------------------------------
btop="$(addr_of "$BTOP_CLASS")"
if [[ -z "$btop" ]]; then
    set_split "$cid" "$RATIO_H" "Estrecho la columna izquierda"
    hypr dispatch "$(lua_focus "$zap")" >/dev/null
    hypr dispatch "$(lua_preselect u)" >/dev/null
    log "Lanzo BTop en $WS (preselect u)"
    hypr dispatch "$(lua_exec_ws 'kitty --class btop -o font_size=10 -e btop')" >/dev/null
    btop="$(wait_window "$BTOP_CLASS" '' 45)" || log "AVISO: BTop no aparecio en 45s."
fi
log "BTop: $btop"

# ------------------------------------------------------------
# 5. NvTop
# ------------------------------------------------------------
nvtop="$(addr_of "$NVTOP_CLASS")"
if [[ -z "$nvtop" ]]; then
    log "Lanzo NvTop en $WS"
    hypr dispatch "$(lua_exec_ws '/home/n30/.local/bin/nvtop')" >/dev/null
    nvtop="$(wait_window "$NVTOP_CLASS" '' 45)" || log "AVISO: NvTop no aparecio en 45s."
fi
log "NvTop: $nvtop"

# ------------------------------------------------------------
# 6. Agrupar NvTop + BTop (idempotente)
# ------------------------------------------------------------
if [[ -n "$btop" && -n "$nvtop" ]]; then
    hypr eval "$(lua_group_btop_nvtop)" >/dev/null
    sleep 0.4
    gm="$(hyprctl clients -j | jq -r --arg a "$btop" '.[] | select(.address==$a) | (.grouped|length)')"
    log "Grupo BTop+NvTop: $gm miembro(s)"
else
    log "AVISO: falta BTop o NvTop; no agrupo."
fi

# ------------------------------------------------------------
# 7. Repartos finales
#    Vertical (50/50) primero, luego el horizontal (819 / 2621).
# ------------------------------------------------------------
cid="$(addr_of "$CIDER_CLASS")"
zap="$(addr_of "$ZAP_CLASS")"

set_split "$zap" "$RATIO_V" "Reparto vertical de la columna izquierda"
set_split "$cid" "$RATIO_H" "Reparto horizontal columna izquierda / CIDER"

# ------------------------------------------------------------
# 8. Volver a ocultar `special` si estaba oculto al empezar
#    (enfocar una ventana de un especial oculto lo revela)
# ------------------------------------------------------------
if [[ "$started_hidden" -eq 1 ]] && special_visible; then
    hypr dispatch 'hl.dsp.workspace.toggle_special("special")' >/dev/null
    log "special vuelto a ocultar"
fi

# ------------------------------------------------------------
# 9. Veredicto
# ------------------------------------------------------------
sleep 0.4
log "--- veredicto ---"
hyprctl clients -j | jq -r '
    .[] | select(.class | test("nvtop-fluid|^btop$|zapzap|^cider$"))
    | "\(.class) | at=\(.at) | size=\(.size) | float=\(.floating) | grouped=\(.grouped|length)"' |
    while IFS= read -r l; do log "$l"; done
log "=== fin ==="
