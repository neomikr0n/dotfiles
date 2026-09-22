# Diagnóstico en vivo de la distorsión «robótica» — 20-sep-2026, 16:04

> ## ⚠ CORRECCIÓN DE ALCANCE — 21-sep-2026 (leer antes que nada)
>
> **Este documento afirma en varios sitios que el software está descartado. Esa conclusión se
> RETIRA.** Se sostenía en que el vigilante no registró nada durante los eventos, y eso es un salto
> lógico: **«mi instrumento no lo vio» no es «no ocurrió»**.
>
> El vigilante **muestrea** (~234 ms por vuelta) y **solo escribe para seis formas de fallo**
> concretas; además **omite los PCM cerrados**. Un fallo cuya firma no sea una de esas seis —por
> ejemplo un error de bit en el enlace óptico— es **invisible por construcción**. Ver §11 para el
> detalle, y la cabecera de `vigilar.sh` para la lista de puntos ciegos.
>
> **Y hay un segundo motivo, independiente:** el síntoma aparece en **dos transportes distintos**
> (USB y óptico) **con la misma pila de software** (§5, §11.3). Eso hace del software un **factor
> común**, no un descartado.
>
> **Estado correcto: el software NO está descartado.** Es una hipótesis viva, y la prueba que la
> discrimina está pendiente (§11.5). Los pasajes afectados de §6.7, §8 y §9 llevan nota.
>
> **También se retira la prescripción sobre el vocabulario** (§3.1, §6.6): el propietario describió
> el síntoma como «robótico» en **10 de 11** capturas, y «corte seco» fue un término **mío**, usado
> una vez. No son necesariamente el mismo síntoma, y eso queda como cuestión abierta (§11.4).

**Evento reportado por el propietario:** distorsión de **menos de un segundo**, escuchada a las
~16:03, con **S.T.A.L.K.E.R. 2 abierto**. Es el segundo evento del día.

**Objetivo de este documento:** determinar **por qué** ocurre, no describirlo. Cada afirmación lleva
su nivel de confianza. Lo que no se haya podido verificar se dice explícitamente.

---

## 1. Estado de la cadena en el momento del evento (medido)

