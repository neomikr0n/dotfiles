#!/usr/bin/env bash
# Comprueba el dictado en vivo sin tocar el escritorio. Ni ventanas, ni sonido, ni pegado.
#
# Lo que NO se prueba aquí, a propósito: abrir la capa y arrancar el motor contra el micro. Eso
# es perceptible y se verifica a mano. Aquí se prueban las piezas que sí se pueden aislar, que son
# justo las que se rompen en silencio. El parser de la salida de whisper-stream, el fichero de
# estado, los modos nuevos de dictado.sh y la detección del dispositivo.
# El pegado sí se prueba, pero contra los dobles de wl-copy, wl-paste y wtype, que no tocan ni el
# portapapeles ni el teclado de la sesión.
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
S="$DIR/dictado.sh"
PY="$DIR/dictado-vivo.py"
QML="$DIR/dictado-vivo.qml"
PUENTE="$DIR/dictado-vivo.sh"
TECLA="$DIR/dictado-tecla.py"
BIN="$HOME/.local/share/dictado/bin"
WAV="$HOME/.local/share/dictado/corpus/m1-comando.wav"
MODELO="$HOME/.local/share/whisper/actual.bin"

# Doble de pactl, el mismo fichero que usa 1-logica.sh. Va en el PATH y no como funcion porque la
# seccion E pide la fuente con `bash dictado.sh fuente`, que es un proceso hijo, y una funcion de
# shell no cruza esa frontera. Sin el, la seccion E falla en cuanto el receptor DJI no esta
# enchufado, aunque el resto de la suite pase. Medido el 2026-10-11.
DOBLES="$DIR/pruebas/dobles"
export PATH="$DOBLES:$PATH"

ok=0; mal=0
comprobar() { if [ "$2" = "$3" ]; then echo "  OK   $1"; ok=$((ok + 1)); else echo "  MAL  $1"; echo "        esperado [$3]"; echo "        obtenido [$2]"; mal=$((mal + 1)); fi; }
# La comparacion de contenido ignora las mayusculas. Whisper capitaliza el arranque de cada
# segmento, y con el VAD una pausa puede partir la frase en dos, asi que la misma locucion sale
# con minuscula o con mayuscula segun donde caiga el corte. Eso no cambia lo que se dijo.
comprobar_contiene() { case "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" in *"$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"*) echo "  OK   $1"; ok=$((ok + 1));; *) echo "  MAL  $1"; echo "        esperaba que contuviera [$3]"; echo "        obtenido [$2]"; mal=$((mal + 1));; esac; }

echo "=== A. la capa pasa qmllint ==="
if command -v qmllint >/dev/null 2>&1; then
    r="$(qmllint -I /usr/lib/qt6/qml "$QML" 2>&1)"
    comprobar "qmllint no encuentra nada" "$r" ""
else
    echo "  --   qmllint no esta instalado, se salta"
fi

echo
echo "=== B. el parser limpia las secuencias ANSI ==="
r="$(python3 - "$PY" <<'PY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("dv", sys.argv[1])
dv = importlib.util.module_from_spec(spec); spec.loader.exec_module(dv)
print(repr(dv.limpiar("\x1b[2K\r  hola   ")))
print(repr(dv.limpiar("\x1b[2K")))
PY
)"
comprobar "quita el escape y recorta espacios" "$(printf '%s' "$r" | head -1)" "'hola'"
comprobar "una linea de solo escape queda vacia" "$(printf '%s' "$r" | tail -1)" "''"

echo
echo "=== C. el parser se queda con la ultima version de la linea ==="
# whisper-stream reescribe una sola linea con \33[2K\r. Se le mete una secuencia sintetica
# igual a la suya y se comprueba que la hipotesis vigente es la ultima, no la primera.
r="$(python3 - "$PY" <<'PY' 2>&1
import importlib.util, os, sys, threading
spec = importlib.util.spec_from_file_location("dv", sys.argv[1])
dv = importlib.util.module_from_spec(spec); spec.loader.exec_module(dv)

class Espia:
    def __init__(self): self.estado = None; self.texto = None
    def fijar(self, estado=None, texto=None, nivel=None, forzar=False):
        if estado is not None: self.estado = estado
        if texto is not None: self.texto = texto

def bombear_con(datos):
    r, w = os.pipe()
    e = Espia()
    t = threading.Thread(target=dv.bombear, args=(os.fdopen(r, "rb"), e), daemon=True)
    t.start()
    os.write(w, datos)
    os.close(w)
    t.join(5)
    return e

