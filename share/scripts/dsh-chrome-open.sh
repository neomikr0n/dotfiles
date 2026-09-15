#!/bin/bash
# Si dsh web no está corriendo, lo arranca
if ! lsof -i :3080 >/dev/null 2>&1; then
    dsh web --no-open > /tmp/dsh-web.log 2>&1 &
    sleep 3
fi

# Extrae el token del log
TOKEN=$(grep -oP 'token=\K[\w-]+' /tmp/dsh-web.log | head -1)

# Abre Chrome con el token
google-chrome-stable --app="http://127.0.0.1:3080/?token=${TOKEN}"