# Enrutamiento de audio al RME: auditoría, corrección y excepciones

> **LÉASE PRIMERO EL §8.8.** Este documento se escribió creyendo que el destino correcto era el
> RME **por USB** y que la salida digital de la placa madre era el problema. **El propietario
> aclaró que es al revés:** el audio viaja **por un cable óptico** desde la salida digital de la
> placa madre hasta el RME, y el USB sirve **sólo para controlar** volumen y perfiles con ADI-2
> Remote. Los apartados §0 puntos 1-3, §1, §2, §8.1 y §8.7 quedaron superados. Se conservan como
> registro del error, con avisos en cada uno.

**Fecha:** 20 de septiembre de 2026, 13:30–13:50 CST
**Objetivo declarado por el propietario:** «todo el audio debe moverlo el RME, sin excepción».
**Equipo:** Garuda Linux · PipeWire 1.6.8 · WirePlumber 0.5.17

---

## §0 Resumen

> **AVISO: los puntos 1, 2 y 3 de este resumen quedaron corregidos por el §8.8.** El propietario
> aclaró que **el audio va a propósito por el cable óptico de la placa madre al RME, y el USB sólo
> sirve para controlar volumen y perfiles**. Por tanto «placa madre gana al RME» no era un fallo
> de enrutamiento: era el montaje correcto que yo estaba deshaciendo. **Léase el §8.8 antes que
> nada.** Los puntos 4 y 5 (calidad de Cider y de Spotify) siguen siendo válidos.

1. **La causa era una preferencia guardada, no una prioridad.** El sink por defecto estaba
   fijado a mano a la salida digital de la placa madre, y WirePlumber da **+30000 de
   prioridad** al nodo así marcado. Por eso ganaba la placa madre (736 + 30000 = 30736)
   frente al RME (1600), aunque el RME tenga la prioridad real más alta de todo el sistema.
2. **Corregido y verificado.** El RME es ahora el sink y la fuente por defecto, y se
   eliminaron **23 destinos guardados por aplicación que apuntaban a nodos inexistentes**.
   Comprobado con reproducción real por las dos rutas (nativa y PulseAudio).
3. **El remuestreo 44,1 → 48 kHz no es un problema de calidad**, pero sí significa que la
   cadena **no es bit-perfect**. Medido y explicado en el §4.
4. **Cider entrega más bits que Spotify en la configuración actual** (AAC-LC 256 kbps frente
   a Ogg Vorbis 160 kbps). Medido en el descriptor de códec, no estimado. §5.
5. **La salida que debe usarse es `iec958-stereo` (placa madre)**, porque es la que alimenta el
   cable óptico que entra al RME. §8.8.

---

## §1 Por qué ganaba la placa madre

El mecanismo está en el propio código de WirePlumber
(`/usr/share/wireplumber/scripts/default-nodes/find-selected-default-node.lua`): el nodo
marcado como *configurado por el usuario* recibe un bonus de prioridad.

```
priority = 30000 + priority
```

Medido en el sistema:

| Nodo | `priority.session` | Con el bonus de «configurado» |
|---|---|---|
| Placa madre, IEC958 | 736 | **30736** ← ganaba |
| RME ADI-2 DAC, pro-output-0 | 1600 | — |
| GPU Navi 48 (HDMI/DP ×4) | 1100–1196 | — |

El valor estaba guardado en dos sitios coherentes:

- `~/.local/state/wireplumber/default-nodes` →
  `default.configured.audio.sink=alsa_output.pci-0000_00_1f.3.iec958-stereo`
- la metadato `default.configured.audio.sink` del gestor de metadatos `default`.

**Segundo problema, más silencioso:** de las 126 entradas en
`~/.local/state/wireplumber/stream-properties` (la memoria de volumen y destino por
aplicación), **24 tenían un destino guardado y 23 de esos destinos ya no existían**:

| Destino guardado | Apps | ¿Existe? |
|---|---|---|
| `easyeffects_sink` | 20 | **No** — EasyEffects no está corriendo |
| `easyeffects_source` | 1 | **No** |
| `…RME_ADI-2_DAC…analog-stereo` | 1 | **No** — el RME está en perfil `pro-audio` |
| `…pci-0000_03_00.1.hdmi-stereo-extra1` | 1 | **No** — la GPU está en perfil `pro-audio` |
| `alsa_output.pci-0000_00_1f.3.iec958-stereo` | 1 (**Cider**) | **Sí** |

Cuando el destino guardado no existe, la aplicación cae al **sink por defecto**. Con el
defecto en la placa madre, **todas esas aplicaciones acababan en la placa madre**. Y Cider,
que sí tenía un destino válido, iba a la placa madre de forma explícita.

---

## §2 Qué se cambió

**Copia de seguridad previa:** `~/.local/state/wireplumber/backup-2026-09-20/`
(`default-nodes`, `default-profile`, `stream-properties`).

1. **Sink por defecto → RME.** Con `pactl set-default-sink`, que actualiza la metadato y
   WirePlumber lo persiste en `default-nodes`. Sobrevive al reinicio.
2. **Fuente por defecto:** ya era la entrada del RME (`pro-input-0`). Sin cambios.
3. **Eliminados los 23 destinos guardados obsoletos**, conservando **121 entradas** con
   volúmenes y mapas de canales por aplicación (no se perdió ningún ajuste de volumen).
   Procedimiento: parar `wireplumber`, editar el archivo quitando la clave `target` de cada
   entrada, volver a arrancarlo.
4. **Reproducciones activas movidas** al RME con `pactl move-sink-input`.

**No se tocó:** el perfil de la tarjeta RME (sigue en `pro-audio`), la configuración
`alsa-hardware.conf`, ni el reloj del grafo.

---

## §3 Verificación

