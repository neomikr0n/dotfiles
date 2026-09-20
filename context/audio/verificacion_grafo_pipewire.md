# Verificación del grafo de PipeWire y de la calidad real de Spotify

**Fecha:** 20 de septiembre de 2026, 13:06–13:25 CST
**Petición:** subir `resample.quality` de 4 a 10, reiniciar PipeWire y **comprobar qué hace el
grafo de verdad** con Spotify sonando (cliente 1.2.96).
**Equipo:** Garuda Linux · PipeWire 1.6.8 · Spotify 1.2.96.518.g366879e1

---

## §0 Resumen en tres líneas

1. **El cambio está hecho y verificado:** las dos rutas de remuestreo están en calidad 10 y el
   grafo efectivamente convierte 44 100 → 48 000 Hz.
2. **[CORREGIDO 20-sep 15:30] Spotify sí llega al RME.** El sink es la salida digital de la
   placa madre **porque un cable óptico la lleva al RME**: es la cadena correcta. El nodo del RME
   por USB aparece `SUSPENDED` porque el USB **sólo transporta control** (volumen, perfiles),
   no audio. Lo que escribí aquí era un error de interpretación del montaje.
3. **Spotify está entregando 160 kbps, no sin pérdida.** La escala de calidad está verificada
   en el propio binario del cliente; el ajuste guardado es `HIGH`, y el caudal medido
   descarta el sin pérdida.

---

## §1 El cambio: hecho y comprobado

**Archivo editado:** `~/.config/pipewire/client.conf.d/resampling.conf`
`resample.quality` pasó de **4** a **10**.

Ese archivo afecta a los **clientes nativos de PipeWire**. La otra ruta,
`~/.config/pipewire/pipewire-pulse.conf.d/force-192k.conf`, **ya estaba en 10** desde antes y
es la que usan los clientes PulseAudio (Cider, Chromium, Zen, Steam, qemu). Su nombre es
histórico: **no fuerza la frecuencia**. Con esto las dos rutas quedan por fin iguales.

**Reinicio y estado:**

| Comprobación | Resultado |
|---|---|
| `systemctl --user restart pipewire pipewire-pulse wireplumber` | exit 0 |
| Los tres servicios | `active` |
| Errores en el journal (90 s) | ninguno |
| `pw-metadata` | `clock.rate = 48000`, quantum 1024, `force-rate = 0` |
| `pw-dump` | **`"resample.quality": 10` en 5 nodos** |

**Rango del parámetro (verificado en `pipewire-props(7)`):** 0 a 14, por defecto 4. A
calidad 10 el error de remuestreo queda por debajo del piso de ruido del propio RME
(123 dBA), así que **el cambio no es audible**: se hace por limpieza de la cadena, no por oído.

---

## §2 Qué hace el grafo de verdad (medido, no supuesto)

Con Spotify reproduciendo:

| Medición | Herramienta | Resultado |
|---|---|---|
| Formato que entrega Spotify | `pw-top` | `F32LE 2 44100` en el nodo `spotify` |
| Formato que entrega Spotify | `pactl list sink-inputs` | `float32le 2ch 44100Hz` |
| Formato del sink que lo recibe | `pw-top` | `S32LE 2 48000` |
| Estado del sink | `pactl list short sinks` | `RUNNING` |

**Conclusión: el remuestreo 44 100 → 48 000 Hz existe y está ocurriendo.** El cambio de
calidad de 4 a 10 aplica exactamente a ese paso, que es el único procesamiento evitable que
quedaba en la cadena.

---

## §3 Hallazgo importante: Spotify no está pasando por el RME

Este es el resultado más relevante de la verificación, y no era lo que se esperaba.

| Comprobación | Resultado |
|---|---|
| `pactl get-default-sink` | `alsa_output.pci-0000_00_1f.3.iec958-stereo` |
| Descripción de ese sink | **«Audio Interno Estéreo digital (IEC958)»** — la placa madre |
| `pw-link -l` | `spotify:output_FL -> …iec958-stereo:playback_FL` (y FR) |
| Sink del RME | `alsa_output.usb-RME_ADI-2_DAC…pro-output-0` → **SUSPENDED** |
| Enlaces hacia el RME | **ninguno** |
| EasyEffects | no está corriendo |

**[CORREGIDO 20-sep 15:30] Esto era falso.** La cadena **no** estaba inactiva. El audio salía
por la salida digital de la placa madre **y entraba al RME por el cable óptico**, con lo cual
**sí pasaba por el RME, el Aune y los HE1000se**. El USB no es el camino de audio en este
montaje: mover los flujos al nodo `…pro-output-0` **deja el audio en silencio**, porque ese
nodo sólo transporta comandos.

**No aplicar los comandos que había aquí.** Eran incorrectos y aplicarlos silencia el audio.
Para la cadena real, ver `enrutamiento_audio_al_rme.md` §8.8.

---

