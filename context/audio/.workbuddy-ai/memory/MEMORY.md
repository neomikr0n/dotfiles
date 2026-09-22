# MEMORY.md — Audio
> Detalle: `diagnostico_distorsion_tiempo_real.md` (**§11 alcance, leer primero**; §10 las 8
> correcciones) · `distorsion_anexo.md` · `referencia-equipos.md` · diarios `2026-09-*.md` ·
> `manuales/` (RME v1.8) · `comparativa_lossless_offline_15k.md` · `analisis_rme_*.md` ·
> skill `pipewire-grafo-y-codec-streaming`.

## Distorsión (21-sep) — causa NO atribuida
9 eventos el 20-sep, 13/13 campos idénticos y sanos. La marca va **después** del fallo (~2 s de reacción
humana, fallo <1 s) → lo medido es estado POSTERIOR. Ráfagas.
- **«El software está descartado» SE RETIRA** (8.ª afirmación falsa, error de **alcance**): «mi
  instrumento no lo vio» ≠ «no ocurrió»; la hipótesis del cable **no era falsable**. Sale por USB y por
  óptico → **el software es factor común.**
- **Falta el control positivo:** 0 xruns desde el 1-sep → «0 xruns ⇒ se habría registrado» es suposición.
- Orden: 0) control positivo · 1) escucha pasiva sin juego (los 9 con Stalker) · 2) cable · 3) coaxial ·
  4) otro DAC · 5) USB. **Señal inequívoca = `state: XRUN`** (`hw_ptr` relativo a la sesión PCM,
  `avail_max` no cuenta xruns, `delay` nunca es alarma).
- **Nomenclatura abierta:** «audio robotico» ×10 y «corte seco» ×1 (lo propuse yo) → no consta que sean
  el mismo síntoma.

## Cadena y reloj
`apps → iec958-stereo (S/PDIF) → CABLE ÓPTICO → RME`; `USB = sólo control`. Sink correcto
**`iec958-stereo`**, no `…RME…pro-output-0`. **Preguntar qué cable hay antes de llamar «problema» a un
enlace.** RME v1.8: `Source=Auto` de fábrica (§12.1); **`Sync Source` NO se configura (§14.1.2), es una
lectura**; SteadyClock FS (§31.3) → la conversión D/A es independiente del reloj entrante.

## PipeWire
`99-rme-fix.conf` **no** fuerza 192 kHz (48000, quantum 1024, remuestreo 10) → **todo corre a 48 kHz: no
es bit-perfect**. El sink por defecto se guarda como **lista ordenada** en
`~/.local/state/wireplumber/default-nodes` → arreglar **en el archivo**; **no fiarse del oído, `pactl
get-default-sink`**. `RUNNING` en `/proc/asound` no prueba que suene. **EasyEffects ya causó silencio
total** → mirarlo primero si el audio desaparece con el sink correcto.

## Cuello de botella
**No está en la electrónica:** (1) grabación/máster (2) formato (3) audición (4) almohadillas (5) PEQ
(6) software. DAC y ampli no limitan (~14 dB de margen). **El PEQ sí:** `HEKSE-HarmanV4` usa 5 bandas +
shelf y una Harman necesita 7–10 → único límite real, rompible gratis con EasyEffects.

## Instrumentos
`share/scripts/audio-debug` (enlace en `~/.local/bin`) con su bitácora `.md` y `.log` al lado;
`estado=?` no es fallo. Vigilante `~/.local/state/audio-debug/vigilar.sh`.

## Wallpaper de vídeo (21-sep-2026)
Motor: **`skwd-paper-v2`** (cliente; `skwd-paper-v2 serve` es el demonio) + renderizador
**`skwd-wall-vk`**. **`mpvpaper` está retirado.** Activo en DP-2: **`yellowmatrix-deepseek144.mp4`**
(AV1 3440×1440, 144 fps, 2318 frames, 17,1 MB, con RIFE), **capa `bottom`**. El ecualizador de mpv y
`--panscan=1` van **grabados en los píxeles** → no se pasa ninguna opción de reproducción. El original
no era de 60 fps (era 30 duplicado). Respaldo intacto `yellowmatrix-original.mp4` (md5 `5b8b550e…`).
**Tres trampas ya pagadas:**
1. **Capas:** `apply` usa `background` por defecto, pero `bottom` se dibuja **encima** → un renderizador
   viejo **tapa** al nuevo y devuelve `ready: true` sin cambiar nada. **Limpiar antes de arrancar**
   (`skwd-paper-v2 stop DP-2` + `pkill -TERM -x mpvpaper` + `pkill -TERM -x skwd-wall-vk`).
2. **`hl.exec_cmd` recibe una CADENA**: `hl.exec_cmd(skwd-paper-v2 apply …)` sin comillas es error de
   **sintaxis** y **deja muerta toda `hyprland.lua`** sin dar la cara. Detector: `hyprctl configerrors`.
3. **Dos motores instalados a la vez:** `skwd-deck-bin` (viejo: `skwd-walld`, socket `skwd-wall-v2/`)
   sigue **`enabled`** → **en cada login recrea una capa `bottom`** que tapa la nueva.
Detalles: `optimizacion_wallpaper_*.md` · skills `video-wallpaper-horneado-mpv` y `hyprland-lua-keybinds`.

## Transparencia de ventanas (21-sep-2026) — `override` es obligatorio para cifras exactas
`decoration:active_opacity=1.0` · `inactive_opacity=0.9` (hyprland.lua 77-78). **`opacity` es un
PRODUCTO por defecto** (doc oficial) → `"0.9 0.8"` da **0.90/0.72**, no 0.9/0.8. Exacto =
**`"0.9 override 0.8 override"`** (convención que ya usaban `chatgpt-pet`, `zen-opaque`, `steam-games`).
Las tres van tras la global `0.9 0.9` (la última coincidencia gana): `workbuddy-opacity`
`^(WorkBuddy AI)$` · `codex-opacity` `^(Chatgpt)$`+`float=false` (**Codex tiene clase `Chatgpt`**;
`float=false` la separa de la mascota) · `steam-opacity` `^(steam)$` (juegos `steam_app.*`, ya con
`1.0 override`). VS Code (`code`) **no se toca**: tiene `code-dim 0.90 0.75` y `editor-dim 0.70 0.70`.
**La opacidad efectiva NO se puede leer** (ni `hyprctl clients -j` ni el objeto de ventana de Lua) →
la comprobación es visual y del usuario; con la sesión en uso medir píxeles no vale (el workspace
especial tapa las ventanas).

