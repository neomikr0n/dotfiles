# Fuente, remuestreo y pérdida de calidad

Levantamiento: **20 de septiembre de 2026**, sobre la máquina del propietario.

Convención: **[verificado]** = leído de la configuración, el manual o una fuente oficial;
**[razonado]** = conclusión propia a partir de datos verificados; **[sin confirmar]** = no
se pudo comprobar.

---

## 0. Resumen en tres líneas

1. **El remuestreo ya lo tienes casi resuelto** —y, sobre todo, importa mucho menos de lo
   que sugerí en el ranking anterior. Corrijo abajo.
2. **Cider te entrega AAC de ~256 kbps y nunca te dará sin pérdida**: el reproductor web de
   Apple Music no lo soporta y Apple no tiene cliente para Linux.
3. **Spotify sí te daría sin pérdida en Linux**, FLAC hasta 24 bits/44,1 kHz incluido en
   Premium. Es la única de las tres vías que cierra la brecha de verdad.

---

## 1. El remuestreo: qué hay realmente en tu máquina

### 1.1 Lo verificado

| Archivo | Contenido | A quién afecta |
|---|---|---|
| `pipewire.conf.d/99-rme-fix.conf` | `default.clock.rate = 48000` · `allowed-rates = [44100 48000 88200 96000 192000]` · quantum 1024 | Todo el grafo |
| `client.conf.d/resampling.conf` | `resample.quality = 4` | **Clientes nativos de PipeWire** |
| `pipewire-pulse.conf.d/force-192k.conf` | `resample.quality = 10` | **Clientes PulseAudio** (Cider, Chromium, Zen, Steam, qemu) |

Estado en vivo (`pw-metadata -n settings`): `clock.rate = 48000`, `clock.quantum = 1024`,
`clock.force-rate = 0`, `clock.force-quantum = 0`.

Rango del parámetro, según `pipewire-props(7)` de tu propio sistema:

> «**resample.quality = 4** — The quality of the resampler. **from 0 to 14**, the default
> is 4.»

### 1.2 Dos correcciones a lo que te dije antes

**Primera.** Dije que tenías «la calidad de remuestreo en el valor por defecto». **Eso es
falso para el camino que usa Cider.** Tu `force-192k.conf` fija `resample.quality = 10`,
seis pasos por encima del valor por defecto, y su propio comentario aclara que el nombre
del archivo es histórico y que **ya no fuerza la frecuencia**:

> «# Nombre historico. Ya no fuerza la frecuencia ni el quantum de las aplicaciones.
> # Conversiones de clientes PulseAudio: se configuran en pipewire-pulse.»

Sólo los **clientes nativos de PipeWire** siguen en 4.

**Segunda, y más importante.** En el ranking anterior puse esto en el puesto 6 y lo
etiqueté como «menor pero real». **Debí bajarlo más.** Cuantifiquemos:

- A calidad 10 de 14 con la ventana `exp` por defecto, el remuestreador de PipeWire deja
  los productos de aliasing e imaging **muy por debajo de −120 dBFS**.
- El propio RME tiene un piso de ruido de **123 dBA**, es decir, unos −123 dB. El error del
  remuestreador queda **por debajo del ruido del propio convertidor**.
- La diferencia audible entre calidad 4 y calidad 10, y entre calidad 10 y no remuestrear,
  es en mi criterio **nula**.

**Conclusión honesta: esto no es un cuello de botella audible.** La razón para tocarlo no es
oír algo nuevo, sino que es **el único paso de procesamiento evitable** de una cadena por lo
demás limpia. Cuesta una línea de configuración y no tiene riesgo. Eso es todo.

### 1.3 Cómo lo arreglaría, en orden

**a) Igualar la calidad de los clientes nativos.** En
`~/.config/pipewire/client.conf.d/resampling.conf`, cambiar `resample.quality` de **4 a 10**.
Es la única asimetría que queda. Reiniciar PipeWire después (`systemctl --user restart
pipewire pipewire-pulse wireplumber`).

**b) Verificar qué hace el grafo de verdad.** Con música sonando, `pw-top` muestra la
frecuencia y el formato de cada flujo. Merece la pena comprobar si el grafo **sigue** la
frecuencia nativa del contenido (44,1 kHz) o se queda en 48 kHz. La clave está en
`allowed-rates`, que ya incluye 44100: el mecanismo existe, pero `default.clock.rate = 48000`
hace que un cliente que no pida su frecuencia nativa reciba 48 kHz.

**c) La vía sin remuestreo: saltarse PipeWire.** Un reproductor que abra el dispositivo ALSA
del RME en exclusiva —`mpv --ao=alsa --audio-device=alsa:hw:…`, o MPD con salida ALSA— es
bit-perfect por construcción. **Advertencia:** ahora mismo `qemu` tiene tomado el RME como
dispositivo de **captura**, lo que puede bloquear el acceso exclusivo.

