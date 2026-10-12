# Memoria del proyecto (scripts de n30)

## Estilo de la casa y comprobador de tics

- **Comprobador.** `~/dotfiles/share/scripts/unslop-revisar.py` señala, no reescribe. Devuelve
  `linea [regla rN] detalle` y sale con 1 si hay hallazgos. `--solo=rayas,dos-puntos` limita a una
  regla; `--listar-reglas` las lista.
- **Emojis en la salida impresa de un script son interfaz, no tic.** Decisión de n30 (2026-10-10).
  La regla 18 solo mira encabezados y viñetas de documentos, no lo que un script imprime con `echo`
  o `printf`.
- **La regla 13 (rayas) perdona lo que va entre comillas invertidas**, porque ahí hay un literal o
  código y no prosa. Medido el 2026-10-10, tras perder un literal por no perdonarlo.
- **Control de regresión.** Las copias previas a un arreglo hay que pasarlas con nombre `.md`, porque
  `negrita-encabezado` y `negrita-excesiva` solo disparan en ficheros `.md`. Con nombre `.bak-...`
  el número sale más bajo y parece que el comprobador se ha quedado ciego.
- **Fuera del corpus, a propósito.** `unslop_ESPAÑOL` y `unslop_EN` (son los diccionarios de reglas)
  y el pack `deep-research` (de terceros, licencia MIT, escrito en chino).

## Trampas ya medidas

- `printf '%-9s'` cuenta BYTES, no caracteres. Para alinear texto con acentos hay que rellenar con
  `${#var}`, que sí cuenta caracteres.
- Varias ediciones al mismo fichero en un solo mensaje se pisan, así que solo sobrevive la última.
  Van de una en una, y se verifica después de cada una. Skill `edicion-multiple-mismo-fichero`.
- En el alcance por fecha de un unslop, mirar el `stat` antes de editar, porque la ventana recoge
  también ficheros de otra sesión que esté trabajando a la vez.

## Ficheros del proyecto

- `dictado/` es el sistema de dictado (whisper.cpp + DJI Mic en Hyprland). Guía en `dictado/GUIA.html`
  y pruebas en `dictado/pruebas/correr-todas.sh`.
- `pila-dispositivos.sh` imprime la pila de ratón, teclado y micrófonos. Symlink en
  `~/.local/bin/pila-dispositivos`.

## Convenciones del dictado (2026-10-10)

- **Las suites aíslan la config del usuario** con `DICTADO_CONF` apuntando a un fichero que no
  existe. Motivo: `dictado.sh` lee `~/.config/dictado.conf` DESPUÉS de heredar el entorno, así que
  una línea nueva en la config cambia lo que prueba una suite sin que la suite falle. Medido al
  habilitar el servidor residente, que rompió el bloque 1.
- **Cambiar de modelo se hace con el instalador**, `dictado/dictado-modelo-usar.sh`, no con `ln -sfn`
  a mano. Verifica el sha256 antes de enlazar, rechaza un corrupto, y reinicia el servicio.
- **El verificador de modelos corre en tres sitios.** Antes de enlazar, al arrancar el servicio
  (`ExecStartPre` de la unidad) y en el bloque 7 de la suite.
- **Batería del dictado.** 86 comprobaciones en siete bloques, todas en verde a 2026-10-11. La 6
  mira el servicio desplegado y la 7 los modelos. Ninguna necesita el receptor DJI conectado. La
  única comprobación que sí lo necesita es la H2 del bloque 5, y se salta sola cuando no está.

## Servidor residente y VAD (2026-10-11)

- **El servidor residente se arranca desde `hyprland.lua`**, con una línea `hl.exec_cmd`, no desde
  el target. Cuelga de `graphical-session.target`, que en este Hyprland no se activa nunca, así que
  `enabled` no basta y la unidad quedaba `inactive` sin dar error. El bloque 6 de la suite exige esa
  línea, para que no vuelva a apagarse en silencio. Medido el 2026-10-11.
