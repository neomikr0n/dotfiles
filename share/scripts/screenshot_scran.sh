#!/bin/bash

TMP_FILE="/tmp/last_screenshot_geometry"

# 1. Ejecutar slurp para permitirte elegir/actualizar el área
# Esta parte siempre se ejecutará al invocar el script.
GEOMETRY=$(slurp)

# 2. Si el usuario presiona ESC (cancela slurp), intentamos usar la anterior
if [ -z "$GEOMETRY" ]; then
    if [ -f "$TMP_FILE" ]; then
        GEOMETRY=$(cat "$TMP_FILE")
    else
        exit 0 # No hay selección y no hay historial, salimos
    fi
else
    # 3. Si hubo selección, la guardamos para la próxima vez (SOBREESCRIBIMOS)
    echo "$GEOMETRY" > "$TMP_FILE"
fi

# 4. Realizar la captura
FILENAME="ss_$(date +%Y-%m-%d_%H-%M_%S)_garuda.jpeg"
scran -g "$GEOMETRY" -f "$FILENAME" -d "$HOME/Imágenes/Screenshots/"