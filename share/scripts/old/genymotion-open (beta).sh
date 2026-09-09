#!/bin/bash

# --- CONFIGURACIÓN ---
GENY_PATH="/opt/genymotion"
PLAYER="$GENY_PATH/player"
GENYSHELL="$GENY_PATH/genyshell"
VM_NAME="Google Pixel 6 Pro"

# Coordenadas Morelia
LAT="19.73663978"
LONG="-101.11478609"
ALT="15.04444408"

echo "🔍 Verificando Genymotion..."

# 1. Arrancar SOLO si no hay ningún 'player' vivo
if ! pgrep -x "player" > /dev/null; then
    echo "🚀 Iniciando instancia..."
    "$PLAYER" --vm-name "$VM_NAME" > /dev/null 2>&1 &
    sleep 10
fi

# 2. Esperar conexión ADB
echo "📡 Sincronizando ADB..."
adb connect 127.0.0.1:5555 > /dev/null 2>&1
SERIAL=$(adb devices | grep -m 1 "device$" | awk '{print $1}')

while [ -z "$SERIAL" ]; do
    sleep 2
    SERIAL=$(adb devices | grep -m 1 "device$" | awk '{print $1}')
    echo -n "."
done
echo -e "\n✅ Conectado a $SERIAL"

# 3. Configurar Pantalla (SIN REINICIAR)
echo "🖥️  Ajustando resolución Tablet..."
adb -s $SERIAL shell wm size 1536x2048
adb -s $SERIAL shell wm density 320

# 4. Potencia GPU
echo "🚀 Optimizando RX 9070 XT..."
adb -s $SERIAL shell su root "setprop threaded 1"
adb -s $SERIAL shell su root "setprop persist.sys.ui.hw true"
adb -s $SERIAL shell su root "setprop debug.hwui.renderer opengl"

# 5. GPS (Inyección de Doble Capa)
if [ -f "$GENYSHELL" ]; then
    echo "📍 Inicializando GPS (Capa Hardware)..."
    # Habilitamos el sensor en el emulador
    "$GENYSHELL" -c "device select '$VM_NAME'; gps setstatus enabled"
    sleep 2
    
    echo "📍 Forzando coordenadas (Capa Sistema)..."
    # Inyectamos vía Genyshell
    "$GENYSHELL" -c "device select '$VM_NAME'; gps setlatitude $LAT; gps setlongitude $LONG; gps setaltitude $ALT"
    
    # REFUERZO ADB: Forzamos al proveedor de red/fused de Android
    # Esto asegura que JWA lea la posición de Morelia y no 0,0
    adb -s $SERIAL shell settings put secure location_mode 3
    adb -s $SERIAL shell am broadcast -a com.genymotion.intent.action.SET_GPS --ef lat $LAT --ef lng $LONG --ef alt $ALT > /dev/null 2>&1
    
    echo "✅ GPS Sincronizado en Morelia."
else
    echo "⚠️ Genyshell no encontrado."
fi

# 6. Lanzar Juego
echo "🦖 Abriendo Jurassic World Alive..."
# Matamos cualquier instancia previa para evitar pantalla negra
adb -s $SERIAL shell am force-stop com.ludia.jw2
sleep 1
adb -s $SERIAL shell monkey -p com.ludia.jw2 -c android.intent.category.LAUNCHER 1

echo "✨ Proceso terminado."