- **El relleno del VAD es 500 ms, y vive en tres sitios que tienen que ir a la vez.** La unidad
  `dictado-servidor.service` (`--vad-speech-pad-ms`), `dictado.sh` (`DICTADO_VAD_PAD`, en el binario)
  y `dictado-bench.py` (`VAD_PAD_MS`). Con el defecto de 30 ms se come la primera palabra. Si se
  cambia en uno y no en los otros, las dos rutas dejan de transcribir igual.
- **El prompt del servidor va en la petición, no en la unidad.** `dictado.sh` manda `-F prompt=...`
  en cada llamada, y medido el 11 oct eso y fijarlo al arrancar dan idéntico. Poner `--prompt` en
  `ExecStart` sería duplicarlo sin ganar nada.
- **El banco tiene que medir lo que se vive.** `correr_servidor` manda el prompt en la petición
  (antes no lo hacía, y por eso la columna del servidor salía 10,6 % en vez de 6,0 %). El binario del
  banco usa el mismo VAD y el mismo relleno que producción.
- **El VAD en el servidor no se puede cambiar por petición.** Se decide al arrancarlo, con `--vad` en
  su línea de comandos. `--sin-vad` del banco solo afecta al binario.
- **La comprobación de contenido de la suite 5 ignora mayúsculas.** El VAD parte la frase y whisper
  capitaliza el arranque de cada segmento, así que la misma locución sale con mayúscula o minúscula
  según dónde caiga el corte. Eso no es un error de contenido.

## Medidor de nivel del dictado en vivo (2026-10-11)

- **El medidor sigue siendo `parec`.** n30 pidió investigar la alternativa antes de implementarla.
  Medido y sin decidir. Informe en `informes/dictado-medidor-nivel-informe.html`, banco en
  `dictado-nivel-medir.{sh,py,qml}`.
- **El periodo de un `PwNodePeakMonitor` es el del nodo, no el de los clientes.** Sobre el receptor
  DJI da 21,0 ms (47,6 Hz) con el monitor solo, con `parec` enganchado y con `whisper-stream`
  dentro. No vale generalizar desde un sumidero nulo, que da 43,0 ms por sí mismo. Mezclar los dos
  nodos en una tabla produjo una conclusión falsa en la primera pasada.
- **El coste se mide con el medidor callado y sobre el nodo de producción.** El QML del banco
  escribe una línea por emisión y lleva dos monitores, así que medía el andamio. El coste real de un
  monitor sobre el micro es 0,67-0,70 % de un núcleo, frente a 0,52 % del `parec` más el bucle de
  Python. `dictado-nivel-medir-cpu.qml` es el que vale para eso.
- **`Quickshell.env(nombre, respaldo)` no acepta respaldo.** El segundo argumento se ignora y
  devuelve `null`. Hay que escribir `Quickshell.env("X") || "valor"`.
- **La calibración no se puede igualar.** Quickshell da `cbrt(pico)` por canal y hoy se da RMS en
  decibelios. Las curvas correlacionan 0,95-0,96, pero remapear a decibelios llena la barra mucho
  más. Es una decisión de aspecto, no un defecto.

## Dictado en vivo (2026-10-11)

- **El toque de Ctrl izquierdo lanza el dictado en vivo**, no el ciego. Lo decide la orden por
  defecto de `dictado-tecla.py`, que resuelve `dictado-vivo.sh` desde la carpeta del script y no
  desde la unidad, para que mover el proyecto no la rompa. El camino ciego sigue disponible con el
  bind `SUPER + D` y con `DICTADO_TECLA_ORDEN`.
- **`dictado-tecla.py --orden`** imprime la orden resuelta y sale. Sirve para comprobar el
  disparador sin tocar el teclado, y es lo que vigila el bloque 5 de la suite.
- **El vigilante es un servicio de systemd**, y su entorno trae `WAYLAND_DISPLAY` y
  `HYPRLAND_INSTANCE_SIGNATURE`, así que la capa se puede abrir desde él.
