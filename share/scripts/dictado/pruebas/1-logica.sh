#!/usr/bin/env bash
# Banco de pruebas de dictado.sh: carga el script SIN ejecutar su main y sustituye
# todo lo que actúa sobre el escritorio (pw-record, wl-copy, wl-paste, wtype, whisper-cli).
set -u
S="$(cd "$(dirname "$0")/.." && pwd)/dictado.sh"

ultima="$(tail -n 1 "$S")"
if [ "$ultima" != 'main "$@"' ]; then echo "ABORTO: la última línea no es main"; exit 1; fi

# RUNTIME propio para no tocar el de la sesión viva.
# NO se toca XDG_RUNTIME_DIR: de ahí saca pactl el socket de PipeWire y sin él no responde.
export DICTADO_RUNTIME=/tmp/dictado-test
rm -rf "$DICTADO_RUNTIME"; mkdir -p "$DICTADO_RUNTIME"

# El portapapeles y el historial van a parar aquí por el mismo motivo. El portapapeles de la
# sesión lo vigilan cliphist y CopyQ. Una prueba que escribiera en él les metería basura en el
# historial, y una que lo leyera daría un resultado distinto en cada pasada, porque depende de lo
# que el usuario tuviera copiado en ese momento. Los dobles de wl-copy, wl-paste y wtype viven en
# dobles/ y llegan por el PATH, que es lo único que cruza a un proceso hijo.
export DICTADO_TEST_PORTA="$DICTADO_RUNTIME/portapapeles.txt"
export DICTADO_TEST_PEGADOS="$DICTADO_RUNTIME/pegados.txt"
export DICTADO_HISTORIAL="$DICTADO_RUNTIME/historial.txt"
# El historial se recorta por el final, y con treinta entradas el recorte no se probaría nunca.
# Aquí se baja a tres y se prueba de verdad. Se puede bajar porque el script lee la variable en
# cada llamada y no al cargarse.
export DICTADO_HISTORIAL_TOPE=3
# La espera antes de devolver el portapapeles es de 800 ms en producción. Aquí se baja a 50 para
# que la batería no se pase medio minuto esperando. Lo que se prueba es el orden de las
# operaciones, no el valor, que es un margen y no una medida.
export DICTADO_PORTA_ESPERA=50

# La config del usuario queda fuera a proposito. Medido el 2026-10-10, al habilitar el servidor
# residente: esta suite sustituye whisper-cli por un stub que escribe siempre la misma frase, pero
# no sustituye la ruta del servidor. Con DICTADO_SERVIDOR en la config y el servicio vivo,
# transcribir() elegia el servidor, mandaba el WAV de prueba al servidor de verdad y el stub no
# llegaba a correr: dos pruebas fallaban con la transcripcion real del jfk.wav. Apuntando la config
# a un fichero que no existe, SERVIDOR queda vacio, manda el stub y cada prueba controla su caso.
# La ruta del servidor tiene su propia suite (4-servidor.sh).
export DICTADO_CONF="$DICTADO_RUNTIME/conf-que-no-existe"

# El silencio de prueba se fabrica aquí y no se lee de /tmp. Medido el 2026-10-10: la suite
# apuntaba a /tmp/dictado-prueba.wav, que no sobrevive a un reinicio, y la guardia de silencio
# daba un fallo falso (sobre un fichero inexistente es_silencio devuelve 1, no 0).
SILENCIO_WAV="$DICTADO_RUNTIME/silencio.wav"
if command -v sox >/dev/null 2>&1; then
    sox -n -r 16000 -c 1 "$SILENCIO_WAV" trim 0 1.0 2>/dev/null
fi

# shellcheck disable=SC1090
source <(head -n -1 "$S")

