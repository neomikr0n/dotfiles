# Control de audio RME

## Uso

`rme-volume up|down|up5|down5|mute|status`

- Volumen normal: ±1 dB. Shift + volumen: ±5 dB, sin autorrepetición.
- Techo: **−12 dB**. El último salto se recorta para no rebasarlo.
- Mute alterna el silenciamiento real del DAC y conserva el nivel.
- `check-up`, `check-down`, `check-up5`, `check-down5`, `check-mute`: simulaciones sin escritura.

## Archivos necesarios

| Archivo | Función |
|---|---|
| `rme-volume` | Entrada para las teclas, compilación automática y avisos |
| `rme-volume.c` | Controlador ALSA USB-MIDI con límites y confirmaciones |
| `rme-osd` | Muestra la barra Quickshell y avisos de DMS |
| `rme-osd-ui/shell.qml` | Apariencia de la barra central |
| `rme-volume-tests.c` | Pruebas locales de codificación y límites, sin acceso al DAC |
| `swayosd-on-demand` | Arranque bajo demanda para las teclas antiguas de brillo/Caps Lock |

## Funcionamiento

No necesita ADI-2 Remote abierto. Requiere USB y MIDI Control habilitado en el RME. Identifica el ADI-2 DAC 51100523 por nombre/serie, no por el número de tarjeta ALSA. Abre explícitamente envío y recepción MIDI.

El binario se compila en `~/.cache/rme-volume/` usando cc y ALSA. La sesión MIDI arranca sola; termina a los 15 segundos sin comandos. Mantiene un socket privado `/run/user/UID/rme-volume-v2.sock`. No requiere servicio al inicio.

Consulta al DAC al empezar y cuando la última confirmación tiene más de 750 ms. Mientras tanto consume actualizaciones del dispositivo y usa el estado confirmado de esa sesión, sin archivo de volumen. Cada escritura se confirma; ante errores invalida el estado y cierra ALSA. Las pulsaciones concurrentes se descartan, no se acumulan. Latencia medida de operaciones consecutivas: 162–164 ms; tras inactividad puede ser mayor.

## Límites

- Sólo escribe volumen o mute de Line Out. No modifica EQ, referencia, ganancia, bloqueo ni PipeWire.
- No sube con Mute/Dim, Lock o Auto Ref activados. Desactivar mute también respeta los límites.
- Además del techo −12 dB, restringe salida nominal sin EQ a −5 dBu XLR según la referencia fija. Referencias superiores pueden imponer un techo más bajo.
- Estos límites no garantizan un SPL seguro: PC, Aune, EQ, grabación y audífonos también influyen. No subir la PC al 100% sin bajar previamente la cadena.
- Evitar cambiar volumen con otro controlador simultáneamente: el protocolo no tiene incremento atómico.

## Indicador

Quickshell arranca sólo al necesitarlo, se oculta a los 1.6 segundos y termina tras 20 segundos inactivo. El porcentaje es recorrido entre −114.5 y −12 dB, no potencia ni sonoridad. DMS presenta avisos y mute; notify-send sirve de respaldo. SwayOSD no se usa para el RME ni arranca con Hyprland; queda bajo demanda para brillo/Caps Lock.

## Pruebas y procedencia

`cc -Wall -Wextra -Werror -O2 rme-volume-tests.c -lasound -o /tmp/rme-volume-tests && /tmp/rme-volume-tests`

Prueba toda la codificación del intervalo de volumen, límites, referencia, mute y rechazo de otro modelo. Las pruebas reales de desarrollo sólo redujeron volumen.

Protocolo oficial: https://rme-audio.de/downloads/adi2remote_midi_protocol.zip

`audio-audit-2026-09-11/` se conserva: documenta pruebas de PipeWire/Cider y sus respaldos de restauración; está enlazada desde audio_context.md. No es necesaria para ejecutar las teclas. Se retiraron a la papelera los respaldos intermedios de Hyprland (`rme-volume-backup/`) y la caché `vkd3d-proton.cache.write`.
