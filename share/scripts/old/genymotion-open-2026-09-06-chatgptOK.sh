#!/usr/bin/env bash

# ============================================================
# GENYMOTION + HYPRLAND + GPS + JURASSIC WORLD ALIVE
# ============================================================

set -u

# ------------------------------------------------------------
# CONFIGURACIÓN
# ------------------------------------------------------------

GENY_PATH="/opt/genymotion"

PLAYER="$GENY_PATH/player"

# Genymotion actual documenta "genymotion-shell".
# Algunas instalaciones antiguas usan "genyshell".
if [[ -x "$GENY_PATH/genymotion-shell" ]]; then
    GENYSHELL="$GENY_PATH/genymotion-shell"
else
    GENYSHELL="$GENY_PATH/genyshell"
fi

VM_NAME="Google Pixel 6"

# ------------------------------------------------------------
# Ventana Hyprland
# ------------------------------------------------------------

GENY_CLASS="Genymotion Player"
GENY_TITLE_PREFIX="Google Pixel 6 ("

# Ancho exacto deseado del tile
GENY_WIDTH=767

# ------------------------------------------------------------
# ADB
# ------------------------------------------------------------

ADB_HOST="127.0.0.1"
ADB_PORT="6555"
ADB_SERIAL="${ADB_HOST}:${ADB_PORT}"

# ------------------------------------------------------------
# Jurassic World Alive
# ------------------------------------------------------------

JWA_PACKAGE="com.ludia.jw2"

# ------------------------------------------------------------
# GPS - Morelia
# ------------------------------------------------------------

LAT="19.73663978"
LONG="-101.11478609"
ALT="15.04444408"

GPS_ACCURACY="5"

GPS_RETRIES=5

# Diferencia máxima aceptada entre coordenada solicitada y devuelta
GPS_TOLERANCE="0.0001"

# ------------------------------------------------------------
# Timeouts
# ------------------------------------------------------------

WINDOW_TIMEOUT_SECONDS=30
ADB_TIMEOUT_SECONDS=60
BOOT_TIMEOUT_SECONDS=90
GENYSHELL_TIMEOUT_SECONDS=30

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

LOG="/tmp/genymotion-jwa.log"


# ============================================================
# LOG
# ============================================================

exec > >(tee -a "$LOG") 2>&1

echo
echo "============================================================"
echo " Genymotion / Hyprland / GPS / JWA"
echo " $(date)"
echo "============================================================"
echo


# ============================================================
# FUNCIONES BÁSICAS
# ============================================================

die() {
    echo
    echo "❌ ERROR: $*" >&2
    echo "📄 Log: $LOG"
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}


# ============================================================
# COMPROBAR DEPENDENCIAS
# ============================================================

check_dependencies() {

    [[ -x "$PLAYER" ]] ||
        die "No existe o no es ejecutable: $PLAYER"

    [[ -x "$GENYSHELL" ]] ||
        die "No encuentro Genymotion Shell en $GENY_PATH"

    have adb ||
        die "No encuentro adb"

    have jq ||
        die "No encuentro jq"

    if ! have hyprctl; then
        echo "⚠️ hyprctl no disponible."
        echo "   Se omitirá el ajuste automático de ventana."
    fi

    echo "✅ Dependencias verificadas."
    echo "   Player: $PLAYER"
    echo "   Shell : $GENYSHELL"
}


# ============================================================
# HYPRLAND - BUSCAR PIXEL
# ============================================================

find_pixel_window() {

    have hyprctl || return 1

    hyprctl clients -j 2>/dev/null |
        jq -r \
            --arg cls "$GENY_CLASS" \
            --arg prefix "$GENY_TITLE_PREFIX" '
                .[]
                | select(
                    .class == $cls
                    and
                    (.title | startswith($prefix))
                )
                | .address
            ' |
        head -n 1
}


# ============================================================
# HYPRLAND - ESPERAR PIXEL
#
# IMPORTANTE:
# Todos los mensajes van a stderr.
# stdout contiene EXCLUSIVAMENTE la address.
# ============================================================

wait_for_pixel_window() {

    have hyprctl || return 1

    local address=""
    local iterations

    iterations=$((WINDOW_TIMEOUT_SECONDS * 5))

    echo "🪟 Esperando ventana principal de Genymotion..." >&2

    for ((i=1; i<=iterations; i++)); do

        address="$(find_pixel_window || true)"

        if [[ -n "$address" && "$address" != "null" ]]; then

            echo "✅ Ventana encontrada: $address" >&2

            printf '%s\n' "$address"
            return 0
        fi

        sleep 0.2
    done

    echo "⚠️ Timeout esperando ventana." >&2
    return 1
}