# tres versiones de la misma linea, la ultima es la que vale
e = bombear_con(b"\x1b[2K\rhola\r\x1b[2K\rhola que\r\x1b[2K\rhola que tal\r")
print("estado:" + str(e.estado))
print("texto:" + str(e.texto))

# la cola SIN \r tambien cuenta, es la version en curso
e = bombear_con(b"\x1b[2K\rhola\r\x1b[2K\rhola que")
print("cola:" + str(e.texto))

# la cola CON un escape a medias se ignora, que si no se colaria como texto
e = bombear_con(b"\x1b[2K\rsolo esto\r\x1b[2K")
print("escape:" + str(e.texto))
PY
)"
comprobar "marca el estado transcribiendo" "$(printf '%s\n' "$r" | grep '^estado:' | cut -d: -f2-)" "transcribiendo"
comprobar "se queda con la ultima version" "$(printf '%s\n' "$r" | grep '^texto:' | cut -d: -f2-)" "hola que tal"
comprobar "procesa la cola sin retorno de carro" "$(printf '%s\n' "$r" | grep '^cola:' | cut -d: -f2-)" "hola que"
comprobar "ignora una cola con escape a medias" "$(printf '%s\n' "$r" | grep '^escape:' | cut -d: -f2-)" "solo esto"

echo
echo "=== D. el fichero de estado se escribe entero y con las claves que lee la capa ==="
r="$(python3 - "$PY" <<'PY' 2>&1
import importlib.util, json, os, sys, tempfile
spec = importlib.util.spec_from_file_location("dv", sys.argv[1])
dv = importlib.util.module_from_spec(spec); spec.loader.exec_module(dv)
d = tempfile.mkdtemp()
ruta = os.path.join(d, "estado.json")
e = dv.Estado(ruta)
e.fijar(estado="escuchando", texto="", nivel=0.0, forzar=True)
e.fijar(estado="transcribiendo", texto="una prueba con acentos: cañón", nivel=0.42)
o = json.load(open(ruta, encoding="utf-8"))
print("claves:" + ",".join(sorted(o.keys())))
print("texto:" + o["texto"])
print("nivel:" + str(o["nivel"]))
# y no queda ningun .tmp suelto: el reemplazo es atomico
print("sueltos:" + str(len([f for f in os.listdir(d) if f.endswith(".tmp")])))
PY
)"
comprobar "las cuatro claves" "$(printf '%s\n' "$r" | grep '^claves:' | cut -d: -f2-)" "estado,ms,nivel,texto"
comprobar "respeta los acentos" "$(printf '%s\n' "$r" | grep '^texto:' | cut -d: -f2-)" "una prueba con acentos: cañón"
comprobar "el nivel llega al fichero" "$(printf '%s\n' "$r" | grep '^nivel:' | cut -d: -f2-)" "0.42"
comprobar "no deja ficheros .tmp" "$(printf '%s\n' "$r" | grep '^sueltos:' | cut -d: -f2-)" "0"