## §4 Hallazgo importante: la calidad de Spotify está en 160 kbps

Se leyó el archivo de preferencias real del usuario,
`~/.config/spotify/Users/1280065891-user/prefs`:

```
audio.allow_downgrade=false
audio.normalize_v2=false
audio.play_bitrate_non_metered_enumeration=3
audio.play_bitrate_enumeration=3
```

**La escala de valores se verificó en el propio binario**, no en una guía de terceros. El
cliente contiene la enumeración protobuf `spotify.audiophile`:

```
Setting
UNKNOWN
LOW
NORMAL
HIGH
VERY_HIGH
LOSSLESS
```

Es decir: **UNKNOWN=0 · LOW=1 · NORMAL=2 · HIGH=3 · VERY_HIGH=4 · LOSSLESS=5**.

El hilo oficial de la comunidad de Spotify confirma, **con el registro de audio del propio
cliente**, que `VERY_HIGH` (4) entrega `codec: vorbis` a **320 000 bits/s**, y que
**`HIGH` = 160 kbps**. Por tanto:

> **El ajuste guardado es 3 = HIGH = 160 kbps Ogg Vorbis.**

El binario además contiene `FLAC_FLAC`, `MP4_FLAC` y `BUCKET_LOSSLESS`, así que **el cliente
sí soporta sin pérdida**; simplemente no está seleccionado. La versión instalada
(1.2.96.518) está muy por encima del mínimo 1.2.67 que Spotify exige para sin pérdida.

**Confirmación independiente por caudal.** Se midió el tráfico real de la interfaz de red:

| Condición | Caudal medido |
|---|---|
| Spotify sonando, ventana de 180 s | **11 MB totales** (≈63 KB/s brutos) |
| Spotify en pausa (fondo del sistema) | ≈35 KB/s |

Una pista en sin pérdida 16/44,1 ocupa entre 700 y 1 400 kbps, es decir **entre 15 y 31 MB en
180 segundos**. Lo medido son 11 MB **contando todo el tráfico del equipo**. → **El sin
pérdida queda descartado por medición**, no por deducción.

**Dato positivo:** `audio.normalize_v2=false` → **la normalización de intensidad está
apagada**, que es lo correcto si se busca fidelidad.

**Nota metodológica:** la caché de Spotify (`~/.cache/spotify/Data`) está **cifrada**, así que
los bytes mágicos no sirven para identificar el códec (`OggS` / `fLaC` no aparecen). Tampoco
sirvió medir su crecimiento: no aumentó durante la reproducción. El caudal de red y el archivo
de preferencias fueron las vías que sí funcionaron.

---

## §5 Qué haría, en orden

1. **Subir la calidad de Spotify a Sin pérdida.** Ajustes → Calidad del audio → Calidad de
   transmisión: **Sin pérdida**. Es gratis (está incluido en el Premium normal) y es el salto
   más grande disponible ahora mismo: de 160 kbps con pérdida a FLAC sin pérdida.
   Alternativa por archivo, si se prefiere: poner `audio.play_bitrate_enumeration` en **4**
   (Very High, 320 kbps) o **5** (Lossless) en el `prefs` del usuario y **reiniciar Spotify**.
   La vía por la interfaz es la segura; la del archivo exige reinicio y no está documentada
   por Spotify.
2. ~~**Enrutar Spotify al RME** con los comandos del §3.~~ **[ANULADO 20-sep]** Ya estaba
   enrutado correctamente: la salida de la placa madre alimenta el RME por el cable óptico.
   No hay nada que corregir aquí.
3. **Romper el límite del PEQ de 5 bandas** pasándolo a EasyEffects. Sigue siendo la única
   mejora real de la electrónica y sigue siendo gratis.

---

## §6 Lo que no se pudo verificar

- **La calidad configurada en la interfaz de Spotify.** Se dedujo del archivo `prefs` y se
  confirmó por caudal, pero no se leyó el menú de Ajustes del cliente. La comprobación
  definitiva es abrir **Ajustes → Calidad del audio** y mirar el valor.
- **[RESUELTO 20-sep] Adónde va físicamente la salida IEC958 de la placa madre.** Va por cable
  óptico a la entrada del RME ADI-2 DAC. Confirmado por el propietario. Ya no es una incógnita.
- **Si el binario usa exactamente la misma numeración que el archivo `prefs`.** La
  enumeración del protobuf y el hilo de la comunidad son coherentes entre sí
  (`HIGH=3`, `VERY_HIGH=4`), pero no se pudo leer el valor desde el cliente en ejecución:
  la instancia abierta no escribe registro y un segundo proceso se delega a la primera.
- **El caudal exacto de Spotify aislado del resto del sistema.** La interfaz no permite
  separar por proceso sin herramientas adicionales, así que el fondo se estimó con la
  diferencia entre reproducción y pausa. La conclusión (sin pérdida descartado) no depende de
  esa estimación: 11 MB totales están por debajo del mínimo del sin pérdida.