| Comprobación | Resultado |
|---|---|
| `pactl get-default-sink` | `…usb-RME_ADI-2_DAC…pro-output-0` |
| `pactl get-default-source` | `…usb-RME_ADI-2_DAC…pro-input-0` |
| Destinos guardados obsoletos restantes | **0** |
| WirePlumber los reescribió | **No** (0 tras reiniciar) |
| Cider (que estaba fijado a la placa madre) | ahora en el sink del RME |

**Prueba con reproducción real, por las dos rutas:**

| Ruta | Cliente | Destino observado |
|---|---|---|
| PulseAudio | `paplay` | Sink del **RME** |
| Nativa de PipeWire | `pw-play` | Sink del **RME** |

Durante la reproducción: **RME `RUNNING`**, los cuatro HDMI/DP y la placa madre
**`SUSPENDED`**. Al terminar, el RME queda en `IDLE` y todo lo demás en `SUSPENDED`.

---

## §4 LISTA DE EXCEPCIONES ENCONTRADAS

Pedido literal: «dame lista de las excepciones que encuentres». Son estas, agrupadas por
tipo. Las de los grupos A y B ya están resueltas; las demás son estructurales y hay que
decidir sobre ellas.

### A. Excepciones ya corregidas

| # | Qué era | Estado |
|---|---|---|
| 1 | Sink por defecto fijado a la placa madre | **Corregido** |
| 2 | **Cider** con destino explícito a la placa madre | **Corregido** |
| 3 | 20 aplicaciones con destino a `easyeffects_sink` (inexistente) | **Corregido** — ahora caen al RME |
| 4 | 1 aplicación con destino a `easyeffects_source` (inexistente) | **Corregido** |
| 5 | 1 aplicación con destino a `…RME…analog-stereo` (perfil inexistente) | **Corregido** |
| 6 | 1 aplicación con destino a `…hdmi-stereo-extra1` (perfil inexistente) | **Corregido** |

### B. Salidas de hardware que existen y no son el RME

Existen en el sistema y pueden recibir audio si algo las elige. Ahora mismo **todas
`suspendidas`**, ninguna recibe nada.

| # | Salida | Qué es | Riesgo |
|---|---|---|---|
| 7 | `…pci-0000_03_00.1.pro-output-3` | GPU Navi 48, HDMI/DP | Si algún día se conecta un monitor o TV, el audio puede irse por ahí |
| 8 | `…pci-0000_03_00.1.pro-output-7` | GPU Navi 48, HDMI/DP | Igual |
| 9 | `…pci-0000_03_00.1.pro-output-8` | GPU Navi 48, HDMI/DP | Igual |
| 10 | `…pci-0000_03_00.1.pro-output-9` | GPU Navi 48, HDMI/DP | Igual |
| 11 | `…pci-0000_00_1f.3.iec958-stereo` | Placa madre, salida digital | La que causaba todo. Ya no es el defecto |

**Nota sobre la GPU:** los cuatro nodos vienen de que la tarjeta AMD está en perfil
`pro-audio`, que expone las salidas en crudo en vez de un único `hdmi-stereo`. Es una
consecuencia del perfil, no un fallo.

### C. Dispositivos que han aparecido en este equipo y pueden robar el audio

Registrados en el historial de WirePlumber. Si se conectan, **tienen prioridad propia y
pueden convertirse en el destino por defecto** cuando el RME no esté disponible.

| # | Dispositivo | Qué es |
|---|---|---|
| 12 | `…usb-Sony_…_DualSense_Edge_Wireless_Controller…sink` | Audio del mando DualSense Edge |
| 13 | `…usb-Burr-Brown_from_TI_USB_Audio_DAC-00.analog-stereo` | Un DAC USB con chip Burr-Brown |
| 14 | `…usb-MQA_Eversolo_DMP-A6_0-00.iec958-stereo` | El Eversolo DMP-A6 como tarjeta de sonido del PC |
| 15 | `alsa_output.pci-0000_00_1f.3.pro-output-0/1/3/7/8/9` | Salidas analógicas y digitales de la placa madre |
| 16 | `auto_null` | Sink ficticio de emergencia cuando no hay ninguna salida |

### D. Captura, no reproducción

| # | Qué | Detalle |
|---|---|---|
| 17 | La **entrada** del RME es la fuente por defecto | `pro-input-0`. Correcto si se graba por el RME; a revisar si se quiere usar el micrófono de otra cosa |
| 18 | `qemu` capturaba desde `easyeffects_source` (inexistente) | Ya eliminado; ahora captura de la fuente por defecto |
| 19 | La placa madre sigue exponiendo entradas (`pro-input-0`, `pro-input-2`) | No reciben nada, pero existen |

### E. EasyEffects: una trampa latente

| # | Qué | Detalle |
|---|---|---|
| 20 | **EasyEffects está instalado (8.2.9) pero no corriendo** | Mientras no corra, `easyeffects_sink` no existe y las apps caen al defecto. **Si algún día se arranca, creará ese sink y su salida por defecto puede no ser el RME** — hay que comprobarlo antes de dejarlo activo |

Esta es la excepción más importante que queda: es la única que puede **revertir** el arreglo
sin que nadie toque nada. Si en algún momento se activa EasyEffects para mover ahí el PEQ de
5 bandas, hay que verificar explícitamente que su salida es el RME.

### E-bis. La trampa se activó: incidente del 20-sep a las 14:05

**Se quedó sin audio durante un minuto escaso.** Y ocurrió exactamente por lo que avisa la
tabla de arriba. Se documenta porque el fallo es reproducible y la causa es fácil de repetir.

**Qué pasó.** EasyEffects arrancó a las **14:05:19** (PID 225047). Al hacerlo:

1. Creó su sink virtual `easyeffects_sink` y **se llevó los tres reproductores activos**
   (Cider, Zen y mpv) a él.
2. Intentó abrir su salida, que estaba configurada a
   `alsa_output.pci-0000_00_1f.3.pro-output-1` — **un nodo que ya no existe**. La tarjeta de la
   placa madre cambió de perfil (`pro-audio` → `iec958-stereo`) y ese nombre quedó huérfano.
