#!/usr/bin/env bash
# dictado-voz-prueba.sh. Mide los modelos contra TU voz y no contra voz sintética.
#
# Por qué existe: el conjunto sintético (espeak-ng) sirve para ordenar modelos, pero es una voz
# robótica y atípica. La única cifra que responde a «¿lee bien MI voz?» es medir sobre
# grabaciones tuyas con el texto que dijiste.
#
#   dictado-voz-prueba.sh grabar    graba las frases una a una (Enter para empezar y parar)
#   dictado-voz-prueba.sh medir     mide todos los modelos contra lo grabado
#   dictado-voz-prueba.sh listar    enseña las frases sin grabar nada
#   dictado-voz-prueba.sh limpiar   borra las grabaciones (a la papelera, no rm)
#
# Las frases están elegidas para atacar justo lo que falla. Son nombres propios de tu equipo
# de audio, siglas técnicas, números y préstamos del inglés, que es lo que aparece en tu habla real.
set -u

DEST="${DICTADO_VOZ_DIR:-$HOME/.local/share/dictado/voz-prueba}"
MICRO="${DICTADO_FUENTE:-Wireless_Mic_Rx}"
BENCH="$(dirname "$(readlink -f "$0")")/dictado-bench.py"

# nombre<TAB>frase
FRASES=$(cat <<'EOF'
equipo	Escucho con los Hifiman HE1000se conectados al amplificador Aune S17 Pro EVO.
cadena	La señal sale del RME ADI-2 por USB y entra en el amplificador en clase A.
sistema	Tengo Hyprland sobre Wayland con PipeWire y WirePlumber en Garuda Linux.
numeros	El monitor va a 3440 por 1440 a 144 hercios y el otro a 60.
ingles	Voy a hacer un commit en la rama main y luego abro una pull request.
tecnico	El convertidor está trabajando a 192 kilohercios con 24 bits.
mezcla	El firmware del receptor DJI Mic Mini se actualiza desde la aplicación.
natural	Mañana quedamos a las diez y media para revisar el informe de la auditoría.
EOF
)

fuente() {
    local n
    n="$(pactl list short sources 2>/dev/null | awk -v p="$MICRO" 'index($2,p){print $2; exit}')"
    [ -n "$n" ] || n="$(pactl get-default-source 2>/dev/null)"
    printf '%s' "$n"
}

grabar() {
    mkdir -p "$DEST"
    local f
    f="$(fuente)"
    if [ -z "$f" ]; then echo "No encuentro el micrófono (patrón $MICRO)." >&2; exit 1; fi
    echo "Micrófono: $f"
    echo "Carpeta  : $DEST"
    echo
    echo "Para cada frase: pulsa Enter, léela en voz alta y normal, y pulsa Enter para parar."
    echo "Lee EXACTAMENTE lo que se muestra: el texto es la referencia para medir el error."
    echo

    while IFS=$'\t' read -r nombre texto; do
        [ -n "$nombre" ] || continue
        printf '%s\n' "$texto" >"$DEST/$nombre.txt"
        echo "──────────────────────────────────────────────────────────"
        echo "  $texto"
        echo "──────────────────────────────────────────────────────────"
        # OJO: los read de dentro van a /dev/tty a propósito. El bucle lee las frases de un
        # heredoc, así que un read normal se comería la frase siguiente en vez de esperarte.
        read -r -p "  Enter para GRABAR… " _ </dev/tty
        pw-record --target "$f" --rate 16000 --channels 1 --format s16 "$DEST/$nombre.wav" &
        local pid=$!
        read -r -p "  grabando… Enter para PARAR " _ </dev/tty
        kill -INT "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        local seg
        seg="$(soxi -D "$DEST/$nombre.wav" 2>/dev/null || echo 0)"
        echo "  guardado: $nombre.wav  (${seg} s)"
        echo
    done <<<"$FRASES"

    echo "Hecho. Ahora:  $(basename "$0") medir"
}

medir() {
    if [ ! -d "$DEST" ] || ! ls "$DEST"/*.wav >/dev/null 2>&1; then
        echo "No hay grabaciones en $DEST. Ejecuta primero: $(basename "$0") grabar" >&2
        exit 1
    fi
    python3 "$BENCH" --dir "$DEST" --detalle "$@"
}

listar() { printf '%s\n' "$FRASES" | awk -F'\t' '{printf "  %-9s %s\n", $1, $2}'; }

limpiar() {
    if [ ! -d "$DEST" ]; then echo "No hay nada que limpiar."; return 0; fi
    command -v gio >/dev/null 2>&1 || { echo "falta gio; no borro nada a lo bruto" >&2; exit 1; }
    gio trash "$DEST" && echo "Movido a la papelera: $DEST"
}

case "${1:-}" in
grabar) grabar ;;
medir) shift; medir "$@" ;;
listar) listar ;;
limpiar) limpiar ;;
*)
    echo "uso: $(basename "$0") {grabar|medir|listar|limpiar}" >&2
    exit 2
    ;;
esac
