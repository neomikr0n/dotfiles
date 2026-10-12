#!/usr/bin/env bash
# Comprueba el verificador de modelos y los tres sitios donde queda enganchado (mejora 3).
#   1. antes de enlazar un modelo, con dictado-modelo-usar.sh
#   2. al arrancar el servicio, con el ExecStartPre de la unidad
#   3. aquí, como prueba de la suite
#
# No abre ventanas ni reproduce sonido, y no toca el modelo en uso. Para el caso del corrupto
# usa una carpeta temporal. Necesita red o la caché del manifiesto, porque sin una de las dos
# no hay contra qué comparar. La sección A refresca la caché si hace falta.
set -u
D="$(cd "$(dirname "$0")/.." && pwd)"
VERIF="$D/dictado-modelos-verificar.py"
USAR="$D/dictado-modelo-usar.sh"
UNIDAD="$HOME/.config/systemd/user/dictado-servidor.service"
ACTUAL="$HOME/.local/share/whisper/actual.bin"

ok=0; mal=0
comprobar() { if [ "$2" = "$3" ]; then echo "  OK   $1"; ok=$((ok + 1)); else echo "  MAL  $1"; echo "        esperado [$3]"; echo "        obtenido [$2]"; mal=$((mal + 1)); fi; }
caso() { if printf '%s' "$2" | grep -qE -- "$3"; then echo "  OK   $1"; ok=$((ok + 1)); else echo "  MAL  $1"; echo "        no casa /$3/ en [$2]"; mal=$((mal + 1)); fi; }

FAKE=/tmp/dictado-modelos-test
rm -rf "$FAKE"; mkdir -p "$FAKE"

echo "=== A. el modelo en uso es el oficial ==="
sal="$(python3 "$VERIF" --solo-uso 2>&1)"; rc=$?
comprobar "el verificador sale 0" "$rc" "0"
caso "no hay corruptos" "$sal" "corruptos: 0"
caso "el modelo en uso da OK" "$sal" "actual\.bin.*OK"

echo
echo "=== B. el verificador caza un corrupto ==="
head -c 1048576 /dev/urandom >"$FAKE/ggml-tiny.bin"
sal="$(python3 "$VERIF" --dir "$FAKE" --estricto 2>&1)"; rc=$?
comprobar "sale con error" "$rc" "1"
caso "lo marca CORRUPTO" "$sal" "CORRUPTO"
sal="$(python3 "$VERIF" --dir "$FAKE" 2>&1)"; rc=$?
comprobar "sin --estricto informa y sale 0" "$rc" "0"

echo
echo "=== C. el modo servicio no bloquea si no hay caché ==="
sal="$(DICTADO_CACHE_MODELOS="$FAKE/no-existe.json" python3 "$VERIF" --servicio --sin-red 2>&1)"; rc=$?
comprobar "sale 0 en vez de bloquear" "$rc" "0"
caso "avisa de que arranca igual" "$sal" "Arranco igual"

echo
echo "=== D. el instalador rechaza un corrupto y no toca el activo ==="
antes="$(readlink -f "$ACTUAL" 2>/dev/null || echo '(nada)')"
sal="$("$USAR" "$FAKE/ggml-tiny.bin" 2>&1)"; rc=$?
comprobar "el instalador sale 1" "$rc" "1"
caso "lo rechaza" "$sal" "RECHAZADO|No puedo confirmar"
comprobar "el activo no cambió" "$(readlink -f "$ACTUAL" 2>/dev/null || echo '(nada)')" "$antes"

echo
echo "=== E. el instalador acepta el que ya es activo (idempotente) ==="
sal="$("$USAR" "$antes" 2>&1)"; rc=$?
comprobar "sale 0" "$rc" "0"
caso "no reinicia el servicio" "$sal" "ya era el activo"
comprobar "el activo sigue igual" "$(readlink -f "$ACTUAL" 2>/dev/null || echo '(nada)')" "$antes"

echo
echo "=== F. la unidad del servicio lleva el ExecStartPre ==="
if [ -r "$UNIDAD" ]; then
    u="$(cat "$UNIDAD")"
    caso "el ExecStartPre llama al verificador" "$u" "ExecStartPre=.*dictado-modelos-verificar\.py"
    caso "y usa el modo servicio" "$u" "[-][-]servicio"
else
    echo "  MAL  no encuentro $UNIDAD"; mal=$((mal + 1))
fi

rm -rf "$FAKE"

echo
echo "RESUMEN: $ok correctos, $mal fallidos"
[ "$mal" -eq 0 ]