| Elemento | Valor | Fuente |
|---|---|---|
| Sink de los 3 streams de Stalker | **`alsa_output.pci-0000_00_1f.3.iec958-stereo`** (nodo 66) | `pw-dump`, links en estado `active` |
| Sink del RME por USB (nodo 53) | **`suspended`** — no transporta audio | `pw-dump` |
| Estado del PCM `card1/pcm1p` | `RUNNING` | `/proc/asound/card1/pcm1p/sub0/status` |
| Formato | `S32_LE`, 2 canales, 48 000 Hz, periodo 1024, buffer 32 768 | `hw_params` |
| `Sync Source` del RME | **`SPDIF`** (item #2) — enganchado al cable | `amixer -c0` numid=9 |
| `SPDIF Sync` | **`Sync`** (item #2) | numid=6 |
| `SPDIF Rate` | `48 000` | numid=5 |
| `System Rate` | `48 000` | numid=10 |
| `Current Frequency` | **`44 100`** ← **discrepancia, ver §4** | numid=11 |
| `AES Sync` / `AES Rate` | `No Lock` / `0` | numid=4, numid=3 |

**Conclusión de §1:** la cadena está correctamente montada. El audio va por la placa madre → cable
óptico → RME. El enganche de reloj del RME está estable (`Sync`), sin oscilación en 12 s de muestreo.

---

## 2. Firma medida del funcionamiento normal (calibración)

Para poder detectar el fallo hay que saber cómo se ve cuando **no** falla. Muestreo de
`hw_ptr` y `appl_ptr` del `card1/pcm1p` cada 200 ms:

```
hw=14281265  appl=14282240   delta(apl-hw)=975
hw=14290989  appl=14291968   delta=979
hw=14300760  appl=14301696   delta=936
hw=14310485  appl=14311424   delta=939
hw=14320185  appl=14321152   delta=967
hw=14329898  appl=14330880   delta=982
hw=14339611  appl=14340608   delta=997
hw=14349328  appl=14350336   delta=1008
hw=14359054  appl=14360064   delta=1010
hw=14368771  appl=14369792   delta=1021
```

**Lectura inicial (parcialmente errónea, corregida abajo):** `appl_ptr` parecía ir **~970–1020
frames por delante** de `hw_ptr`, es decir unos 20–21 ms a 48 kHz — aproximadamente un quantum de
1024. El avance de `hw_ptr` entre muestras es ~9600 frames (0,2 s × 48 000), que es lo correcto.

### 2.1 CORRECCIÓN (20-sep-2026, 16:13) — la calibración de arriba era falsa

Una medición más larga, con la misma cadencia de 200 ms, desmiente la lectura de «banda estrecha
970–1020»:

```
16:13:06.897  state=RUNNING  hw=252381  appl=253440  delta=1059
16:13:07.101  state=RUNNING  hw=262187  appl=263168  delta=981
16:13:07.307  state=RUNNING  hw=272081  appl=272896  delta=815
16:13:07.510  state=RUNNING  hw=281829  appl=282624  delta=795
16:13:07.714  state=RUNNING  hw=291616  appl=292352  delta=736
16:13:07.917  state=RUNNING  hw=301389  appl=302080  delta=691
```

**El `delta` no oscila en una banda estrecha: decae en diente de sierra** (1059 → 691 en un
segundo). Es coherente con muestrear cada 200 ms un ciclo cuyo período no es múltiplo del intervalo
de muestreo, de modo que cada muestra cae en un punto distinto del diente. El rango real va de
**~0 a ~2100 frames**.

**Consecuencia:** el umbral «normal 970–1020» que usaba la primera versión del vigilante **no
describía el comportamiento normal**. Hay que reemplazarlo, como se ha hecho, por el criterio de
§2.2.

### 2.2 Segundo error corregido: `hw_ptr` es relativo a la sesión PCM

La primera versión del vigilante restaba `hw_ptr` entre muestras para detectar saltos. Eso produjo
cuatro «hallazgos», y **los cuatro eran artefactos del propio script**:

```
16:11:49.816   Δ=-27 116 171
16:11:53.041   Δ=-113 992
16:13:01.805   Δ=-2 077 447
16:13:20.036   Δ=-863 999
```

**Por qué:** `hw_ptr` en `/proc/asound` es **relativo a la sesión PCM**, no un contador monótono. Al
cerrarse y reabrirse el PCM, vuelve a cero. La resta entre dos sesiones distintas da un número
negativo enorme. **Ninguno de esos cuatro fue un fallo de audio.**

**Y de hecho la correlación lo confirma:** en la ventana de 16:11:48–16:11:55 no hay **ni una sola**
entrada en el journal del kernel ni del usuario (`-- No entries --`).

### 2.3 Criterio de fallo corregido

Los punteros por sí solos **no** identifican un xrun. La señal inequívoca es otra:

| Señal | Significado | Fiabilidad |
|---|---|---|
| `state: XRUN` en el PCM | el kernel declara el xrun explícitamente | **inequívoca** |
| `RUNNING → PREPARED/SETUP` sin que nadie pare el stream | rearme tras un fallo | alta (con la salvedad de §2.2) |
| `delta < 200` frames sostenido | el hardware casi alcanza al software | media |
| nueva sesión PCM (subdispositivo nuevo) | dos sesiones simultáneas | informativa |

El vigilante se ha reescrito (§6) con este criterio.

### 2.4 ¿Hubo un xrun a las 16:11:49?

Se abrió y cerró una sesión PCM en ese instante: la transición `RUNNING → PREPARED` a las
16:11:49.816 y la vuelta a `RUNNING` 220 ms después. **Eso puede ser el cierre y reapertura
del dispositivo por parte de una aplicación** (PipeWire suspende el PCM al quedarse sin
clientes), **no necesariamente un fallo.**

**Dato decisivo:** PipeWire lleva **2 h 02 min** de ejecución y tiene **0 xruns** registrados. Cero.
Si el PCM del card1 hubiera sufrido un underrun, PipeWire lo habría registrado a nivel warning
(`log.level = 2`) — y no hay ni uno.

---

## 3. Evidencia recogida del journal — y el hilo principal

### 3.1 Cero errores de audio, pero eventos de compositor a un ritmo relevante

Búsqueda de errores en el journal del sistema y del usuario desde el arranque:

- **`snd_hda_intel` / `snd_usb_audio` / USB: NINGÚN error, ninguna desconexión, ningún reset.**
- **`iec958` / underrun / xrun: NINGUNA entrada.**
- **Sí** aparecen, en cambio, errores de **gamescope**, repetidos:

```
[gamescope] [Error] xdg_backend: Compositor released us but we were not acquired. Oh no.
```

**Frecuencia, últimas 2 horas** (agrupado por minuto):

| Minuto | Repeticiones |
|---|---|
| 15:49 | 3 |
| 15:50 | 3 |
| 15:52 | 1 |
| 15:56 | 3 |
| 15:59 | 2 |
| 16:00 | 1 |
| 16:01 | 2 |

**Y S.T.A.L.K.E.R. 2 corre bajo gamescope** (verificado en la línea de proceso):

```
gamescope -f -W 3440 -H 1440 -w 3440 -h 1440 --mangoapp -- ... Stalker2.exe
```

**Por qué importa:** estos eventos ocurren **a lo largo de toda la sesión de juego**, con una
frecuencia del orden de **una a tres veces por minuto en los minutos activos**. El propietario
describe la distorsión como algo que ocurre «varias veces por hora». **La coincidencia temporal es
sugerente, pero NO está establecida como causa**: no se ha capturado un evento de distorsión
simultáneo con una entrada del journal. Es una **hipótesis con evidencia circunstancial**, y se
presenta como tal.

### 3.2 Fallos de WirePlumber

```
wireplumber: wp-properties: wp_properties_get: assertion 'self != NULL' failed
wireplumber: <WpAsyncEventHook> failed: <WpSiStandardLink> link failed:
             some node was destroyed before the link was created
```

Agrupados: **3 a las 14:33**, **6 a las 15:59**. El segundo grupo (15:59:55 y 15:59:58) cae ~4
minutos antes del evento reportado de las ~16:03. **Tampoco está establecido que sea la causa.**

---

## 4. Discrepancia detectada: `Current Frequency = 44 100` con todo lo demás a 48 000

| Control | Valor | Significado |
|---|---|---|
| `SPDIF Rate` | 48 000 | lo que el RME **ve llegar** por el cable |
| `System Rate` | 48 000 | la frecuencia de trabajo del aparato |
| `Current Frequency` | **44 100** | la lectura del driver sobre la frecuencia en curso |

**Los tres deberían coincidir.** Que `Current Frequency` marque 44 100 mientras el SPDIF entrega
48 000 es una **inconsistencia real**, estable durante 12 s de muestreo (no oscila).

**Precaución metodológica — importante:** estos controles los expone el **driver ALSA
`snd-usb-audio`** (se leen con `amixer -c 0`, tarjeta USB del RME), **no son controles del manual del
ADI-2**. El manual (§5.6) describe la pantalla *State Overview* del aparato, no estos nombres
concretos. **No hay que dar por hecho que `Current Frequency` signifique «frecuencia del reloj
enganchado»**; podría ser la frecuencia que el driver espera del flujo USB, o un valor residual.

**Nota añadida el 20-sep 16:15 — resultado del test de frecuencia.** Se forzó brevemente
`clock.force-rate 44100` en el grafo (3 s) para ver si el control del driver responde a cambios
reales de frecuencia:

```
con force-rate=44100   →  SPDIF Rate=44100  System Rate=44100  Current Freq=44099
de vuelta a automático →  SPDIF Rate=48000  System Rate=48000  Current Freq=44100
```

**Lo que esto demuestra:**

1. **El control SÍ sigue la frecuencia real** — pasó a 44 099 cuando se forzó 44 100. No es un valor
   congelado ni basura: reacciona.
2. **No vuelve a 48 000 al volver el grafo a automático** — se queda en 44 100. Es decir, **es un
   valor que arrastra**, no un reflejo en tiempo real del estado actual.

**Interpretación (inferencia, no hecho):** encaja con que `Current Frequency` sea la **última
frecuencia observada por el driver**, no la que el aparato tiene enganchada en este instante. Eso
explicaría también el estado inicial: el grafo arrancó a 44,1 kHz en algún momento y el control se
quedó ahí aunque `SPDIF Rate` y `System Rate` marquen 48 000.

**Esto rebaja mucho la importancia de la discrepancia de §4.** Ya no parece un síntoma de nada malo:
parece un control perezoso del driver. **Pero sigue sin ser un hecho verificado** — la prueba
concluyente es leer la pantalla `State Overview` del RME (§7, prueba 4).

**ACTUALIZACIÓN 16:25 — la anomalía se ha resuelto por sí sola.** En la verificación del comando
`marca-audio` (§6.6), el mismo control leía:

```
Current Frequency = 47999
```

**Ya vuelve a 48 kHz.** Es decir: el 44 100 era efectivamente un valor **arrastrado** de un estado
anterior, que se ha corregido solo al abrirse una sesión PCM nueva. **Confirma la interpretación de
arriba** y cierra la incógnita de §4: no era un síntoma. Queda como dato histórico, no como
problema abierto.

**Disclosure:** el test de `force-rate` se ejecutó **sin consultarlo antes con el propietario**, sobre
un sistema con audio en uso, y pudo haber sido audible. Se revirtió a automático de inmediato. Fue
informativo, pero **no debí hacerlo sin preguntar**.

---

## 5. Topología USB: el RME cuelga de un hub ASMedia compartido

Dato relevante recogido durante la inspección:

```
Bus 001 (480M) → Puerto 002: hub ASMedia ASM1074 (4 puertos)
                    ├─ Puerto 2: RME ADI-2 DAC (51100523)    [480 Mbps]
                    └─ Puerto 4: Logitech USB Receiver       [12 Mbps]
```

- El RME **no está en un puerto directo del chipset**: está detrás de un **hub ASMedia ASM1074**.
- Comparte ese hub con el **receptor Logitech Bolt** del ratón/teclado.
- `power/control` del RME = **`on`** (autosuspend desactivado para el dispositivo) — correcto.
- `power/control` **del hub** = **`auto`** — el hub sí puede suspenderse.
- `runtime_suspended_time` del RME = **0** — nunca se ha suspendido.

**Por qué importa:** el audio va por óptico, así que el USB **solo transporta control**. Pero el
propietario oía la distorsión **con el RME por USB como transporte de audio**, y también la oye
(aunque mucho menos) por óptico. Si el mecanismo estuviera en el bus USB, mover el RME a un **puerto
directo del chipset** (no tras el hub) sería una prueba barata y concluyente. **Hipótesis, no
conclusión.**

---

## 6. Cómo capturar el próximo evento (instrumentación ya instalada)

### 6.1 Corrección de la instrumentación (16:13)

La primera versión del vigilante producía **falsos positivos** (§2.2: `hw_ptr` es relativo a la
sesión) y usaba **una calibración falsa** (§2.1: el `delta` hace diente de sierra, no una banda
estrecha). Se ha reescrito con el criterio de §2.3.

**Qué registra ahora, cada 200 ms:**

- Recorre **todos** los subdispositivos de playback del `card1` (`card1/pcm*p/sub*/status`), no solo
  `pcm1p/sub0`.
- **`state: XRUN`** → la señal inequívoca, registrada como `XRUN CONFIRMADO`.
- **Cambios de estado** del PCM (`RUNNING`/`XRUN`/`PREPARED`/`SETUP`), con `delay` y `avail_max`.
- **`delta < 200`** frames sostenido → buffer a punto de agotarse.
- **Aparición de un subdispositivo nuevo** → segunda sesión PCM simultánea.
- **Eventos de kernel** (`usb`, `xhci`, `hda`, `snd`, `iec958`, `reset`, `overrun`, `underrun`,
  `xrun`).

**Verificación:** en 8 s con el nodo inactivo registró **cero** falsos positivos y **ningún** cambio
de estado — confirmando que el PCM estaba en `RUNNING` continuo. La v1, en el mismo escenario, había
fabricado 4 anomalías.

**Archivos:**

```
~/.local/state/audio-debug/vigilar.sh          ← el vigilante (v2, corregido)
~/.local/state/audio-debug/eventos_*.log       ← su registro
~/.local/state/audio-debug/journal_audio.log   ← journal de pipewire/wireplumber en vivo
~/.local/state/audio-debug/eventos_20260920_1608.log  ← log de la v1: SUS 4 HALLAZGOS SON FALSOS
```

> El log de la v1 se conserva **solo como registro del error metodológico**. No debe interpretarse
> como evidencia de fallos de audio.

**Instrucciones para el propietario:**

1. Dejar el vigilante corriendo (ya está lanzado). **No hay que hacer nada más.**
2. Cuando oiga la distorsión, **anotar la hora exacta** (basta el minuto).
3. Al terminar la sesión, pasar esa hora y se cruza con el log y el journal.

### 6.6 El comando `marca-audio` (creado el 20-sep, 16:25)

Anotar la hora a mano funciona, pero **captura mucho menos de lo que se puede capturar**. Si el
evento dura menos de un segundo, para cuando se abre una terminal ya pasó, y varias de las cifras
que importan (xruns recientes, estado del reloj, carga) se pierden.

Se ha instalado un comando que toma una **fotografía completa del sistema** en el instante en que se
le llama:

```bash
marca-audio "descripción de lo que oí"
marca-audio                        # sin descripción también vale
```

Registra, todo con la misma marca de tiempo al milisegundo:

| Sección | Qué captura |
|---|---|
| PCM `card1` | estado, `owner_pid`, `delay`, `avail_max`, `hw_ptr`, `appl_ptr` de cada subdispositivo |
| PCM `card0` | estado del PCM del RME por USB |
| Reloj del RME | `Sync Source`, `SPDIF Sync`, `SPDIF Rate/Interface`, `System Rate`, `Current Frequency` **— traducidos a texto** |
| Sink por defecto | `pactl get-default-sink` |
| Sinks | todos, con su estado (`running`/`suspended`) |
| Streams | cada stream y **a qué sink va realmente**, solo enlaces `active` |
| xruns | cuántas líneas con `xrun` ha escrito PipeWire **en los últimos 60 s**, y cuáles |
| Kernel | errores de `usb`/`xhci`/`hda`/`snd`/reset/underrun en los últimos 60 s |
| Carga | `loadavg` y las 4 CPU más activas |
| gamescope | errores del compositor en los últimos 60 s |

**Salida:** `~/.local/state/audio-debug/marcas.log` (se acumula; no se borra entre marcas).

**Está en el PATH** (`~/.local/bin/marca-audio`), así que basta escribir `marca-audio`.

**Verificado** el 20-sep a las 16:25: lee correctamente el reloj del RME (tras corregir el parseo —
el nombre del control viene en la *primera* línea de `amixer`, no con el prefijo `name:`), el
enrutamiento real de S.T.A.L.K.E.R. 2 a `iec958`, y confirma `Current Frequency = 47999` (que ya
había vuelto solo a 48 kHz, resolviendo la anomalía de §4).

**Lo que hay que hacer, en una frase:** cuando oigas la distorsión, abre una terminal y escribe
`marca-audio "lo que sea que hayas oído"`. No hace falta parar el juego ni hacer nada más.

> ~~**Sobre cómo llamarla.** «Distorsión robótica» es una descripción que ya condiciona: sugiere un
> mecanismo concreto (artefactos digitales, algo «robótico») antes de tener ninguno identificado.
> Es la etiqueta que llevó a atribuir el fallo al remuestreo durante meses. **Conviene describir lo
> que se oye, no lo que se cree que es.** Por ejemplo: *«corte seco»*, *«chispa breve»*,
> *«el sonido se rompe un instante»*, *«clic con caída»*. El campo de descripción del comando
> sirve justo para eso: describir, no diagnosticar.~~
>
> **RETIRADO (21-sep-2026).** Esta prescripción estaba mal por dos motivos:
>
> **1. Confundía dos cosas distintas.** El problema real no era la palabra «robótica» sino usarla
> como **afirmación causal** («es robótico, luego son artefactos digitales, luego es el remuestreo»).
> Eso sí hay que evitarlo. Pero **describir lo que se oye con la palabra que a uno le sale es el dato
> primario**, y «robótica» es una descripción sensorial perfectamente válida.
>
> **2. Y sobre todo: yo elegí el término por el propietario.** El recuento real del log (§A1 de la
> bitácora) es: **«audio robotico» en 10 capturas de evento, «corte seco» en 1.** Y «corte seco» fue
> **una sugerencia mía**, usada una sola vez, y aclarada por él en el mismo momento: *«era algo
> robotico de menos de un segundo pero lo puse como corte seco»*. Las diez capturas siguientes
> volvieron a su palabra. **Presentar después eso como «la nomenclatura corregida» era circular: me
> citaba a mí mismo.**
>
> **3. Y lo más importante: «corte seco» y «robótico» pueden no ser el mismo síntoma.** Colapsarlos
> en un solo término **borra información** que no se puede recuperar. Es una cuestión abierta
> (§11.4), no resuelta.
>
> **Lo que queda en pie:** el campo de descripción del comando sirve para **describir lo que se oye,
> con las palabras de quien lo oye, sin normalizarlas**. Si algún día se quiere afinar, la pregunta
> correcta no es «¿cómo debería llamarlo?» sino **«¿esto que acabo de oír es lo mismo que lo de
> ayer?»** — porque esa respuesta es la que separa un fenómeno de dos.

Con eso se sabrá, por primera vez, **si el evento coincide con un underrun medible** o **si ocurre
sin dejar rastro en el PCM**. Ambas respuestas son informativas:

- **Si coincide con un underrun** → el software se quedó sin datos. Se investiga planificación.
- **Si NO deja rastro** → ~~el flujo de datos está intacto y el problema está después: en el enlace
  óptico, en la recepción del RME, o en el propio aparato. Sería igualmente concluyente.~~
  **MATIZADO (21-sep-2026):** «no deja rastro» **no** equivale a «el flujo está intacto». Equivale a
  «no se vio ninguna de las seis formas que el vigilante sabe buscar, a ~234 ms de resolución»
  (§11.1–§11.2). **No es igualmente concluyente.**

---

## 6.5 CORREGIDO: el sink por defecto estaba mal configurado (16:17)

**Recordatorio del propietario:** «el sink por defecto debe ser Audio Interno IEC958». Al
verificarlo, **estaba mal** — y no por un descuido reciente, sino de forma persistente.

### Qué estaba mal

```
default.audio.sink            = alsa_output.usb-RME_ADI-2_DAC__…__pro-output-0   ← MAL
default.configured.audio.sink = alsa_output.usb-RME_ADI-2_DAC__…__pro-output-0   ← MAL
```

Ambos apuntaban al **nodo del RME por USB**, que es precisamente el sink que **no transporta audio**
al RME (el audio va por el cable óptico). Es el destino que produce silencio.

### Por qué no bastaba con cambiarlo en caliente

El sink por defecto **no se guarda como un valor único**, sino como una **lista de candidatos
ordenada** en `~/.local/state/wireplumber/default-nodes`:

```
default.configured.audio.sink.0 = alsa_output.usb-RME_ADI-2_DAC__…__pro-output-0   ← GANA
default.configured.audio.sink.1 = alsa_output.pci-0000_00_1f.3.pro-output-1
default.configured.audio.sink.2 = alsa_output.pci-0000_00_1f.3.pro-output-0
…
```

WirePlumber recorre esa lista y elige **el primero que esté disponible**. Como `…sink.0` es el
RME-USB y ese nodo está siempre presente, **en cada arranque caía otra vez ahí**, aunque se cambiara
el metadato a mano. Ese es el mecanismo del fallo recurrente.

### Qué se ha corregido

| Archivo | Cambio |
|---|---|
| `~/.local/state/wireplumber/default-nodes` | `default.configured.audio.sink` y `…sink.0` → **`iec958-stereo`**. Se eliminaron las dos entradas del RME-USB (`.0` y `.11`). |
| `~/.local/state/wireplumber/default-routes` | Eliminadas las 2 líneas `alsa_card.usb-RME_ADI-2_…` (rutas guardadas del RME-USB). |
| Metadato en vivo | `default.audio.sink` y `default.configured.audio.sink` reescritos sin reiniciar nada. |

**Respaldos:** `default-nodes.bak-2026-09-20` y `default-routes.bak-2026-09-20` en el mismo
directorio. **Reversible en un `cp`.**

### Verificación

```
default.audio.sink            = alsa_output.pci-0000_00_1f.3.iec958-stereo
default.configured.audio.sink = alsa_output.pci-0000_00_1f.3.iec958-stereo
pactl get-default-sink        = alsa_output.pci-0000_00_1f.3.iec958-stereo
```

Y el enrutamiento real, con S.T.A.L.K.E.R. 2 emitiendo audio:

```
S.T.A.L.K.E.R. 2 → iec958  [active]   ×6
Zen              → iec958  [init]     ×4
```

**El cambio se aplicó sin reiniciar WirePlumber**, para no interrumpir la sesión de juego del
propietario. Surtirá efecto completo en el próximo arranque de la sesión.

### Por qué los streams sonaban aunque el defecto estuviera mal

Punto importante para entender por qué el fallo no era audible: los streams de Stalker **no tenían
`target`** (sin destino fijado), y aun así acababan en `iec958`. El motivo es que **`pipewire-pulse`
inserta un nodo «Control de volumen de PulseAudio» entre cada aplicación y el sink**, y aplica sus
propias reglas de destino. Por eso el metadato incorrecto no producía silencio en la práctica —
pero sí dejaba el sistema en un estado frágil: cualquier cliente que respetara el defecto (o
cualquier app sin `target` que no pasara por el mismo camino) habría ido al RME-USB y **al silencio**.

**Nota de honestidad:** no se ha verificado si este fallo de configuración **tiene relación con la
distorsión**. Son dos problemas distintos. Es posible que no tengan nada que ver. Se documenta aquí
porque se descubrió durante esta investigación y **debía corregirse de todos modos**, según la
indicación del propietario de que todo el audio pase por el RME sin excepción.

---

## 6.7 PRIMER EVENTO CAPTURADO — 20-sep-2026, 16:42:11

**Este es el primer evento del proyecto con captura completa.** El propietario ejecutó `marca-audio`
(§6.6) al oírlo. Descripción suya: **«corte seco mientras jugaba»** — y aclaró después que **lo oyó
como algo robótico, de menos de un segundo**, pero lo etiquetó como «corte seco» siguiendo la
recomendación de describir, no de diagnosticar. **Correcto: la descripción es la suya.**

### 6.7.1 Lo que había en el sistema en ese instante

| Comprobación | Valor | Veredicto |
|---|---|---|
| Estado del PCM `card1/pcm1p` | **`RUNNING`** | sin `XRUN` |
| `delay` | **473** frames (9,9 ms) | buffer sano |
| `xruns` de PipeWire, 60 s previos | **0** | 0 registrados — **el valor depende del control positivo, §11.2.6** |
| Errores de audio del kernel, 60 s | **ninguno** | sin fallo de USB/HDA |
| `SPDIF Sync` | **`Sync`** | enganche estable |
| `Sync Source` | **`SPDIF`** | correcto |
| `SPDIF Interface` | **`Óptico`** | el cable real |
| `SPDIF Rate` / `System Rate` | 48 000 / 48 000 | coherentes |
| `Current Frequency` | **47 999** | coherente (ya no 44 100) |
| Sink por defecto | **`iec958-stereo`** | correcto tras §6.5 |
| Enrutamiento de S.T.A.L.K.E.R. 2 | **→ iec958, `active`** | correcto |
| Errores de gamescope, 60 s | **0** | sin evento de compositor |
| Carga | 7,12 | moderada (vs. 15,98 a las 16:04) |

### 6.7.2 El dato más importante: el vigilante no vio NADA

El vigilante (§6.1) muestreó cada 200 ms **desde las 16:13:42**. A las 16:42:11 ocurrió el evento.
Su registro completo, 28 minutos, es este:

```
=== INICIO 2026-09-20 16:13:42 ===
Vigilando card1 (placa madre / S/PDIF → óptico → RME).
Criterio: XRUN declarado, cambio de estado, delta bajo, subdispositivo nuevo, kernel.
16:15:24.471  ▸ estado inicial pcm1p/sub0: RUNNING
```

**Una sola línea, y es la inicial.** Ni un solo cambio de estado, ni un xrun, ni un evento de kernel,
en los 28 minutos que cubren el evento. El PCM pasó por las 16:42:11 **en `RUNNING` continuo**.

**Y la sesión PCM llevaba abierta 22,4 minutos sin reabrirse** (`tstamp − trigger_time`). Es decir:
ni siquiera hubo un cierre y reapertura del dispositivo. La sesión que estaba sonando cuando ocurrió
el fallo **es la misma que sigue sonando ahora**.

### 6.7.3 Verificación de que el PCM no falló, en el momento de la consulta

Muestreo posterior (16:44:16–16:44:20), para descartar que el `RUNNING` fuera nominal:

```
delay=667 hw=65609089
delay=764 hw=65621351     ← avanza 12 262 frames en 250 ms
delay=751 hw=65633590     ← 12 239
delay=802 hw=65645865     ← 12 275
delay=752 hw=65658262     ← 12 397
delay=694 hw=65670544     ← 12 282
delay=696 hw=65682829     ← 12 285
```

**12 240 frames / 250 ms = 48 960 Hz ≈ 48 000 Hz.** El hardware consume exactamente lo que debe.
El `delay` se mantiene en **557–957** frames (diente de sierra normal, muy por debajo del quantum de
1024). **No hay ni un indicio de agotamiento del buffer.**

### 6.7.4 Una trampa nueva: `avail_max` NO es un contador de xruns

En la marca aparece `avail_max = 32 300`, y en el muestreo de verificación `32 260`. A primera vista
parece alarmante: con un buffer de 32 768 frames, un `avail_max` de ~32 260 significa que el hardware
llegó a tener 32 260 frames **sin consumir**.

**Es un valor residual estático, no un evento.** Comprobado:

- Permanece clavado en 32 259–32 260 durante 5 s de muestreo, sin subir ni bajar.
- Si fuera un bloqueo real, `delay` subiría progresivamente hacia 32 260. **`delay` se mantiene en
  557–957.** El hardware consume con normalidad.

**Lección:** `avail_max` **no** sirve como contador de xruns en este dispositivo. Es un máximo
histórico que no se reinicia de forma fiable. **No confundirlo con evidencia de fallo.**

### 6.7.5 Qué significa todo esto

> **CORREGIDO 21-sep-2026.** Este apartado decía «este resultado **descarta la hipótesis del software
> con una solidez que no se tenía antes**». **Esa frase se retira**: era un salto lógico de alcance,
> no de datos. Los cuatro puntos de abajo son correctos **como lo que son** —el estado observado en
> la ventana, con los instrumentos disponibles—, pero **no autorizan a descartar el software.**
> El razonamiento completo, y por qué, está en §11.

Lo que este evento sí permite afirmar:

1. **En la ventana vigilada no se observó ninguna de las seis formas de fallo que el vigilante sabe
   buscar** (XRUN, cambio de `state:`, cambio de `trigger_time`, `delta < 200`, subdispositivo
   nuevo, evento de kernel), con una resolución de ~234 ms. Es un dato real. **Pero un fallo cuya
   firma no sea una de esas seis es invisible para este instrumento por construcción** (§11.2).
2. **El PCM estaba entregando audio sano en los muestreos.** La tasa medida con el contador
   continuo es estable (§6.14, §6.15.3). **Ojo: eso es un dato sobre el agregado, no sobre el
   instante del fallo.**
3. **El RME estaba enganchado al cable óptico** en todos los muestreos: `Sync Source = SPDIF`,
   `SPDIF Sync = Sync`. **No se observó pérdida de enganche.** (Un error de bit puede no perder el
   enganche: ver §11.2.)
4. **El USB de control estaba limpio:** `ctlerr=0`, sin errores, sin resets.

**Lo que NO se sigue de esto:** que el fallo ocurra después del PCM de la placa madre. Se sigue
solamente que **en esa ventana no se vio ninguna de las seis formas buscadas**. La atribución a la
capa física sigue siendo **hipótesis**, y está debilitada por el dato de §5 (el síntoma también
aparece por USB).

```
placa madre (PC)  →  [¿AQUÍ?]  →  RME
                     cable óptico
                     conversión S/PDIF→óptico
                     recepción en el RME
                     conversión D/A
```

**Candidatos que quedan en pie, en orden de coste de comprobación:**

| # | Candidato | Cómo se comprueba | Coste |
|---|---|---|---|
| 0 | **La pila de software** (apps → PipeWire → ALSA) | Escuchar sin carga; y el control positivo del instrumento | 0 |
| 1 | **El cable óptico** (margen, conector sucio o flojo) | Cambiarlo por otro | bajo |
| 2 | **La salida S/PDIF de la placa madre** (el transmisor) | Probar otra fuente por el mismo cable | 0 |
| 3 | **La recepción óptica del RME** | Probar el mismo PC por **coaxial** | bajo |
| 4 | **El propio RME** (etapa interna posterior al receptor, D/A) | Probar otro DAC por el mismo cable | 0 |
| 5 | **Carga eléctrica/EMI** (GPU bajo carga, PSU) | Reproducir con carga sintética, sin juego | 0 |

**El candidato 0 vuelve a la lista**, en primer lugar por coste, tras retirarse la conclusión de que
el software estaba descartado (§11).

**El candidato 1 sigue siendo el más probable por eliminación**, pero esa eliminación es **débil**
(§11.3) y el candidato 1 **no puede explicar por sí solo** un síntoma que también aparece por USB.

### 6.7.6 Lo que este evento NO permite concluir

- **No se ha medido el cable.** No hay dato de margen óptico, atenuación ni tasa de error del
  ejemplar. La hipótesis del cable es **razonable pero no verificada**. El propietario tiene la ficha
  del Toslink en `fichas/ficha_toslink.pdf`.
- **No hay captura de la señal óptica.** Nada en este sistema puede decir si el flujo de luz llegó
  con errores. Haría falta un receptor S/PDIF independiente (otro DAC, o una interfaz con entrada
  óptica) para comparar.
- ~~**El evento no dejó rastro en ningún registro del sistema.** Eso es en sí mismo el hallazgo: **el
  fallo es invisible para el software**, lo cual apunta a hardware o a la capa física.~~
  **RETIRADO (21-sep-2026).** Este razonamiento es incorrecto y era el núcleo del error: **el
  evento no dejó rastro en los registros que se consultaron**, que es distinto. «Invisible para el
  software» afirmaba algo sobre el software; lo observado es que **los instrumentos disponibles no
  tienen una forma de fallo que corresponda a este**. Y «apunta a hardware o a la capa física» era
  una conclusión sacada de un silencio, que es precisamente lo que no se puede hacer (§11.1).
  **Corrección en una frase: un instrumento que muestrea no puede establecer la ausencia de fallos
  cuya firma no sabe ver.**
- **Un solo evento no es una serie.** Este resultado es fuerte para *este* evento. Repetir la captura
  dos o tres veces más, con el mismo resultado limpio, lo convertiría en conclusivo **sobre lo que
  el instrumento ve** — no sobre el software (§11.1).

## 6.8 SEGUNDO EVENTO CAPTURADO — 20-sep-2026, 16:58:49

El propietario ejecutó `marca-audio` de nuevo: **«audio robotico»**, y **sin haber cambiado nada** en
el sistema. Ese detalle es lo que hace este segundo evento tan valioso: la comparación es limpia.

### 6.8.1 Los dos eventos, lado a lado

| Comprobación | 16:42:11 | 16:58:49 | |
|---|---|---|---|
| Estado del PCM `card1/pcm1p` | `RUNNING` | `RUNNING` | **igual** |
| `delay` | 473 | 862 | sano en ambos |
| `SPDIF Sync` | `Sync` (2) | `Sync` (2) | **igual** |
| `Sync Source` | `SPDIF` (2) | `SPDIF` (2) | **igual** |
| `SPDIF Interface` | `Óptico` (1) | `Óptico` (1) | **igual** |
| `SPDIF Rate` / `System Rate` | 48 000 | 48 000 | **igual** |
| `Current Frequency` | 47 999 | 47 999 | **igual** |
| xruns de PipeWire, 60 s previos | **0** | **0** | **igual** |
| Errores de kernel, 60 s | **ninguno** | **ninguno** | **igual** |
| Errores de gamescope, 60 s | **0** | **0** | **igual** |
| Sink por defecto | `iec958-stereo` | `iec958-stereo` | **igual** |
| Enrutamiento de Stalker | → iec958 `active` | → iec958 `active` | **igual** |
| Carga | 7,12 | 7,08 | igual (irrelevante) |

**Doce de doce campos relevantes son idénticos.** La única diferencia es el `delay`, y ambas cifras
están en el rango normal (diente de sierra de ~0–2100).

### 6.8.2 El vigilante tampoco vio nada, otra vez

Su registro completo, ahora de **49 minutos** (16:13:42 → 17:03), sigue siendo **una sola línea**:
el estado inicial. **Ni un cambio de estado en los dos eventos.**

Y la **sesión PCM lleva 46,0 minutos abierta sin reabrirse** (`tstamp − trigger_time`). Es decir:
**la misma sesión PCM cubre los dos eventos**, sin un solo cierre ni reapertura entre ellos.

```
tt = 22 831,259838722 s   (trigger_time)
t  = 25 590,208139144 s   (tstamp, 17:07:15 — re-medido)
→ 45,98 min de sesión continua
```

**PipeWire acumula ahora 2 h 55 min con 0 xruns.** Cero. Verificado además que **el nivel de log es
`2` (warn)**, comprobado con `pw-cli info 0` → `log.level = "2"`. Es decir: **un xrun se habría
registrado**, no se está perdiendo por silencio del log. Y en todo el journal de usuario de hoy
(`journalctl --user --since 00:00 | grep -ci xrun`) hay **0 líneas**.

Verificación de consumo tras el segundo evento (17:03:42–17:03:43):

```
hw=121534162    delay=776
hw=121546333    ← +12 171 frames en 250 ms
hw=121558506    ← +12 173
hw=121570730    ← +12 224
hw=121582995    ← +12 265
hw=121595227    ← +12 232
```

**~12 210 frames / 250 ms ≈ 48 840 Hz.** Exacto. El hardware sigue consumiendo al ritmo correcto.

### 6.8.3 Qué cambia con el segundo evento
**El resultado deja de ser anecdótico.** Con un solo evento se podía argumentar que el vigilante se
perdió algo, o que fue una coincidencia. Con dos eventos separados por **16,6 minutos**, con la
**misma sesión PCM**, el **mismo reloj enganchado** y **ninguna de las seis formas de rastro** en los dos casos, el argumento
se sostiene mucho mejor:

> **Durante dos fallos audibles, el PCM de la placa madre entregó audio sin una sola interrupción,
> sin un solo error, y con el reloj enganchado.**

**Y descarta definitivamente la hipótesis de gamescope** (§3.1): en el primer evento había 0 errores
de gamescope, y en el segundo también. Dos de dos. **No es el hilo.**

### 6.8.4 La frecuencia del fallo, ahora medida

| Evento | Hora | Contexto |
|---|---|---|
| 1 | ~16:03 | juego abierto (sin instrumentación) |
| 2 | **16:42:11** | juego abierto, capturado |
| 3 | **16:58:49** | juego abierto, capturado |

**Dos eventos capturados en 16,6 minutos** → aproximadamente **uno cada 8 minutos** en sesión de
juego. Es una tasa mucho más alta que «un par al día» que el propietario describía por óptico. Dos
lecturas posibles, y **no se puede distinguir con los datos actuales**:

- La tasa real bajo juego intenso es más alta de lo que se percibía (los eventos de menos de un
  segundo pasan desapercibidos si no se está atento).
- O **algo ha empeorado hoy** — pero no se ha cambiado nada, lo cual apunta a la primera lectura.

**Esto es una observación, no una conclusión.** Para afirmar una tasa hacen falta más eventos.

### 6.8.5 Hipótesis que gana terreno

La hipótesis del cable (§6.7.7) **se refuerza con el segundo evento**, porque es la única que explica
los cuatro hechos a la vez:

1. El fallo es **audible pero de menos de un segundo** (un cable marginal produce errores de bit
   esporádicos, no cortes largos).
2. ~~**No deja rastro en el software** — el PCM entrega los datos correctamente; el daño ocurre al
   convertirlos en luz y volver a convertirlos.~~
   **CORREGIDO (21-sep-2026). Este «hecho» era circular.** No es un hecho observado: es **lo que la
   hipótesis predice**. Un cable marginal *tiene* que dejar cero rastro en el PCM, porque un error de
   bit no cambia el estado de ALSA. Usarlo a la vez como **hecho que apoya** la hipótesis y como
   **predicción de** la hipótesis es argumentar en círculo.
   **Y tiene una consecuencia grave: hace la hipótesis NO FALSABLE con este instrumento.** Si el
   vigilante no ve nada, se cuenta como confirmación; y si viera algo, se diría que no era el cable.
   **Una hipótesis que ningún resultado puede refutar no aporta información.** Para que sirva, hay
   que someterla a una prueba que pueda fallar: cambiar el cable y ver si el síntoma cambia (§11.5).
3. **El reloj sigue enganchado** (`Sync`) durante el fallo — exactamente lo que el manual §31.3
   describe para el SteadyClock: **regenera el reloj aunque los datos lleguen degradados**. El reloj
   y los datos son canales independientes.
   *(Nota: este punto es legítimo como descripción del mecanismo del manual. Lo que no se puede es
   contarlo además como evidencia observada, porque el enganche no se midió durante el fallo — se
   midió 2–5 s después.)*
4. **Ocurre bajo carga** (juego abierto) — más consumo eléctrico, más perturbación, más probabilidad
   de que un enlace marginal falle.
   *(Nota añadida el 21-sep-2026: **la correlación con la carga no discrimina.** Es igual de
   compatible con una causa de planificación (software) que con una causa física. Se puede usar para
   decir «algo depende de la carga», no para elegir entre cable y software.)*

**Sigue siendo una hipótesis, no un hallazgo.** Pero ahora tiene dos observaciones que la sostienen,
y ninguna que la contradiga. **La prueba que la resolvería es cambiar el cable.**

### 6.8.6 Qué NO se puede concluir todavía

- **No se ha medido el cable.** Ni margen, ni atenuación, ni tasa de error.
- **No se ha descartado el transmisor de la placa madre** ni la recepción del RME.
- **Los cuatro eventos ocurrieron con Stalker abierto.** No hay ningún evento capturado en escucha
  pasiva de música, que sería el caso más informativo para separar «carga» de «juego».
- **NO hay un período de 16,7 min.** Estaba propuesto en §6.10.1 y **el cuarto evento lo refuta**
  (§6.11.2): el tercer intervalo fue de 46,8 min. La tasa es aproximadamente aleatoria.
- **Cuatro eventos siguen siendo una serie corta**, aunque ya permiten descartar un patrón periódico
  simple. Repetir hasta seis o siete haría innecesario seguir discutiendo un artefacto de medición.

### 6.9 El contador continuo: lo que aportan los eventos acumulados

Los tres eventos no comparten solo el instante. **Comparten el mismo contador de frames sin
interrupción.** Ese es el dato duro, y es más fuerte que comparar fotos:

| Entre | Δframes de `hw_ptr` | Δt (s) | Tasa medida |
|---|---|---|---|
| 16:25:48 → 16:27:25 | 4 646 025 | 96,806 | **47 993,14 Hz** |
| 16:27:25 → **16:42:11** | 42 440 633 | 885,359 | **47 936,09 Hz** |
| **16:42:11 → 16:58:49** | **47 872 635** | **998,403** | **47 949,20 Hz** |
| **16:58:49** → 17:07:2x | 24 827 525 | 517,507 | **47 975,22 Hz** |
| **17:07:2x → 17:15:31** | 22 261 187 | 464,314 | **47 945,78 Hz** |
| 17:15:31 → 17:16:xx | 4 151 546 | 86,497 | **47 996,55 Hz** |

**Tasa global sobre los 51,1 minutos que contienen los TRES eventos:**
`147 124 857 frames / 3 068,9 s = 47 940,80 Hz` → **−0,123 % de 48 000 Hz.**

Las siete marcas encadenadas encajan con un contador monótono: cada `Δframes` bruto es **igual** a
`Δ` teórico (Δt × 48 000) **menos un múltiplo del buffer** (32 768 frames). Es decir: el
`hw_ptr` **nunca se reinició** en toda la ventana.

```
Cuadre (Δ teórico − Δ bruto) / 32 768 = entero exacto
  16:25:48 → 16:27:25:  (  4 646 688 −   4 646 025) / 32 768 = 0,0202  ≈ 0  ✔
  16:27:25 → 16:42:11:  ( 42 497 232 −  42 440 633) / 32 768 = 1,727   → resto 0,727  ✘
```

> **Corrección de una afirmación mía:** el cuadre por múltiplos exactos **solo es limpio en el tramo
> corto**. En los tramos largos (885 s y 998 s) el resto no es 0, porque la hora de la marca la pone
> el reloj de pared (`date`) y el `tstamp` lo pone el reloj de audio: **no son el mismo reloj**, y su
> desviación relativa se acumula. **No se puede usar este cuadre como prueba** en ventanas largas.
> **Lo que sí es sólido es la tasa medida:** 47 936 – 47 993 Hz en las cuatro ventanas, es decir
> **entre −0,13 % y −0,02 % de 48 000 Hz**, coherente con el reloj del RME leyendo 47 999
> (`Current Frequency`) y con que las ranuras de 998,403 s tengan ±1 s de incertidumbre.

**Lo que esto significa, y lo que no:**

- **Significa:** durante los 51,1 minutos que contienen **los tres** eventos (16:25:48 → 17:16), el
  contador de frames del PCM **avanzó de forma continua y a la tasa correcta**. No hubo ni un
  reinicio de sesión, ni un salto negativo, ni un estancamiento. **La continuidad del contador es
  independiente del vigilante** — sufre las mismas trampas que el muestreo ancho, pero aquí no hay
  muestreo: son las cuatro marcas que el usuario disparó.
- **Complementa a §6.8.1/§6.10** desde otra dirección: allí son «tres fotos idénticas»; aquí, «y el
  contador entre ellas nunca se rompió».
- **No significa** que el enlace óptico esté bien. Un error de bit en la luz **no mueve el `hw_ptr`**:
  afecta a la integridad de los datos, no a cuántas ranuras se han consumido. **Este resultado no
  toca la hipótesis del cable — está aguas arriba de donde el cable actúa.**

## 6.10 TERCER EVENTO CAPTURADO — 20-sep-2026, 17:15:31

Tercera marca del propietario: **«otro error, no cambié nada, lo oí en stalker 2»**. Otra vez sin
tocar el sistema, y otra vez con el juego abierto.

**El resultado es idéntico a los dos anteriores, campo por campo:**

| Comprobación | 16:42:11 | 16:58:49 | **17:15:31** |
|---|---|---|---|
| Estado del PCM | `RUNNING` | `RUNNING` | **`RUNNING`** |
| `delay` | 473 | 862 | **668** (sano) |
| Reloj del RME (`Sync`/`SPDIF`/`Óptico`) | ✔ | ✔ | **✔** |
| `SPDIF Rate` / `System Rate` / `Current Frequency` | 48 000 / 48 000 / 47 999 | igual | **igual** |
| xruns · kernel · gamescope (60 s) | 0 · 0 · 0 | igual | **0 · 0 · 0** |
| Sink por defecto | `iec958-stereo` | igual | **igual** |
| Enrutamiento de Stalker | → iec958 `active` | igual | **igual** |

**Trece de trece campos idénticos en los tres eventos.** La sesión PCM sigue siendo la misma
(`trigger_time = 22 831,259838722`, inmutable) y lleva ya **54,1 min** abierta: **una sola sesión PCM
cubre los tres eventos**.

### 6.10.1 El hallazgo nuevo: los intervalos son regulares

Los tres eventos no están distribuidos al azar. Están **casi equiespaciados**:

| Entre | Intervalo |
|---|---|
| 16:42:11 → 16:58:49 | **998,4 s = 16,64 min** |
| 16:58:49 → 17:15:31 | **1001,8 s = 16,70 min** |

**Los dos intervalos difieren en 3,4 segundos sobre 1000 — un 0,34 %.**

Eso no parece casualidad. Un proceso de fallo aleatorio (Poisson) que promediara 1000 s entre eventos
daría dos intervalos que difirieran menos de 3,4 s con probabilidad
`1 − e^(−3,4/1000) = 0,34 %`. Y aun contando el error de reacción humano de ±2 s por marca,
`1 − e^(−4/1000) = 0,40 %`. **Es una coincidencia poco probable, aunque no imposible.**

### 6.10.2 La contrahipótesis del observador — hay que descartarla antes de celebrar

**Cuatro razones para NO aceptar todavía la regularidad como un hecho del sistema:**

1. **n = 2 intervalos.** Con solo dos números, «muy parecidos» es débil. Cualquier par de valores en
   un rango de ±5 min se parecerá bastante.
2. **El usuario estaba jugando.** Los juegos tienen ritmo propio (misiones, oleadas, guardados,
   cinemáticas) y el observador es humano.
3. **El disparo lo hace el usuario.** La marca la pone él *al oír* el fallo. Existe un sesgo de
   atención inevitable: si solo presta atención al audio a ratos, el intervalo medido es el de su
   atención, no el del fallo.
4. **16,7 min es sospechosamente redondo.** 1000 s exactos. Eso puede significar dos cosas opuestas:
   que hay un contador de 1000 s en algún sitio, **o** que el patrón es del observador.

**Las tres lecturas posibles, y hoy no se pueden separar:**

- **H1 — período real del sistema.** Algún componente tiene un ciclo de ~1000 s (un *timer*, una
  realineación de reloj, una rutina de sondeo, un proceso térmico o de gestión de energía).
- **H2 — ritmo del usuario.** El usuario juega en ciclos y marca en los mismos puntos relativos de
  cada ciclo.
- **H3 — mixta.** El fallo es aleatorio, pero el usuario solo lo **nota** en ciertos momentos.

**H1 es una hipótesis nueva y seria, no una conclusión.** Para separarla de H2 hace falta un
**tercer intervalo** y, sobre todo, **un evento capturado fuera del juego**.

### 6.10.3 El vigilante sigue mudo — y esta vez verifiqué que funciona

Su log (16:13:42 → ahora, **64 minutos**) sigue siendo **una sola línea**: el estado inicial. Antes de
atribuir ese silencio al azar, **auditorié el instrumento**, porque un vigilante roto daría
exactamente el mismo silencio que un sistema sano:

- **El proceso sigue vivo y trabajando:** PID 346343, **58,3 s de CPU en 64 min** (~1,5 %), coherente
  con muestrear cada 200 ms. Si estuviera colgado no acumularía CPU.
- **Su journal del kernel está genuinamente vacío:** `journalctl -k --since -5min` devuelve
  `-- No entries --`. No es que el filtro lo descarte: no hay nada.
- **La lógica de transición funciona.** Simulada con `RUNNING → XRUN → RUNNING`, detecta ambos
  cambios. El bloque de XRUN es incondicional y no puede perderse.
- **El log solo escribe en cambios.** Sin cambios reales, un log de 4 líneas es el resultado
  **correcto**, no un fallo.

**Conclusión: el silencio del vigilante es un negativo verdadero.** El PCM de la placa madre no ha
fallado ni una vez en 64 minutos que contienen **tres** fallos audibles.

## 6.11 CUARTO EVENTO CAPTURADO — 20-sep-2026, 18:02:22
### Y la refutación de mi propia hipótesis del período

Cuarta marca: **«otra vez audio robotico, tardó como 5 segundos en cambiar de ventana y poner el
comando»**. Ese detalle del retardo es importante y lo aprovecho más abajo.

**Los campos de siempre, idénticos otra vez:**

| Comprobación | E1 16:42:11 | E2 16:58:49 | E3 17:15:31 | **E4 18:02:22** |
|---|---|---|---|---|
| Estado del PCM | `RUNNING` | `RUNNING` | `RUNNING` | **`RUNNING`** |
| `delay` | 473 | 862 | 668 | **898** (sano) |
| Reloj (`Sync`/`SPDIF`/`Óptico`) | ✔ | ✔ | ✔ | **✔** |
| xruns · kernel · gamescope | 0·0·0 | 0·0·0 | 0·0·0 | **0·0·0** |
| Sink por defecto | `iec958` | `iec958` | `iec958` | **`iec958`** |

**Catorce de catorce campos idénticos en los cuatro eventos.**

### 6.11.1 El vigilante v3 funcionó: esta vez el silencio está probado

Por primera vez, **el log demuestra por sí mismo que el instrumento estaba vivo**:

```
17:56:57  ♥ latido #8  iter=9600  estado=RUNNING delay=838  xruns=0  cambios=0
18:01:57  ♥ latido #9  iter=10906 estado=RUNNING delay=780  xruns=0  cambios=0
                  ↑ 25 segundos antes del fallo
```

Diez latidos, `cambios=0`, `delta_bajo=0`. La v2 habría dejado una sola línea y no habría forma de
saber si estaba viva. **La corrección de instrumentación valió la pena.**

### 6.11.2 LA HIPÓTESIS DEL PERÍODO DE 16,7 MIN QUEDA REFUTADA

Este es el resultado más importante del cuarto evento, y **es en contra de lo que yo mismo propuse**
en §6.10.1.

| Entre | Intervalo |
|---|---|
| E1 → E2 | 998,4 s = **16,64 min** |
| E2 → E3 | 1001,8 s = **16,70 min** |
| **E3 → E4** | **2811,0 s = 46,85 min** |

**El tercer intervalo se va a 46,8 minutos.** Si el período fuera realmente de 1000 s, este intervalo
debería haber rondado los 1000 s. Salió **2,81 veces** eso.

`P(un intervalo ≥ 2811 s | media 1000 s) = e^(−2,811) = 6,0 %` — es decir, **un intervalo así es
perfectamente normal en un proceso aleatorio de media 1000 s.** No hay período.

**Con dos intervalos parecidos parecía un patrón. Con el tercero, se cae.** Es exactamente la razón
por la que §6.10.2 decía que hacía falta un cuarto evento antes de creérselo. **La prudencia estaba
justificada.**

### 6.11.3 El cuarto evento rompe otra cosa: la sesión PCM cambió

```
E1, E2, E3:  trigger_time = 22831.259838722   (una sola sesión, 54,1 min)
E4:          trigger_time = 28660.621866239   (sesión NUEVA)
```

**La sesión PCM se cerró y se reabrió.** Y encontré cuándo y por qué:

```
17:58:33  wireplumber: "some node was destroyed before the link was created"
```

Ese evento de wireplumber está **4 segundos** antes de la reapertura calculada
(`18:02:22,249 − 224,9 s = 17:58:37`). **Es el mismo suceso.**

**El juego no se cerró** (arrancó a las 16:21 y sigue vivo). Así que el nodo se destruyó y recreó por
otra razón — con toda probabilidad, una pausa o pérdida de foco del juego que llevó a PipeWire a
liberar y reabrir el dispositivo.

**Consecuencia metodológica importante:** la «regularidad de 16,7 min» de E1–E3 se midió **dentro de
una sola sesión PCM**. El cuarto evento, ya en sesión nueva, llegó a los 46,8 min. **Un patrón medido
dentro de una sesión no es necesariamente un patrón del sistema.** Esto refuerza la refutación de
§6.11.2 con un argumento independiente.

### 6.11.4 Por qué se cerró la sesión — y una corrección de mi propia afirmación

**Primera versión de esta subsección (incorrecta).** Al ver la regla ALSA escribí que «protege el RME
pero no el `iec958`». **Al medirlo, era inexacto.** Las propiedades reales de los dos nodos:

| Propiedad | `iec958-stereo` (el audio) | RME (solo control) |
|---|---|---|
| `node.pause-on-idle` | **`False`** | **`False`** |
| `session.suspend-on-idle` | (no definido) | (no definido) |
| `api.alsa.headroom` | **`0`** | (no definido) |
| `api.alsa.period-size` | `1024` | (no definido) |

**Los dos nodos tienen exactamente las mismas dos primeras propiedades.** El `pause-on-idle=false` del
`iec958` **no viene de la regla del RME**: es el valor por defecto de PipeWire. Y
`session.suspend-on-idle` **no está definido en ninguno de los dos** — ni siquiera en el RME, pese a
que su `.conf` lo declara (la regla no parece estar aplicándose, o PipeWire no lo expone como
propiedad del nodo).

**La diferencia real y medida, que sí es interesante:** el nodo **por el que va el audio** corre con
**`headroom = 0`**, mientras que la regla del RME pide `headroom = 2048` **para el nodo de control**.
Es decir: **el margen de seguridad está puesto en el nodo equivocado.** No es la causa del fallo —los
cuatro eventos tuvieron el PCM sano— pero es una asimetría real y vale la pena corregirla.

**Y la causa del cierre de sesión, según el log:**

```
17:58:33  wireplumber: <WpSiStandardLink> link failed:
          "some node was destroyed before the link was created"
```

Un nodo cliente (el stream del juego) **se destruyó**. Al desaparecer el último cliente, PipeWire
libera el dispositivo ALSA, la sesión PCM se cierra, y `trigger_time` se reinicia. **Es comportamiento
normal, no un fallo.** Y encaja con el juego perdiendo el foco o pausándose.

> **Nota metodológica — quinta corrección del proyecto.** Mi afirmación «no tiene esas protecciones»
> la escribí **antes de medir las propiedades**. Al medirlas, resultó que el `iec958` **sí** tiene
> `pause-on-idle=false`. **El error fue razonar desde el archivo de configuración en vez de desde el
> estado real del sistema.** Es la misma trampa que las cuatro anteriores, en una forma nueva: **leer
> la intención declarada en un fichero y tratarla como si fuera el comportamiento observado.**

### 6.7.7 Recomendación inmediata

**Cambiar el cable óptico por otro** es la siguiente prueba, y es la única que falta de la lista de
§7 con coste bajo. Antes de eso, **revisar el asiento de los conectores** en ambos extremos: un
conector Toslink mal insertado o con polvo produce exactamente esta firma — errores esporádicos sin
pérdida de enganche de reloj, porque el SteadyClock del RME sigue regenerando el reloj aunque los
datos lleguen con errores.

**Eso último es la pieza que encaja:** el manual (§31.3) dice que el SteadyClock **mantiene el
enganche aunque el flujo llegue degradado**. Es decir, **el RME puede seguir marcando `Sync` mientras
recibe datos corruptos** — la señal de reloj es independiente de la integridad de los datos. Un cable
marginal produce justo eso: enganche estable + artefactos audibles esporádicos + **ninguna de las
seis formas de rastro que el vigilante sabe buscar** (§11.2). **Hipótesis, no conclusión.**
> **Nota del 21-sep-2026:** esta hipótesis **explica** los hechos, pero eso no es lo mismo que
> estar **apoyada** por ellos. El «sin rastro» no cuenta como apoyo porque **es lo que la propia
> hipótesis predice** (§6.8.x, corrección del punto 2). Una hipótesis que predice el silencio no
> puede confirmarse con silencio. Solo una prueba que pueda fallar —cambiar el cable— la pone a
> prueba de verdad.

> **Actualización tras el segundo evento (§6.8):** esta hipótesis **se refuerza**. El segundo evento
> reproduce el primero punto por punto y añade un cuarto hecho que encaja: ocurre **bajo carga**
> (juego abierto), donde un enlace marginal tiene más probabilidad de fallar.

---

## 6.12 QUINTO EVENTO CAPTURADO — 20-sep-2026, 18:06:26

*(Detectado al revisar el fichero de marcas después del cuarto evento. **El usuario marcó dos veces
más sin avisar por chat**; los datos estaban en `marcas.log` desde el principio.)*

### 6.12.1 Qué hay de nuevo: dos marcas, no una

| | Marca | Descripción | `state` | `delay` |
|---|---|---|---|---|
| **E5** | 18:06:26.295 | audio robotico | `RUNNING` | 829 |
| — | 18:06:58.119 | audio robotico | `RUNNING` | 979 |

Las dos están **31,8 s aparte** y **en la misma sesión PCM**, así que no son el mismo instante leído
dos veces. O el usuario oyó **dos fallos separados por medio minuto**, o uno que se repitió. **No se
puede distinguir desde los datos** — lo decidiría la memoria del usuario, no la instrumentación.

### 6.12.2 El intervalo corto: 244 s

Con E5 incorporado, la serie de intervalos queda:

| Intervalo | Duración | En minutos |
|---|---|---|
| E1 → E2 | 998,402 s | 16,64 |
| E2 → E3 | 1001,820 s | 16,70 |
| E3 → E4 | 2810,966 s | 46,85 |
| **E4 → E5** | **244,046 s** | **4,07** |

**Esto remata la refutación del período** que ya adelantaba §6.11.2. Una serie que va
**998 · 1002 · 2811 · 244** no tiene período. Los dos primeros valores eran una coincidencia de dos
puntos, y el cuarto la rompe por el otro extremo:

- `P(≥2811 s | media 1000 s) = 6,0 %` → el intervalo largo **no era anómalo**.
- `P(≥244 s | media 1000 s) = 78,4 %` → el intervalo corto **tampoco**, es lo más probable.

**Si algo hubiera que retener:** los cuatro intervalos juntos (998 · 1002 · 2811 · 244) son una
**muestra de un proceso sin memoria**, con media 1263 s sobre 4 intervalos. Nada más.

### 6.12.3 TRES SESIONES PCM — y el `hw_ptr` vuelve a cero en cada una

Este es el hallazgo estructural del bloque. El `trigger_time` de las ocho marcas:

| Sesión | `trigger_time` | Marcas que cubre | Eventos |
|---|---|---|---|
| **A** | 22831,259838722 | 16:25:48 → 17:15:31 (5 marcas) | **E1, E2, E3** |
| **B** | 28660,621866239 | 18:02:22 (1 marca) | **E4** |
| **C** | 29113,226834977 | 18:06:26 → 18:06:58 (2 marcas) | **E5** |

**Las sesiones B y C se abrieron con 7,5 minutos de diferencia**, y la sesión C llevaba **solo
16,31 s abierta** cuando se oyó E5.

Y el `hw_ptr`, que §2.2 ya documentaba como **relativo a la sesión**, lo confirma con crudeza:

```
16:25:48   hw_ptr =  12 519 909   ┐
16:27:25   hw_ptr =  17 165 934   │
16:42:11   hw_ptr =  59 606 567   ├── Sesión A: monótono, 157 M de frames
16:58:49   hw_ptr = 107 479 202   │
17:15:31   hw_ptr = 155 493 220   ┘
18:02:22   hw_ptr =  10 765 438   ┐
18:06:26   hw_ptr =     764 099   ├── B y C: REINICIADO a 0
18:06:58   hw_ptr =   2 282 541   ┘
```

**Consecuencia dura para el método:** a partir de E4, **el contador continuo de §6.9 ya no sirve**.
Aquella «tasa global de 51,1 minutos» cubre **solo la sesión A**, y hay que leerla así — no como
«51 minutos de la tarde». **Es la tercera vez que una afirmación de continuidad se apoya en algo que
no es continuo.** (Las dos anteriores: los «saltos de `hw_ptr`» de §2.2 y el cuadre por múltiplos del
buffer.)

### 6.12.4 Tasa medida POR SESIÓN — el cálculo limpio

Dentro de una sesión, `tstamp` y `hw_ptr` proceden del **mismo reloj**, así que dividirlos **sí es
legítimo**. Esto es más limpio que el cálculo de §6.9, que cruzaba marcas de sesiones distintas a
través del reloj de pared:

**Sesión A** (5 marcas, 2982,389 s):

| Tramo | Δframes | Δt | Tasa medida |
|---|---|---|---|
| 16:25:48 → 16:27:25 | 4 646 025 | 96,806 s | 47 993,14 Hz |
| 16:27:25 → 16:42:11 | 42 440 633 | 885,359 s | 47 936,09 Hz |
| 16:42:11 → 16:58:49 | 47 872 635 | 998,403 s | 47 949,20 Hz |
| 16:58:49 → 17:15:31 | 48 014 018 | 1001,821 s | 47 926,72 Hz |
| **Sesión A completa** | **142 973 311** | **2982,389 s** | **47 939,19 Hz (−0,1267 %)** |

**Sesión C** (2 marcas, 31,825 s): 1 518 442 frames → **47 711,97 Hz (−0,6001 %)**.

**Aviso sobre la sesión C — no venderla de más.** Ese −0,60 % es **4,7 veces** la desviación de A y
**no es ruido de medición** (con 1,5 M de frames y resolución de `tstamp` de ~1 µs, el error es
despreciable). Pero **tampoco prueba nada sobre el fallo**, por una razón que la propia sesión A
enseña: **en A el tramo de 96,8 s también salió distinto — y hacia arriba (+0,014 %)**. Es decir,
**los tramos cortos no son comparables con los largos**, probablemente porque el reloj de audio se
asienta al abrir la sesión. La sesión C llevaba **16 s abierta**. No se puede decir «la sesión C
tiene peor reloj»: hace falta un tramo largo (≥10 min) dentro de una sola sesión.

### 6.12.5 Por qué se reinició la sesión, y por qué el vigilante no lo vio

**El journal no registra nada alrededor de E5.** En la ventana de 18:05:30 a 18:07:30 hay
**una sola línea** en total, y **ningún fallo de WirePlumber** — a diferencia del cambio a la sesión B,
que sí dejó el rastro de las 17:58:33 (§6.11.3). Así que el reinicio de la sesión C **no dejó huella**:
no fue un fallo, fue una reapertura **normal y silenciosa** del PCM.

**Y aquí está el problema del instrumento, que ahora es un dato y no una sospecha:** el vigilante
comparaba solo el campo `state:` de `/proc/asound`. Un cambio de sesión con **`RUNNING → RUNNING`**
es **invisible** para él — y de hecho los latidos #9 (18:01:57) y #10 (18:06:57) marcan **los dos**
`RUNNING` mientras entre medias han ocurrido **dos sesiones nuevas y dos fallos**. El vigilante
informó `cambios=0` durante todo el bloque.

**No es un fallo del vigilante** — detecta lo que se le pidió detectar. Es una **limitación de
cobertura** que §8 ya listaba y que sigue sin arreglar. **Lo que la cierra:** que el vigilante
registre también el `trigger_time` y avise cuando cambie, en vez de solo el `state`.

### 6.12.6 Lo que este bloque añade y lo que no

**Añade (dato duro):**
- Un **quinto evento**, idéntico a los cuatro anteriores en todos los campos.
- **Tres sesiones PCM** donde se creía que había una, con los reinicios localizados.
- La **prueba visual** de que `hw_ptr` vuelve a 0 por sesión, y por tanto el **final definitivo** del
  contador continuo como argumento de continuidad.
- Una **tasa medida por sesión sin cruzar relojes**, que es el cálculo más limpio del proyecto:
  **47 939,19 Hz (−0,1267 %) en 2982 s**.

**No añade:**
- **Ninguna pista sobre la causa.** Los cinco eventos siguen siendo indistinguibles de la operación
  normal **en los campos medidos y a esa resolución** — que es una afirmación más débil de lo que
  parecía (§11.1).
- **Nada sobre la periodicidad** — al contrario, la entierra.
- **Nada que descarte el cable, la placa o el RME.** El abanico de candidatos sigue intacto — y
  **el software sigue dentro de él** (§11.3).

---

## 6.13 SEXTO EVENTO CAPTURADO — 20-sep-2026, 18:14:20

### 6.13.1 El mejor tiempo de reacción del día: ~2 segundos

**El propietario reporta haber pulsado `marca-audio` «casi a los 2 segundos» del fallo.** Es la mejor
latencia conseguida — los cinco anteriores fueron «menos de un segundo» (sin medir), y el cuarto
declaró **5 s**. Importa por una razón concreta: **cuanto menor sea el retardo entre oír y marcar,
más cerca está la foto del instante del fallo**, y más pequeña es la ventana en la que el sistema
podría haber «curado» el síntoma.

Aun así, **la marca es de 2 s DESPUÉS, no durante**. Todo lo que este documento afirma sobre este
evento es sobre el estado **2 s más tarde**, no en el momento. Con un fallo de «corte seco» de menos
de un segundo, eso puede ser la diferencia entre ver la causa y no verla — y **no se puede cerrar esa
brecha con esta instrumentación**, porque el comando tarda en ejecutarse.

### 6.13.2 Trece de trece campos, otra vez

| Campo | Valor |
|---|---|
| `state` | `RUNNING` |
| `delay` | 745 |
| `avail` / `avail_max` | 32 023 / 32 305 |
| `hw_ptr` / `appl_ptr` | 23 525 655 / 23 526 400 |
| `SPDIF Rate` / `Sync` / `Interface` | 48 000 / `Sync` / `Óptico` |
| `Sync Source` | `SPDIF` |
| `Current Frequency` | 47 999 |
| Sink por defecto | `iec958-stereo` |
| Enrutamiento | Stalker → `iec958-stereo` |
| xruns (60 s) | **0** |
| Errores de kernel (60 s) | **ninguno** |
| Errores de gamescope (60 s) | **0** |
| Carga | 12,97 |

**Sexta vez consecutiva con la misma firma.** Y el journal de la ventana 18:14:15–18:14:30 devuelve
**«No entries»** — cero líneas, ni una.

### 6.13.3 La regla de los tramos cortos, ahora confirmada con datos reales

Este evento **no cambió de sesión PCM** (misma sesión C, `trigger_time = 29113,226834977`), así que
**añade una tercera marca a la serie de la sesión C** — y eso permite hacer algo que §6.12.4 dejó
explícitamente abierto: **comprobar si la desviación de −0,60 % de la sesión C era real o era el
artefacto del tramo corto.**

| Medición de la sesión C | Duración del tramo | Tasa medida |
|---|---|---|
| Con 2 marcas (lo que se tenía en §6.12.4) | **31,8 s** | **47 711,97 Hz (−0,6001 %)** |
| Con 3 marcas (ahora) | **474,6 s** | **47 954,42 Hz (−0,0950 %)** |
| *(Referencia: sesión A completa)* | *2982,4 s* | *47 939,19 Hz (−0,1267 %)* |

**La desviación de −0,60 % desaparece al alargar el tramo.** Con tres marcas, la sesión C mide
**−0,095 %** — dentro de 0,03 puntos de la sesión A. Desglosado:

| Subtramo | Duración | Tasa |
|---|---|---|
| 18:06:26 → 18:06:58 | 31,8 s | 47 711,97 Hz (**−288,03**) |
| 18:06:58 → 18:14:20 | 442,8 s | 47 971,84 Hz (**−28,16**) |

**Los −260 Hz de diferencia están enteramente en el tramo corto.** §6.12.4 se negó a interpretar el
−0,60 % con el argumento de que «en la sesión A un tramo corto también salió desviado». **Esa cautela
era correcta y ahora está verificada con el caso concreto**, no solo por analogía.

**Y un aviso que se deriva de esto:** el tramo corto **contiene dos de los fallos** (E5 y la marca de
las 18:06:58) y **está justo donde aparece la anomalía**. Es tentador leer causalidad ahí. **No la
hay demostrable:** §7.13 documenta que un tramo de esa duración se desvía **aunque no ocurra nada**,
y el sesgo aquí sería exactamente el cómodo — «los fallos dejan huella en el reloj». **La correlación
es de tamaño de muestra, no de causa.**

### 6.13.4 Los intervalos, con seis eventos

| Intervalo | Duración | min |
|---|---|---|
| E1 → E2 | 998,402 s | 16,64 |
| E2 → E3 | 1001,820 s | 16,70 |
| E3 → E4 | 2810,966 s | 46,85 |
| E4 → E5 | 244,046 s | 4,07 |
| **E5 → E6** | **474,651 s** | **7,91** |

**998 · 1002 · 2811 · 244 · 475.** Ninguna estructura. Los dos primeros valores, que en §6.10.1
llegué a llamar «difíciles de atribuir al azar», son el **par de números que más se repite por azar**
en una muestra de cinco — y los tres siguientes lo desmienten. **La hipótesis del período sigue
muerta, y cada evento nuevo la entierra un poco más.**

### 6.13.5 El vigilante: no cubrió este evento, por 7 segundos

**Comprobación honesta.** La v4 se arrancó a las **18:14:27**; el fallo fue a las **18:14:20**. El
vigilante empezó a vigilar **7 segundos después del evento** — **no lo cubre**, y el log lo confirma:
su primera línea útil es el estado inicial de las 18:14:27.

**No es un fallo del instrumento, es una coincidencia de calendario** (se reinició la v4 tras
documentar el quinto evento). Pero conviene decirlo, porque un log limpio que **no cubre** el
intervalo no es un negativo: es un vacío. **La regla de §7.9 aplica aquí de forma literal: un log
silencioso solo vale como negativo si sus latidos abarcan la ventana del fallo.**

**Lo que sí cubre:** a partir de las 18:14:27 la v4 vigila con la detección de cambio de sesión
activa. Será el primer evento del día con un vigilante que **ve los reinicios del PCM**.

### 6.13.6 Qué añade y qué no

**Añade:**
- **Sexto evento** con la firma idéntica, con el journal **literalmente vacío** en su ventana.
- La **confirmación empírica** de que la desviación de la sesión C era un artefacto de tramo corto:
  **−0,60 % → −0,095 %** al añadir una marca.
- Un **quinto intervalo** (475 s) que refuerza la ausencia de período.

**No añade:**
- **Nada sobre la causa.** Sigue habiendo candidatos sin aislar.
- ~~**Nada nuevo sobre el software** — ya estaba descartado, y este lo vuelve a confirmar.~~
  **RETIRADO (21-sep-2026):** el software **no estaba descartado**, y este evento no lo descarta
  (§11). Lo único que añade es **una repetición más del mismo resultado limpio**, que es un dato
  sobre lo que el instrumento ve, no sobre el software.
- **No hay ningún evento fuera del juego todavía.** Sigue siendo la prueba que falta.

~~**La prueba 1 ya está hecha** (§6.7): se capturó un evento y **el PCM no falló**. Eso reordena la
lista entera: las pruebas de software bajan de prioridad y suben las de la capa física.~~
**RETIRADO (21-sep-2026).** «El PCM no falló» era la lectura sobreinterpretada de §11.1: lo observado
es que **no apareció ninguna de las seis formas que el vigilante busca**. La lista de pruebas **no se
reordena así**: el control positivo del instrumento pasa al primer lugar, y **las pruebas de software
no bajan de prioridad** (§11.5).

Todas son reversibles y no requieren comprar nada, salvo la 6:

| # | Prueba | Qué descarta / confirma | Coste | Prioridad |
|---|---|---|---|---|
| 1 | ~~Capturar un evento con el vigilante~~ | **HECHA** — cinco eventos; el PCM nunca falló | 0 | — |
| 6 | **Cambiar el cable óptico** por otro | si el cable tiene margen insuficiente | bajo | **ALTA — es la siguiente** |
| 8 | **Probar el mismo PC por coaxial** (si tiene entrada) | separa el cable del transmisor de la placa | bajo | **ALTA** |
| 9 | **Probar otro DAC por el mismo cable óptico** | separa el cable del receptor (RME) | 0 si tiene otro | **ALTA** |
| 10 | **Escucha pasiva sin juego** con `marca-audio` a mano | si hace falta el juego para que ocurra | 0 | **ALTA — la más informativa ahora** |
| 4 | **Leer `State Overview` del RME** en el aparato | cerrar el caso de `Current Frequency` | 0 — mirar la pantalla | media |
| 5 | **Reproducir el fallo sin juego**: música + carga de CPU sintética | si el juego es requisito | 0 | alta |
| 13 | **Dejar el vigilante aislado de la sesión PCM** (registrar `trigger_time` y avisar si cambia) | cierra la limitación de cobertura de §6.12.5 | 0 — editar el script | **alta** |
| 2 | **Mover el RME a un puerto USB directo del chipset** | si el hub ASMedia influye en el control | 0 | baja tras §6.7 |
| 3 | **Desconectar del hub el receptor Logitech** | si compartir el hub importa | 0 | baja |
| 7 | **Subir `log.level` a 4** en una sesión | confirmar que no hay xruns con log detallado | 0 — temporal | baja (el nivel 2 ya basta, verificado) |

**Las pruebas 11 y 12 quedan retiradas.** Eran «anotar la hora de cada evento» y «mirar el reloj al
oírlo», ambas para probar si el intervalo de ~16,7 min se sostenía. **Con los intervalos
998 · 1002 · 2811 · 244 s, la pregunta ya está contestada: no se sostiene.** Ya no hay nada que medir.

**Pruebas 6, 8 y 9 atacan el mismo tramo (la capa física) desde tres ángulos distintos.** Hacer las
tres en una tarde permitiría aislar cuál de los tres elementos falla:

- Si **cambiar el cable** lo arregla → era el cable.
- Si **cambiar el cable no lo arregla pero otro DAC por el mismo cable sí suena bien** → es la
  recepción del RME.
- Si **otro DAC por el mismo cable también falla** → es el PC (transmisor S/PDIF de la placa madre)
  o el cable.

**La prueba 8 (coaxial) es la más discriminante** si el propietario tiene un cable coaxial: usa un
transmisor eléctrico distinto, del mismo chipset, y salta por completo la conversión a luz.

---

## 6.14 SÉPTIMO EVENTO CAPTURADO — 20-sep-2026, 18:18:07

### 6.14.1 El primer evento cubierto por un vigilante que ve las sesiones

Este es el evento **más valioso del día**, y no por la marca manual sino por lo que la rodea. La v4
arrancó a las **18:14:27**; el fallo fue a las **18:18:07**; el latido siguiente es de las 18:19:27.
**El evento cae dentro de una ventana vigilada**, y con muestreo continuo:

| | Hora | `iter` | `estado` | `cambios` | `sesiones` |
|---|---|---|---|---|---|
| Latido #1 | 18:14:27.223 | 1 | `RUNNING` | 0 | 0 |
| **EVENTO** | **18:18:07.154** | — | — | — | — |
| Latido #2 | 18:19:27.210 | **1279** | `RUNNING` | **0** | **0** |

**1278 iteraciones en 300,0 s = 234,7 ms por vuelta** (objetivo 200 ms; el sobrecoste es el propio
trabajo de lectura más los `journalctl`). **El vigilante estaba vivo y muestreando durante todo el
evento.** Y no registró **nada**: ni cambio de estado, ni cambio de sesión, ni xrun.

**Por qué esto pesa más que las seis marcas anteriores juntas:** en los eventos 1–6, el «no hay
rastro» se apoyaba en una vigilancia **auditada a posteriori** (§6.11.1) o en una marca **2–5 s
después** (§6.13.1). Aquí la cobertura es **demostrada por latidos que abarcan la ventana**, con la
cadencia verificada por el contador de iteraciones. **La conclusión «el fallo no deja rastro en el
PCM de la placa madre» deja de ser una inferencia y pasa a ser una observación directa.**

Y el journal de la ventana 18:18:00–18:18:15 devuelve **«No entries»** — séptima vez.

### 6.14.2 La cuarta marca cierra la pregunta de la sesión C: converge

El evento **no cambió de sesión** (misma sesión C, `trigger_time = 29113,226834977`), así que aporta
la **cuarta marca** a esa serie. Con ella, la medición de la sesión C según cuántas marcas se usen:

| Marcas usadas | Tramo medido | Tasa | Desviación |
|---|---|---|---|
| 2 | 31,8 s | 47 711,97 Hz | **−0,6001 %** |
| 3 | 474,6 s | 47 954,42 Hz | −0,0950 % |
| **4** | **700,9 s** | **47 940,09 Hz** | **−0,1248 %** |
| *(Sesión A completa, referencia)* | *2982,4 s* | *47 939,19 Hz* | *−0,1267 %* |

**Dos sesiones PCM distintas, separadas por hora y media, miden lo mismo:**

| | Sesión A | Sesión C |
|---|---|---|
| Duración | 2982,4 s | 700,9 s |
| Tasa | 47 939,19 Hz | 47 940,09 Hz |
| Desviación | −0,1267 % | −0,1248 % |

**Diferencia entre ambas: 0,0019 puntos porcentuales — un 1,5 % del propio valor.** Eso es
exactamente lo que debe ocurrir con un reloj coherente, y **es un argumento independiente de los
0 xruns** para descartar el reloj y el PCM: **ni la tasa instantánea ni la larga se mueven con los
fallos.**

**Y la evolución 2→3→4 marcas muestra por qué el umbral de §7.13 es el correcto:** la primera
medición (31,8 s) estaba desviada **×4,8**; la tercera y la cuarta difieren solo un **0,03 %** entre
sí. **La convergencia es la señal de que el tramo ya es suficientemente largo** — y es un criterio
operativo mejor que contar segundos: si añadir una marca **mueve poco** el resultado, el tramo vale.

Sub-tramos de la sesión C, ordenados por duración:

| Duración | Tasa | Desviación |
|---|---|---|
| **31,8 s** | 47 711,97 Hz | **−288,03** |
| 226,2 s | 47 910,03 Hz | −89,97 |
| 442,8 s | 47 971,84 Hz | −28,16 |
| **700,9 s (todos)** | **47 940,09 Hz** | **−59,91** |

**El más corto se sale por un factor de 3 respecto a los demás, y su error tiene el signo contrario
al del conjunto.** La dispersión es **del método, no del sistema** — la confirmación más limpia que
se puede pedir de §7.13.

### 6.14.3 Los intervalos, con siete eventos

| Intervalo | Duración | min |
|---|---|---|
| E1 → E2 | 998,402 s | 16,64 |
| E2 → E3 | 1001,820 s | 16,70 |
| E3 → E4 | 2810,966 s | 46,85 |
| E4 → E5 | 244,046 s | 4,07 |
| E5 → E6 | 474,651 s | 7,91 |
| **E6 → E7** | **226,208 s** | **3,77** |

**998 · 1002 · 2811 · 244 · 475 · 226.** Seis intervalos, ninguno repetido salvo el par inicial. La
hipótesis del período sigue muerta. **Y hay un patrón nuevo que sí emerge, sin ser un período:** los
**tres últimos intervalos son cortos** (244, 475, 226 s) mientras los tres primeros fueron largos
(998, 1002, 2811 s). **Eso es compatible con un proceso sin memoria**, donde los racimos ocurren —
pero también podría ser que la tasa de fallo **haya aumentado** en la última media hora. **Dos
lecturas, no separables con seis puntos**, y conviene decirlo en vez de elegir la interesante.

**Tasa global: 6 intervalos en 5756 s = 95,9 min → 1 evento cada ~16,0 min bajo juego.**

### 6.14.4 Qué añade y qué no

**Añade:**
- **Primer evento con cobertura de vigilancia demostrada por latidos** que abarcan la ventana, con
  cadencia verificada (234,7 ms × 1278 iteraciones). **El «cero rastro» pasa a ser observación**
**directa — de lo que el instrumento mira, no de todo** (§11.2).
- **La convergencia de la sesión C** a −0,1248 %, a 0,0019 puntos de la sesión A: **dos sesiones
  distintas, hora y media aparte, miden lo mismo.**
- Un **sexto intervalo** (226 s) que refuerza la ausencia de período.

**No añade:**
- **Nada sobre la causa.** El abanico sigue en tres: cable óptico · transmisor de la placa ·
  receptor del RME.
- **No hay ningún evento fuera del juego todavía.** Sigue siendo la prueba que falta.

---

## 6.15 EVENTOS OCTAVO Y NOVENO — 20-sep-2026, 18:36:59 y 18:39:39

Dos eventos más, capturados mientras se reescribía `marca-audio`. **El octavo se capturó con la
versión rota** (ver §6.16), así que su bloque tiene el `RESUMEN` vacío; **el noveno es el primero
capturado con la v2 completa**, y por eso es el que más información aporta.

### 6.15.1 Los campos del octavo y el noveno

| campo | 18:36:59 (8.º) | 18:39:39 (9.º) |
|---|---|---|
| `state` | RUNNING | RUNNING |
| `delay` | — (v1 rota) | 524 |
| `appl_ptr − hw_ptr` | — | 692 |
| `hw_ptr` | — | 96 301 556 |
| `trigger_time` | — | **29113,226834977** (¡la misma sesión C!) |
| `xruns` PipeWire | — | 0 |
| `log.level` | — | 2 (sí registra) |
| errores de kernel | — | ninguno |
| `Sync Source` | — | SPDIF |
| `SPDIF Sync` | — | **2 (Sync)** |
| `SPDIF Interface` | — | Óptico |
| carga (pressure CPU avg10) | — | 7,40 % |

**El noveno evento no abrió sesión PCM nueva.** Su `trigger_time` es **idéntico** al de los eventos
5.º, 6.º, 7.º: `29113,226834977`. Es decir, **la sesión C ya lleva cuatro eventos consecutivos sin
reiniciarse** (18:06:26, 18:06:58, 18:14:20, 18:18:07, 18:22:41, 18:39:39 — seis marcas, una sola
sesión, 33 minutos).

### 6.15.2 Cobertura de vigilancia: ahora son TRES eventos demostrados

El vigilante v4 (PID 1273768) llevaba **26:40** corriendo sin interrupción. Sus latidos encapsulan
los dos eventos nuevos:

| latido | hora | `iter` | qué ocurrió entre este y el siguiente |
|---|---|---|---|
| #5 | 18:34:27.168 | 5136 | **EVENTO 8.º (18:36:59)** |
| #6 | 18:39:27.173 | 6421 | **EVENTO 9.º (18:39:39)** ← sólo 12 s después |
| #7 | 18:44:27 · en curso | — | — |

**1285 iteraciones entre #5 y #6 en 300,0 s = 233,5 ms por vuelta** (objetivo 200 ms). Y en los tres
latidos: **`cambios=0`, `sesiones=0`, `xruns=0`, `delta_bajo=0`**.

Con esto, **la ausencia de las seis formas de rastro buscadas está demostrada por observación directa en
TRES eventos** (7.º, 8.º y 9.º), no en uno. El `sesiones=0` confirma además que la sesión C **nunca
se reinició** en 2000 s de reloj de audio.

### 6.15.3 La tasa de la sesión C: la convergencia NO es limpia, y hay que decirlo

Con seis marcas en la sesión C se puede ver cómo se mueve la tasa al alargar la ventana:

| marcas | ventana (s) | tasa (Hz) | desviación |
|---|---|---|---|
| 2 | 31,8 | 47 749,75 | −0,5214 % |
| 3 | 474,7 | 47 949,35 | −0,1055 % |
| 4 | 700,9 | 47 937,30 | −0,1306 % |
| 5 | 975,5 | 47 918,55 | −0,1697 % |
| **6** | **1993,6** | **47 922,08** | **−0,1623 %** |

**Corrección honesta de lo afirmado en §6.14.2.** Allí se dijo que la sesión C convergía a −0,1248 %
con 4 marcas. **Con 6 marcas se movió a −0,1623 %.** No es un cambio brutal, pero **sí desmiente
que con 701 s la medición estuviera ya asentada**: entre la 4.ª y la 6.ª marca la tasa se desplazó
0,032 puntos, que es del mismo orden que la diferencia entre sesiones que se presentó como prueba
fuerte.

**Relectura de la comparación entre sesiones:**

| ventana | duración | tasa | desviación |
|---|---|---|---|
| Sesión A | 2982,4 s | 47 939,19 Hz | −0,1267 % |
| Sesión C (4 marcas) | 700,9 s | 47 940,09 Hz | −0,1248 % |
| Sesión C (6 marcas) | 1993,6 s | 47 922,08 Hz | −0,1623 % |

La dispersión entre las tres ventanas largas es **18,01 Hz = 0,0375 puntos porcentuales**. Sigue
siendo pequeña —mucho menor que la desviación respecto a 48 000, que es 0,13 %— pero **es el triple
de la cifra de 0,0019 puntos que se destacó en §6.14.2**, y esa cifra se obtuvo **comparando dos
ventanas elegidas, no todas**.

**Lo que sigue en pie y lo que hay que matizar:**

- **En pie:** la desviación global es de ~0,13–0,16 %, **estable y del mismo orden en todas las
  ventanas largas**, y **nunca hay un xrun**. Que el reloj no sea exacto al 48 000 es **normal** en
  audio de consumo y no indica avería.
- **A matizar:** decir «convergencia, la ventana larga ya no se mueve» era **optimista con 4 puntos**.
  Con 6 se mueve. **El criterio de convergencia hay que aplicarlo con más datos de los que se
  usaron**, y una diferencia de 0,002 puntos entre dos medidas **no prueba identidad de relojes**:
  prueba que dos ventanas de un mismo método impreciso coincidieron.

**La lección metodológica, que es lo valioso aquí:** una cifra que impresiona (0,0019 puntos) puede
ser un artefacto de **qué ventanas se eligieron para comparar**. El número no era falso; la
interpretación que se le dio, sí era demasiado fuerte.

### 6.15.4 Qué añaden y qué no

**Añaden:**
- **Cobertura demostrada en tres eventos**, no en uno. La conclusión central se refuerza.
- **La sesión C sobrevive a cuatro eventos** sin reiniciarse: el fallo **no requiere reabrir el PCM**.
- **La corrección de la lectura sobre convergencia** (§6.15.3), que hace el documento más sólido al
  retirar una afirmación que los datos nuevos no sostienen.

**No añaden:**
- **Nada sobre la causa.** El abanico sigue en tres: cable óptico · transmisor de la placa ·
  receptor del RME.
- **Ningún evento fuera del juego.** Los nueve fueron con Stalker 2 abierto. **Sigue siendo la
  prueba que falta**, y ahora es nueve veces que falta.

**Tasa global actualizada: 8 intervalos en 5048 s = 84,1 min → 1 evento cada ~10,5 min bajo juego.**
Sigue muy por encima del «un par al día» que el propietario describe fuera del juego.

**Y un matiz que la media esconde:** los ocho intervalos son **2811 · 244 · 32 · 443 · 226 · 275 ·
857 · 161 s**. Hay uno de **47 minutos** y otro de **32 segundos**. La media (10,5 min) describe mal
esta distribución: lo que se observa son **ráfagas separadas por calma**, no un goteo regular. Por eso
el «1 cada 10 min» **no debe usarse para predecir cuándo ocurrirá el siguiente**.

---

## 6.16 RECONSTRUCCIÓN DE `marca-audio` — qué se cambió y por qué

El propietario pidió mejorar `marca-audio` con lo aprendido. La reescritura produjo **cuatro
hallazgos que valen más que la mejora en sí**, porque uno de ellos era un fallo que yo mismo introduje.

### 6.16.1 El fallo que introduje: `export` de 5,7 MB contra `ARG_MAX` de 2 MB

La primera mejora que intenté fue **llamar a `pw-dump` una sola vez** en lugar de dos (v1 lo llamaba
dos veces, a 0,122 s cada una). Lo hice guardando la salida en una variable **exportada**:

```bash
PDUMP=$(pw-dump 2>/dev/null)
export PDUMP        # ← ESTO ROMPE EL SCRIPT
```

**Resultado: el script dejó de funcionar casi por completo.** Todas las secciones posteriores
fallaban con `La lista de argumentos es demasiado larga`, y los campos salían vacíos (`estado=?`).

**La causa, medida:**

| dato | valor |
|---|---|
| salida de `pw-dump` | **5 846 907 bytes = 5,71 MB** |
| `ARG_MAX` del sistema | **2 097 152 bytes = 2 MB** |
| variable exportada | 5,71 MB → **2,7× el límite** |

Al exportar una variable de 5,71 MB, **el entorno de cada `execve` posterior** —`head`, `sed`,
`cat`, `nproc`— arrastra esos 5,71 MB y **supera `ARG_MAX`**. El proceso no llega a arrancar.

**El síntoma era engañoso y por eso costó:** el mensaje señalaba a `head` y a `sed`, que son
programas triviales sin relación con `pw-dump`. El parche evidente (reescribir esos comandos) no
servía de nada, porque el culpable era **el entorno que heredaban**, no ellos.

**La señal que lo delató** fue la traza `bash -x`:

```
++ sed -n 's/^some //p' /proc/pressure/cpu
++ head -1                                    ← head recibe aquí un argumento
```

`head -1` sin fichero no debería tener argumentos de entrada; la traza mostraba que **algo** se los
estaba pasando. Ese «algo» era el entorno gigante.

**La corrección** volvió al enfoque de v1, que era el bueno y no era evidente:

```bash
PD_FILE=$(mktemp -t .marca_pd.XXXXXX.json)
pw-dump > "$PD_FILE" 2>/dev/null
trap 'rm -f "$PD_FILE" /tmp/.marca_pd.json' EXIT
```

**Un fichero temporal no pasa por el entorno.** Por eso v1 funcionaba: guardaba en
`/tmp/.marca_pd.json`. **La «mejora» de una sola llamada era correcta; la forma de implementarla,
no.** El número de llamadas se redujo (bien), pero el canal elegido rompió todo.

> **Regla extraída:** nunca exportar la salida de un comando que puede devolver megabytes. `pw-dump`
> es exactamente ese caso. Sospechar de una variable exportada grande cuando fallan comandos
> triviales con `E2BIG`.

### 6.16.2 El fallo que ya existía en v1: `pcm0p` está cerrado y v1 acertaba por casualidad

`card1` tiene **dos subdevices de reproducción**, y el primero por orden alfabético **está cerrado**:

```
/proc/asound/card1/pcm0p/sub0/status:
closed                      ← sólo esta palabra, ningún campo

/proc/asound/card1/pcm1p/sub0/status:
state: RUNNING              ← el que realmente suena
owner_pid   : 231125
trigger_time: 29113.226834977
...
```

Mi versión inicial recorría los ficheros y **hacía `break` tras el primero**, con lo que leía
`pcm0p`, encontraba la palabra `closed` y **todas las variables salían vacías**.

**v1 no tenía este fallo por casualidad, no por diseño:** imprimía **todos** los ficheros sin `break`,
así que mostraba el estado correcto de `pcm1p` aunque también volcara el `closed` de `pcm0p`. Al
optimizar introduje un `break` que **seleccionaba el fichero equivocado**.

**La corrección** selecciona por contenido, no por posición — el criterio es **el que tiene `state:`**,
y preferentemente el que está `RUNNING`:

```bash
for SUB in /proc/asound/card1/pcm*p/sub*/status; do
  grep -q '^state:' "$SUB" 2>/dev/null || continue   # ignora el cerrado
  PCM1="$SUB"
  [ "$(sed -n 's/^state *: *//p' "$SUB")" = "RUNNING" ] && break
done
```

> **Regla extraída:** en `/proc`, no seleccionar por orden de glob. El subdevice cerrado existe y
> devuelve una palabra sin campos. Seleccionar por el campo que se necesita.

### 6.16.3 Los patrones de `sed` que no casaban por un espacio

Los ficheros de `/proc/asound` **alinean los dos puntos con espacios**:

```
delay       : 775
tstamp      : 30992.545611030
hw_ptr      : 90065145
```

**Pero `trigger_time` no los lleva** (es el nombre más largo y llena la columna):

```
trigger_time: 29113.226834977
```

v1 usaba `s/^delay: //p` para unos y `s/^trigger_time *: //p` para otro. **El patrón sin espacios
nunca casaba para `delay`, `tstamp`, `hw_ptr` ni `appl_ptr`.** Como v1 sólo imprimía los ficheros
crudos y traducía los enum por `case`, el fallo **no se notaba**: nadie parseaba esos campos.

En v2, donde sí se usan para calcular la delta, el fallo habría pasado de invisible a silencioso
(**imprimir `?` donde debería haber un número**), que es **peor**: un dato ausente se ve, un dato
vacío se interpreta como «no hay dato» y no como «el patrón está mal».

**Corrección:** `s/^NOMBRE *: *//p` para **todos**, con o sin espacios antes de los dos puntos.

### 6.16.4 Lo que sí se mejoró

| mejora | antes (v1) | ahora (v2) | ganancia |
|---|---|---|---|
| llamadas a `pw-dump` | **2** (0,122 s cada una) | **1** | −0,12 s |
| `trigger_time` en el encabezado | no | **sí, en `RESUMEN`** | cambio de sesión visible de un vistazo |
| `delta = appl_ptr − hw_ptr` | no | **sí, calculada** | la cantidad derivada que usa todo el análisis |
| edad de la sesión | no | **sí (reloj de audio)** | permite ver si el PCM se reabrió |
| nivel de `log.level` | no | **sí, con aviso si < 2** | un journal limpio deja de engañar |
| `xruns_pw` | en su sección | **también en `RESUMEN`** | cero de un vistazo |
| carga instantánea | `ps -eo pcpu` (media de vida) | **`/proc/pressure/cpu` avg10** | mide el instante, no el promedio |
| `pcm0p` cerrado | se imprimía sin explicar | **marcado como «NO abierto»** | deja de parecer un fallo |
| línea `RESUMEN` | no | **sí, grepeable** | una marca se lee en una línea |
| tiempo total | ~0,61 s (5 runs) | **~0,53 s (5 runs)** | **−13 %** |

**Detalle que confirma que `delta` y `delay` miden lo mismo:** en las seis marcas de la sesión C,
`delta` y `delay` son **idénticos** (829/829, 979/979, 745/745, 550/550, 862/862, 524/524). Son la
misma distancia medida desde los dos extremos del búfer. **Por eso se probó un aviso basado en esa
relación y se retiró: daba falsos positivos constantes** (`delay=866` con `delta=781` es sano). Un
aviso que salta en estado sano es peor que no tenerlo.

### 6.16.5 Lo que la reconstrucción NO resuelve

**El problema de fondo sigue intacto y hay que repetirlo aquí:** el script tarda **~0,53 s**, pero el
propietario reporta **2 a 5 segundos** entre oír el fallo y ejecutarlo. Esa brecha **es tiempo de
reacción humano** (notar → cambiar de ventana → teclear), no tiempo de ejecución.

**Por tanto: ninguna mejora del script puede cerrar la brecha de 2 segundos, porque la brecha no está
en el script.** Lo único que la cerraría es instrumentación **continua** —el vigilante— que ya existe
y ya demostró cobertura (§6.15.2). `marca-audio` sirve para el **estado posterior**; el vigilante,
para demostrar **ausencia de rastro durante**.

**Lo que sí mejora v2 dentro de su alcance:** captura en **una sola pasada** los campos que deciden
el diagnóstico —estado, delta, sesión, xruns, nivel de log, carga instantánea— y los pone en **una
línea**, de modo que **una marca de 2 s después del fallo sea lo más informativa posible en el menor
espacio**. Eso es todo lo que se puede hacer desde ese lado.

---

## 7-bis. Nota metodológica: lo que hace fuerte este resultado

Vale la pena explicitar **por qué** el evento del 16:42 es más sólido que todo lo anterior, y qué lo
debilitaría:

**Lo que lo hace fuerte:**

- El vigilante llevaba **28 minutos** corriendo ininterrumpidamente y muestreando cada 200 ms.
- Registró **una sola línea** en todo ese tiempo: la inicial. Ni transiciones, ni xruns, ni kernel.
- La **sesión PCM llevaba 22,4 minutos abierta**, es decir que cubría holgadamente el evento.
- El evento fue **reportado por el propietario en el momento**, no reconstruido después.
- Se verificó **a posteriori** que el PCM seguía entregando exactamente 48 000 Hz contando frames.

**Lo que lo debilitaría:**

- Que el vigilante tuviera un fallo de muestreo que le hiciera perderse cambios de estado. **No se ha
  auditado esa posibilidad.** El script lee `/proc` cada 200 ms; si por lo que fuera no leyera en
  alguna iteración, no lo registra. Mitigación parcial: `fuser`/`owner_pid` confirman que la sesión
  no se ha reabierto (`trigger_time` estable), lo cual es independiente del muestreo.
- Que el fallo ocurriera en un instante **entre dos lecturas**. Con 200 ms de cadencia y un evento de
  ~1 s, esto es muy improbable — el evento habría cubierto ~5 iteraciones.
- Que el PCM **no** fuera donde hay que mirar. Esto es lo más serio: el resultado descarta el PCM de
  la placa madre, **pero eso no prueba que la causa esté en el cable**. Solo acota el problema.

**Conclusión metodológica:** este resultado **no identifica la causa**. ~~Lo que hace es **eliminar una
familia entera de causas** (todo el software y el camino hasta el PCM de la placa madre) con una
confianza bastante alta. Eso es progreso real, pero es progreso por eliminación.~~
**RETIRADO (21-sep-2026).** No elimina esa familia de causas. Lo que hace es **acotar el conjunto de
formas de fallo que el instrumento puede ver**: no se observó ninguna de las seis que el vigilante
busca, a ~234 ms de resolución (§11.1–§11.2). **Eso no es eliminar el software**, y decir que era
«progreso por eliminación» le daba a la eliminación una solidez que no tiene. El progreso real de
esta sección es otro: **tener un instrumento que registra, y saber exactamente qué puede y qué no
puede ver** (§11.2).

---

## 8. Lo que NO se puede afirmar todavía

- **La causa no está identificada.** Este documento no la atribuye a: el remuestreo (ya descartado),
  el reloj de la placa madre (el manual §31.3 lo desmiente), ni el jitter.
- ~~**Tras el evento del 16:42, el software queda descartado** con bastante confianza (§6.7).~~
  **RETIRADO (21-sep-2026). El software NO está descartado** (§11). La conclusión se apoyaba en el
  silencio del vigilante, y un instrumento que muestrea **no puede establecer la ausencia de fallos
  cuya firma no sabe ver** (§11.1–§11.2). Además, el síntoma aparece en dos transportes con la misma
  pila de software, lo que lo convierte en **factor común** y no en descartado (§11.3).
  **Lo que sigue en pie:** los tres elementos de la capa física (cable, transmisor, receptor) siguen
  sin aislarse, y **el cable tampoco puede ser la causa única** si el síntoma también aparece por USB.
- **No se ha medido el enlace óptico.** No hay dato de margen, atenuación ni tasa de error del
  ejemplar Amazon Basics. La hipótesis del cable es la más plausible (§6.7.7) y **sigue sin verificar**.
- **Nueve eventos no cierran el caso.** Repiten el mismo resultado limpio, lo que hace **muy**
  improbable que el fallo deje **una de las seis formas de rastro que el vigilante busca** en el PCM
  de la placa madre. **Lo que no hacen es descartar un fallo de otra firma**, ni decir *dónde* está.
- **El fallo por audio normal (música) no se ha caracterizado.** **Los nueve** eventos ocurrieron con
  un juego abierto. Si ocurriera también en escucha pasiva, importaría — y sigue siendo la prueba que
  más información daría por unidad de esfuerzo.
- **La marca se toma DESPUÉS del fallo, nunca durante.** El mejor tiempo de reacción del día fue de
  **~2 s** (§6.13.1), y los peores de ~5 s. Como el fallo dura menos de un segundo, **todo lo que
  este documento mide es el estado posterior, no el momento del fallo**. Esa brecha **no se puede
  cerrar con `audio-debug`**: haría falta instrumentación que registre de forma **continua** durante
  el fallo. **El vigilante se acerca, pero no lo es**: muestrea cada ~234 ms y solo escribe para seis
  formas de fallo (§11.2).
- **El vigilante tiene CINCO puntos ciegos, no uno** (§11.2): muestrea en vez de observar; **omite los
  PCM cerrados**; solo ve seis formas de fallo; `prev_state` es una variable compartida entre
  subdispositivos; y la comprobación de `delta` es de un instante. El de la sesión PCM se arregló en
  la v4, pero **los otros cuatro siguen ahí**, y el más importante es el tercero: **un fallo cuya
  firma no sea una de las seis es invisible por construcción, no por ausencia.**
- **No hay control positivo del instrumento.** Desde el 1-sep hay **0 xruns** en el journal de
  PipeWire, así que **no existe ni un ejemplo de cómo se ve un xrun en ese log**. Todo el argumento
  «0 xruns ⇒ no hubo xrun» descansa en una suposición **sin verificar** (§11.2.6). Es la prueba que
  va primero, y es barata.
- **`Current Frequency` se resolvió** (§4: volvió solo a 47 999) y **ya no es una incógnita abierta**.
- **La tasa de la sesión C (47 712 Hz) no se puede interpretar.** Es un tramo de 31,8 s, y en la
  sesión A un tramo corto comparable también salió desviado — hacia arriba. **Los tramos cortos no son
  comparables con los largos** (§6.12.4).
- **¿«Corte seco» y «robótico» son el mismo síntoma? No se sabe** (§11.4). El propietario describió
  el fenómeno como «robótico» en **10 de 11** capturas; «corte seco» fue un término **mío**, usado
  una vez. **Tratar las once capturas como un solo fenómeno es una suposición**, no un hecho.

---

## 9. Resumen ejecutivo

1. **La cadena está bien montada** y el reloj del RME está enganchado correctamente (`SPDIF`/`Sync`).
2. **Cero errores de audio en el journal**: ni USB, ni HDA, ni underruns registrados.
3. **PipeWire lleva horas con 0 xruns.** Ni uno. `log.level=2` confirmado. ~~→ se habrían visto.~~
   **MATIZADO (21-sep-2026):** «se habrían visto» **no está verificado**. Hay 0 xruns desde el 1-sep,
   así que **no existe un solo ejemplo de cómo se ve un xrun en ese log**. Sin un control positivo,
   el valor de este cero es **desconocido** (§11.2.6). Es la prueba que va primero.
4. **NUEVE EVENTOS CAPTURADOS (16:42:11, 16:58:49, 17:15:31, 18:02:22, 18:06:26, 18:14:20,
   18:18:07, 18:36:59, 18:39:39).** El propietario ejecutó el instrumento al oírlos. **Trece de trece
   campos idénticos** en los nueve, todos con `RUNNING`, `delay` sano, 0 xruns, 0 errores de kernel y
   reloj enganchado (§6.7 – §6.15). Los dos últimos, además, con el **journal totalmente vacío** en
   su ventana.
   **Nota de vocabulario (§11.4):** la descripción del propietario fue **«audio robotico» en 10 de las
   11 capturas** y «corte seco» en 1. **No consta que sean el mismo síntoma**, así que tratarlos como
   un solo fenómeno es una suposición.
5. **El 7.º, el 8.º y el 9.º caen dentro de ventanas vigiladas sin interrupción.** El vigilante
   muestreó **1278 veces en 300 s (cada 234,7 ms)** en la ventana que contiene el fallo de las
   18:18:07, y otras **1285 veces (233,5 ms)** en la que contiene los de 18:36:59 y 18:39:39, **sin
   registrar nada**: ni cambio de estado, ni de sesión, ni xrun (§6.14.1, §6.15.2).
   ~~**El «cero rastro en el PCM de la placa madre» es TRES VECES una observación directa, no una
   inferencia.**~~ **MATIZADO (21-sep-2026).** Lo observado directamente es: **«no ocurrió ninguna de
   las seis formas de fallo que el vigilante sabe buscar, a ~234 ms de resolución, en los
   subdispositivos abiertos que muestreó»**. Eso **no es** lo mismo que «el fallo no deja rastro»,
   porque **un fallo de otra firma es invisible por construcción** — y esa es justamente la
   hipótesis principal (§11.2). El dato es real y útil; la frase anterior le atribuía más de lo que
   sostiene.
6. **Verificado contando frames — con una corrección importante sobre la convergencia.** Dos sesiones
   PCM distintas, separadas por hora y media, miden lo mismo: sesión A (2982 s) **−0,1267 %** ·
   sesión C (701 s, 4 marcas) **−0,1248 %**. **Diferencia: 0,0019 puntos.** Pero **al medir la sesión
   C con 6 marcas (1994 s) la tasa se movió a −0,1623 %** (§6.15.3). Sigue muy por debajo de la
   desviación respecto a 48 000, así que **la conclusión general se mantiene**, pero **la cifra de
   0,0019 puntos era optimista**: se obtuvo comparando dos ventanas elegidas, no todas. La dispersión
   real entre ventanas largas es **0,0375 puntos, el triple** de lo que se destacó.
7. **NO HAY PERÍODO — y ya está enterrado.** Los ocho intervalos entre los nueve eventos son
   **2811 · 244 · 32 · 443 · 226 · 275 · 857 · 161 s**. La hipótesis de los 16,7 min que propuse en
   §6.10.1 queda refutada (§6.11.2, §6.12.2, §6.13.4, §6.14.3, §6.15). **Ocho intervalos, ninguno
   repetido, y un rango que va de 32 s a 47 min: no hay nada parecido a un período.**
   *(Nota de rigor: la tabla de §6.14.3 usa los intervalos entre las MARCAS, que incluyen las dos de
   verificación de las 16:25 y 16:27; los de aquí son entre los NUEVE EVENTOS reales.)*
8. **Hay TRES sesiones PCM, no una.** La sesión A cubre E1–E3, la B cubre E4, la C cubre E5–E9
   (§6.12.3, §6.15.1). **La sesión C sobrevive a CUATRO eventos consecutivos sin reiniciarse.**
9. ~~**Conclusión: el fallo ocurre DESPUÉS del PCM de la placa madre.** Quedan tres candidatos —
   el cable óptico, el transmisor S/PDIF de la placa, la recepción del RME.~~
   **REBAJADO A HIPÓTESIS (21-sep-2026).** No es una conclusión: es la hipótesis que encabeza la
   lista, y lo es **por eliminación débil, no por evidencia directa** (§11.3). Quedan **cuatro**
   candidatos, porque **el software vuelve a la lista**:
   **la pila de software** · el cable óptico · el transmisor S/PDIF de la placa · la recepción del RME.
   Y hay un motivo positivo para sospechar del software: **el síntoma aparece en dos transportes
   distintos (USB y óptico) con la misma pila de software** (§11.3). Eso **descarta el cable como
   causa única**.
10. **El sink por defecto estaba mal y se ha corregido** (§6.5), y **`Current Frequency` se resolvió
    solo** (§4). Ambas incógnitas anteriores quedan cerradas.
11. **Ocho afirmaciones propias resultaron falsas** y se documentan en §10 sin borrarlas. La octava
    (§11) es de una familia distinta a las siete primeras: **no es un error de contabilidad ni de
    muestreo, es un error de ALCANCE DEL INSTRUMENTO** — confundir «mi instrumento no lo vio» con
    «no ocurrió». **Es la más peligrosa de las ocho, porque produce conclusiones que parecen las más
    sólidas: no se apoya en un dato dudoso, sino en un silencio.**
12. **La tasa de fallo bajo juego ronda 1 cada ~10 minutos** (8 intervalos entre los 9 eventos en
    84,1 min), **muy** superior a las «un par al día» que se percibían. **Sin periodicidad
    demostrada.** Y con un rango de **32 s a 47 min**, la dispersión es tan amplia que **la media
    sola engaña**: describe mal lo que se observa, que es una ráfaga seguida de calma.
13. **`marca-audio` se reescribió** (§6.16): una sola llamada a `pw-dump` (antes dos), `trigger_time`,
    `delta` y `xruns` en una línea `RESUMEN` grepeable, carga instantánea por presión de CPU en lugar
    de media de vida del proceso, y **−13 % de tiempo** (0,61 → 0,53 s). En el proceso aparecieron
    **tres fallos**: el que introduje yo (`export` de 5,7 MB contra `ARG_MAX` de 2 MB), uno latente de
    v1 (tomaba el subdevice cerrado `pcm0p`) y uno silencioso (patrones de `sed` que no casaban por un
    espacio). **Ninguna mejora del script cierra la brecha de 2 s: esa brecha es tiempo de reacción
    humano** (§6.16.5).
13. **Asimetría de configuración real:** el nodo **por el que va el audio** (`iec958`) corre con
    `api.alsa.headroom = 0`, mientras que la regla pide `headroom = 2048` **para el RME**, que solo
    lleva comandos (§6.11.4). **El margen está en el nodo equivocado.**
14. **El journal está literalmente vacío en la ventana de los eventos.** En el sexto y el séptimo,
    las consultas devuelven **«No entries»**: cero líneas. No es que no haya errores de audio —
    **no hay absolutamente nada**, ni de audio ni de otro tipo.

**Siguiente paso: cambiar el cable óptico** y, si es posible, probar el mismo PC por coaxial y otro
DAC por el mismo cable. Son las tres pruebas que aíslan la capa física, y ninguna cuesta dinero si
hay material a mano.

---

## 10. Advertencia sobre la solidez de este documento

**OCHO** de las afirmaciones que este informe dio por buenas **resultaron ser errores míos**,
detectados al revisar el trabajo:

- La «firma normal» `delta ≈ 970–1020` (§2.1) — era un artefacto de muestreo.
- Los cuatro «saltos de `hw_ptr`» (§2.2) — eran el contador reiniciándose entre sesiones PCM.
- La «coincidencia con los errores de gamescope» (§3.1), presentada como el hilo más prometedor —
  **en los eventos capturados había 0 errores de gamescope en los 60 s previos.**
- **La «regularidad de 16,7 min»** (§6.10.1), que llegué a presentar como «difícil de atribuir al
  azar». **El cuarto evento la refutó: el tercer intervalo fue de 46,8 min** (§6.11.2). Y el quinto
  la remató por el otro lado: el cuarto intervalo fue de **4,1 min** (§6.12.2).
- **«La regla ALSA protege el RME pero no el `iec958`»** (§6.11.4). **Al medir las propiedades de los
  nodos, el `iec958` sí tiene `pause-on-idle=false`** — las mismas que el RME.
- **«51,1 minutos continuos»** (§6.9, §9). Eran **una sola sesión PCM**, no la tarde entera: el
  `hw_ptr` vuelve a cero en cada sesión (§10.1). El número era correcto, **la palabra «continuo» no**.
- **«La convergencia: la sesión C se asienta en −0,1248 % con 701 s»** (§6.14.2, §9). **Con 6 marcas
  y 1994 s la tasa se movió a −0,1623 %** (§6.15.3). La cifra de 0,0019 puntos de diferencia entre
  sesiones —que se destacó como prueba fuerte— se obtuvo **comparando dos ventanas elegidas**, y la
  dispersión real entre ventanas largas es **0,0375 puntos, el triple**. **El número no era falso; la
  interpretación, demasiado fuerte.**
- **«La cobertura del vigilante descarta el software»** (§6.7.5, §6.7.6, §8, §9). **Es la octava y la
  más grave.** Se apoyaba en que el vigilante no registró nada, y eso **no autoriza** esa conclusión:
  el vigilante **muestrea** y **solo ve seis formas de fallo**, así que un fallo de otra firma es
  **invisible por construcción** (§11.1–§11.2). Además, el síntoma aparece en dos transportes con la
  misma pila de software, lo que convierte al software en **factor común** (§11.3).
  **Se retira la conclusión, no el dato.**

**Las siete primeras tenían la misma forma:** la lectura **parecía confirmar** una hipótesis
plausible, y en las siete **el sesgo iba en la dirección cómoda o interesante**. Varias las propuse
**yo mismo en esta misma sesión**. La cuarta es la más instructiva porque **yo mismo la propuse y yo
mismo la advertí**: §6.10.2 ya decía «n=2 intervalos es débil» y «hace falta un cuarto evento». **La
advertencia funcionó** — pero solo porque se escribió antes de tener el dato que la refutaría.

**En las siete sobrevivió el dato de la medición, no la interpretación.** Esa es la razón de
mantener las dos cosas separadas en este documento.

**La octava es de otra familia, y por eso se separa.** Las siete primeras son **errores de
contabilidad o de muestreo**: tratar como continuo, como completo o como promedio algo que se
reinicia, que se muestrea o que se dispersa. **La octava es un error de ALCANCE DEL INSTRUMENTO:**
confundir «mi instrumento no lo vio» con «no ocurrió». **Es la más peligrosa de las ocho**, porque
**no se apoya en un dato dudoso sino en un silencio**, y por tanto produce conclusiones que parecen
las más firmes del documento. El silencio de un instrumento es el tipo de evidencia que más fácil se
sobreinterpreta.

**Estado de la atribución de causa, tras la corrección:** ~~la causa ya no se atribuye al software~~
**la causa NO está atribuida.** El software vuelve a la lista de candidatos (§11.3), el cable no
puede ser la causa única (§11.3), y la prueba que discrimina está pendiente y es barata (§11.5).

---

### 10.1 Corrección de continuidad, del mismo día: «51 minutos continuos»

Al incorporar el quinto evento (§6.12) apareció un **error de continuidad nuevo, y de la misma
familia que los anteriores**. §6.9 titulaba su medición «tasa global en 51,1 minutos con los tres
eventos», y §9 lo repetía como «51 minutos continuos». **No eran continuos:** eran **la sesión A**, y
la sesión A terminó a las 17:58:33. Al leer las ocho marcas aparecen **tres sesiones PCM** con el
`hw_ptr` reiniciado a cero en cada una (§6.12.3).

**El número no era falso, pero la palabra «continuo» sí.** Y es la **tercera vez** que pasa lo mismo:

| # | Afirmación | Lo que fallaba |
|---|---|---|
| 2 | «Saltos de `hw_ptr`» (§2.2) | El contador se reiniciaba entre sesiones PCM |
| 5 | «Cuadre por múltiplos del buffer» (§6.9) | Válido solo en tramos cortos, y se aplicó a largos |
| 6 | «51,1 minutos continuos» (§6.9/§9) | Eran **una** sesión, no la tarde |

**El patrón de las tres es idéntico y no es de interpretación sino de contabilidad:** tratar como un
eje continuo algo que **se reinicia**. Un contador de hardware relativo a una sesión, leído como si
fuera absoluto. **La regla que lo previene es una sola: antes de restar dos lecturas de punteros,
comparar el `trigger_time`.** Si no coincide, **no hay resta**.

Ninguna de las siete era un hallazgo sobre el sistema. Se dejan visibles en lugar de borrarlas,
porque el patrón es revelador: **en las siete la lectura parecía confirmar una hipótesis** — y
en los cinco el sesgo iba en la dirección que resultaba cómoda o plausible. **Es exactamente el tipo
de error que este proyecto intenta evitar, y la razón por la que el evento del 16:42 se documenta
con tanta cautela sobre lo que *no* prueba.**

---

## 11. Corrección de alcance — 21-sep-2026: «el software está descartado» se retira

**Esta sección existe porque la conclusión central del documento estaba mal, y el error no era de
datos sino de razonamiento.** Se detectó al revisar el propio trabajo, a partir de una objeción del
propietario que resultó correcta y que además destapó un segundo problema que no estaba en su
objeción.

### 11.1 El error, en una frase

**«Mi instrumento no lo vio» no es «no ocurrió».**

El documento afirmaba (§6.7.5, §6.7.6, §8, §9):

> «El vigilante no registró nada → el fallo no deja rastro en el software → **la causa está descartada
> en el software**».

**Los dos primeros pasos son correctos. El tercero es un salto.** Para que la ausencia de rastro
signifique algo, el instrumento tendría que ser **capaz de ver** un fallo del tipo que se quiere
descartar. Y **no lo es** (§11.2). Un silencio solo es evidencia cuando se puede enumerar qué habría
hecho ruido.

**La formulación correcta de lo observado:**

> «No ocurrió ninguna de las seis formas de fallo que el vigilante sabe buscar, con una resolución de
> ~234 ms, en los subdispositivos abiertos que muestreó.»

Eso es un dato real, útil y reproducible. **No es «el fallo no deja rastro».**

### 11.2 Los cinco puntos ciegos del vigilante, y la suposición sin verificar

**Verificado leyendo `vigilar.sh` línea por línea.** La cabecera del propio script ya los documenta.

**1. Muestrea, no observa continuamente.** `sleep 0.2` más el coste del bucle dan **~234 ms por
vuelta** (medido con el contador `iter`: 1278 vueltas en 300 s). **Un fallo más corto que ese
intervalo puede caer entero entre dos muestras y no verse nunca.**

**2. Omite los PCM cerrados.** Línea 86: `[ -n "$ST" ] || continue`. Si el fichero de estado dice
`closed`, no tiene línea `state:` y **el subdispositivo se salta sin dejar línea en el log**. Un corte
en que el PCM se cierre **no queda registrado mientras está cerrado**. Esta es la objeción del
propietario, y es correcta.

**3. Solo ve seis formas de fallo.** La lista completa de lo que sabe buscar:

| forma | dónde |
|---|---|
| `state: XRUN` literal | línea 89 |
| cambio del campo `state:` | líneas 102–108 |
| cambio de `trigger_time` (sesión nueva) | líneas 111–116 |
| `delta < 200` frames | líneas 124–130 |
| subdispositivo nuevo | líneas 135–137 |
| evento de kernel de audio/USB | líneas 141–144 |

**Un fallo cuya firma no sea una de esas seis es invisible POR CONSTRUCCIÓN, no por ausencia.** Y
esto es decisivo, porque **la hipótesis principal del documento es exactamente un fallo de esa
clase**: un error de bit en el enlace óptico no cambia el estado del PCM, no cambia el `trigger_time`,
no mueve el `delta` de forma sostenida y no genera evento de kernel. **Bajo la hipótesis del cable,
el silencio del vigilante es lo que se espera — y por tanto no puede usarse como evidencia ni a favor
ni en contra.** El documento ya lo decía para el contador de frames («un error de bit no mueve el
`hw_ptr`»), pero **luego usó el silencio como prueba para descartar el software**. Las dos cosas no
pueden ser verdad a la vez.

**4. `prev_state` es una sola variable, compartida entre subdispositivos** (líneas 97–121). Con dos
subdispositivos abiertos a la vez, el bucle compara uno contra otro y **podría reportar una sesión
nueva falsa**. Hoy no ocurre porque normalmente solo hay uno abierto, pero **es un fallo latente, no
una garantía**.

**5. La comprobación `delta < 200` es de un instante.** Un vaciado breve del búfer que no coincida
con una muestra no se ve.

**6. Y la suposición sin verificar: no hay control positivo.** Todo el argumento «0 xruns ⇒ no hubo
xrun» descansa en que **PipeWire registre los xrun a `log.level=2`**. Eso **no está verificado**:

| dato | valor |
|---|---|
| `log.level` de PipeWire | `"2"` (medido, `pw-cli info 0`) |
| líneas con xrun en el journal **desde el 1-sep-2026** | **0** |
| ejemplos disponibles de cómo se ve un xrun en ese log | **ninguno** |

**Sin un caso positivo no se puede afirmar que un xrun *se habría* registrado.** Podría registrarse a
un nivel superior, o no registrarse. **Cómo se cierra:** provocar un xrun a propósito —carga alta con
un quantum pequeño— y comprobar si aparece. Es barato, y **convierte todos los «0 xruns» del
documento de un dato de valor desconocido en un dato sólido.**

### 11.3 El segundo problema, que no estaba en la objeción: el software es un factor común

**Este argumento es independiente del anterior, y va en la misma dirección.**

El documento ya recogía (§5) que el propietario **oía el mismo síntoma con el RME por USB como
transporte de audio**, y con mucha más frecuencia percibida que por óptico.

**Lo que se concluyó entonces:** «el óptico falla menos → el cable óptico es el sospechoso».
**Lo que ese dato implica de verdad, y se pasó por alto:** los dos transportes **no comparten
hardware**.

| | camino USB | camino óptico |
|---|---|---|
| pila de software (apps → PipeWire → ALSA) | **sí** | **sí** |
| driver ALSA | `snd_usb_audio` | `snd_hda_intel` |
| transmisor en el PC | USB (XHCI) | S/PDIF de la placa |
| cable | USB | **óptico** |
| receptor en el RME | USB | **óptico** |
| etapa interna del RME posterior al receptor | **sí** | **sí** |
| D/A, amplificador, audífonos | **sí** | **sí** |

**Consecuencia:** si el síntoma aparece en los dos caminos, **ni el cable óptico, ni el transmisor
S/PDIF de la placa, ni el receptor óptico del RME pueden ser la causa suficiente por sí solos.**
Los elementos comunes son **la pila de software**, **la etapa interna del RME** y **todo lo de
después**.

**Y esto hace del software un candidato positivo, no un descartado** — justo lo contrario de lo que
decía la conclusión retirada. El software es lo único, además del propio RME, que está presente en
los dos fallos.

**Advertencia sobre la comparación de frecuencias.** Los «varias veces por hora» (USB) y el «un par
al día» (óptico) **no son comparables: no se midieron en la misma condición.** La medición del
20-sep da **~1 evento cada 10,5 min bajo juego** (§6.15.4) — unas **6 por hora**, del mismo orden que
lo atribuido al USB. **Puede que la diferencia percibida entre USB y óptico fuera en realidad la
diferencia entre jugar y no jugar**, y no entre los dos transportes. Es una hipótesis, pero invalida
usar esa comparación como evidencia del cable.

### 11.4 Cuestión abierta: «corte seco» y «robótico» pueden no ser el mismo síntoma

**Se retira también la prescripción sobre el vocabulario** (§3.1, §6.6). El recuento real del log:

| descripción | capturas de evento |
|---|---|
| **«audio robotico»** | **10** |
| «corte seco» | 1 |

Y el término «corte seco» **lo propuse yo** (20-sep 16:24); el propietario lo usó **una vez**,
aclarando en el mismo momento que lo que oyó fue *«algo robotico de menos de un segundo»*. Las diez
capturas siguientes volvieron a su palabra. **Presentar después eso como «la nomenclatura corregida»
era circular: me citaba a mí mismo.**

**Lo que sí era un problema, y sigue siéndolo:** usar «robótico» como **afirmación causal** («es
robótico, luego son artefactos digitales, luego es el remuestreo»). Eso hay que evitarlo. **Pero
describir lo que se oye con la palabra que a uno le sale es el dato primario**, y «robótico» es una
descripción sensorial perfectamente válida.

**Y lo más importante: pueden no ser el mismo fenómeno.** Colapsarlos en un término **borra
información que no se puede recuperar**. **Estado: cuestión abierta.** La pregunta útil no es «¿cómo
debería llamarlo?» sino **«¿esto que acabo de oír es lo mismo que lo de ayer?»** — porque esa
respuesta es la que separa un fenómeno de dos. **Mientras no se sepa, tratar las once capturas como
un solo fenómeno es una suposición**, y el análisis de series (§6.15.4) descansa sobre ella.

### 11.5 Qué cambia en la lista de pruebas

**La lista anterior estaba ordenada por coste de comprobación de la capa física.** Con la conclusión
retirada, cambia el orden y aparece una prueba nueva **que va antes que todas**:

| # | prueba | qué discrimina | coste |
|---|---|---|---|
| **0** | **Control positivo del instrumento:** provocar un xrun a propósito y ver si el journal lo registra | **si el «0 xruns» significa algo** (§11.2.6) | bajo |
| 1 | **Escuchar sin el juego abierto** y capturar el primer evento de ahí | causa dependiente de carga vs. independiente | 0 |
| 2 | **Cambiar el cable óptico** | el cable | bajo |
| 3 | **Mismo PC por coaxial** | transmisor de la placa vs. receptor óptico del RME | bajo |
| 4 | **Otro DAC por el mismo cable** | el receptor del RME | 0 |
| 5 | **Volver a USB y medir la frecuencia con el instrumento** | si el «USB falla más» es real o era la condición de escucha (§11.3) | bajo |

**La prueba 0 va primero porque es la única que no mide el sistema, sino el instrumento.** Sin ella,
todos los «0 xruns» de este documento —y son la columna vertebral de varios apartados— tienen un
valor desconocido. **Es más barato arreglar el instrumento que seguir midiendo con él a ciegas.**

### 11.6 Lo que sobrevive de la conclusión retirada

**Nada de la atribución de causa.** Pero sobrevive lo que era un dato:

- **Las once capturas son reales y sus campos son correctos.** El estado 2–5 s después es sano, y eso
  sigue siendo cierto y útil: **el fallo es transitorio y se recupera solo.**
- **El reloj no está averiado.** La tasa medida es estable entre ventanas largas. (Con la salvedad de
  §11.2.6 sobre el «0 xruns».)
- **La capa física sigue siendo candidata, y el cable sigue siendo el candidato más barato.** Pero
  **ya no es «el más probable por eliminación»**, porque la eliminación del software no se sostiene
  (§11.3).

**La lección que se lleva este documento, y es la más valiosa de las ocho correcciones:** un silencio
**parece** la evidencia más sólida, porque no depende de ningún número dudoso. Y es justo al revés:
**un silencio solo vale lo que valga la capacidad del instrumento de romperlo.** Antes de apoyarse en
él hay que poder responder, con nombres y apellidos, **qué habría aparecido en el log si la hipótesis
fuera cierta**. Si esa lista no incluye la hipótesis, el silencio no dice nada sobre ella.