**d) La vía más limpia, y ya la tienes: el Eversolo DMP-A6 como fuente.** El manual local
lista sus servicios: **Tidal, Qobuz, Highresaudio, Amazon Music, Roon Ready, Tidal Connect,
DLNA, UPnP**. Y tiene **salidas digitales** (óptica, coaxial y USB audio out) hacia el RME.
Eso saca al PC, a PipeWire y al remuestreador de la cadena por completo.
*Limitaciones declaradas:* **Spotify Connect no aparece en la lista del A6**, y el manual
avisa de que las **entradas digitales** del A6 sólo salen por analógico —lo que no afecta a
su reproductor interno, que sí sale en digital.

---

## 2. Apple Music a través de Cider

### 2.1 Qué es Cider y qué te entrega

**[verificado en tu máquina]** Cider **4.0.9.1** (paquete `cider`, repositorio Genten), en
`/usr/lib/cider/Cider`. Es una aplicación **Electron**: los procesos en ejecución muestran
`--type=utility --utility-sub-type=audio.mojom.AudioService` y `--user-data-dir=…/sh.cider.genten`.

**[razonado a partir de la evidencia]** En su directorio de datos hay un **`CdmStorage.db`**
—almacén del módulo de descifrado de contenido—, que es la firma de un reproductor que
reproduce contenido protegido con DRM. Encaja con la arquitectura conocida de Cider: un
envoltorio del **reproductor web de Apple Music**.

**El reproductor web de Apple Music no entrega audio sin pérdida.** Y Apple **no incluye
Linux** en su lista de plataformas con soporte de sin pérdida: la página oficial de soporte
enumera iPhone/iPad, Mac, HomePod, Apple TV 4K, Apple Vision Pro, Android y **la aplicación
de Apple Music para Windows**. Linux no aparece. **No existe cliente oficial de Apple Music
para Linux.**

**Consecuencia: Cider te entrega AAC-LC de ~256 kbps** —el nivel «High Quality» de Apple—
independientemente de lo que incluya tu suscripción.

### 2.2 Los niveles de Apple Music, verificados

| Nivel | Códec | Bitrate / resolución |
|---|---|---|
| Efficient | HE-AAC | ~64 kbps |
| High Quality | AAC-LC | ~256 kbps |
| Lossless | ALAC | hasta 24 bits / 48 kHz |
| Hi-Res Lossless | ALAC | hasta 24 bits / 192 kHz |
| Dolby Atmos | E-AC-3 + JOC | ~768 kbps |

Medición independiente citada: un mismo tema de 221 s ocupa **7,9 MB en AAC-LC** (≈286 kbps
medidos) y **44,2 MB en ALAC 24/44,1** (≈1.600 kbps).

**Cuánto pierdes, con honestidad:** la diferencia entre AAC de 256 kbps y sin pérdida es
**pequeña** para la mayoría del material y la mayoría de los oyentes, y bastante menor que
la diferencia entre un buen y un mal máster. No voy a venderte lo contrario. Pero hay dos
costes reales:

1. **Estás pagando un nivel sin pérdida que en esta máquina no puedes recibir**, en cada
   canción.
2. Es una pérdida **con pérdida acumulada**: el AAC decodificado pasa además por el
   remuestreador. No se suma de forma audible, pero es un escalón que no existiría con una
   fuente sin pérdida.

### 2.3 Cómo saber qué códec y bitrate estás recibiendo de verdad

**Método 1 — DevTools dentro de Cider (el más directo).** Cider es Electron, así que
normalmente admite las herramientas de desarrollo (Ctrl+Shift+I, o el menú de ajustes
avanzados). En la pestaña **Network**, filtra por `media` o por `.m3u8`. Apple sirve el audio
por HLS: verás una lista de reproducción y segmentos. **La variante de la lista revela el
códec y el bitrate** de la representación que se está sirviendo.

**Método 2 — El caudal de red (el más simple y decisivo).** Mira la tasa de transferencia
mientras suena una canción:

| Formato | Caudal aproximado |
|---|---|
| AAC 256 kbps | ~32 KB/s |
| HE-AAC 64 kbps | ~8 KB/s |
| Sin pérdida 16/44,1 | ~176 KB/s |
| Sin pérdida 24/48 | ~290 KB/s |

Si ves ~32 KB/s, es AAC de 256 kbps. No hay ambigüedad posible: el caudal no se puede
falsificar. Con `nethogs`, `bandwhich` o el monitor de red de tu barra, sirve.

**Método 3 — Nivel de PipeWire.** `pw-top` y `pw-dump` muestran el **formato de salida** y la
frecuencia del grafo, no el códec de origen. Sirven para confirmar si el grafo cambió de
frecuencia, no para identificar el códec.

**Método 4 — Análisis espectral (el más trabajoso).** Captura la salida y mira el espectro.
El AAC de 256 kbps suele mostrar un filtro pasa-bajos en torno a 19–20 kHz; el material sin
pérdida llega a 22,05 kHz. Requiere grabar la salida del sistema.

