#!/bin/bash

# Ruta del archivo temporal
TMP_FILE="/tmp/last_screenshot_geometry"

# Función para realizar la captura
take_shot() {
    local geom="$1"
    local filename="ss_$(date +%Y-%m-%d_%H-%M_%S)_garuda.jpeg"
    scran -g "$geom" -f "$filename" -d "$HOME/Imágenes/Screenshots/"
}

# Comprobamos si el script se llamó con el argumento "repeat"
if [ "$1" == "repeat" ] && [ -f "$TMP_FILE" ]; then
    GEOMETRY=$(cat "$TMP_FILE")
    take_shot "$GEOMETRY"
else
    # Selección normal
    GEOMETRY=$(slurp)
    if [ -n "$GEOMETRY" ]; then
        echo "$GEOMETRY" > "$TMP_FILE"
        take_shot "$GEOMETRY"
    fi
fi