echo
echo "=== E. dictado.sh resuelve fuente y modelo para el dictado en vivo ==="
fuente="$(bash "$S" fuente 2>/dev/null)"
case "$fuente" in
*Wireless_Mic*) echo "  OK   encuentra la fuente: ${fuente:0:40}…"; ok=$((ok + 1));;
*) echo "  MAL  fuente inesperada: [$fuente]"; mal=$((mal + 1));;
esac
compobar_modelo="$(bash "$S" modelo 2>/dev/null)"
# No se compara contra una ruta escrita a mano. dictado.sh puede estar leyendo dictado.conf y
# devolver otra. Lo que importa es que devuelva algo y que ese algo exista.
case "$compobar_modelo" in
"$HOME"/*) echo "  OK   el modelo es una ruta absoluta"; ok=$((ok + 1));;
*) echo "  MAL  ruta de modelo rara: [$compobar_modelo]"; mal=$((mal + 1));;
esac
if [ -f "$compobar_modelo" ]; then echo "  OK   y el fichero existe"; ok=$((ok + 1)); else echo "  MAL  el modelo no existe"; mal=$((mal + 1)); fi

echo
echo "=== F. transcribir-fichero saca el texto de un WAV concreto ==="
r="$(bash "$S" transcribir-fichero "$WAV" 2>/dev/null)"
comprobar_contiene "transcribe el corpus" "$r" "transcribe esto"

echo
echo "=== G. transcribir-fichero distingue el fichero que no existe ==="
bash "$S" transcribir-fichero /no/existe.wav >/dev/null 2>&1
comprobar "devuelve 2 si el WAV no existe" "$?" "2"

echo
echo "=== H. el parser de la lista de dispositivos de SDL ==="
# OJO: el nombre de SDL y el de PipeWire no se parecen. Aqui se comprueba el de SDL, que es el
# que usa whisper-stream para abrir el micro.
# Se prueba contra un doble y no contra el binario real, para que no dependa de que el receptor DJI
# este enchufado. Lo que se prueba aqui es el parser, que es la parte que se rompe en silencio si
# cambia el formato de la lista.
r="$(python3 - "$PY" "$DOBLES" <<'PY' 2>&1
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("dv", sys.argv[1])
dv = importlib.util.module_from_spec(spec); spec.loader.exec_module(dv)
b = os.path.join(sys.argv[2], "falso-whisper-stream")
print("indice:" + str(dv.indice_dispositivo(b, "Wireless Mic", dict(os.environ))))
print("sin-casar:" + str(dv.indice_dispositivo(b, "no-existe-jamas", dict(os.environ))))
print("minusculas:" + str(dv.indice_dispositivo(b, "wireless mic", dict(os.environ))))
PY
)"
comprobar "encuentra el indice por patron" "$(printf '%s\n' "$r" | grep '^indice:' | cut -d: -f2-)" "1"
comprobar "no se lo inventa si el patron no casa" "$(printf '%s\n' "$r" | grep '^sin-casar:' | cut -d: -f2-)" "None"
comprobar "el patron no distingue mayusculas" "$(printf '%s\n' "$r" | grep '^minusculas:' | cut -d: -f2-)" "1"

echo
echo "=== H2. el binario real con el receptor enchufado ==="
# Esta si necesita el receptor. Se salta sola si no esta, porque no tenerlo enchufado no es un
# defecto del dictado. La de arriba ya cubre la parte que es codigo.
r="$(python3 - "$PY" "$BIN" <<'PY' 2>&1
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("dv", sys.argv[1])
dv = importlib.util.module_from_spec(spec); spec.loader.exec_module(dv)
ent = dict(os.environ)
ent["LD_LIBRARY_PATH"] = sys.argv[2] + (":" + ent["LD_LIBRARY_PATH"] if ent.get("LD_LIBRARY_PATH") else "")
print("indice:" + str(dv.indice_dispositivo(os.path.join(sys.argv[2], "whisper-stream"), "Wireless Mic", ent)))
PY
)"
case "$(printf '%s\n' "$r" | grep '^indice:')" in
indice:None) echo "  --   el receptor DJI no esta conectado, se salta";;
indice:[0-9]*) echo "  OK   el binario real lo encuentra ($(printf '%s\n' "$r" | grep '^indice:'))"; ok=$((ok + 1));;
*) echo "  MAL  respuesta rara del binario real: [$r]"; mal=$((mal + 1));;
esac

echo
echo "=== I. el puente dice parado con la sesion vacia ==="
# La premisa de esta comprobacion es que no hay motor ni capa. En una sesion donde n30 esta
# dictando de verdad si hay motor, y entonces el puente dice "vivo" con razon. Eso no es un fallo
# del codigo, es la medida de otro estado. Medido el 2026-10-11, una pasada entera de la bateria
# fallo aqui porque habia un dictado en vivo abierto. Para que la comprobacion no dependa de lo
# que haya en la sesion, se le esconde con dos dobles que valen solo para esta orden.
comprobar "estado en reposo" "$(PATH="$DOBLES/sin-sesion:$PATH" DICTADO_VIVO_RUNTIME=/tmp/dv-suite-nada bash "$PUENTE" estado 2>/dev/null)" "parado"

echo
echo "=== J. el puente escribe el estado con el mismo formato que el motor ==="
export DICTADO_VIVO_RUNTIME=/tmp/dv-suite-puente
rm -rf "$DICTADO_VIVO_RUNTIME" 2>/dev/null; mkdir -p "$DICTADO_VIVO_RUNTIME"
# El puente termina en un case que ejecuta la accion, asi que para probar sus funciones hay que
# cargarlo sin ese case. No vale `head -n -2`: el case ocupa mas de dos lineas y quedaria a
# medias. Se corta desde la linea del case hasta el final.
#
# Y el corte NO puede ir a /tmp ni cargarse por sustitucion de proceso. Al cargarlo, el puente
# resuelve sus propias rutas con ${BASH_SOURCE[0]}, que bajo sustitucion de proceso no existe
# (con set -u aborta) o apunta a /dev/fd, con lo que el control de "falta dictado-vivo.qml"
# tumba el guion antes de llegar a la funcion. Por eso el corte se escribe como copia temporal
# DENTRO del directorio del proyecto, donde las rutas si resuelven, y se borra al terminar.
corte="$DIR/.dv-corte-$$.sh"
awk '/^case "\$\{1:-toggle\}" in$/{exit} {print}' "$PUENTE" > "$corte"
cat > /tmp/dv-suite-j.sh <<'FIN'
set -u
source "$DV_CORTE"
escribir_estado listo 'texto de prueba'
python3 - "$DICTADO_VIVO_RUNTIME/estado.json" <<'PY'
import json, sys
o = json.load(open(sys.argv[1], encoding="utf-8"))
print("claves:" + ",".join(sorted(o.keys())))
print("estado:" + o["estado"])
print("texto:" + o["texto"])
PY
FIN
r="$(DV_CORTE="$corte" bash /tmp/dv-suite-j.sh 2>&1)"
rm -f /tmp/dv-suite-j.sh "$corte" 2>/dev/null
comprobar "las cuatro claves" "$(printf '%s\n' "$r" | grep '^claves:' | cut -d: -f2-)" "estado,ms,nivel,texto"
comprobar "el estado pedido" "$(printf '%s\n' "$r" | grep '^estado:' | cut -d: -f2-)" "listo"
comprobar "el texto pedido" "$(printf '%s\n' "$r" | grep '^texto:' | cut -d: -f2-)" "texto de prueba"
rm -rf "$DICTADO_VIVO_RUNTIME" 2>/dev/null

echo
echo "=== K. el toque de Ctrl lanza el dictado en vivo, no el ciego ==="
# El disparador del vivo es el toque de Ctrl izquierdo, que vigila dictado-tecla.py. Si alguien
# devuelve ese script a dictado.sh toggle, la capa deja de abrirse y no falla nada. Solo vuelve el
# modo ciego, que es justo lo que se queria dejar atras. Por eso se comprueba aqui.
orden="$(/usr/bin/python3 "$TECLA" --orden 2>/dev/null)"
case "$orden" in
*dictado-vivo.sh*toggle*) echo "  OK   la orden apunta al vivo"; ok=$((ok + 1));;
*) echo "  MAL  la orden no apunta al vivo: [$orden]"; mal=$((mal + 1));;
esac
# Y que el destino exista de verdad, no solo que la orden lo nombre.
objetivo="${orden% toggle}"
if [ -n "$objetivo" ] && [ -f "$objetivo" ] && [ -x "$objetivo" ]; then
    echo "  OK   el destino existe y es ejecutable"; ok=$((ok + 1))
else
    echo "  MAL  el destino no existe o no es ejecutable: [$objetivo]"; mal=$((mal + 1))
fi

echo
echo "=== L. el puente pega por dictado.sh, no por su cuenta ==="
# El pegado lo hace dictado.sh, que es quien lleva el historial y la devolución del portapapeles.
# Si alguien volviera a copiar aquí el wl-copy con su Ctrl+V, el puente dejaría de apuntar las
# transcripciones al historial y volvería a destruir el portapapeles, y no fallaría nada. Por eso
# se comprueba, y se comprueba ejecutando el pegado de verdad contra los dobles.
comprobar "el puente ya no copia por su cuenta" "$(grep -c 'wl-copy' "$PUENTE")" "0"

export DICTADO_TEST_PORTA=/tmp/dv-suite-porta
export DICTADO_TEST_PEGADOS=/tmp/dv-suite-pegados
export DICTADO_HISTORIAL=/tmp/dv-suite-historial.txt
export DICTADO_CONF=/tmp/dv-suite-conf-que-no-existe
export DICTADO_PORTA_ESPERA=50
rm -f "$DICTADO_TEST_PORTA" "$DICTADO_TEST_PEGADOS" "$DICTADO_HISTORIAL" "$DICTADO_TEST_PORTA.copias"
printf 'lo que había copiado antes' >"$DICTADO_TEST_PORTA"

# Mismo corte que la sección J. El puente termina en un case que ejecuta la acción, así que para
# probar sus funciones hay que cargarlo sin ese case. El corte se escribe dentro del directorio
# del proyecto, donde las rutas del puente sí resuelven.
corte_pegado="$DIR/.dv-corte-pegado-$$.sh"
awk '/^case "\$\{1:-toggle\}" in$/{exit} {print}' "$PUENTE" > "$corte_pegado"
DV_CORTE="$corte_pegado" bash -c 'source "$DV_CORTE"; pegar "texto pegado por el puente"' >/dev/null 2>&1
rm -f "$corte_pegado" 2>/dev/null

comprobar "el puente pega el texto" "$(sed -n '1s/^copia://p' "$DICTADO_TEST_PORTA.copias" 2>/dev/null)" "texto pegado por el puente"
comprobar "y lo apunta al historial" "$(cut -f2- "$DICTADO_HISTORIAL" 2>/dev/null)" "texto pegado por el puente"
comprobar "y manda Ctrl+V una vez" "$([ -f "$DICTADO_TEST_PEGADOS" ] && wc -l <"$DICTADO_TEST_PEGADOS" | tr -d ' ')" "1"
comprobar "y devuelve el portapapeles" "$(cat "$DICTADO_TEST_PORTA" 2>/dev/null)" "lo que había copiado antes"
rm -f "$DICTADO_TEST_PORTA" "$DICTADO_TEST_PEGADOS" "$DICTADO_HISTORIAL" "$DICTADO_TEST_PORTA.copias"

echo
echo "=== M. Escape cancela, y su orden tambien resuelve ==="
# Escape vive en dictado-tecla.py y no en un bind de Hyprland, porque este proceso solo LEE el
# teclado y asi Escape sigue llegando a la aplicacion con el foco. Un bind lo consumiria. La orden
# se comprueba igual que la del toque. Es una ruta que, si se rompe, no falla al cargar sino al
# pulsar, y al pulsar ya no hay dictado que cancelar.
orden_esc="$(/usr/bin/python3 "$TECLA" --orden-escape 2>/dev/null)"
case "$orden_esc" in
*dictado-vivo.sh*cancelar*) echo "  OK   la orden de Escape apunta a cancelar"; ok=$((ok + 1));;
*) echo "  MAL  la orden de Escape no cancela: [$orden_esc]"; mal=$((mal + 1));;
esac
objetivo_esc="${orden_esc% cancelar}"
if [ -n "$objetivo_esc" ] && [ -f "$objetivo_esc" ] && [ -x "$objetivo_esc" ]; then
    echo "  OK   el destino existe y es ejecutable"; ok=$((ok + 1))
else
    echo "  MAL  el destino no existe o no es ejecutable: [$objetivo_esc]"; mal=$((mal + 1))
fi

# El puente cubre tambien el camino ciego, que es otro proceso, para que un solo Escape valga con
# independencia de cual de los dos este grabando.
comprobar "el puente cancela tambien el dictado ciego" "$(grep -cF 'bash "$DICTADO" cancelar' "$PUENTE")" "1"

# Con nada en marcha tiene que salir callado y con cero. El vigilante la llama en CADA Escape del
# sistema, asi que un aviso aqui seria una notificacion por cada dialogo que se cierra en cualquier
# aplicacion. El runtime de la parte ciega se apunta a un directorio vacio para que esa parte no
# toque la sesion de verdad.
corte_cancelar="$DIR/.dv-corte-cancelar-$$.sh"
awk '/^case "\$\{1:-toggle\}" in$/{exit} {print}' "$PUENTE" > "$corte_cancelar"
mkdir -p /tmp/dv-suite-ciego-vacio
salida="$(DICTADO_RUNTIME=/tmp/dv-suite-ciego-vacio DV_CORTE="$corte_cancelar" bash -c '
    source "$DV_CORTE"
    pids_motor() { :; }
    pids_capa() { :; }
    hay_motor() { return 1; }
    notificar() { printf "AVISO:%s\n" "$2"; }
    cancelar
' 2>&1)"; rc=$?
rm -f "$corte_cancelar" 2>/dev/null
comprobar "cancelar sin nada en marcha devuelve 0" "$rc" "0"
comprobar "y no avisa de nada" "$salida" ""

echo
echo "RESUMEN: $ok correctos, $mal fallidos"
[ "$mal" -eq 0 ]
