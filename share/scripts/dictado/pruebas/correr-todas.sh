#!/usr/bin/env bash
# Corre las suites de dictado y resume. Una sola orden para re-verificar todo.
#
#   1-logica.sh             la lógica del script, con dobles (no toca el escritorio)
#   2-entorno-hyprland.sh   con el PATH real de Hyprland (no toca el escritorio)
#   3-ramas-binario.sh      las tres ramas de resolución, con el binario real
#   4-servidor.sh           el servidor y, sobre todo, la caída al binario si no está
#   5-vivo.sh               el dictado en vivo: parser, estado, modos nuevos, dispositivo y disparador
#   6-servicio.sh           el servicio residente desplegado: habilitado, activo y respondiendo
#   7-modelos.sh            el verificador de modelos y los tres sitios donde está enganchado
#
# Ninguna abre ventanas, reproduce sonido ni pega texto. Ninguna necesita que el receptor DJI esté
# conectado: lo que lo consultaba pasa por un doble, en pruebas/dobles/, que comparten la 1 y la 5.
# La única comprobación que sí lo necesita es la H2 de 5-vivo.sh, y se salta sola cuando no está en
# vez de fallar. La 7 sí necesita red o la caché del manifiesto de modelos. La 5 se salta sola el
# control de qmllint si no está instalado, y la 6 se salta sola si la config no declara servidor.
set -u
D="$(cd "$(dirname "$0")" && pwd)"
total_ok=0; total_mal=0; fallos=()

for s in 1-logica.sh 2-entorno-hyprland.sh 3-ramas-binario.sh 4-servidor.sh 5-vivo.sh 6-servicio.sh 7-modelos.sh; do
    echo "########## $s ##########"
    salida="$(bash "$D/$s" 2>&1)"; rc=$?
    printf '%s\n' "$salida"
    resumen="$(printf '%s\n' "$salida" | grep -o 'RESUMEN: [0-9]* correctos, [0-9]* fallidos' | tail -1)"
    ok="$(printf '%s' "$resumen" | sed -n 's/.*: \([0-9]*\) correctos.*/\1/p')"
    mal="$(printf '%s' "$resumen" | sed -n 's/.*, \([0-9]*\) fallidos.*/\1/p')"
    total_ok=$((total_ok + ${ok:-0}))
    total_mal=$((total_mal + ${mal:-0}))
    [ "$rc" -ne 0 ] && fallos+=("$s")
    echo
done

echo "=========================================="
echo "TOTAL: $total_ok correctos, $total_mal fallidos"
[ "${#fallos[@]}" -gt 0 ] && echo "SUITES CON FALLOS: ${fallos[*]}"
echo "=========================================="
[ "$total_mal" -eq 0 ] && [ "${#fallos[@]}" -eq 0 ]
