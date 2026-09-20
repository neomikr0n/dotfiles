# MEMORY.md — Notas duraderas del proyecto de audio

## Convención
Cada dato con **fuente y confianza** (medido / fabricante / declarado / inferencia). No rellenar
huecos con suposiciones; si dos fuentes discrepan, dar ambas. No atribuir firmas sonoras a marcas o
chips. Importes en MXN. **El usuario pide ejecución, no instrucciones.** No inventar precios, fechas
ni tiendas. **Si el usuario describe algo que contradice una medición, su descripción manda:
preguntar qué cables hay. El manual del fabricante manda sobre mis deducciones.**

## PC
Sin Bluetooth ni Wi-Fi; sólo ethernet `enp8s0` (I225-V, 1000 Mb, 192.168.1.23). `bluez` 5.87 +
plugins de códec de PipeWire + `libfdk-aac` → basta un dongle USB BT. Placa ASUS PRIME Z690-A,
4 ranuras M.2 **Key M** (no E-key). Router ZTE ZXHN F679L (Wi-Fi 5 AC1200). GPU RX 9070 XT
→ `whisper.cpp` con Vulkan. i5-13600K, 31 GB.

## LA CADENA REAL
`apps → placa madre iec958-stereo (S/PDIF) → CABLE ÓPTICO → RME` · `USB = SÓLO CONTROL`
**El audio va por el cable óptico; el USB sólo lleva comandos.** El sink correcto es
**`iec958-stereo`**, no `…RME…pro-output-0`: mandar los flujos al USB da **silencio** (medido: ese
sink queda `IDLE`, 0 enlaces). **Regla: preguntar qué cable hay antes de llamar «problema» a un
enlace.**
**Reloj (manual ADI-2 v1.8):** `Source = Auto` es el **ajuste de fábrica** (§12.1): «any detected
SPDIF signal will have priority over USB playback». **`Sync Source` NO se configura:** «a selection
is neither possible nor necessary» (§14.1.2). **SteadyClock FS (§31.3)** regenera el reloj; la
conversión D/A es «completely independent from the quality of the incoming clock signal» → **«el
jitter es el de la placa madre» está mal enfocado.** No hay que tocar nada: `Auto`+`SPDIF` es lo
correcto para que el Eversolo entre solo.
**Dato del propietario (escucha, no medición):** por **USB** oía distorsión «robótica» de ~1 s
**varias veces por hora**; por **óptico**, un par al día o ninguna. **Causa NO identificada** →
**mantener el óptico.**

## PipeWire
- `99-rme-fix.conf` **no fuerza 192 kHz**: `clock.rate=48000`, `allowed-rates=[44100 48000 88200
  96000 192000]`, quantum 1024 (512/2048), sin force-rate.
- **Remuestreo: las dos rutas en calidad 10** (`client.conf.d/resampling.conf` subido de 4 a 10;
  `pipewire-pulse.conf.d/force-192k.conf` ya estaba en 10 — **no fuerza la frecuencia**). Rango
  **0–14**, por defecto 4. A 10 el error queda bajo el piso de ruido del RME.
- **El grafo NO sigue la fuente: todo corre a 48 kHz** (`clock.force-rate 44100` sí conmuta el RME,
  pero el grafo no lo hace solo). → **La cadena no es bit-perfect.**
- **`RUNNING` en `/proc/asound` NO prueba que suene.** `alsa-hardware.conf` pone en el RME
  `session.suspend-on-idle=false` y `node.pause-on-idle=false`: el PCM queda `RUNNING` aunque no le
  llegue ni una muestra. Comprobar **estado del nodo en PipeWire** + si está `corked`.
- **Los puertos del RME en `pro-audio` son `playback_AUX0/AUX1`, no `FL/FR`. El RME no tiene
  control de volumen de salida por hardware**, sólo estado de lectura.
- **Trampa recurrente: destinos guardados por aplicación** en
  `~/.local/state/wireplumber/stream-properties`. Mover una app en el panel **no es temporal**: queda
  grabado y vuelve ahí siempre. **Limpiar: parar `wireplumber` primero**, quitar la clave `target`
  con Python, reiniciar. Copias en `~/.local/state/wireplumber/backup-2026-09-20/`.
- **EasyEffects: la trampa ya se activó (20-sep).** Se llevó las apps a `easyeffects_sink`, pero su
  `outputDevice` apuntaba a un **nodo inexistente** y con `useDefaultOutputDevice=false` no cayó al
  defecto → **silencio total**. Arreglado; copia en `easyeffectsrc.bak-2026-09-20`.
  **Ojo: `[EffectsPipelines] bypass=true` → el PEQ no actúa.** **Regla: si desaparece el audio y el
  sink por defecto es correcto, mirar EasyEffects primero.**
- `qemu` usa el RME como **captura**. Sin bypass por ALSA directo (no hay `~/.asoundrc`).