# ============================================================
# HYPRLAND - RESIZE TILE
# ============================================================

resize_pixel_window() {

    local address="$1"
    local height
    local result
    local final_width
    local final_height
    local floating

    have hyprctl || return 0

    echo
    echo "📐 Ajustando tile de Genymotion..."

    # Dar tiempo a Dwindle para finalizar el reparto inicial
    sleep 1

    height="$(
        hyprctl clients -j 2>/dev/null |
            jq -r \
                --arg addr "$address" '
                    .[]
                    | select(.address == $addr)
                    | .size[1]
                '
    )"

    if ! [[ "$height" =~ ^[0-9]+$ ]]; then
        echo "⚠️ No pude determinar la altura del tile."
        return 1
    fi

    echo "   Objetivo: ${GENY_WIDTH}x${height}"

    result="$(
        hyprctl dispatch resizewindowpixel \
            "exact ${GENY_WIDTH} ${height},address:${address}" \
            2>&1
    )"

    echo "   hyprctl: $result"

    sleep 0.5

    read -r final_width final_height floating < <(
        hyprctl clients -j |
            jq -r \
                --arg addr "$address" '
                    .[]
                    | select(.address == $addr)
                    | "\(.size[0]) \(.size[1]) \(.floating)"
                '
    )

    echo "   Resultado: ${final_width}x${final_height}"
    echo "   Floating: $floating"

    if [[ "$final_width" == "$GENY_WIDTH" ]]; then
        echo "✅ Ancho confirmado en ${GENY_WIDTH}px."
    else
        echo "⚠️ Hyprland dejó el ancho en ${final_width}px."
    fi
}


# ============================================================
# ARRANCAR GENYMOTION
# ============================================================

start_genymotion() {

    local address

    address="$(find_pixel_window || true)"

    if [[ -n "$address" && "$address" != "null" ]]; then
        echo "✅ El Pixel 6 ya está abierto."
        return 0
    fi

    echo "🚀 Iniciando $VM_NAME..."

    "$PLAYER" --vm-name "$VM_NAME" >>"$LOG" 2>&1 &

    echo "   Launcher PID: $!"

    # NO usamos pgrep player como condición.
    # Esperaremos a la ventana y a ADB.
    return 0
}


# ============================================================
# ADB - ESPERAR DISPOSITIVO
# ============================================================

wait_for_adb() {

    local iterations

    iterations=$((ADB_TIMEOUT_SECONDS / 2))

    echo
    echo "📡 Esperando ADB en $ADB_SERIAL..."

    for ((i=1; i<=iterations; i++)); do

        adb connect "$ADB_SERIAL" >/dev/null 2>&1 || true

        if adb devices |
            awk -v target="$ADB_SERIAL" '
                $1 == target && $2 == "device" {
                    found=1
                }
                END {
                    exit !found
                }
            '
        then
            echo "✅ ADB conectado: $ADB_SERIAL"
            return 0
        fi

        echo "   ADB: $((i * 2))/${ADB_TIMEOUT_SECONDS}s"
        sleep 2
    done

    return 1
}


# ============================================================
# ANDROID - ESPERAR BOOT COMPLETO
# ============================================================

wait_for_android_boot() {

    local boot_completed=""

    echo
    echo "🤖 Esperando arranque completo de Android..."

    for ((i=1; i<=BOOT_TIMEOUT_SECONDS; i++)); do

        boot_completed="$(
            adb -s "$ADB_SERIAL" \
                shell getprop sys.boot_completed \
                2>/dev/null |
                tr -d '\r\n'
        )"

        if [[ "$boot_completed" == "1" ]]; then
            echo "✅ Android completamente iniciado."

            # Servicios Android terminan de estabilizarse
            sleep 2

            return 0
        fi

        if (( i % 5 == 0 )); then
            echo "   Android boot: ${i}/${BOOT_TIMEOUT_SECONDS}s"
        fi

        sleep 1
    done

    return 1
}


# ============================================================
# GENYMOTION SHELL
# ============================================================

geny_cmd() {

    "$GENYSHELL" -q -c "$1" 2>&1
}


# ============================================================
# ESPERAR QUE GENYMOTION SHELL VEA LA VM
# ============================================================

wait_for_genyshell() {

    local output

    echo
    echo "🛰️ Esperando interfaz de sensores Genymotion..."

    for ((i=1; i<=GENYSHELL_TIMEOUT_SECONDS; i++)); do

        output="$(geny_cmd "gps getstatus" || true)"

        if ! grep -qi \
            "No Genymotion virtual device running found" \
            <<< "$output" &&
           ! grep -qi \
            "Command not found" \
            <<< "$output" &&
           [[ -n "$output" ]]
        then
            echo "✅ Genymotion Shell conectado al dispositivo."
            echo "   $output"
            return 0
        fi

        if (( i % 5 == 0 )); then
            echo "   Sensores: ${i}/${GENYSHELL_TIMEOUT_SECONDS}s"
        fi

        sleep 1
    done

    echo "❌ Genymotion Shell no detectó una VM activa."
    return 1
}