- **Para probar que la capa abre sin pegar nada**, lanzar `dictado-vivo.sh start`, comprobar
  `estado` y `hyprctl layers`, y cerrar por PID. NO usar `dictado-vivo.sh parar`, porque ese camino
  pega el texto en la ventana que tenga el foco.
- **Trampa al probar el disparador.** Si la orden de prueba viaja en la línea de comandos,
  `pgrep -f dictado-vivo.py` se encuentra a sí misma y el script cree que ya hay un motor vivo.
  La prueba va en un fichero, no en la línea de comandos.

## Dobles de las suites (2026-10-11)

- **El doble que tiene que cruzar a un proceso hijo va en fichero, no en función.** `pactl() { … }`
  vale para el shell que lo define y para sus subshells, pero no para un `bash script.sh`, que
  arranca un proceso aparte. La sección E del bloque 5 pide la fuente así, y por eso el doble es
  `dictado/pruebas/dobles/pactl`, con esa carpeta antepuesta al `PATH` en los bloques 1 y 5.
- **Un doble no lleva el nombre de un comando real** si su carpeta va en el `PATH`. El de
  whisper-stream es `dobles/falso-whisper-stream` y se llama por ruta explícita.
- **Lo que depende del hardware se prueba dos veces.** Una contra un doble, que es determinista y
  siempre corre, y otra contra el hierro real, que se salta sola cuando el hierro no está. Un salto
  declarado no es lo mismo que un fallo silencioso.
- **Una comprobación que da por hecho una sesión en reposo miente cuando no lo está.** La del
  puente en reposo del bloque 5 salía en rojo con un dictado en vivo abierto, y el puente tenía
  razón. Se aísla escondiéndole la sesión con dos dobles, `dobles/sin-sesion/pgrep` y
  `dobles/sin-sesion/hyprctl`, que valen solo para esa orden y no entran en la carpeta del PATH.

## Higiene de las copias y del estilo (2026-10-11)

- **Las copias `.bak` van a una carpeta por proyecto, no junto al fichero.** En el proyecto de
  scripts, `scripts/backups/` y `dictado/backups/`. En el árbol de skills,
  `~/.workbuddy-ai/skills/backups/`, con la ruta del skill delante del nombre. Mover no es borrar.
- **El plan de estilo se hace fichero a fichero, nunca de una tacada.** Un diff de 55 ficheros no
  se puede revisar, y si una reescritura cambia el sentido de una instrucción el fallo aparece
  cuando la skill se usa mal. El método está en la skill `unslop-corpus-documentacion`.
- **Al comprobador no se le enseña a callar.** Un hallazgo falso se arregla reescribiendo la frase.
  La excepción solo se pone para el término de dominio que no tiene sustituto, y se documenta en
  el propio comprobador.
- **En HTML las etiquetas se quitan antes de mirar la prosa, así que una etiqueta de código no
  exime.** La exención es para comillas invertidas, y solo en Markdown.
- **La copia va antes de escribir, también en un documento de trabajo.** Medido a mi costa el
  11-oct-2026 con `unslop-plan-skills.md`, que se reescribió sin copia y no estaba en git.


## Historial y portapapeles del dictado (2026-10-11)

- **El historial de transcripciones está en `~/.local/share/dictado/historial.txt`**, una línea por
  dictado con la fecha y un tabulador. Se apunta ANTES de pegar. No vive en el runtime, que está en
  `/run` y se borra al reiniciar.
- **El pegado vive en `dictado.sh`, y el puente del vivo pega por él.** `dictado.sh pegar` lee el
  texto por la entrada estándar, y `dictado-vivo.sh` no copia ni teclea nada por su cuenta. Duplicar
  el pegado sería duplicar también la devolución del portapapeles y el apunte al historial.
- **Antes de pisar el portapapeles se guarda, y se devuelve después de pegar.** Solo texto, y solo si
  el portapapeles sigue teniendo el texto dictado. Se apaga con `DICTADO_PORTA_RESTAURAR=0`.
