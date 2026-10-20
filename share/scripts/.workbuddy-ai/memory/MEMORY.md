# Memoria del proyecto (scripts de n30)

## Estilo y comprobador

- `~/dotfiles/share/scripts/unslop-revisar.py`: señala, no reescribe, y sale con 1 si hay hallazgos.
  `--solo=regla` limita, `--listar-reglas` las lista.
- Los emojis que imprime un script son interfaz, no tic (decisión de n30). La regla 13 (rayas)
  perdona lo que va entre comillas invertidas.
- Las copias previas a un arreglo se pasan con nombre `.md`, porque `negrita-encabezado` y
  `negrita-excesiva` solo disparan en ficheros `.md`.
- Al comprobador no se le enseña a callar. El hallazgo falso se arregla reescribiendo la frase.
- `printf '%-9s'` cuenta BYTES, no caracteres. Para alinear texto con acentos hay que rellenar con
  `${#var}`, que sí cuenta caracteres.

## Ficheros del proyecto

- `dictado/` es el sistema de dictado (whisper.cpp + DJI Mic en Hyprland). Guía en
  `dictado/GUIA.html`, batería en `dictado/pruebas/correr-todas.sh` (153 comprobaciones en siete
  bloques, todas en verde a 2026-10-18).
- Copias de seguridad en `scripts/backups/`, `dictado/backups/` y `~/.workbuddy-ai/skills/backups/`.
- Varias ediciones al mismo fichero en un solo mensaje se pisan y solo sobrevive la última. Van de
  una en una y se verifica después de cada una (skill `edicion-multiple-mismo-fichero`).

## Dictado

- Las suites aíslan la config del usuario con `DICTADO_CONF` apuntando a un fichero que no existe,
  porque `dictado.sh` lee `~/.config/dictado.conf` después de heredar el entorno.
- Cambiar de modelo se hace con `dictado/dictado-modelo-usar.sh`, no con `ln` a mano. Verifica el
  sha256 en tres sitios: el instalador, el `ExecStartPre` de la unidad y el bloque 7 de la suite.
- `graphical-session.target` no se activa nunca en este Hyprland, así que los servicios
  (dictado-servidor, dictado-tecla, dms, ktimer-alert, openlogi-agent) se arrancan con
  `hl.exec_cmd` desde `hyprland.lua`, no con `enabled`.
- El relleno del VAD son 500 ms y vive en tres sitios que tienen que ir a la vez. La unidad
  `dictado-servidor.service`, `dictado.sh` (`DICTADO_VAD_PAD`) y `dictado-bench.py`
  (`VAD_PAD_MS`). El prompt del whisper va en la petición (`-F prompt=...`), no en la unidad.
- El historial está en `~/.local/share/dictado/historial.txt`. El pegado vive en `dictado.sh`, y el
  portapapeles se guarda antes de pisarlo y se devuelve después.
- El vocabulario (`dictado-vocabulario.txt`) se lee en cada invocación, así que un cambio vale en el
  dictado siguiente sin reiniciar. Su tabla de medidas es del 2026-10-10 y no es comparable con el
  arnés actual, que lleva el relleno VAD de 500 ms: la misma lista de 444 da 11 errores hoy y 12 en
  la tabla. Comparar siempre variantes medidas el mismo día. «DeepSeek» se añadió el 2026-10-17 y
  empata en el corpus (11 con ella y 11 sin ella) porque el corpus no contiene la palabra.
- Las erratas sistemáticas de nombres propios se corrigen en `dictado.sh` con
  `corregir_terminos()`, una lista cerrada con límites de palabra aplicada en `transcribir()`,
  así que vale para las dos rutas y para el vivo. Cubre DeepSeek (también DeepSeq y DeepSync),
  Anthropic, OpenAI y WorkBuddy, pegado o partido en dos palabras; la forma partida exige mayúscula
  inicial. Cada regla lleva su propia caja, porque la primera versión comparaba distinguiendo
  mayúsculas y «WorkBody» se colaba. WorkBuddy no está en el prompt del vocabulario, así que solo
  lo arregla la corrección; meterlo en el prompt exige medirlo dentro de la lista.
  «Cloth» por Claude queda fuera a propósito porque «cloth» es una palabra inglesa real. No es
  un corrector general.

## Escape y el vigilante de teclado

- Escape cancela el dictado y eso vive en `dictado-tecla.py`, que solo LEE el teclado por evdev.
  Un bind de Hyprland lo consumiría y dejaría sin Escape a todo el escritorio.
- `cancelar` no es `parar`: tira la grabación sin transcribir, y sale callado cuando no hay nada
  grabando porque el vigilante la llama en cada Escape del sistema.
- Escape desarma la ventana de gracia del toque de Ctrl; si no, el toque pendiente volvería a
  arrancar el dictado recién cancelado. Ese caso de la gracia se llama `abortar`.
- `dictado-vivo.sh cancelar` delega en `dictado.sh cancelar`, para que un solo Escape valga en los
  dos caminos.
- Para probar un camino que empieza en evdev sin pulsar teclas. Teclado `uinput` creado ANTES de
  arrancar el vigilante (lista los dispositivos una vez al arrancar) y la orden apuntando a un
  `touch`. `--orden` y `--simular` comprueban el disparador sin teclado.

## Capas y escritorio

- `hyprctl layers -j` tiene la forma `d[monitor]["levels"][nivel]` (doble anidamiento). Un «sin
  capas» de más suele ser fallo de parseo, no un escritorio vacío. Medido el 2026-10-13.
- La ventana flotante `org.quickshell` de 500×500 que aparece al arrancar la sesión es
  `ktimer-alert.service` (la lanza `hyprland.lua:333`), no es del dictado. Es un defecto del QML:
  su raíz es un `Item` pelado y Quickshell envuelve cualquier raíz QQuickItem en una FloatingWindow
  extra de tamaño por defecto. El arreglo es una línea, la raíz `ShellRoot`, como ya hacen
  `jwa-timer.qml` y `dictado-vivo.qml`. Aplicado el 2026-10-13 (copia en
  `dotfiles/backups/`): la ventana flotante desapareció y la capa overlay se mantiene.
- Tras una recarga de GPU (hotplug), las capas overlay de Quickshell pueden no volver a mapearse:
  ktimer-alert y jwa-timer las perdieron el 2026-10-13 y dms:bar se recuperó solo. Se arregla
  reiniciando el servicio o relanzando el Quickshell.