3. Como EasyEffects tenía `useDefaultOutputDevice=false`, **no cayó al dispositivo por
   defecto**: se quedó con un destino inexistente.

Resultado: el audio entraba en `easyeffects_sink`, EasyEffects no podía entregarlo a ninguna
parte, y **no salía nada por ningún sitio**. El RME aparecía en `IDLE` y la placa madre en
`SUSPENDED`: el audio simplemente se quedaba dentro del sink virtual.

**Por qué no lo causó el cambio de enrutamiento.** El RME era el destino y estaba en `RUNNING`
con Cider reproduciendo justo antes del incidente. La avería la introdujo la configuración
inválida de EasyEffects, que llevaba tiempo guardada y sólo se manifestó al arrancar la
aplicación. Aun así, el incidente demuestra el riesgo real de la excepción 20.

**Cómo se arregló.**

1. Copia de seguridad: `~/.config/easyeffects/db/easyeffectsrc.bak-2026-09-20`.
2. `outputDevice` corregido a
   `alsa_output.usb-RME_ADI-2_DAC__51100523__7BF05DF3F61F3C8-00.pro-output-0`.
3. EasyEffects reiniciado. (Al cerrarlo, los tres reproductores cayeron solos al sink por
   defecto —el RME— y el audio volvió de inmediato, lo que confirma el diagnóstico.)

**Cadena verificada tras el arreglo:**

```
Cider · Zen · mpv  →  easyeffects_sink  →  (pipeline de EasyEffects)  →  ee_soe_output_level
                                                                              ↓
                                                        RME: playback_AUX0 / playback_AUX1
```

Comprobado con `pw-link -l`: `ee_soe_output_level:output_FL` alimenta
`…pro-output-0:playback_AUX0`, y `output_FR` alimenta `playback_AUX1`. El RME en `RUNNING`,
`easyeffects_sink` en `RUNNING`, ninguno silenciado, los dos al 100 %.

**Dos avisos que quedan pendientes:**

- **`bypass=true`** en `[EffectsPipelines]`. Ahora mismo EasyEffects **deja pasar el audio sin
  procesarlo**: no está aplicando ningún efecto, incluido el PEQ. Si se quiere que el preset
  (`HE1000SE_opus-slam`) actúe, hay que **desactivar el bypass** — y eso sí cambia el sonido,
  así que es decisión del propietario.
- **El fallo puede repetirse.** Si algún día se cambia el perfil de la tarjeta RME
  (`pro-audio` → `analog-stereo`), el nombre `…pro-output-0` dejará de existir y EasyEffects
  volverá a quedarse mudo. Poner `useDefaultOutputDevice=true` sería inmune a esto, porque
  seguiría al dispositivo por defecto en lugar de a un nombre fijo. **No se cambió** para no
  alterar un ajuste cuyo comportamiento no se ha probado en esta máquina.

**Regla que sale de esto:** si el audio desaparece de golpe y el sink por defecto es correcto,
**comprobar primero si EasyEffects está corriendo y a qué dispositivo apunta su salida.**

### F. Aplicaciones que podrían saltarse PipeWire por completo

Comprobado que **no hay ninguna configurada así** en este equipo:

- `~/.asoundrc` → no existe
- `/etc/asound.conf` → no existe
- `~/.config/mpv/` → sin `ao=` ni `audio-device=`
- Ningún proceso en ejecución con `PULSE_SINK` o `PIPEWIRE_NODE` fijado en el entorno

Pero la vía existe: cualquier aplicación que use ALSA directo (`hw:…`, `--ao=alsa` en mpv,
ciertos juegos de Wine, `aplay -D hw`) **no pasa por PipeWire** y por tanto **no pasa por
ningún control de enrutamiento**. No hay nada que se pueda hacer desde PipeWire contra eso;
sólo revisarlo aplicación por aplicación si alguna vez suena por donde no debe.

---

## §5 El remuestreo 44,1 → 48 kHz: ¿bueno o malo?

**Respuesta corta: no es un problema de calidad, pero sí significa que la cadena no es
bit-perfect.**

**Lo medido.** Con el RME ya como destino:

| Material de origen | Frecuencia a la que corrió el RME | ¿Hubo conversión? |
|---|---|---|
| 44 100 Hz | **48 000 Hz** | **Sí** |
| 48 000 Hz | 48 000 Hz | No |

Es decir: el RME está **fijo en 48 kHz**, y todo el material de 44,1 kHz —que es la mayor
parte del catálogo, CD incluido— se convierte.

**Por qué no es un problema de calidad.** A `resample.quality = 10` el error de la
conversión queda por debajo del piso de ruido del propio RME (123 dBA), y muy por debajo de
la resolución de 16 bits. No es audible, ni siquiera con los HE1000se.

**Por qué aun así importa.** Es un paso de procesamiento que no debería estar ahí. Un
convertidor que recibe exactamente los bits del archivo no necesita ningún filtro
interpolador; uno que recibe 48 kHz desde un archivo de 44,1 kHz sí. Para una cadena que se
quiere bit-perfect, esto la descalifica.

**Qué comprobé y descarté** (para no dejar la explicación en una suposición):

| Hipótesis | Prueba | Resultado |
|---|---|---|
| El grafo *no puede* cambiar de frecuencia | `pw-metadata -n settings 0 clock.force-rate 44100` | **Falso.** El RME pasó a `S32LE 2 44100`: el hardware **sí** sigue la fuente |
| `session.suspend-on-idle = false` / `node.pause-on-idle = false` en `alsa-hardware.conf` impiden la conmutación | Se comentaron las dos líneas y se reinició PipeWire | **Falso.** Siguió a 48 kHz. Config **restaurada** |
| `default.clock.rate = 48000` es la causa | Cambio en caliente de `clock.rate` a 44100 | **No concluyente.** No surtió efecto |