- **El margen de `DICTADO_PORTA_ESPERA`, 800 ms, es un margen y no una medida.** Lo medido es el
  trayecto del dato, 3,3 ms. Medir el resto exigiría mandar un Ctrl+V al escritorio.
- **`tail -n N | head -n 1` no devuelve vacío si N pasa del total.** Saca el fichero entero y se queda
  con la primera. Un rango fuera de la lista tiene que devolver nada, y se comprueba el total antes.
- **Los dobles que tienen que cruzar a un proceso hijo son ejecutables en el `PATH`, y se niegan a
  correr sin su variable de entorno.** El pegado corre en `bash dictado.sh pegar`, así que una función
  de shell no llegaba hasta ahí. El doble sin variable da un fallo ruidoso en vez de tocar el estado
  real.
- **El portapapeles de la sesión lo vigilan cliphist y CopyQ.** Una suite que copie de verdad le mete
  basura en el historial al usuario, y una que lea de verdad da un resultado distinto en cada pasada.

## Corregir y normalizar el texto, medido (2026-10-11)

- **El medidor es `dictado-normalizar-medir.py`.** Mide sobre las hipótesis ya guardadas en
  `informes/dictado-modelos-medidas.json`, así que no transcribe y da el mismo número siempre. Cuenta
  el error con `normalizar()` y `wer()` del banco, importadas.
- **Un corrector por distancia de edición sin filtro de diccionario empeora el texto cinco veces.**
  Medido: 24 errores de base a 111. El filtro es la condición para que la capa exista.
- **El filtro tiene que ser un corrector de verdad, con las reglas de flexión.** El `.dic` de hunspell
  guarda la forma base y las flexiones van en el `.aff`, así que una lista de palabras no reconoce
  `abro` ni `hace`. Con el `.dic` suelto, tope 2 rompe palabras; con tope 1 no rompe ninguna.
- **El corpus no usa un criterio solo para los números.** `l2-informe` escribe `quinientos treinta y
  siete` y `m2-numeros` escribe `47 320`. Por eso la dirección dígitos a palabras sube el error, y la
  de símbolos a palabras (`%` → `por ciento`) lo baja.
- **`normalizar()` del banco tira la puntuación, así que ninguna capa de puntuación se puede medir con
  el WER.** Cuesta cero por construcción. Para puntuarla hace falta otra métrica, y mientras no la
  haya, eso se dice antes de decidir.
- **El diccionario general está en disco, sin descargar nada.** El hunspell español del runtime de
  Flatpak de GNOME, y `cracklib-small` como guarda inglesa, que es una lista de contraseñas.

## Escape y el vigilante de teclado (2026-10-11)

- **El dictado se cancela con Escape, y eso vive en `dictado-tecla.py`, no en un bind de Hyprland.**
  Un bind consume la tecla y dejaría sin Escape a todo el escritorio. El vigilante solo LEE el teclado
  por evdev, así que Escape sigue llegando a la aplicación con el foco.
- **`cancelar` no es `parar`.** Parar transcribe y pega; cancelar tira la grabación. Cancelar sale
  callado cuando no hay nada grabando, porque el vigilante la llama en CADA Escape del sistema.
- **Escape desarma la ventana de gracia del toque de Ctrl.** Si no, el toque pendiente dispararía
  justo después de cancelar y volvería a arrancar el dictado que se acaba de tirar.
- **El caso de la gracia se llama `abortar`, no `cancelar`.** Antes compartía nombre con la
  cancelación de Escape y se confundían dos cosas distintas.
- **`dictado-vivo.sh cancelar` delega en `dictado.sh cancelar`**, para que un solo Escape valga
  aunque esté grabando el camino ciego. La dependencia va en ese sentido y no al revés.
- **Para probar un camino que empieza en evdev sin pulsar teclas, se crea un teclado virtual de
  `uinput` ANTES de arrancar el vigilante.** `buscar_teclados` lista los dispositivos al arrancar, así
  que uno que aparezca después no se ve. Se comprueba el camino entero apuntando la orden a un `touch`.