# ---- stubs de lo que actúa de verdad ----
# Los stubs corren en subshells (uno en background, otro al otro lado de una tubería), así que
# el estado se lleva en FICHEROS, porque una variable puesta en un subshell no vuelve al padre.
AVISOS=()
notificar() { AVISOS+=("$1 | $2"); }
WAV_SIMULADO=""
setsid() { "$@"; } # deja pasar al stub de pw-record
pgrep() { [ -f "$DICTADO_RUNTIME/grabando.marca" ]; }
pkill() { rm -f "$DICTADO_RUNTIME/grabando.marca"; }
# Doble de pactl. La suite no debe depender de que el receptor DJI este enchufado. Sin micro real,
# fuente() devolvia vacio, arrancar() se negaba a empezar y caian en cadena las secciones C, D y F.
# El doble es un fichero ejecutable y no una funcion de shell porque la seccion E de 5-vivo.sh pide
# la fuente con `bash dictado.sh fuente`, que es un proceso hijo, y hasta ahi no llega una funcion.
# Se antepone su carpeta al PATH para que lo encuentren igual este shell y sus hijos.
export PATH="$(cd "$(dirname "$0")" && pwd)/dobles:$PATH"
pw-record() {
    touch "$DICTADO_RUNTIME/grabando.marca"
    echo x >>"$DICTADO_RUNTIME/grabaciones.txt"
    [ -n "$WAV_SIMULADO" ] && cp "$WAV_SIMULADO" "$WAV"
    sleep 5
}
whisper-cli() { printf 'texto de prueba con acentos: ñ á é\n' >"${SALIDA}.txt"; }
# El `[ -f ]` va delante a proposito. Con `wc -l <fichero 2>/dev/null`, si el fichero no existe
# falla la propia redireccion y el shell escribe el error en su stderr ANTES de aplicar el
# 2>/dev/null, asi que el mensaje se colaba en la salida de la suite (visto el 2026-10-10 en la
# prueba F, que borra pegados.txt a mano). Sin fichero no se imprime NADA, que es lo que esperan
# las pruebas: la F cuenta "no pegó nada" como cadena vacia, no como un cero.
grabaciones() { [ -f "$DICTADO_RUNTIME/grabaciones.txt" ] && wc -l <"$DICTADO_RUNTIME/grabaciones.txt" | tr -d ' '; }
pegados() { [ -f "$DICTADO_TEST_PEGADOS" ] && wc -l <"$DICTADO_TEST_PEGADOS" | tr -d ' '; }
# Cada escritura en el portapapeles queda anotada por el doble de wl-copy, así que se puede
# comprobar el ORDEN de las operaciones y no solo el estado final. La primera línea es el texto
# dictado y la última la devolución de lo que hubiera antes.
copias() { [ -f "$DICTADO_TEST_PORTA.copias" ] && sed -n 's/^copia://p' "$DICTADO_TEST_PORTA.copias"; }

ok=0; mal=0
comprobar() { if [ "$2" = "$3" ]; then echo "  OK   $1"; ok=$((ok + 1)); else echo "  MAL  $1 (esperado [$3], obtenido [$2])"; mal=$((mal + 1)); fi; }

echo "--- A. resolución de la fuente ---"
f="$(fuente)"
echo "  fuente() -> $f"
case "$f" in *Wireless_Mic_Rx*) echo "  OK   resuelve el DJI por patrón"; ok=$((ok + 1));; *) echo "  MAL  no resolvió el DJI"; mal=$((mal + 1));; esac

echo "--- B. guardia de silencio ---"
es_silencio "$SILENCIO_WAV"; comprobar "silencio real se detecta" "$?" "0"
es_silencio /home/n30/Documentos/investigacion-dictado/prueba/jfk.wav; comprobar "voz real NO se descarta" "$?" "1"

echo "--- C. arrancar dos veces no duplica la grabación ---"
WAV_SIMULADO=/home/n30/Documentos/investigacion-dictado/prueba/jfk.wav
arrancar >/dev/null 2>&1
comprobar "grabando tras arrancar" "$(grabando && echo si || echo no)" "si"
arrancar >/dev/null 2>&1
comprobar "no relanza pw-record" "$(grabaciones)" "1"
comprobar "avisa de que ya grababa" "${AVISOS[1]%% |*}" "audio-input-microphone"