**Conclusión honesta: la causa de que no conmute automáticamente no quedó identificada.**
Lo que sí quedó establecido es que el hardware puede seguir la fuente y que el grafo no lo
hace solo. Si se quiere bit-perfect, la vía verificada es forzar la frecuencia según el
material —lo que obliga a cambiarla a mano en cada disco— o sacar a PipeWire de la cadena.

**La vía limpia ya está en casa:** el **Eversolo DMP-A6** lee el archivo y entrega por
salida digital al RME sin que PipeWire intervenga. Para bit-perfect de verdad, esa es la
ruta, no el PC.

---

## §6 Cider frente a Spotify: medido, no estimado

### Cider

Se extrajo el descriptor de códec de los archivos que Cider acababa de escribir en su caché
(`~/.config/sh.cider.genten/Cache/Cache_Data/`), servidos desde
`aod-ssl.itunes.apple.com` (AOD = audio bajo demanda de Apple). Contenedor MP4 marca
`iso5`, marcas compatibles `isom, iso5, hlsf` (HLS fragmentado).

Caja `esds` → DecoderConfigDescriptor:

| Campo | Valor |
|---|---|
| `objectTypeIndication` | `0x40` = **AAC-LC** |
| `avgBitrate` | **256 000 bps = 256 kbps** |
| `maxBitrate` | 305 616 bps |
| Frecuencia (`mvhd` timescale) | **44 100 Hz** |
| Canales (AudioSpecificConfig `0x1210`) | **2 (estéreo)** |

Esto **confirma la deducción anterior** con una medición directa: Cider entrega
**AAC-LC 256 kbps a 44,1 kHz**, y no sin pérdida. No hizo falta estimar nada.

### Spotify

`audio.play_bitrate_enumeration = 3` y la escala verificada en el binario
(`UNKNOWN=0 · LOW=1 · NORMAL=2 · HIGH=3 · VERY_HIGH=4 · LOSSLESS=5`) dan
**Ogg Vorbis a 160 kbps**.

### Comparación

| | Códec | Bitrate | Frecuencia que entrega a PipeWire |
|---|---|---|---|
| **Cider** (Apple Music) | AAC-LC | **256 kbps** | 48 000 Hz — Chromium remuestrea dentro de la app |
| **Spotify** (ajuste actual) | Ogg Vorbis | **160 kbps** | 44 100 Hz — nativo, sin remuestrear en la app |
| Spotify en *Very High* | Ogg Vorbis | 320 kbps | — requiere Premium |
| Spotify *Lossless* | FLAC ≤24/44,1 | 700–1400 kbps | — requiere Premium |

**Respuesta: sí, en la configuración actual Cider entrega más calidad que Spotify.** 256 kbps
en AAC-LC es más margen que 160 kbps en Vorbis. Dicho con la cautela que corresponde: los dos
códecs a esos bitrates son ya bastante transparentes para la mayoría del material, y la
diferencia se nota sobre todo en pasajes difíciles, no en todo.

**Matiz en contra de Cider:** su audio llega a PipeWire a **48 kHz** (Chromium remuestrea
dentro de la aplicación), mientras que Spotify entrega **44 100 Hz** sin tocar. Es decir,
Cider gana en bitrate y pierde en pureza de frecuencia.

**Y el matiz que lo cambia todo:** si Spotify se pone en *Very High* (320 kbps) —gratis con
Premium— o en *Lossless*, Spotify pasa por delante de Cider en las dos dimensiones.

---

## §7 Sobre conseguir el sin pérdida sin pagar Premium

Pregunta directa, respuesta directa: **no existe un programa en Linux que lo consiga**, y la
razón no es comercial sino técnica.

**El sin pérdida no lo decide el cliente, lo decide el servidor.** El cliente de Spotify
contiene los formatos (`FLAC_FLAC`, `MP4_FLAC`, `BUCKET_LOSSLESS` están en el binario), pero
**el bucket que se sirve lo elige el servidor según el derecho de la cuenta**. Un cliente
modificado —SpotX, bloqueadores de anuncios, parches— cambia la interfaz y la publicidad; no
puede hacer que el servidor envíe un flujo para el que la cuenta no tiene derecho. No hay
parche posible: habría que falsificar la respuesta del servidor de licencias.

**Y encaja con lo medido:** los 160 kbps que se ven son exactamente el **techo del plan
gratuito** de Spotify (Low 24 · Normal 96 · High 160). Que el ajuste esté en `HIGH` y no en
`VERY_HIGH` es coherente con una cuenta sin Premium: en el plan gratuito la opción superior
ni siquiera está disponible.

**Aparte de lo técnico:** modificar el cliente incumple las condiciones de servicio de
Spotify y es motivo de cancelación de cuenta. No es una advertencia moral, es el riesgo real
de perder la cuenta y las listas.

**Lo que sí da calidad sin pagar nada:**

| Vía | Calidad | Coste |
|---|---|---|
| **Archivos propios** (FLAC/ALAC de CD ripeado) | Sin pérdida, bit-perfect | Gratis si ya tiene los discos |
| **Bandcamp / Internet Archive / Free Music Archive** | Sin pérdida o alta tasa | Gratis o compra puntual |
| **Spotify en Very High (320 kbps)** | 320 kbps Vorbis | Gratis **si tiene Premium** |
| Apple Music vía Cider | 256 kbps AAC | Requiere suscripción de Apple Music |

La conclusión que le sirve: **la mejor calidad disponible en su equipo ahora mismo no es
ninguna plataforma de streaming, son sus propios archivos por el DMP-A6 hacia el RME.**
Sin pérdida, bit-perfect, y sin depender de ningún derecho de cuenta.

---

## §8 Mapa de salidas: qué es cada una, cuáles sirven y cuáles son lastre

