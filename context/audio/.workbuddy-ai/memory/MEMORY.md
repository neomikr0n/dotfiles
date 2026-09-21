# MEMORY.md — Notas duraderas del proyecto de audio

## Investigación de la distorsión (20-sep-2026) — leer esto primero
→ **Detalle en `diagnostico_distorsion_tiempo_real.md`** (1 778 líneas). Esencial:
**NUEVE EVENTOS (16:42:11 · 16:58:49 · 17:15:31 · 18:02:22 · 18:06:26 · 18:14:20 · 18:18:07 ·
18:36:59 · 18:39:39), sin cambiar nada.** El usuario ejecuta `audio-debug` al oírlos. **13 de 13 campos
idénticos:** `RUNNING`, `delay` sano, 0 xruns, 0 de kernel, 0 de gamescope,
`Sync`/`Source=SPDIF`/`Interface=Óptico`, enrutamiento correcto. **0 xruns con `log.level=2`
verificado** (`pw-cli info 0`) → un xrun **se habría registrado**. El journal de la ventana da
**«No entries»: CERO líneas, de ningún tipo**. **Ojo: leer `marcas.log` ENTERO** — eventos aparecieron
ahí sin que el usuario los reportara. **La marca va DESPUÉS del fallo** (mejor tiempo **~2 s**). El
fallo dura <1 s → todo lo medido es estado posterior; **esa brecha NO se cierra mejorando el script:
es tiempo de reacción humano** (el script tarda 0,53 s). Solo la cubre el registro **continuo**.
→ **Instrumentos:** `audio-debug` (**v2**, §6.16) → estado POSTERIOR completo.
`~/.local/state/audio-debug/vigilar.sh` (**v4**, 200 ms, latido 300 s) → ausencia de rastro DURANTE.
**v4 mete `trigger_time` en la clave** (`SESS:ST:TRIG`) para ver reinicios PCM — la v3 no los veía
(`RUNNING→RUNNING` con sesión nueva daba `cambios=0`). Probada con 4 casos sintéticos.
**Un log limpio que NO abarque la ventana del fallo no es negativo, es un vacío.**
**★ COBERTURA DEMOSTRADA EN TRES EVENTOS (7.º, 8.º y 9.º):** latidos cada ~234 ms que abarcan los
fallos, y **0 cambios / 0 sesiones / 0 xruns**. → **«El fallo no deja rastro en el PCM de la placa
madre» es OBSERVACIÓN DIRECTA, tres veces.**
→ **NO HAY PERÍODO.** Intervalos entre los 9 eventos: **2811 · 244 · 32 · 443 · 226 · 275 · 857 ·
161 s** (8 intervalos, 5048 s = 84,1 min). Tasa **~1 cada 10,5 min bajo juego**, pero **rango de 32 s
a 47 min: la media sola engaña, son RÁFAGAS, no un goteo** — no sirve para predecir.
→ **TRES sesiones PCM**: **A**=22831,259838722 (E1–E3) · **B**=28660,621866239 (E4) ·
**C**=29113,226834977 (E5–E9, **sobrevive a CUATRO eventos sin reabrirse**). **`hw_ptr` vuelve a 0 por sesión.**
→ **TASA:** A (2982 s) **47 939,19 Hz (−0,1267 %)** · C con 4 marcas (701 s) **47 940,09 Hz (−0,1248 %)**.
**PERO con 6 marcas (1994 s) C da −0,1623 %.** → **CORRECCIÓN: la cifra de 0,0019 puntos era optimista**
(comparaba dos ventanas elegidas); la dispersión real entre ventanas largas es **0,0375 puntos, el triple**.
**Sigue en pie:** la desviación ~0,13–0,16 % es estable y **no hay xruns** → el reloj no es exacto pero
**no está averiado**. **REGLA: los tramos cortos no valen.** C con 2 marcas (31,8 s) daba **−0,60 %**.
**Criterio: si añadir una marca MUEVE POCO el resultado, el tramo vale** — pero con 4 puntos aún se movía.
→ **La causa NO está en el software ni en el PCM de la placa madre.** Tres candidatos **sin aislar**:
**cable óptico · transmisor S/PDIF de la placa · recepción del RME**. Pruebas: cambiar el cable ·
mismo PC por **coaxial** · **otro DAC por el mismo cable** · **escucha pasiva sin juego**.
**Hipótesis (no verificada):** §31.3 — el SteadyClock engancha **aunque el flujo llegue degradado** →
cable marginal daría *enganche estable + artefactos esporádicos + CERO rastro + bajo carga*.
**Alcance:** un error de bit en la luz **no mueve el `hw_ptr`** → el contador **no corrobora ni refuta**
el cable. **Los 9 eventos fueron con Stalker abierto; falta uno fuera.**
→ **Criterios válidos:** la señal inequívoca es **`state: XRUN`**; los punteros NO sirven. **`hw_ptr`
es RELATIVO a la sesión PCM.** **`avail_max` NO cuenta xruns.** **`delay` NUNCA es alarma** (= `delta`,
misma distancia del búfer). **Journal limpio solo vale con `log.level` ≥2.**
→ **SIETE afirmaciones propias FALSAS:** `delta ≈ 970–1020` · saltos de `hw_ptr` · gamescope como
«hilo más prometedor» · cuadre por múltiplos del buffer · **la regularidad de 16,7 min** · **«la regla
ALSA no cubre `iec958`»** · **«convergencia limpia a −0,1248 %»**. **Patrón:** la lectura *parecía
confirmar* lo plausible y el sesgo iba hacia lo cómodo. Varias son de CONTABILIDAD.
**Reglas: medir el nodo con `pw-dump`, no leer el `.conf` · antes de restar dos punteros, comparar el
`trigger_time`; si no coincide, NO hay resta.**
→ **Nomenclatura:** no llamarlo «distorsión robótica» — condiciona el diagnóstico (culpó al
remuestreo). Describir lo que se oye: «corte seco», «chispa breve».