echo "--- D. parar transcribe, pega UNA vez y devuelve el portapapeles ---"
# Antes de dictar hay algo copiado. Es justo lo que la mejora 7 dice que no se debe destruir.
rm -f "$DICTADO_HISTORIAL" "$DICTADO_TEST_PORTA.copias"
printf 'lo que había copiado antes' >"$DICTADO_TEST_PORTA"
AVISOS=()
parar >/dev/null 2>&1; rc=$?
comprobar "parar devuelve 0" "$rc" "0"
comprobar "Ctrl+V enviado una sola vez" "$(pegados)" "1"
comprobar "el texto dictado llegó al portapapeles" "$(copias | head -1)" "texto de prueba con acentos: ñ á é"
comprobar "y el portapapeles acaba como estaba" "$(cat "$DICTADO_TEST_PORTA" 2>/dev/null)" "lo que había copiado antes"
comprobar "texto guardado en ultimo.txt" "$(cat "$TXT" 2>/dev/null)" "texto de prueba con acentos: ñ á é"
comprobar "la transcripción queda en el historial" "$(historial_texto 1)" "texto de prueba con acentos: ñ á é"
comprobar "deja de estar grabando" "$(grabando && echo si || echo no)" "no"
echo "  aviso final: ${AVISOS[0]:-<ninguno>}"

echo "--- E. parar sin estar grabando ---"
AVISOS=(); parar >/dev/null 2>&1
comprobar "avisa y no falla" "$?" "0"
comprobar "mensaje correcto" "${AVISOS[0]%% |*}" "dialog-warning"

echo "--- F. silencio: no llama a whisper ni pega ---"
WAV_SIMULADO="$SILENCIO_WAV"
rm -f "$DICTADO_TEST_PEGADOS"
arrancar >/dev/null 2>&1
AVISOS=()
parar >/dev/null 2>&1; rc=$?
comprobar "devuelve error" "$rc" "1"
comprobar "no pegó nada" "$(pegados)" ""
echo "  aviso: ${AVISOS[0]:-<ninguno>}"

echo "--- G. uso incorrecto ---"
main basura >/dev/null 2>&1; comprobar "rc=2 con argumento inválido" "$?" "2"
main estado >/dev/null 2>&1; comprobar "estado no falla" "$?" "0"

echo "--- H. el historial guarda, recorta y devuelve el texto ---"
rm -f "$DICTADO_HISTORIAL"
historial_apuntar 'la primera'
comprobar "una línea por dictado" "$(wc -l <"$DICTADO_HISTORIAL" | tr -d ' ')" "1"
comprobar "con la fecha delante" "$(cut -f1 "$DICTADO_HISTORIAL" | grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$')" "1"
comprobar "devuelve el texto de la última" "$(historial_texto 1)" "la primera"
historial_apuntar 'la segunda'
comprobar "la segunda pasa a ser la última" "$(historial_texto 1)" "la segunda"
comprobar "y la primera queda como la anterior" "$(historial_texto 2)" "la primera"
comprobar "listar saca las dos" "$(historial_listar 10 | wc -l | tr -d ' ')" "2"
comprobar "de la más vieja a la más nueva" "$(historial_listar 10 | sed -n 's/^[0-9-]* [0-9:]*  //p' | tr '\n' '|')" "la primera|la segunda|"
# Un salto de línea partiría la entrada en dos, así que el texto se aplana antes de guardarlo.
historial_apuntar "$(printf 'con salto\ny tabulador\t')"
comprobar "el texto se aplana a una línea" "$(wc -l <"$DICTADO_HISTORIAL" | tr -d ' ')" "3"
comprobar "sin salto ni tabulador dentro" "$(historial_texto 1)" "con salto y tabulador"
# El tope está en tres, así que la cuarta entrada empuja a la primera fuera.
historial_apuntar 'la cuarta'
comprobar "el tope recorta por el principio" "$(wc -l <"$DICTADO_HISTORIAL" | tr -d ' ')" "3"
comprobar "y la primera ya no está" "$(historial_texto 3)" "la segunda"
comprobar "pedir una que no existe no devuelve nada" "$(historial_texto 99)" ""

echo "--- I. repegar vuelve a pegar sin duplicar la entrada ---"
rm -f "$DICTADO_HISTORIAL" "$DICTADO_TEST_PEGADOS" "$DICTADO_TEST_PORTA.copias"
historial_apuntar 'la penúltima'
historial_apuntar 'la última de verdad'
printf 'lo que había antes' >"$DICTADO_TEST_PORTA"
main repegar >/dev/null 2>&1
comprobar "repega la última, no la anterior" "$(copias | head -1)" "la última de verdad"
comprobar "manda Ctrl+V otra vez" "$(pegados)" "1"
comprobar "el historial no crece" "$(wc -l <"$DICTADO_HISTORIAL" | tr -d ' ')" "2"
comprobar "y el portapapeles se devuelve igual" "$(cat "$DICTADO_TEST_PORTA")" "lo que había antes"
main repegar 2 >/dev/null 2>&1
comprobar "con N=2 repega la anterior" "$(copias | sed -n '3p')" "la penúltima"