Pedido literal: «tengo muchas salidas NAVI pero solo la pro 7 que es mi bocina del monitor
sirve, las demás son necesarias o por qué están ahí? No entiendo las salidas que tengo
explícalas».

### 8.1 Las seis salidas que existen

> **Ojo:** la salida correcta **en este montaje** es la de la placa madre
> (`iec958-stereo`), no la del RME por USB. Ver §8.8.

Medido con `pactl list short sinks` y `pactl list sinks` (20-sep-2026, 14:33).

| # | Nodo | Nombre en el panel | Qué es físicamente | ¿Sirve? |
|---|---|---|---|---|
| 1 | `…pci-0000_03_00.1.pro-output-3` | Navi 48 HDMI/DP Audio Controller Pro | Salida 1 de la GPU | **No** — nada conectado |
| 2 | `…pci-0000_03_00.1.pro-output-7` | Navi 48 … Pro 7 | Salida 2 de la GPU → **monitor LG ULTRAGEAR+ por DisplayPort** | **Sí** — es la bocina del monitor |
| 3 | `…pci-0000_03_00.1.pro-output-8` | Navi 48 … Pro 8 | Salida 3 de la GPU | **No** — nada conectado |
| 4 | `…pci-0000_03_00.1.pro-output-9` | Navi 48 … Pro 9 | Salida 4 de la GPU | **No** — nada conectado |
| 5 | `…pci-0000_00_1f.3.iec958-stereo` | Audio Interno Estéreo digital (IEC958) | Salida S/PDIF de la placa madre | **No** — es la que causaba el problema |
| 6 | `…usb-RME_ADI-2_DAC…pro-output-0` | ADI-2 DAC (51100523) Pro | **El RME** | **Sí** — es la que hay que usar |

### 8.2 Por qué hay cuatro salidas «Navi» y por qué solo funciona una

**No son cuatro tarjetas: es una sola GPU con cuatro conectores.** La Radeon RX 9070 XT
(Navi 48) tiene varios puertos de vídeo, y cada uno lleva su propio canal de audio. Lo que
cambia es cómo se presentan:

- En perfil **normal**, PipeWire agrupa todo en **un solo nodo** llamado `hdmi-stereo`.
- La tarjeta está en perfil **`pro-audio`** (verificado: `Active Profile: pro-audio`), que
  expone **cada salida en crudo por separado**. De ahí los cuatro nodos.

**Cuál funciona lo dice el propio monitor, no una suposición.** El kernel escribe un archivo
por salida con los datos que el dispositivo conectado le envía (ELD = datos del EDID del
monitor). Leídos en `/proc/asound/card2/eld#0.0` a `eld#0.3`:

| Nodo | Archivo ELD | `monitor_present` | Nombre del monitor | Conexión |
|---|---|---|---|---|
| pro-output-3 | `eld#0.0` | **0** | — | — |
| **pro-output-7** | `eld#0.1` | **1** | **LG ULTRAGEAR+** | **DisplayPort** |
| pro-output-8 | `eld#0.2` | **0** | — | — |
| pro-output-9 | `eld#0.3` | **0** | — | — |

Es decir: **pro-7 es la única con algo enchufado**, y ese algo es el monitor. Coincide
exactamente con lo observado por el propietario. Las otras tres están ahí porque el
controlador las expone siempre; no tienen cable, así que no pueden sonar. **No son
necesarias y no se pueden borrar** sin cambiar la tarjeta al perfil normal, lo cual quitaría
también el acceso en crudo al RME si se hiciera en la misma tarjeta (no es el caso: son
tarjetas distintas).

El monitor declara por ELD que acepta **LPCM de hasta 8 canales a 32/44,1/48/96/192 kHz**,
16/20/24 bits. Eso es lo que el monitor dice de sí mismo, no una medición de lo que suena.

### 8.3 Por qué «Zen no se oye nada»

Dos causas independientes, ambas verificadas:

1. **Zen tenía su destino fijado a la placa madre.** WirePlumber había vuelto a guardar
   `Audio:application.name:Zen -> alsa_output.pci-0000_00_1f.3.iec958-stereo` en
   `stream-properties`. Los tres flujos de Zen (`#797`, `#1536`, `#2072`) estaban en el sink
   `1257`, que es la salida S/PDIF de la placa madre — **no el RME**. Era el mismo mecanismo
   del §1: un destino guardado por aplicación gana sobre el destino por defecto.
2. **Los flujos estaban «corked»** (pausados por la propia aplicación). `Corked: yes` en dos
   de ellos, y tras la corrección el nodo del RME quedó `suspended`, lo que significa que
   **ahora mismo ninguno está entregando audio**: Zen tiene la reproducción en pausa.

**Corrección aplicada:** se borraron los destinos guardados (4 en total, ver §8.4) y al
reiniciar WirePlumber los tres flujos cayeron solos al RME. Estado final verificado: los tres
en el sink `1802` (el RME), la salida de la placa madre `SUSPENDED`, y **0 destinos guardados**.

### 8.4 Los destinos fantasma volvieron a aparecer — y por qué

Tras la limpieza del §2, `stream-properties` tenía **0 destinos**. Al revisar hoy había **4
nuevos**, creados al mover flujos a mano en el panel:

| Aplicación | Destino guardado | Problema |
|---|---|---|
| `Zen` | `…pci-0000_00_1f.3.iec958-stereo` | Placa madre: silencio |
| `Cider` | `…pci-0000_00_1f.3.iec958-stereo` | Placa madre: silencio |
| `mpv` | `easyeffects_sink` | **Nodo inexistente** (EasyEffects cerrado) |
| `PipeWire ALSA ompv` | `…pci-0000_00_1f.3.iec958-stereo` | Placa madre: silencio |