**[sin confirmar]** No pude comprobar desde la máquina qué representación pide Cider, porque
en el momento del levantamiento no estaba reproduciendo nada.

---

## 3. Spotify: ¿tendrías mejor calidad?

**Sí, y no por el códec, sino porque podrías recibir sin pérdida de verdad.**

- **Spotify lanzó el audio sin pérdida el 10 de septiembre de 2025**: **FLAC hasta
  24 bits/44,1 kHz**, incluido en el **plan Premium normal** (no es un plan aparte), con
  despliegue a más de 50 mercados.
- **Está disponible en México.** La página de soporte de Spotify México describe el audio
  sin pérdida para «oyentes de Spotify Premium que cumplan con los requisitos».
- **El cliente de escritorio lo soporta desde la versión 1.2.67.** En septiembre de 2025 el
  cliente de Linux se quedó en 1.2.63 y hubo una queja formal en la comunidad de Spotify.
  **Esa brecha ya se cerró:** en el mismo foro hay usuarios reportando la versión
  **1.2.74.477** (noviembre de 2025) y un usuario de Debian confirmando que «funcionaba al
  100 %, **lossless**, toda mi biblioteca». **[verificado en la comunidad de Spotify; no
  encontré un anuncio oficial específico para Linux]**

**El argumento completo, en una tabla:**

| | En Linux | Sin pérdida posible |
|---|---|---|
| **Apple Music** (vía Cider) | Reproductor web envuelto en Electron | **No.** AAC ~256 kbps y punto |
| **Spotify** (cliente de escritorio) | Cliente oficial nativo | **Sí.** FLAC 24/44,1 en Premium |

### Los matices que debo darte

- **24 bits/44,1 kHz es calidad de CD, no alta resolución.** Spotify no ofrece alta
  resolución. Apple sí (hasta 24/192) — pero no en Linux.
- **La diferencia audible entre AAC de 256 kbps y sin pérdida es pequeña.** Con el mismo
  criterio que apliqué al DAC, no te prometo una revelación. Es real, pero modesta, y menor
  que la diferencia entre un buen y un mal máster.
- **Spotify aplica normalización de intensidad incluso en sin pérdida.** Lo dice su propia
  documentación: «Todavía aplicamos la normalización de intensidad para equilibrar el
  volumen en todas las canciones, independientemente del formato». Apple tiene Sound Check.
  **Ninguno de los dos es bit-perfect en sentido estricto.**
- **El sin pérdida no cubre todo:** «Lossless is unavailable on Music Videos, Podcasts or
  Audiobooks».
- **Es 44,1 kHz** —exactamente la frecuencia que dispara la cuestión del remuestreo—. Los dos
  temas van juntos: si cambias de fuente, toca el remuestreo en el mismo movimiento.

---

## 4. Qué haría yo

1. **Para escucha sin pérdida, la mejor respuesta no es un arreglo de software: es el
   DMP-A6.** Tidal o Qobuz desde el Eversolo, salida óptica o coaxial al RME. Sale el PC,
   sale PipeWire, sale el remuestreador. Cero configuración y cero mantenimiento.
   *Si eliges Spotify, esta vía no vale:* Spotify Connect no está en la lista de servicios
   del A6, así que la ruta sería el cliente de escritorio del PC.
2. **Si te quedas en el PC:** sube `resample.quality` de 4 a 10 en
   `client.conf.d/resampling.conf`, para igualar lo que ya tienes en la ruta PulseAudio.
   Una línea, sin riesgo.
3. **Verifica** con `pw-top` a qué frecuencia corre el grafo mientras suena algo, y si sigue
   la del contenido o se queda en 48 kHz.
4. **Con Cider:** asume AAC de 256 kbps. No esperes una vía sin pérdida de Apple en Linux;
   no existe.

---

## 5. Lo que no se pudo verificar

| Afirmación | Estado |
|---|---|
| Qué representación de audio pide Cider exactamente | **No verificado.** No estaba reproduciendo durante el levantamiento |
| Que Cider envuelva el reproductor web de Apple Music | **Inferido** del `CdmStorage.db` y de la arquitectura Electron, no confirmado en su código |
| Soporte oficial de Spotify para sin pérdida **en Linux** | **Evidencia de la comunidad**, no anuncio oficial. Versión 1.2.74 y un usuario confirmando que funciona |
| Que el grafo de PipeWire siga la frecuencia nativa del contenido | **No verificado.** Hay que medirlo con `pw-top` mientras suena |
| Bitrate exacto del AAC de Apple Music | **~256 kbps** según la especificación del nivel «High Quality». El único dato medido disponible da ~286 kbps |
| Si la app de Apple Music para Windows corre bajo Wine con sin pérdida | **No investigado.** Sería la única vía no oficial a ALAC en Linux |
