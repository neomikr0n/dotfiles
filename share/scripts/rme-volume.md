# Teclas de volumen del RME

`/home/n30/dotfiles/share/scripts/rme-volume up|down|status|check-up|check-down`

Control USB-MIDI nativo ALSA de Line Out del ADI-2 DAC con serie 51100523. Funciona con audio por óptico y permite coexistir con ADI-2 Remote. El ejecutable auxiliar C se compila en ~/.cache/rme-volume; necesita cc y ALSA. No usa Wine ni controla PipeWire.

## Límites

- Pasos relativos de 1 dB, basados en lectura actual y revisión de actualizaciones MIDI antes de escribir. El último paso se acorta al alcanzar el techo.
- Techo -15 dB, autorizado por el propietario; no lo supera al subir. También limita la salida nominal calculada sin EQ a -8 dBu XLR según la referencia fija.
- Con Auto Ref habilitado no permite subir: la escala cambia y requiere otra calibración.
- Mute sólo cambia por orden explícita `mute`. Nunca cambia bloqueo, dim, ganancia, referencia, EQ ni volumen de la PC. No sube con Mute o Dim activos.
- Si no hay respuesta válida, no escribe. No reutiliza valores de sesiones anteriores. Verifica respuesta después de escribir, sin reintentar una escritura incierta.
- Intervalo mínimo de 100 ms entre operaciones (máximo teórico 10 pasos/s; limitado además por el transporte MIDI). Exclusión mutua sin cola: las repeticiones que llegan durante otra operación se descartan.
- Identifica el dispositivo por nombre y serie, no por número ALSA mutable.
- El techo no garantiza un SPL seguro: dependen también de PC, Aune, ganancia, EQ, auriculares y grabación. Subir la PC a 100% puede incrementar mucho el nivel; bajar primero el Aune/RME. No se automatiza esa transición.
- No mover simultáneamente el volumen mediante otro controlador: se consultan actualizaciones antes de escribir, pero el protocolo no ofrece una operación atómica de incremento.

## Verificación

Vector del protocolo oficial comprobado, codificación/decodificación de todo el intervalo de volumen y rechazo de otro modelo. Lectura real con Remote abierto; rechazo de subida desde -19 dB; descenso real confirmado a -19.5 dB. La simulación check-up/check-down no escribe.

Se comentaron las asignaciones Raise/Lower de swayosd en n30.conf y sus duplicadas de dms en hyprland.conf. Copias previas en rme-volume-backup/. Mute controla ahora Line Out del RME.

Protocolo oficial: https://rme-audio.de/downloads/adi2remote_midi_protocol.zip (v0.2, 30/09/2023). Las teclas envían el parámetro 12 (volumen) o 15 (mute) de dirección 3, dispositivo 0x71. No envían cargas de presets ni comandos de fábrica.

## OSD y velocidad

SwayOSD muestra una barra personalizada, nivel confirmado en dB y techo. La barra representa la posición en el intervalo -114.5 a -17 dB, no potencia ni porcentaje de sonoridad. No llama a --output-volume. Los fallos se notifican con mensajes y emojis; las operaciones simultáneas descartadas no notifican.

Se eliminaron las esperas fijas cuando la respuesta está completa. Se consulta el estado al empezar, se revisan cambios entrantes y se consulta de nuevo para confirmar el volumen escrito. El firmware no confirmó de forma fiable mediante eco espontáneo, por lo que se conserva la consulta explícita. Medición local final previa al cambio de tamaño de paso: ~341 ms por operación. Las pruebas sólo bajaron el volumen, hasta -22 dB.

## DMS (sustituye SwayOSD para RME)

`rme-osd level -22.0` muestra una tarjeta nativa de DankMaterialShell mediante `toast infoWith`. La categoría rme-volume se sustituye en cada actualización para no dejar una cola de niveles antiguos. Los avisos usan warnWith. Conserva tema/posición de las tarjetas de DMS: no es una barra gráfica de volumen. Si DMS no está disponible, usa notify-send como respaldo. No invoca ninguna API de audio de DMS ni cambia el volumen de PipeWire. No se necesita otro proceso Quickshell.

La prueba del OSD se hace con el valor consultado mediante status; no requiere cambiar el volumen. SwayOSD permanece disponible para brillo y otras teclas existentes.

## Actualización 13/09/2026

- Techo autorizado: -15 dB. Para Ref +1 dBu RCA (+7 XLR), límite nominal sin EQ: -8 dBu XLR. Referencias superiores limitan más la subida.
- Teclas normales: +/-1 dB; Shift+volumen: +/-5 dB por pulsación, sin autorrepetición para saltos grandes.
- Último salto recortado al techo: desde -17, up5 termina en -15, no -12.
- Tecla Mute: alterna el mute real de Line Out. Conserva el volumen. No se asigna un nivel artificial de silencio.
- Al quitar mute se verifica techo y referencia; si Auto Ref está activo o el nivel supera los límites, permanece silenciado. No desbloquea volumen ni modifica EQ/ganancia/PC.
- Pruebas: codificación de Mute y límites comprobados; consultas simuladas reales desde -17 dB: up5 -> -15, down5 -> -22, Mute 0 -> 1. No se enviaron cambios audibles durante esta actualización. Hyprland recargado sin errores.

## Barra bajo demanda (13/09/2026)

El control MIDI no necesita ADI-2 Remote ni daemon al arranque. Requiere RME encendido y USB con control MIDI habilitado. `rme-osd` inicia una instancia independiente de Quickshell sólo al mostrar volumen; se oculta a los 1.6 s y el proceso termina a los 20 s sin actividad. DMS sigue gestionando avisos y mute como antes.

Barra naranja/ámbar, clics transparentes, sin foco. Porcentaje = 100 × (dB + 114.5) / 99.5, limitado a 0–100: posición en el intervalo -114.5 a -15 dB, no potencia ni volumen percibido. Ejemplo: -22 dB = 93% del recorrido. El valor dB sigue siendo el dato principal.

SwayOSD fue retirado del inicio y detenido. Las teclas existentes de brillo/Caps Lock llaman ahora a swayosd-on-demand, que sólo lo inicia cuando lo necesitan. No se desinstaló. Archivo UI: rme-osd-ui/shell.qml. Probada carga sin errores e IPC devuelve -22.0 dB · 93%; no se modificó audio para esta prueba.