**Lección:** mover una aplicación a un dispositivo en el panel **no es temporal**, queda
grabado y esa aplicación volverá ahí siempre, incluso si el dispositivo no tiene nada
conectado. La entrada de `mpv → easyeffects_sink` es la peor: apunta a un nodo que solo existe
mientras EasyEffects corre. Se eliminaron los cuatro (copia en
`~/.local/state/wireplumber/backup-2026-09-20/stream-properties.1433`); se conservaron **143
entradas** de volumen.

### 8.5 Corrección de una lectura anterior mía

En el incidente del §E-bis interpreté que `/proc/asound/card0/pcm0p/sub0/status` en estado
`RUNNING` con `hw_ptr` avanzando **probaba** que el audio llegaba al RME. **Eso estaba
mal.** El propio archivo de configuración del propietario,
`~/.config/pipewire/pipewire.conf.d/alsa-hardware.conf`, fija para el RME:

```
session.suspend-on-idle = false
node.pause-on-idle      = false
```

Con eso, **PipeWire nunca pausa ni suspende el dispositivo**: el PCM queda `RUNNING` y
avanzando aunque no le llegue ni una muestra, rellenando con silencio. El proceso que lo
mantiene abierto es `pipewire` (pid 231125), que también abre el PCM de la placa madre.
**Conclusión: `RUNNING` en `/proc/asound` no distingue «suena» de «está abierto en
silencio».** Para saber si algo suena de verdad hay que mirar el **estado del nodo en
PipeWire** (`RUNNING` vs `IDLE`/`SUSPENDED`) y si el flujo está `corked`.

### 8.6 Dos pestañas, dos destinos: qué es normal y qué no

Caso reportado: dos flujos «Zen: AudioStream», uno en **ADI-2 DAC Pro** y otro en **Audio Interno
Estéreo digital (IEC958)**, con la observación de que **solo el de IEC958 se oye en los
audífonos**.

**Medido:** tres flujos de Zen — `#797` y `#1536` al RME (sink 1802), `#2297` a la placa madre
(sink 1804). El del RME llevaba el título real de YouTube (`(124) Deepseek just did the
impossible`); los otros dos, `AudioStream` genérico. Los tres estaban `Corked: yes` en la primera
medición (en pausa) y uno de ellos sonando en la segunda.

**Qué es cada cosa:**

| Situación | ¿Correcto? | Por qué |
|---|---|---|
| Varias pestañas de Zen, cada una con su flujo | **Sí** | Cada pestaña de vídeo abre su propio flujo de audio |
| Un solo flujo por pestaña | **Sí** | Es lo esperado |
| Flujos distintos apuntando a destinos distintos | **No** | Rompe la regla «todo al RME» |
| Que la pestaña en segundo plano siga emitiendo | **No** | Debería pausarse al no estar visible |
| Que solo suene el flujo que tiene foco | **Sí, es esperado** | Solo se reproduce lo que está en pestaña activa |

Es decir: **el problema no es que haya dos flujos, es que uno va al sitio equivocado.** El de la
placa madre hay que devolverlo al RME, y conviene cerrar o pausar la pestaña que no se usa.

### 8.7 Hallazgo aparte: el RME está enganchado a su entrada SPDIF, no al USB

> **ATENCIÓN: este apartado quedó CORREGIDO por el §8.8.** Aquí interpreté el enganche al SPDIF
> como algo sospechoso. **Es al revés: es la pieza que hace funcionar la cadena.** Léase el §8.8
> antes que este.

Al comprobar el reloj del RME aparecieron estos datos, que conviene tener presentes:

| Control del RME (card 0) | Valor medido |
|---|---|
| `Sync Source` | **`SPDIF`** (no `Internal` ni `AES`) — *Item0* |
| `SPDIF Sync` | **`Sync`** (está enganchado) |
| `SPDIF Rate` | `48000 Hz` |
| `AES Sync` | `No Lock` (AES no tiene nada) |
| `AES Rate` | `0` |
| `Current Frequency` | `47999 Hz` |
| `System Rate` | `48000 Hz` |

**Qué significa.** El ADI-2 DAC FS tiene **una sola entrada digital óptica/coaxial**. Que su
`Sync Source` esté en `SPDIF` y que el estado sea `Sync` **sugiere que hay un cable en esa entrada
y algo conectado emitiendo a 48 kHz** — el candidato evidente es la salida S/PDIF de la placa
madre, la misma que desviaba el audio en el §1.

**Nivel de confianza: medio.** Dos motivos para no darlo por cerrado:
1. **El RME guarda `Sync Source` en su propia memoria**, no lo gestiona PipeWire. Puede ser un
   ajuste heredado de una configuración anterior, sin que el cable siga puesto.
2. **Desde software no se puede saber cuál de los dos relojes manda de verdad.** Los dos corren a
   48 kHz, así que la frecuencia no distingue nada por sí sola.

**Por qué importa aunque la frecuencia coincida.** Si el reloj efectivo viene del S/PDIF de la
placa madre, el **jitter** es el de un reloj de placa madre — muy inferior al del USB, que es
síncrono y además es el que manda el ADI-2 cuando está en `Internal`. Es exactamente el tipo de
factor que el §0 del `cuello_de_botella_cadena.md` coloca por debajo de la grabación y el máster,
pero que no hace falta arrastrar si se puede quitar gratis.

**Cómo comprobarlo (requiere manos, no se puede desde software):** poner `Sync Source = Internal`
en el menú del RME, o desconectar el cable óptico, y volver a medir `SPDIF Sync`. Si pasa a
`No Lock` y el audio sigue igual, el cable estaba puesto y el reloj venía de ahí. **Es un cambio de
sonido del propietario, no se toca sin su permiso.**

### 8.8 CORRECCIÓN: la cadena real es placa madre → cable óptico → RME

**El propietario corrige el §8.7 y todo el planteamiento anterior.** Dijo textualmente: «RME está
recibiendo por cable óptico la señal de audio, también lo tengo conectado por USB al PC para que
reciba las instrucciones de cambio de volumen y poder modificar perfiles con adi-2-remote, cuando
selecciono la iec958 sí tengo sonido con la otra no».

