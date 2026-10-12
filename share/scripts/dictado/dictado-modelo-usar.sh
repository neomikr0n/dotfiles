#!/usr/bin/env bash
# Instala un modelo de whisper como el activo, con dos guardias que antes no había.
#
#   dictado-modelo-usar.sh ~/.local/share/whisper/candidatos/ggml-large-v3-turbo.bin
#   dictado-modelo-usar.sh --listar
#
# Guardia 1. El fichero existe y es legible. La lección 11 del registro fue justo esta, un enlace
# creado a un fichero que no estaba, roto en silencio hasta el dictado siguiente.
# Guardia 2. El sha256 coincide con el oficial. La lección 3 fue un modelo corrupto por dentro
# con el tamaño exacto del bueno. Aquí se comprueba antes de que llegue a dictar nada.
#
# Si el veredicto no es OK, no enlaza. Un CORRUPTO no se enlaza ni con --forzar. Un fichero que
# no se puede confirmar, sea no oficial o sin red y sin caché, sí, pero solo con --forzar.
#
# Al terminar reinicia el servicio del servidor si estaba corriendo y el activo cambió, para que
# cargue el modelo nuevo. Ese reinicio deja el servidor caído un par de segundos, y en ese hueco
# dictado.sh cae al binario sin avisar. No abre ventanas ni reproduce sonido.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
VERIF="$DIR/dictado-modelos-verificar.py"
WHISPER_DIR="$HOME/.local/share/whisper"
ACTUAL="$WHISPER_DIR/actual.bin"
UNIDAD="dictado-servidor.service"

forzar=0
case "${1:-}" in
--listar)
    echo "Candidatos en $WHISPER_DIR/candidatos"
    ls -1 "$WHISPER_DIR"/candidatos/*.bin 2>/dev/null || echo "  (ninguno)"
    echo
    echo "Activo ahora: $(readlink -f "$ACTUAL" 2>/dev/null || echo '(enlace roto o ausente)')"
    exit 0
    ;;
--forzar) forzar=1; shift ;;
"") echo "uso: $(basename "$0") RUTA_DEL_MODELO [--forzar] | --listar" >&2; exit 2 ;;
esac

objetivo="${1:-}"
if [ -z "$objetivo" ]; then echo "falta la ruta del modelo" >&2; exit 2; fi

# --- Guardia 1. Que el fichero esté de verdad ahí ---
if [ ! -f "$objetivo" ]; then
    echo "no existe el fichero: $objetivo" >&2
    echo "si iba a candidatos/, revisa el nombre. Los modelos viven un nivel por debajo de whisper/." >&2
    exit 1
fi
if [ ! -r "$objetivo" ]; then
    echo "no se puede leer: $objetivo" >&2
    exit 1
fi
objetivo="$(readlink -f "$objetivo")"

# --- Guardia 2. Que el contenido sea el oficial ---
echo "Verificando $objetivo"
json="$(mktemp)"
python3 "$VERIF" --dir "$(dirname "$objetivo")" --json "$json" >/dev/null 2>&1
veredicto="$(python3 - "$json" "$objetivo" <<'PY'
import json, os, sys
try:
    filas = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print("SIN DATOS"); raise SystemExit
obj = os.path.realpath(sys.argv[2])
for f in filas:
    if os.path.realpath(f["fichero"]) == obj:
        print(f["veredicto"]); break
else:
    print("SIN DATOS")
PY
)"
rm -f "$json"
echo "veredicto: $veredicto"

case "$veredicto" in
OK) ;;
CORRUPTO)
    echo "RECHAZADO. El nombre es el oficial pero el contenido no. Un corrupto no se arregla, se" >&2
    echo "vuelve a bajar. No enlazo, y esto no se salta ni con --forzar." >&2
    exit 1
    ;;
*)
    if [ "$forzar" != 1 ]; then
        echo "No puedo confirmar que este fichero sea el oficial ($veredicto). No enlazo." >&2
        echo "Si aun así quieres usarlo, repite con --forzar." >&2
        exit 1
    fi
    echo "aviso: veredicto $veredicto, se enlaza por --forzar"
    ;;
esac

# --- Enlazar y, si hace falta, reiniciar el servidor ---
antes="$(readlink -f "$ACTUAL" 2>/dev/null || true)"
ln -sfn "$objetivo" "$ACTUAL"
echo "activo: $ACTUAL -> $objetivo"

if [ "$antes" = "$objetivo" ]; then
    echo "ya era el activo, no toco el servicio"
    exit 0
fi

if systemctl --user is-active --quiet "$UNIDAD"; then
    conf="${DICTADO_CONF:-$HOME/.config/dictado.conf}"
    url=""
    if [ -r "$conf" ]; then
        # shellcheck source=/dev/null
        . "$conf"
        url="${DICTADO_SERVIDOR:-}"
    fi
    echo "reiniciando $UNIDAD para que cargue el modelo nuevo"
    systemctl --user restart "$UNIDAD"
    if [ -n "$url" ]; then
        listo=0
        for _ in $(seq 1 40); do
            if curl -s -o /dev/null --max-time 1 "${url}/" 2>/dev/null; then listo=1; break; fi
            sleep 0.5
        done
        if [ "$listo" = 1 ]; then
            echo "el servidor responde ya en $url"
        else
            echo "aviso: el servidor no responde todavía en $url. Mira: systemctl --user status $UNIDAD" >&2
        fi
    fi
else
    echo "el servicio $UNIDAD no estaba corriendo, no lo arranco"
fi