## PC
Sin Bluetooth ni Wi-Fi; sólo ethernet `enp8s0` (I225-V, 192.168.1.23). Placa ASUS PRIME Z690-A, 4 M.2
**Key M** (no E-key). Router ZTE ZXHN F679L (Wi-Fi 5). GPU RX 9070 XT · i5-13600K · 31 GB.

## LA CADENA REAL
`apps → placa madre iec958-stereo (S/PDIF) → CABLE ÓPTICO → RME` · `USB = SÓLO CONTROL`
El sink correcto es **`iec958-stereo`**, no `…RME…pro-output-0`: al USB da **silencio** (medido:
`IDLE`, 0 enlaces). **Regla: preguntar qué cable hay antes de llamar «problema» a un enlace.**
**Reloj (manual ADI-2 v1.8):** `Source = Auto` es el **ajuste de fábrica** (§12.1). **`Sync Source`
NO se configura** (§14.1.2) — **es una LECTURA, no un ajuste.** **SteadyClock FS (§31.3)** regenera el
reloj; la conversión D/A es «completely independent from the quality of the incoming clock signal» →
**«el jitter es el de la placa madre» está mal enfocado.** **Clave del diagnóstico:** el SteadyClock
engancha **aunque el flujo llegue degradado** → el RME puede marcar `Sync` con datos corruptos.
**Dato del propietario (escucha):** por **USB** oía distorsión de ~1 s **varias veces por hora**; por
**óptico**, un par al día o ninguna. **Mantener el óptico.**

## PipeWire
- **`99-rme-fix.conf` NO fuerza 192 kHz** (mito viejo): `clock.rate=48000`, quantum 1024, sin
  force-rate. **Remuestreo: ambas rutas en calidad 10** (rango 0–14, por defecto 4). **El grafo NO
  sigue la fuente: todo corre a 48 kHz** → **la cadena no es bit-perfect.**
- **`RUNNING` en `/proc/asound` NO prueba que suene** (el RME tiene `session.suspend-on-idle=false`
  y `node.pause-on-idle=false`). Comprobar el **nodo en PipeWire** + si está `corked`. **Ojo:** al
  **medir con `pw-dump`**, `iec958` y el RME tienen **las mismas** propiedades; la única asimetría es
  **`api.alsa.headroom = 0`** en `iec958` vs. **2048 pedido** para el RME (control). **Sin cambiar.**
- **Los puertos del RME en `pro-audio` son `playback_AUX0/AUX1`, no `FL/FR`. Sin volumen de salida
  por hardware.**
- **Destinos por aplicación** en `~/.local/state/wireplumber/stream-properties`: mover una app en el
  panel **queda grabado**. **Limpiar: parar `wireplumber` primero**, quitar `target` con Python.
- **EasyEffects: trampa ya activada (20-sep).** Llevó las apps a `easyeffects_sink` con su
  `outputDevice` en un **nodo inexistente** → **silencio total**. **Ojo: `[EffectsPipelines]
  bypass=true` → el PEQ no actúa. Regla: si desaparece el audio y el sink por defecto es correcto,
  mirar EasyEffects primero.**
- `qemu` usa el RME como **captura**. Sin bypass por ALSA directo (no hay `~/.asoundrc`).
- **Seis sinks**: las **Navi pro-output-3/7/8/9** son UNA GPU con 4 conectores; **sólo pro-7** tiene
  algo (monitor LG por DisplayPort). **`iec958-stereo`** → cable óptico. **`…RME…pro-output-0`** = RME
  por USB (control).

## Fuentes de música
- **Cider 4.0.9.1** = Electron del web de Apple Music. **Medido** en su caché (`esds`): **AAC-LC, 256
  kbps, 44,1 kHz**; entrega a PipeWire a **48 000 Hz** (Chromium remuestrea dentro). **Verificar
  códec:** DevTools → Network, `.m3u8`, o caudal (AAC 256 ≈ 32 KB/s). Guía: skill
  `pipewire-grafo-y-codec-streaming`.