# ============================================================
# RESOLUCIÓN ANDROID
# ============================================================

configure_display() {

    echo
    echo "🖥️ Ajustando resolución Android..."

    adb -s "$ADB_SERIAL" shell wm size 1080x2160
    adb -s "$ADB_SERIAL" shell wm density 320

    echo "✅ Resolución configurada."
}


# ============================================================
# AJUSTES GRÁFICOS
# ============================================================

configure_gpu() {

    echo
    echo "🚀 Aplicando ajustes gráficos..."

    adb -s "$ADB_SERIAL" shell su root \
        "setprop threaded 1" \
        >/dev/null 2>&1 || true

    adb -s "$ADB_SERIAL" shell su root \
        "setprop persist.sys.ui.hw true" \
        >/dev/null 2>&1 || true

    adb -s "$ADB_SERIAL" shell su root \
        "setprop debug.hwui.renderer opengl" \
        >/dev/null 2>&1 || true

    echo "✅ Ajustes gráficos enviados."
}


# ============================================================
# GPS - EXTRAER NÚMERO DE RESPUESTA
# ============================================================

extract_number() {

    grep -Eo -- '[-+]?[0-9]+([.][0-9]+)?' |
        tail -n 1
}


# ============================================================
# GPS - COMPARACIÓN NUMÉRICA CON TOLERANCIA
# ============================================================

number_close() {

    local actual="$1"
    local expected="$2"
    local tolerance="$3"

    awk \
        -v a="$actual" \
        -v b="$expected" \
        -v t="$tolerance" '
            BEGIN {
                d = a - b
                if (d < 0)
                    d = -d

                exit !(d <= t)
            }
        '
}


# ============================================================
# GPS - CONFIGURACIÓN ROBUSTA
# ============================================================

set_gps() {

    local attempt

    local status_output
    local lat_output
    local lon_output
    local alt_output

    local current_lat
    local current_lon
    local current_alt

    echo
    echo "📍 Configurando GPS..."
    echo "   Latitud : $LAT"
    echo "   Longitud: $LONG"
    echo "   Altitud : $ALT"
    echo "   Accuracy: ${GPS_ACCURACY}m"

    for ((attempt=1; attempt<=GPS_RETRIES; attempt++)); do

        echo
        echo "📡 Intento GPS $attempt/$GPS_RETRIES..."

        # ----------------------------------------------------
        # Cada comando se ejecuta POR SEPARADO.
        #
        # No usamos:
        # device select ...; gps ...
        #
        # porque -c ejecuta un comando y el dispositivo
        # activo ya es seleccionado por Genymotion.
        # ----------------------------------------------------

        echo "   Activando GPS..."

        geny_cmd "gps setstatus enabled" >/dev/null || true

        sleep 0.5

        geny_cmd "gps setlatitude $LAT" >/dev/null || true
        geny_cmd "gps setlongitude $LONG" >/dev/null || true
        geny_cmd "gps setaltitude $ALT" >/dev/null || true
        geny_cmd "gps setaccuracy $GPS_ACCURACY" >/dev/null || true

        sleep 1


        # ----------------------------------------------------
        # Android location services
        # ----------------------------------------------------

        adb -s "$ADB_SERIAL" \
            shell settings put secure location_mode 3 \
            >/dev/null 2>&1 || true


        # ----------------------------------------------------
        # LEER DE VUELTA
        # ----------------------------------------------------

        status_output="$(geny_cmd "gps getstatus" || true)"
        lat_output="$(geny_cmd "gps getlatitude" || true)"
        lon_output="$(geny_cmd "gps getlongitude" || true)"
        alt_output="$(geny_cmd "gps getaltitude" || true)"

        current_lat="$(extract_number <<< "$lat_output")"
        current_lon="$(extract_number <<< "$lon_output")"
        current_alt="$(extract_number <<< "$alt_output")"

        echo "   Estado   : $status_output"
        echo "   Latitud  : $lat_output"
        echo "   Longitud : $lon_output"
        echo "   Altitud  : $alt_output"


        # ----------------------------------------------------
        # VALIDAR
        # ----------------------------------------------------

        if grep -qi "enabled" <<< "$status_output" &&
           [[ -n "$current_lat" ]] &&
           [[ -n "$current_lon" ]] &&
           number_close "$current_lat" "$LAT" "$GPS_TOLERANCE" &&
           number_close "$current_lon" "$LONG" "$GPS_TOLERANCE"
        then

            echo
            echo "✅ GPS verificado correctamente."
            echo "   Latitud real : $current_lat"
            echo "   Longitud real: $current_lon"

            # Pequeña espera antes de abrir JWA para permitir
            # propagación de la posición dentro de Android.
            sleep 2

            return 0
        fi

        echo
        echo "⚠️ GPS todavía no coincide."

        if (( attempt < GPS_RETRIES )); then
            echo "🔄 Reintentando en 2 segundos..."
            sleep 2
        fi
    done

    echo
    echo "❌ GPS no pudo verificarse tras $GPS_RETRIES intentos."

    return 1
}