**Esto invalida mi interpretación.** Yo trataba la salida S/PDIF de la placa madre como el enemigo
a eliminar y el RME por USB como el destino correcto. **Es exactamente al revés.**

**La cadena real, verificada tras la corrección:**

```
apps (Zen, Cider)  →  placa madre iec958-stereo (S/PDIF)  →  CABLE ÓPTICO  →  RME ADI-2 DAC
                                                                              ↕
                                                                    USB = SÓLO CONTROL
                                                          (volumen, perfiles, ADI-2 Remote)
```

| Comprobación | Medición | Lectura |
|---|---|---|
| Sink de la placa madre (1804) | **`RUNNING`** | **Es el que transporta el audio** |
| Sink del RME por USB (1802) | **`IDLE`**, **0 enlaces** `playback_AUX` | El USB **no** lleva audio |
| `Sync Source` | `SPDIF` | El RME toma el reloj del cable óptico |
| `SPDIF Sync` | `Sync` | Está enganchado a la señal del cable |
| `AES Sync` | `No Lock` | Coherente: no hay AES |

**Por qué lo que yo decía que «debería funcionar» no funciona.** Porque **el USB no es un camino
de audio en este montaje, es un camino de control.** Al mandar los flujos a
`…RME_ADI-2_DAC…pro-output-0` (el nodo USB), PipeWire los entrega a un dispositivo que en esta
configuración **sólo recibe comandos**, no señal. Por eso no se oye nada por ahí. El audio tiene un
único camino real, y es el cable óptico.

**Y por eso `Sync Source = SPDIF` es correcto, no un problema.** En el §8.7 lo presenté como un
hallazgo sospechoso y resulta ser **la pieza que hace funcionar la cadena**: el RME tiene que
engancharse al reloj de la señal que le llega por óptico.

**Dos matices que sí se mantienen, para que no se pierdan:**

1. **En esta cadena el reloj lo manda la placa madre**, no el RME (`Sync Source=SPDIF`, no
   `Internal`). **[MATIZADO 20-sep 15:30: leer el §8.9 antes de sacar conclusiones de esta
   frase.]** El impacto real del reloj de la placa madre es mucho menor de lo que esa frase
   sugiere, porque SteadyClock FS lo regenera. Ver §8.9.
2. **La ventaja de este montaje:** el volumen y los perfiles se controlan por USB con ADI-2 Remote
   sin que el audio pase por ahí. Es un montaje deliberado y coherente.

**Corrección de mi criterio.** El error de razonamiento fue doble: (a) vi `SPDIF Sync = Sync` y lo
leí como «señal parásita que hay que quitar», cuando **era la señal que el propietario quiere**;
(b) asumí que el USB debía llevar el audio por ser el camino técnicamente superior, sin comprobar
el montaje real. **Antes de llamar «problema» a un enlace, hay que preguntar qué cable hay puesto
y para qué: un ajuste raro puede ser una decisión deliberada.**

---

### 8.9 El reloj, el jitter y `Sync Source`: qué se puede afirmar y qué no

Este apartado existe porque en el §8.8 escribí que «el jitter es el de la placa madre» y lo
presenté como el precio del montaje óptico. **Eso estaba mal enfocado**, y el propietario aportó
el dato que lo demuestra.

#### 8.9.1 El dato del propietario (observación de escucha, no medición)

> «Lo tenía conectado por USB y varias veces por hora oía distorsión robótica por un segundo.
> Conectado desde el cable óptico esto para un par de veces al día, si acaso; hoy no he escuchado
> que pase.»

Es la evidencia más directa que existe sobre esta instalación. **Nivel de confianza: observación
del propietario**, con la fuerza de ser reproducible y haberlo notado sin buscarlo. Se registra
como hecho, sin extrapolarlo a otras máquinas.

#### 8.9.2 Lo que dice el manual del ADI-2 DAC (v1.8) — y desmonta mi frase

Tres pasajes textuales del manual, que cambian la conclusión:

| Sección | Texto del manual | Consecuencia |
|---|---|---|
| **12.1** (Settings → Source) | «The source of the analog output signal: Auto, SPDIF coax, Optical, USB… **Default: Auto.**» | `Source = Auto` **no es un ajuste raro**: es el de fábrica |
| **12.1**, misma página | «**In Auto Mode any detected SPDIF Signal will have priority over USB playback.**» | Explica por qué el RME se engancha al óptico teniendo USB conectado: **es su comportamiento diseñado** |
| **14.1.2** (Clock) | «The clock source is automatically determined and set by the unit, **a selection is neither possible nor necessary**» | `Sync Source` **no se configura**: se muestra. Lo elige el RME solo |
| **14.1.2**, mismo | «With USB the internal clock is used, **with SPDIF the external one**» | Coincide exacto con lo medido |
| **31.3** (SteadyClock FS) | «Its highly efficient jitter suppression **refreshes and cleans up any clock signal**» | **Aquí está mi error** |
| **31.3**, misma | «…the DA-conversion always operates on highest sonic level, **being completely independent from the quality of the incoming clock signal**» | Idem |
| **31.3**, misma | «locks in **fractions of a second** to the input signal, follows even extreme varipitch changes with phase accuracy» | Relevante para el fallo: engancha rápido |

**Mi frase era errónea por dos motivos:**

1. **`Sync Source = SPDIF` no es algo que se configure ni que esté «mal puesto».** El manual dice
   literalmente que **no es posible ni necesario seleccionarlo**. El propietario no lo tocó porque
   **no se puede tocar**. Presentarlo como un ajuste a revisar era un error de bulto.