- **Spotify (1.2.96.518): 160 kbps, no sin pérdida.** `spotify.audiophile`: `HIGH=3`=160,
  `VERY_HIGH=4`=320 Ogg, `LOSSLESS=5`. **Sin Premium no hay sin pérdida.** Alternativa gratis real:
  **archivos propios por el DMP-A6 → RME**.
- **Lossless en Arch + offline de 15.000: ningún servicio cumple las tres** (Spotify tope 10.000;
  Qobuz sin cliente Linux y **QBZ retirado 20-sep-2026**; TIDAL offline roto). **Para offline, Apple
  Music.** Detalles: `tidal_descargas_offline_bug.md`, `comparativa_lossless_offline_15k.md`,
  `qobuz_webplayer_lossless.md`.

## Sink por defecto — CORREGIDO 20-sep-2026
**Debe ser `alsa_output.pci-0000_00_1f.3.iec958-stereo`, nunca el RME-USB. NO se guarda como valor
único** sino como **lista ordenada** en `~/.local/state/wireplumber/default-nodes` (`…sink.0` era el
RME-USB → WirePlumber coge el primero y **volvía ahí en cada arranque**). **Arreglar SIEMPRE en el
archivo**, no solo con `pw-metadata`; limpiar el RME-USB en `default-routes`. Respaldos `.bak-2026-09-20`.
**Suena igual aunque el defecto esté mal porque `pipewire-pulse` intercala un nodo «Control de volumen
de PulseAudio»** — fallo latente, no audible. **Regla: no fiarse del oído, usar `pactl get-default-sink`.**

## RME serie ADI-2 EX (estado 20-sep-2026)
Anunciada 3-jun-2026. Sólo el **ADI-2 Pro EX** tiene página y precio (**CHF 1699**). **DAC EX y
2/4 Pro EX: 404, sin precio oficial ni disponibilidad en México** («late Q3 2026»). El precio de
$2,499 USD del 2/4 Pro EX **es de un revendedor, no de RME**. Automatización
`078e7794-bd6a-45c0-bfba-ce1f160564bc`.

## Cuello de botella
**No está en la electrónica.** Orden: (1) grabación y máster, (2) formato de entrega, (3) audición,
(4) almohadillas y sellado, (5) PEQ de 5 bandas, (6) software. **El DAC y el amplificador no limitan**
(~14 dB de margen con el Aune). **El PEQ está saturado:** `HEKSE-HarmanV4` usa las 5 bandas + shelf y
una Harman necesita 7–10 filtros. **Único límite real, rompible gratis con EasyEffects.** Los
`.adieqpr` **sólo guardan EQ**. **Transporte:** el óptico falla menos que el USB.

## Dónde está cada cosa
- **Fichas** → `referencia-equipos.md`. **Diarios:** `2026-09-*.md`. **Manuales:** `manuales/` (RME v1.8
  §§12.1/14.1.2/31.3 · Eversolo DMP-A6).
- **Diagnóstico:** `diagnostico_distorsion_tiempo_real.md` — **§6.15** los eventos 8.º y 9.º y la
  corrección de convergencia · **§6.16** la reconstrucción de `marca-audio` (3 fallos) · **§10** las
  siete correcciones · **§6.7–§6.14** los siete primeros eventos.
- **Instrumentos:** **`share/scripts/audio-debug`** (enlace en `~/.local/bin/audio-debug`, así que
  basta `audio-debug`) + bitácora **`share/scripts/audio-debug.md`** + capturas
  **`share/scripts/audio-debug.log`**. **Los tres viven juntos**; el script resuelve las rutas desde
  su propia ubicación. Vigilante: `~/.local/state/audio-debug/vigilar.sh` (**v4**).
- **Convención de `share/scripts/`:** cada script lleva su `.md` al lado; `share/scripts` **NO está en
  el PATH** (por eso el enlace en `~/.local/bin`). Estilo de esos `.md`: español, conciso.
- **Si `audio-debug` da `estado=?` NO es un fallo:** significa que no había sesión PCM abierta (sin
  audio sonando o en pausa). Comprobar con `cat /proc/asound/card1/pcm*p/sub*/status` → «closed».
- **Entregables** (raíz): `enrutamiento_audio_al_rme.md` · `verificacion_grafo_pipewire.md` ·
  `cuello_de_botella_cadena.md` · `audio_context.md` · `fuente_remuestreo_y_perdida.md` ·
  `analisis_rme_dac_fs_vs_adi-2-4_pro_ex.md` · `analisis_rme_vs_eversolo_a8_gen2.md` ·
  `cable_y_almohadillas_he1000se.md` · `fichas/`.