## Mapa de salidas
Seis sinks. **Navi pro-output-3/7/8/9** = una sola GPU con cuatro conectores; perfil `pro-audio`, que
expone cada salida en crudo. **Sólo pro-7 tiene algo conectado**: **monitor LG ULTRAGEAR+ por
DisplayPort** (`card2/eld#0.1`, `monitor_present=1`; los otros dan 0). **`iec958-stereo`** = S/PDIF de
la placa madre → **alimenta el cable óptico: es la correcta**. **`…RME…pro-output-0`** = el RME por USB
(sólo control). Las tres Navi sin monitor sobran, pero no se borran sin cambiar el perfil.

## Fuentes de música
- **Cider 4.0.9.1** = Electron del web de Apple Music. **Medido** en su caché (caja `esds`):
  **AAC-LC, 256 kbps, 44,1 kHz**. Entrega a PipeWire a **48 000 Hz** (Chromium remuestrea dentro de
  la app). Apple no tiene cliente Linux.
- **Spotify (1.2.96.518): 160 kbps, no sin pérdida.** Escala en el binario (`spotify.audiophile`):
  `HIGH=3`=160, `VERY_HIGH=4`=320 Ogg Vorbis, `LOSSLESS=5`. **160 kbps es el techo del plan gratis.**
- **El sin pérdida NO se desbloquea sin Premium:** el bucket lo elige el servidor. Alternativa gratis
  real: **archivos propios por el DMP-A6 → RME**.
- **Verificar el códec:** DevTools en Cider (Network, `.m3u8`) o caudal de red (AAC 256 ≈ 32 KB/s);
  la caché de Spotify está **cifrada**. Guía: skill `pipewire-grafo-y-codec-streaming`.
- **TIDAL:** offline roto (v2.215.0) también en iOS y Android → del cliente. **Para offline, Apple
  Music.** Detalle: `tidal_descargas_offline_bug.md`.
- **Lossless en Arch + offline de 15.000: ningún servicio cumple las tres** (Spotify tope **10.000
  descargas**; Qobuz sin tope pero **sin cliente Linux** y **QBZ retirado 20-sep-2026**; TIDAL, único
  con cliente Linux oficial, offline roto). Detalle: `comparativa_lossless_offline_15k.md`.
- **Qobuz web player (`play.qobuz.com`):** hasta **FLAC 24/192** pero **remuestreado por el
  navegador** (Web Audio fuerza una frecuencia de reloj: 48 kHz en Windows/Linux, 44,1 en macOS).
  **No es bit-perfect ni permite offline.** Detalle: `qobuz_webplayer_lossless.md`.

## Cuello de botella
**No está en la electrónica.** Orden: (1) grabación y máster, (2) formato de entrega, (3) audición,
(4) almohadillas y sellado, (5) PEQ de 5 bandas, (6) software. **El DAC y el amplificador no limitan**
(~14 dB de margen con el Aune). **El PEQ está saturado:** `HEKSE-HarmanV4` usa las 5 bandas + shelf de
graves y una Harman necesita 7–10 filtros. **Único límite real, y se rompe gratis con EasyEffects.**
Los `.adieqpr` **sólo guardan EQ**.
**Transporte:** aquí el óptico falla mucho menos que el USB (escucha del propietario). Efecto
audible real, por encima de cualquier diferencia de DAC o amplificador.

## RME serie ADI-2 EX (estado 20-sep-2026)
Anunciada 3-jun-2026. Sólo el **ADI-2 Pro EX** tiene página, precio **CHF 1699** y venta real
(€1.992,87). **DAC EX y 2/4 Pro EX: 404, sin precio oficial y sin disponibilidad en México**
(«late Q3 2026»). Único precio del 2/4 Pro EX: preventa de revendedor $2,499 USD (Reverb, Tidepool
Audio) — **no es de RME**. Thomann retiró el DAC FS. México (`solidelectronics.mx`), **todo sin
existencias** salvo Babyface Pro FS $20,900: DAC FS $27,600 · 2/4 Pro SE $51,100 · Pro FS R BE
$42,600 · ADI-2 FS $20,200. Ningún «EX» listado. Automatización `078e7794-bd6a-45c0-bfba-ce1f160564bc`.

## Dónde está cada cosa
- **Fichas de equipos** → `referencia-equipos.md`.
- **Entregables** (raíz): `enrutamiento_audio_al_rme.md` (§8.9 reloj/`Sync Source`, §8.8 cadena real,
  §8 mapa de salidas, §4 excepciones) · `verificacion_grafo_pipewire.md` · `cuello_de_botella_cadena.md`
  (§1.1-bis transporte) · `audio_context.md` (§6) · `fuente_remuestreo_y_perdida.md` ·
  `analisis_rme_dac_fs_vs_adi-2-4_pro_ex.md` · `analisis_rme_vs_eversolo_a8_gen2.md` ·
  `cable_y_almohadillas_he1000se.md` · `tidal_descargas_offline_bug.md` ·
  `comparativa_lossless_offline_15k.md` · `qobuz_webplayer_lossless.md` · `fichas/`.
- **Manuales:** `manuales/MANUAL-RMEadi2dac_e.pdf` (v1.8, §§12.1/14.1.2/31.3) ·
  `manuales/Manual EVERSOLO-DMP-A6-v1.0.pdf`. **Diarios:** `2026-09-*.md`.