# ============================================================
# COMPROBAR QUE JWA ESTÁ INSTALADO
# ============================================================

check_jwa_installed() {

    adb -s "$ADB_SERIAL" shell pm path "$JWA_PACKAGE" \
        2>/dev/null |
        grep -q '^package:'
}


# ============================================================
# LANZAR JWA
# ============================================================

launch_jwa() {

    echo
    echo "🦖 Preparando Jurassic World Alive..."

    if ! check_jwa_installed; then
        echo "❌ No encuentro el paquete Android:"
        echo "   $JWA_PACKAGE"
        return 1
    fi

    echo "✅ JWA instalado."

    echo "🛑 Cerrando instancia previa..."

    adb -s "$ADB_SERIAL" \
        shell am force-stop "$JWA_PACKAGE"

    sleep 1

    echo "🦖 Abriendo Jurassic World Alive..."

    local output

    output="$(
        adb -s "$ADB_SERIAL" shell monkey \
            -p "$JWA_PACKAGE" \
            -c android.intent.category.LAUNCHER \
            1 \
            2>&1
    )"

    echo "$output"

    # Dar tiempo a Android para crear la actividad
    sleep 2

    if adb -s "$ADB_SERIAL" shell pidof "$JWA_PACKAGE" \
        >/dev/null 2>&1
    then
        echo "✅ JWA está ejecutándose."
        return 0
    fi

    echo "⚠️ Monkey terminó pero no encuentro proceso de JWA."
    return 1
}


# ============================================================
# MAIN
# ============================================================

main() {

    check_dependencies

    echo
    echo "[1/7] 🔍 Verificando Genymotion..."

    start_genymotion ||
        die "No fue posible iniciar Genymotion."


    # --------------------------------------------------------
    # VENTANA / RESIZE
    # --------------------------------------------------------

    echo
    echo "[2/7] 🪟 Esperando ventana..."

    if have hyprctl; then

        local pixel_address

        pixel_address="$(wait_for_pixel_window || true)"

        if [[ -n "$pixel_address" ]]; then

            echo "   Address limpia: <$pixel_address>"

            resize_pixel_window "$pixel_address" ||
                echo "⚠️ El resize falló, continúo."

        else

            echo "⚠️ No encontré la ventana."
            echo "   Continúo con ADB."
        fi

    fi


    # --------------------------------------------------------
    # ADB
    # --------------------------------------------------------

    echo
    echo "[3/7] 📡 ADB..."

    wait_for_adb ||
        die "ADB no quedó disponible."


    # --------------------------------------------------------
    # BOOT ANDROID
    # --------------------------------------------------------

    echo
    echo "[4/7] 🤖 Android..."

    wait_for_android_boot ||
        die "Android no completó el arranque."


    # --------------------------------------------------------
    # GENYMOTION SHELL
    # --------------------------------------------------------

    echo
    echo "[5/7] 🛰️ Sensores Genymotion..."

    wait_for_genyshell ||
        die "Genymotion Shell no detectó la VM."


    # --------------------------------------------------------
    # CONFIGURACIÓN
    # --------------------------------------------------------

    configure_display
    configure_gpu


    # --------------------------------------------------------
    # GPS
    # --------------------------------------------------------

    echo
    echo "[6/7] 📍 GPS..."

    if ! set_gps; then

        die "GPS no pudo verificarse. JWA no será iniciado."
    fi


    # --------------------------------------------------------
    # JWA
    # --------------------------------------------------------

    echo
    echo "[7/7] 🦖 Jurassic World Alive..."

    launch_jwa ||
        die "No pude confirmar el inicio de JWA."


    echo
    echo "============================================================"
    echo "✅ TODO COMPLETADO"
    echo
    echo "Genymotion : activo"
    echo "Tile       : ${GENY_WIDTH}px"
    echo "ADB        : conectado"
    echo "Android    : iniciado"
    echo "GPS        : verificado"
    echo "JWA        : ejecutándose"
    echo
    echo "📄 Log: $LOG"
    echo "============================================================"
}


main "$@"