2. **Decir que «el jitter es el de la placa madre» ignora SteadyClock FS.** El ADI-2 **regenera el
   reloj** y el manual afirma que la conversión D/A es **completamente independiente de la calidad
   del reloj entrante**. El reloj de la placa madre es, por tanto, **una preocupación mucho menor
   de lo que sugerí** — no el «precio» que hay que pagar.

**Honestidad sobre el alcance de esto:** las frases del manual son **afirmaciones del fabricante**,
no una medición de esta instalación. RME publicó además una prueba con jitter inyectado
(§audio_context.md), que corresponde a *su* unidad y *su* método. Es verosímil —SteadyClock FS es
la tecnología insignia de la marca y el diseño está documentado— pero **no es una medición de este
equipo**. Lo correcto es decir: *el fabricante afirma que el jitter entrante queda prácticamente
eliminado*, y el diseño lo respalda.

#### 8.9.3 Recomendación sobre `Source`

**Dejarlo en `Auto`, exactamente como está.** No hay nada que corregir, y el motivo es funcional,
no de calidad de sonido:

- **`Auto` es el ajuste de fábrica** y el que hace que el Eversolo funcione solo (§8.8 del plan
  original): el propietario quiere que la fuente pueda ser automáticamente el DMP-A6 cuando lo
  conecte, sin entrar al menú.
- **`Auto` cumple ese objetivo por diseño:** «any detected SPDIF signal will have priority over USB
  playback».
- **Poner `Optical` fijo** rompería precisamente lo que el propietario quiere, porque dejaría de
  detectar automáticamente al Eversolo. Solo tendría sentido si hubiera una fuente óptica parásita
  que moleste.

**Conclusión: el propietario no está confundido. Yo estaba equivocado.** La configuración
`Source: Auto` + `Sync Source: SPDIF` es **exactamente la correcta** para lo que quiere hacer.

#### 8.9.4 El fallo de «distorsión robótica»: qué se puede y qué no se puede afirmar

El dato es sólido: **USB fallaba varias veces por hora; el óptico, como mucho un par de veces al
día.** Sin embargo, **asignarle una causa concreta sería especulación**, y no la voy a hacer.
Candidatos razonables, ninguno verificado:

| Candidato | Por qué es plausible | Por qué no se puede afirmar |
|---|---|---|
| Pérdida de paquetes en el bus USB | El audio USB no tiene retransmisión; un paquete perdido se oye | No hay captura de errores durante un evento |
| Gestión de energía / carga del sistema | El USB comparte bus y controlador; el óptico no | Sin registro de `dmesg` en el momento del fallo |
| Mala recuperación del receptor | Un corte de ~1 s sugiere un buffer vaciándose o un reenganche | No hay log del RME de ese instante |
| Deriva entre relojes | Dos relojes independientes pueden divergir | Medido `Current Frequency` estable en 18 s, sin oscilación |

**Lo que el manual sí permite decir:** SteadyClock FS **engancha «en fracciones de segundo»** y
sigue cambios extremos con precisión de fase. Un evento que dura **~1 segundo** es más largo que
ese tiempo de enganche, lo que **apunta a un problema aguas arriba del receptor** (entrega de datos
o interrupción), no a un fallo de la etapa de reloj del RME. **Es una inferencia, no un hecho: la
marco como hipótesis.** Para cerrarla harían falta registros en el momento del fallo.

**Qué haría falta para diagnosticarlo de verdad** (no se hizo, y por eso no se afirma): dejar
`dmesg -w` capturando durante un fallo, contar errores en `/proc/asound/card0/pcm0p/sub0/status`
(`xrun`), y comparar. Con el óptico los fallos son tan raros que haría falta días de captura.

#### 8.9.5 Recomendación de transporte

**Mantener el cable óptico.** No como concesión de compromiso, sino porque **es el camino que
funciona mejor en esta instalación según la única evidencia que importa: la escucha del
propietario durante uso normal**. Y encaja con lo que ya decía `audio_context.md` sobre el
aislamiento galvánico del Toslink, que el USB no tiene.

**No cambiar nada.** El USB del RME se queda para lo que sirve: ADI-2 Remote, volumen y perfiles.

---

## §9 Lo que no se pudo verificar

- **La causa exacta de que el grafo no conmute la frecuencia automáticamente.** Se probaron y
  descartaron dos hipótesis; la tercera quedó sin concluir. Lo que sí se verificó es que el
  hardware sigue la fuente cuando se le fuerza.
- **Si hay algo conectado físicamente a la salida digital de la placa madre.** El propietario
  informa que oía Cider cuando estaba enviado a «Audio Interno Estéreo digital (IEC958)».
  **Eso no cuadra** con que las otras tres salidas Navi estén sin monitor y con que el RME sea
  el que tiene el Aune y los HE1000se. Desde software solo se ve el estado del nodo, no si hay
  un cable: **queda pendiente que el propietario diga qué hay enchufado a cada salida.** Es la
  única pieza que falta del mapa.
- **Si el perfil `pro-audio` del RME es el óptimo.** Es el que tiene y funciona; expone el
  dispositivo en crudo (`pro-output-0`), sin control de volumen por software. No se cambió
  porque es una decisión de sonido del propietario, no un fallo.
- **La causa de la «distorsión robótica» del USB.** Ver §8.9.4. El hecho está registrado
  (varias veces por hora por USB, un par al día por óptico), pero **no se identificó el
  mecanismo**. Hacen falta logs capturados en el momento del fallo.
- **El efecto audible del resto de medidas.** No se hizo ninguna prueba de escucha de lo demás.
  Todo lo anterior son mediciones, salvo la observación del USB frente al óptico (§8.9.1).
- **Si el reloj del RME viene de verdad del SPDIF o del USB.** **Resuelto en el §8.8:** el cable
  óptico está puesto a propósito y el RME se engancha a él. Ya no es una incógnita.
- **Qué hay enchufado a la entrada óptica del RME.** **Resuelto:** la salida S/PDIF de la placa
  madre, confirmado por el propietario (§8.8).