echo "--- J. repegar sin historial avisa y no pega ---"
rm -f "$DICTADO_HISTORIAL" "$DICTADO_TEST_PEGADOS"
AVISOS=()
main repegar >/dev/null 2>&1; rc=$?
comprobar "devuelve error" "$rc" "1"
comprobar "no manda ninguna tecla" "$(pegados)" ""
comprobar "avisa de que está vacío" "${AVISOS[0]%% |*}" "dialog-warning"

echo "--- K. el portapapeles solo se devuelve cuando se puede ---"
rm -f "$DICTADO_TEST_PORTA" "$DICTADO_TEST_PEGADOS"
printf 'dictado sin nada copiado antes' | bash "$S" pegar >/dev/null 2>&1
comprobar "sin nada copiado, el texto se queda" "$(cat "$DICTADO_TEST_PORTA" 2>/dev/null)" "dictado sin nada copiado antes"
printf 'una imagen' >"$DICTADO_TEST_PORTA"
DICTADO_TEST_TIPOS='image/png' bash "$S" pegar <<<"dictado con una imagen copiada" >/dev/null 2>&1
comprobar "con una imagen copiada, no se devuelve" "$(cat "$DICTADO_TEST_PORTA" 2>/dev/null)" "dictado con una imagen copiada"
printf 'lo de antes' >"$DICTADO_TEST_PORTA"
DICTADO_PORTA_RESTAURAR=0 bash "$S" pegar <<<"dictado con la devolución apagada" >/dev/null 2>&1
comprobar "con la devolución apagada, el texto se queda" "$(cat "$DICTADO_TEST_PORTA" 2>/dev/null)" "dictado con la devolución apagada"

echo "--- L. cancelar tira la grabación sin transcribir ni pegar ---"
# Cancelar es lo contrario de parar. Lo hablado se descarta. Se comprueba que no queda rastro en
# ninguno de los tres sitios por los que parar sí deja rastro (portapapeles, teclado e historial).
WAV_SIMULADO=/home/n30/Documentos/investigacion-dictado/prueba/jfk.wav
rm -f "$DICTADO_TEST_PEGADOS" "$DICTADO_TEST_PORTA.copias" "$DICTADO_HISTORIAL"
printf 'lo que había copiado antes' >"$DICTADO_TEST_PORTA"
arrancar >/dev/null 2>&1
comprobar "grabando antes de cancelar" "$(grabando && echo si || echo no)" "si"
# El aviso de arrancar se descarta antes de cancelar, para que AVISOS[0] sea el de la cancelación.
AVISOS=()
cancelar >/dev/null 2>&1; rc=$?
comprobar "cancelar devuelve 0" "$rc" "0"
comprobar "deja de estar grabando" "$(grabando && echo si || echo no)" "no"
comprobar "no manda ningún Ctrl+V" "$(pegados)" ""
comprobar "no escribe en el portapapeles" "$(copias)" ""
comprobar "no deja WAV" "$([ -e "$WAV" ] && echo si || echo no)" "no"
comprobar "y el portapapeles no se toca" "$(cat "$DICTADO_TEST_PORTA" 2>/dev/null)" "lo que había copiado antes"
comprobar "el historial no crece" "$(historial_texto 1)" ""
comprobar "avisa de la cancelación" "${AVISOS[0]#* | }" "Dictado cancelado"

echo "--- M. cancelar sin estar grabando sale callado ---"
# El vigilante de teclado llama a cancelar en CADA Escape, así que cuando no hay nada grabando no
# puede avisar. Si avisara, cada Escape del sistema daría una notificación.
AVISOS=()
cancelar >/dev/null 2>&1; rc=$?
comprobar "devuelve 0" "$rc" "0"
comprobar "no avisa de nada" "${#AVISOS[@]}" "0"

echo
echo "RESUMEN: $ok correctos, $mal fallidos"
[ "$mal" -eq 0 ]
