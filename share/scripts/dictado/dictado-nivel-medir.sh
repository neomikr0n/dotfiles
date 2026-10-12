#!/usr/bin/env bash
# Mide el medidor de nivel del dictado en vivo por las dos vias y las compara sobre la MISMA senal.
#
#   A) PwNodePeakMonitor, el medidor nativo de Quickshell, que vive dentro de la capa
#   B) parec, que es lo que usa hoy dictado-vivo.py
#
# No hace ruido y no toca el escritorio. La senal se reproduce a un sumidero nulo que se crea y se
# destruye aqui mismo, asi que no sale por ningun altavoz y no queda nada cargado. Si algo se corta
# a medias, el trap descarga el sumidero igual.
#
# Uso
#   dictado-nivel-medir.sh            medida corta, unos 40 s
#   dictado-nivel-medir.sh --cpu      anade el coste de CPU, ventana de 60 s, unos 2 min
#
# Lo que saca esta escrito en dictado-nivel-medir.py, que hace las dos mitades.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
QML="$DIR/dictado-nivel-medir.qml"
QML_CPU="$DIR/dictado-nivel-medir-cpu.qml"
PY="$DIR/dictado-nivel-medir.py"
CORPUS="${DICTADO_CORPUS:-$HOME/.local/share/dictado/corpus}"
WAV1="$CORPUS/m1-comando.wav"
WAV2="$CORPUS/c3-abre.wav"
SUMIDERO="${DICTADO_NIVEL_SUMIDERO:-dictado-nivel-rig}"
VENTANA_CPU=60
HACER_CPU=0
[ "${1:-}" = "--cpu" ] && HACER_CPU=1

for c in quickshell pactl pw-play python3; do
    command -v "$c" >/dev/null 2>&1 || { echo "falta $c" >&2; exit 1; }
done
[ -f "$WAV1" ] || { echo "falta el corpus en $CORPUS" >&2; exit 1; }
[ -f "$QML" ] || { echo "falta $QML" >&2; exit 1; }
[ -f "$QML_CPU" ] || { echo "falta $QML_CPU" >&2; exit 1; }

D="$(mktemp -d /tmp/dictado-nivel-XXXXXX)"
MODULO=""; BUCLE=""; QS=""; PY_PID=""
limpiar() {
    [ -n "$BUCLE" ] && kill "$BUCLE" 2>/dev/null
    [ -n "$QS" ] && kill "$QS" 2>/dev/null
    [ -n "$PY_PID" ] && kill "$PY_PID" 2>/dev/null
    [ -n "$MODULO" ] && pactl unload-module "$MODULO" >/dev/null 2>&1
    rm -rf "$D"
}
trap limpiar EXIT INT TERM

MODULO="$(pactl load-module module-null-sink sink_name="$SUMIDERO" \
    sink_properties=device.description="$SUMIDERO" format=float32le rate=48000 channels=2)"
echo "sumidero nulo creado (modulo $MODULO), la senal no sale por ningun altavoz"
sleep 1

DICTADO_NIVEL_SUMIDERO="$SUMIDERO" quickshell -p "$QML" > "$D/qs.log" 2>&1 &
QS=$!
python3 "$PY" comparar "$SUMIDERO.monitor" > "$D/parec.log" 2>&1 &
PY_PID=$!
sleep 3

# Tres pasadas del corpus, unos 20 s de audio, y luego silencio para ver que hace cada via cuando
# no hay nada sonando.
( for _ in 1 2 3; do
    pw-play --target "$SUMIDERO" "$WAV1" >/dev/null 2>&1
    pw-play --target "$SUMIDERO" "$WAV2" >/dev/null 2>&1
  done ) &
BUCLE=$!
sleep 20
kill "$BUCLE" 2>/dev/null; BUCLE=""
sleep 6

if [ "$HACER_CPU" = "1" ]; then
    echo
    echo "=== coste de CPU, ventana de ${VENTANA_CPU} s ==="
    # El quickshell de arriba escribe una linea por emision en su registro, y lleva dos
    # monitores, uno por nodo. Para medir el coste eso no sirve, porque el registro forma
    # parte de lo que se mide y en produccion no existiria. Se para y se levanta el
    # callado, con un solo monitor sobre el microfono, que es lo que correria de verdad.
    kill "$QS" 2>/dev/null; QS=""
    quickshell -p "$QML_CPU" > "$D/qs-cpu.log" 2>&1 &
    QS=$!
    sleep 3
    tics() { awk '{print $14+$15}' "/proc/$1/stat" 2>/dev/null; }
    TICS=$(getconf CLK_TCK)
    ( for _ in 1 2 3 4 5 6; do
        pw-play --target "$SUMIDERO" "$WAV1" >/dev/null 2>&1
        pw-play --target "$SUMIDERO" "$WAV2" >/dev/null 2>&1
      done ) &
    BUCLE=$!
    hijo=$(pgrep -P "$PY_PID" -x parec | head -1)
    a_qs=$(tics "$QS"); a_py=$(tics "$PY_PID"); a_pa=$(tics "$hijo")
    sleep "$VENTANA_CPU"
    b_qs=$(tics "$QS"); b_py=$(tics "$PY_PID"); b_pa=$(tics "$hijo")
    awk -v t="$TICS" -v v="$VENTANA_CPU" -v a="$a_qs" -v b="$b_qs" \
        'BEGIN { printf "%-42s %6.2f %% de un nucleo  (%d tics)\n", "quickshell + un monitor sobre el micro", (b-a)/(t*v)*100, b-a }'
    awk -v t="$TICS" -v v="$VENTANA_CPU" -v a="$a_py" -v b="$b_py" \
        'BEGIN { printf "%-42s %6.2f %% de un nucleo  (%d tics)\n", "python del medidor, bucle de RMS", (b-a)/(t*v)*100, b-a }'
    awk -v t="$TICS" -v v="$VENTANA_CPU" -v a="$a_pa" -v b="$b_pa" \
        'BEGIN { printf "%-42s %6.2f %% de un nucleo  (%d tics)\n", "parec", (b-a)/(t*v)*100, b-a }'
    picos=$(grep -o 'CUENTA [0-9]*' "$D/qs-cpu.log" | tail -1 | awk '{print $2}')
    echo "   el monitor conto ${picos:-0} picos durante la ventana"
    kill "$BUCLE" 2>/dev/null; BUCLE=""
fi

kill "$QS" "$PY_PID" 2>/dev/null; QS=""; PY_PID=""
sleep 1

python3 "$PY" analizar "$D/qs.log" "$D/parec.log"

echo
echo "banco desmontado"
