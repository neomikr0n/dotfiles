# Transición a Lua — Hyprland 0.56

> Documento generado el 2026-09-14. Resume el procedimiento completo de migración
> de `hyprland.conf` + `n30.conf` a un único `hyprland.lua`, incluyendo la auditoría
> previa, los conflictos encontrados, las decisiones tomadas y cómo verificar/rollback.

---

## 1. Contexto: por qué Lua y cómo carga Hyprland los archivos

Desde **Hyprland 0.55**, el parser hyprlang (`.conf`) está deprecado en favor de Lua:

- Hyprland busca **primero** `~/.config/hypr/hyprland.lua`.
- Si existe, **se usa exclusivamente ese archivo** y `hyprland.conf` se ignora por completo.
- Si no existe, cae de vuelta al `hyprland.conf` (compatibilidad con versiones antiguas).

Consecuencia importante que había que tener en cuenta: en la config antigua,
`hyprland.conf` terminaba con `source = ~/.config/hypr/n30.conf`. Al migrar a Lua
esa cadena desaparece, así que **todo** lo que vivía en ambos `.conf` tenía que
quedar en el `hyprland.lua`, o se perdería silenciosamente.

Documentación de referencia:
- Anuncio oficial: <https://hypr.land/news/26_lua/>
- Wiki (sintaxis nueva): <https://wiki.hypr.land/Configuring/Start/>
- Ejemplo oficial: <https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua>

### Estado inicial de los archivos

| Archivo | Rol |
|---|---|
| `hyprland.conf` (9.3 KB) | Config base: monitor comodín, decoration, animaciones, reglas de ventana `windowrule-1..19`, binds principales. Terminaba con `source = n30.conf`. |
| `n30.conf` (16 KB) | Capa personal: monitor DP-2 10-bit, env vars, animaciones Material 3, ~50 windowrules, autostart con sleeps, zoom de cursor con `hyprctl+jq`, wallpaper mpvpaper. |
| `n30.lua` | Experimento previo con `hl.bind`/`hl.window_rule` (flameshot). **No** estaba sourceado (`#source` comentado), así que su contenido no entró en la migración. |
| `hyprland.lua.dms-2026-09-06` | Backup que generó DMS; tampoco activo. |

---

## 2. Procedimiento usado

### Fase 1 — Auditoría de los `.conf` (lectura línea a línea)

1. Localicé los archivos activos en `~/.config/hypr/` (había copias viejas en
   `~/.config/_OLD/` que se descartaron).
2. Leí `hyprland.conf` y `n30.conf` completos y los crucé sección por sección
   buscando: settings duplicados, binds que se pisaban entre archivos, reglas de
   ventana solapadas, variables sin definir y opciones inexistentes.
3. Cruce de binds: como `n30.conf` se sourceaba **al final**, cualquier bind
   repetido lo resolvía n30. Eso dejó varios binds "muertos" en `hyprland.conf`.

Resultado: ~20 hallazgos agrupados en conflictos de binds, duplicados, errores
reales y reglas de ventana solapadas (detalle en §3).

### Fase 2 — Decisiones de migración (acordadas contigo)

| Decisión | Elección |
|---|---|
| Conflictos de binds/settings | Gana siempre **n30.conf** (era el comportamiento real en pantalla) |
| **Excepción**: `Ctrl+Alt+Del` | **Processlist de DMS**, no `systemctl reboot` (decisión explícita tuya) |
| Reglas zen/steam | Fusionar y dejar comentario apuntando a la regla de excepción que mantiene a zen sin transparencia |
| Wallpaper mpvpaper | Se deja como `exec` (se relanza en cada reload), tal como estaba |
| Destino | **Todo unificado en un solo `hyprland.lua`** |

### Fase 3 — Investigación de la API Lua

Antes de escribir el archivo verifiqué la sintaxis exacta para no traducir a ciegas:

- **Ejemplo oficial** `example/hyprland.lua` en el repo de Hyprland → patrón de
  `hl.monitor`, `hl.env`, `hl.config({...})`, `hl.curve`, `hl.animation`,
  `hl.bind`, `hl.dsp.*`, `hl.window_rule`, `hl.layer_rule`.
- **Wiki de Binds** → sintaxis de teclas (`"SUPER + Q"`), flags como tabla de
  opciones (`{ release = true }`, `{ repeating = true }`, `{ locked = true }`,
  `{ mouse = true }`, `{ drag = true }`, `description = "..."`).
- **Wiki de Dispatchers** → mapa de equivalentes dispatcher a dispatcher.
- **Wiki de Window Rules / Expanding functionality** → propiedades de reglas,
  `hl.get_config`, eventos `hyprland.start` / `config.reloaded`.

### Fase 4 — Escritura del `hyprland.lua`

Traducción sección por sección (mapa completo en §4), con estas técnicas:

- **Binds en bucle**: los 9 workspaces numerados (×3 variantes) → un `for i = 1, 9`.
- **Timers en vez de sleeps**: los `exec-once = bash -c "sleep N && hyprctl dispatch exec ..."`
  se convirtieron en `hl.timer(..., { timeout = N*1000, type = "oneshot" })`.
- **Zoom de cursor nativo**: los 8 binds que spawneaban
  `hyprctl keyword cursor:zoom_factor $(hyprctl getoption ... | jq ...)` por cada
  pulsación ahora son dos funciones locales (`zoomBy`, `zoomReset`) que leen y
  escriben la opción directamente con `hl.get_config` / `hl.config`. Sin procesos
  externos, sin jq.
- **Semántica de `exec` vs `exec-once`**: `exec` corre en cada reload. Para
  preservarlo (wallpaper y auto-game-mode) se registran las mismas funciones en
  `hl.on("hyprland.start", ...)` **y** `hl.on("config.reloaded", ...)`.
- **Sonido de workspace** (`play -v 0.1 ...`): se traduce a un callback que hace
  `hl.dispatch(...)` + `hl.exec_cmd(...)`. `exec_cmd` es asíncrono, así que no
  bloquea el bind (requisito de la API: nunca llamar cosas bloqueantes en un bind).
- **Variables de hyprlang → locales de Lua**: `$mainMod`, `$term`, `$music`, etc.
  pasan a ser `local mainMod = "SUPER"` etc., interpoladas con `..`.

### Fase 5 — Validación

1. `luac -p hyprland.lua` → detectó un error real: `col.active_border` no es un
   identificador Lua válido (el punto). Se corrigió a `["col.active_border"] = ...`.
2. Revalidación → **SINTAXIS OK** (589 líneas).
3. Revisión manual de duplicados que introduje al traducir (bloque "Move to
   Monitor" duplicaba 6 teclas de "Window Movement"; regla kalk repetida) →
   se limpiaron dejando nota.
4. Pendiente del lado del usuario (no ejecutable desde la sesión de edición):
   `hyprctl configerrors` tras el reload y prueba de los binds críticos.

### Respaldos creados

```
~/.config/hypr/hyprland.conf.bak-preluau-20260914
~/.config/hypr/n30.conf.bak-preluau-20260914
```

Los `.conf` originales **no se tocaron**: siguen en su sitio como fallback de
versiones antiguas. Basta renombrar/borrar el `.lua` para volver a ellos.

---

## 3. Hallazgos de la auditoría (lo que motivó cada cambio)

### 3.1 Conflictos de binds — `hyprland.conf` tenía binds muertos

`n30.conf` se sourceaba al final, así que ganaba siempre. Estos binds de
`hyprland.conf` no hacían nada:

| Tecla | hyprland.conf (muerto) | n30.conf (efectivo) | Resolución en el .lua |
|---|---|---|---|
| `Ctrl+Alt+Del` | processlist DMS | `systemctl reboot` | **Processlist DMS** (tu excepción; de paso se elimina un reboot sin confirmación) |
| `$mod+L` | movefocus right | `screenlock.sh` | screenlock (movefocus-L eliminado) |
| `$mod+CTRL left/right` | focusmonitor | workspace ±1 + sonido | workspace con sonido |
| `$mod+minus/equal` | resizeactive ±10% | zoom de cursor | zoom de cursor |
| `$mod+SHIFT+flechas` | movewindow (duplicado exacto) | movewindow | una sola definición |
| `class ^(steam)$` | float on | tile on | tile on (el cliente Steam se teselaba de facto) |
| `$mod+SHIFT+CTRL left/right` | movewindow l/r **y** movewindow mon:l/r | — | solo `movewindow l/r` (las `mon:` disparaban después y eran redundantes) |

Además había riesgos sin resolver: `Ctrl+Alt+Del` reiniciaba el sistema y
`$mod+SHIFT+E` hacía `exit` sin confirmación. El reboot desapareció con la
excepción; el `exit` se conserva tal cual (con comentario en el archivo).

### 3.2 Duplicados eliminados

1. `dbus-update-activation-environment` + `systemctl --user import-environment`
   se ejecutaban **dos veces** (una por archivo) → una sola.
2. **cliphist dos veces**: `wl-paste --watch cliphist store` (todos los tipos, en
   hyprland.conf) y `wl-paste --type text --watch cliphist store` (n30.conf) →
   historial duplicado. Queda solo el de todos los tipos (es superconjunto).
3. Secciones `input`, `general`, `misc` pisadas:
   - `kb_layout = us` (hyprland) era muerto → el real es `latam`.
   - `misc.vrr = 1` muerto → `vrr = 2`.
   - gaps 5/5, border_size 0 y colores grises muertos → 0/0, 2, ámbar.
4. Animaciones `border`, `fade`, `workspaces` definidas en ambos → solo las de
   n30.conf (md3/easeOutExpo).
5. `movetoworkspace e+1/e-1` con 3 bindings distintos ($mod+CTRL+↑↓,
   $mod+SHIFT+PgUp/PgDn, $mod+SHIFT+U/I) → se conservan (no colisionan, son
   teclas distintas), ya no hay razón para duplicar definiciones.

### 3.3 Errores reales corregidos

| Error | Dónde | Corrección |
|---|---|---|
| `$mainMod_L` — variable **sin definir** | n30.conf:157 `bindr = $mainMod, $mainMod_L, togglespecialworkspace` | ⚠️ Corrección posterior (§"Espacio especial"): el bind SÍ funcionaba por sustitución de prefijo en hyprlang ($mainMod_L → "SUPER_L"); restaurado explícitamente en el `.lua` |
| `CTRLx` — modificador **inválido** | n30.conf:241 `bind = $mainMod CTRLx, mouse_down` | Bind eliminado (nunca registró) |
| `env = vulkan-driver,radv` — **no es una variable de entorno** | n30.conf:33 | Eliminada (`MESA_LOADER_DRIVER_NAME=radv` sí es válida y se queda) |
| `rgba(255,255,155,0)` — formato de color inválido | n30.conf:56 | `rgba(ffff9c00)` (borde inactivo transparente, que era la intención) |
| `pkill -CONT` después de `pkill -TERM` | n30.conf:95 (`$w_cleanup`) | Simplificado a dos `pkill -TERM` (reanudar un proceso recién matado no hace nada) |
| Regla muerta `opacity 0.99 steam_app_.*3` | n30.conf:195 | Eliminada: la regla posterior `opacity 1.0 override (steam_app.*)` la pisaba siempre |

### 3.4 Reglas de ventana fusionadas

| App | Antes | Ahora |
|---|---|---|
| zen | 3 reglas (border en hyprland.conf, opacity override + border en n30.conf) | 1 regla `zen-opaque` |
| steam | 5 reglas (tile, opacity 0.99 muerta, opacity override+fullscreen+float, Ark específico, steam_games_performance) | 2 reglas (`steam-client-tiled`, `steam-games`) + Ark |
| megasync | 3 opacidades distintas (0.85, 0.35, 0.80 en clases distintas) | 2 (una por clase real: `nz.co.mega.megasync` con la 0.35 que ganaba, `MEGAsync` con la suya) |
| kalk | 3 reglas (opacity, float genérico, size/move) | 2 (`kalk-opacity`, `kalk-float` con size/move integrados) |
| PiP | `windowrule-16` (firefox) + regla por título en n30.conf | 1 regla por título (cubre cualquier PiP, incluido zen) |
| kitty / ghostty | opacity en n30.conf + border 0 en hyprland.conf | 1 regla por terminal |
| dynisland | 2 reglas con `zen` y `steam_app_2399830` metidos en la alternación | 2 reglas limpias (esos dos ya estaban cubiertos por sus reglas propias) |
| `windowrule-1..19` | nombres genéricos | nombres semánticos (`wezterm-borderless`, `dms-shell-float`, …) |
| Regex sin anclar (`Calculator`, `$term`, `(steam_app.*)`…) | match parcial posible | todas ancladas `^…$` |

### 3.5 La excepción de transparencia (comentario pedido)

El dimming global del sistema era `windowrule-19` de hyprland.conf:

```
windowrule = opacity 0.9 0.9, match:class negative:^(zen)$, match:float 0, match:focus 0
```

Es decir: **todas** las ventanas no flotantes sin foco bajan a opacidad 0.9,
**excepto zen**, que está excluido con el match negativo `negative:^(zen)$`.
Además zen tiene su propia regla con `opacity = "1.0 override"` (override =
opacidad absoluta, no multiplicador), así que zen queda siempre opaco y sin borde.

En el `hyprland.lua` esa regla se llama `global-inactive-opacity` y lleva
comentarios en tres sitios: en la propia regla, en `zen-opaque` y en
`steam-games` (los juegos de Steam quedan opacos por su propio
`opacity "1.0 override"`, no por la exclusión negativa).

---

## 4. Mapa de traducción hyprlang → Lua (API usada)

### 4.1 Estructura general

| hyprlang | Lua |
|---|---|
| `monitor=DP-2,3440x1440@144.05,auto,1,bitdepth,10` | `hl.monitor({ output="DP-2", mode="3440x1440@144.05", position="auto", scale=1, bitdepth=10 })` |
| `env = X,y` | `hl.env("X", "y")` |
| secciones (`input { ... }`, `general { ... }`, `misc { ... }`) | un solo `hl.config({ input = {...}, general = {...}, ... })` |
| `bezier = nombre, x1,y1,x2,y2` | `hl.curve("nombre", { type="bezier", points={{x1,y1},{x2,y2}} })` |
| `animation = name, 1, speed, curve, style` | `hl.animation({ leaf="name", enabled=true, speed=speed, bezier="curve", style="style" })` |
| `exec-once = cmd` | `hl.exec_cmd("cmd")` dentro de `hl.on("hyprland.start", ...)` |
| `exec = cmd` (start + cada reload) | misma función registrada en `hyprland.start` **y** `config.reloaded` |
| `$var = valor` | `local var = "valor"` |
| `exec-once [workspace N silent] app` | `hl.exec_cmd("app", { workspace = "N silent" })` |
| `bash -c "sleep N && ..."` | `hl.timer(function() ... end, { timeout = N*1000, type = "oneshot" })` |

### 4.2 Binds

| hyprlang | Lua |
|---|---|
| `bind = MOD, K, dispatcher, args` | `hl.bind("MOD + K", hl.dsp.xxx({ args }))` |
| `binde` (repeat) | `{ repeating = true }` |
| `bindl` (locked) | `{ locked = true }` |
| `bindel` (repeat+locked) | `{ repeating = true, locked = true }` |
| `bindr` (release) | `{ release = true }` |
| `bindd` (drag + descripción) | `{ drag = true, description = "..." }` |
| `bindm` / `bindmd` | `{ mouse = true }` (+ `drag = true`) |
| `bind = , K, exec, cmd` | `hl.bind("K", hl.dsp.exec_cmd("cmd"))` |
| `exec, X ; Y` (dos comandos) | callback: `hl.dispatch(...)` + `hl.exec_cmd(...)` |
| `pass, class:X` | `hl.dsp.pass({ window = "class:X" })` |

### 4.3 Dispatchers usados

| Dispatcher antiguo | `hl.dsp.*` |
|---|---|
| `killactive` | `window.close()` |
| `fullscreen, 1` / `fullscreen, 0` | `window.fullscreen({ mode = "maximized" })` / `{ mode = "fullscreen" }` |
| `togglefloating` | `window.float({ action = "toggle" })` |
| `movefocus, l` | `focus({ direction = "l" })` |
| `movewindow, l` / `movewindow, mon:l` | `window.move({ direction = "l" })` / `window.move({ monitor = "l" })` |
| `focusmonitor, l` | `focus({ monitor = "l" })` |
| `workspace, e+1` | `focus({ workspace = "e+1" })` |
| `movetoworkspace, N` / `movetoworkspacesilent, N` | `window.move({ workspace = N })` / `window.move({ workspace = N, follow = false })` |
| `togglespecialworkspace` | `workspace.toggle_special("special")` |
| `resizeactive, X Y` / `exact` | `window.resize({ x=..., y=..., relative=true })` |
| `layoutmsg, togglesplit` / `preselect l` | `layout("togglesplit")` / `layout("preselect l")` |
| `cyclenext` + `bringactivetotop` | `window.cycle_next()` + `window.alter_zorder({ mode = "top" })` |
| `togglegroup` | `group.toggle()` |
| `dpms, toggle` | `dpms({ action = "toggle" })` |
| `exit` | `exit()` |

### 4.4 Reglas de ventana

| hyprlang | Lua |
|---|---|
| `windowrule { name = X match:class = Y prop = Z }` | `hl.window_rule({ name = "X", match = { class = "Y" }, prop = Z })` |
| `match:title / match:xwayland / match:float / match:focus` | `match.title / match.xwayland / match.float / match.focus` |
| `negative:^(zen)$` | igual, como string dentro de `match.class` |
| `opacity 0.9 0.9` / `opacity 1.0 override` | `opacity = "0.9 0.9"` / `"1.0 override"` (string) |
| `move (x) (y)` / `size (w) (h)` | `move = { x, y }` / `size = { w, h }` |
| `size 70% 70%` | `size = { "70%", "70%" }` |
| `workspace = 5 silent` | `workspace = "5 silent"` |
| `layerrule { match:namespace ... }` | `hl.layer_rule({ name = ..., match = { namespace = ... } })` |

Orden de evaluación conservado: las reglas globales van **antes** que las de apps
(la última coincidencia gana), y `global-inactive-opacity` con su exclusión
`negative:^(zen)$` queda antes de todas las opacidades específicas.

---

## 5. Qué cambió de comportamiento (resumen honesto)

Intencionalmente distinto (acordado):

1. `Ctrl+Alt+Del` ya **no reinicia**: abre el processlist de DMS.
2. Binds que nunca funcionaron (`$mainMod_L`, `CTRLx`) ya no están.
3. cliphist ya no duplica entradas (una sola instancia, todos los tipos).
4. Las reglas `mon:l/d/u/r` de "Move to Monitor" ya no disparan junto a las de
   dirección (en el `.conf` ambas se ejecutaban; eran redundantes). Quedaron
   comentadas en el `.lua` por si se quieren restaurar.

Idéntico a propósito:

- Wallpaper mpvpaper con `exec` (se relanza en cada reload) — así lo pediste.
- `exit` en `$mod+SHIFT+E` sin confirmación (igual que antes; con comentario).
- Todos los launchers de DMS, sonidos de workspace, RME, ddcutil, scran,
  secuencias de autostart (mismos tiempos con timers) y reglas de ventana
  efectivas.

---

## 6. Verificación y rollback

### La herramienta clave: `Hyprland --verify-config`

**No hay que recargar para saber si la config va a fallar.** El binario trae un
modo de validación que parsea el config completo (Lua incluido: registra binds,
valida reglas, comprueba keysyms y argumentos de dispatchers) **sin arrancar el
compositor**:

```bash
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
```

Salida limpia = `config ok`. Salida con problemas = lista de errores con archivo
y línea, por ejemplo `Unknown keysym` o `field 'rounding': value 40 is more than
the maximum of 20`. Fue esta herramienta la que destapó los 4 errores de la
primera traducción (§6.1).

⚠️ Efecto secundario importante: `--verify-config` **ejecuta algunos comandos del
autostart** (en la práctica: los `exec` de wallpaper y game-mode). Con el comando
de wallpaper del .lua eso significa un `pkill mpvpaper` + relanzamiento; en una
sesión viva puede dejar el wallpaper muerto si el relanzamiento falla. Para
validar sin tocar la sesión, usa un archivo de prueba en `/tmp`:

```bash
Hyprland --verify-config -c /tmp/hyprprobe/hyprland.lua
```

Después de recargar, sigue disponible el chequeo en caliente:

```bash
hyprctl configerrors   # errores de la config ya cargada en la sesión viva
hyprctl binds | less   # revisar que los binds clave estén
```

#### Técnica de "probe" para descubrir la API

Como el validador reporta cada llamada fallida sin abortar el resto, sirve para
probar sintaxis dudosa antes de escribirla en el config real: se crea un
`/tmp/hyprprobe/hyprland.lua` con las variantes candidatas, se corre
`--verify-config` y las que **no** aparecen en el resultado son válidas. Así se
descubrió, por ejemplo, que `hl.dsp.window.resize` solo acepta números (no
strings `"100%"`) pero sí un flag `exact = true`, y que el keysym correcto es
`Control_R` (no `CTRL_R`).

### 6.1 Errores que `--verify-config` encontró y cómo se corrigieron

| Línea | Error | Causa | Corrección |
|---|---|---|---|
| 260/263 | `Unknown keysym: "CTRL_R"` | El .conf antiguo usaba `CTRL_R` como modificador; el parser Lua de binds pide el keysym real | `Control_R` (modificadores del monitor externo F1/F2) |
| 361 | `resize` rechaza `{ x = "100%" }` | El nuevo API de resize solo acepta enteros | Bind como función Lua: lee el ancho del monitor con `hl.get_active_monitor()` y hace `resize({ x = w, y = 0, exact = true })` (no-op seguro si el campo no existe) |
| 364/365 | idem con `"±10%"` | idem | `±100 px relative` (coherente con los binds de flechas que ya usaban 100) |
| 450/482 | `field 'rounding': value 40 is more than the maximum of 20` | El nuevo API valida rangos que hyprlang aceptaba sin quejarse | `rounding = 20` (máximo permitido) en `chromium-bar` y `safeeyes`, con comentario |

Además, la validación confirmó como correctas (sin error) todas las demás
llamadas dudosas: `hl.dsp.focus({ direction/monitor/workspace/window })`,
`window.move({ workspace, follow = false })`, `workspace.toggle_special`,
`alter_zorder({ mode = "top" })`, `dpms`, `pass`, `group.toggle`,
`fullscreen({ mode = ... })`, la ruta `cursor.zoom_factor` del zoom, los efectos
`size = { "70%", "70%" }` y `workspace = "5 silent"` de las reglas, y las
propiedades `immediate`, `stay_focused`, `min_size`, `suppress_event`.

### Puntos que la validación NO puede cubrir

`--verify-config` solo valida lo que se ejecuta al **cargar** el config. Lo que
vive dentro de callbacks (funciones de bind, timers, handlers de eventos) se
evalúa al pulsar/disparar, así que conviene probar a mano:

1. Zoom de cursor (`$mod+minus/equal`, `$mod+mouse_up`) — usa `hl.get_config`
   dentro del bind; la ruta validó, pero el flujo completo no.
2. `$mod+CTRL+F` (resize exact 100%) — depende de los campos del objeto monitor
   (`width`/`widthInPixels`/`pixelWidth`, se prueban en cascada).
3. Timers del autostart (secuencia de apps a los 3/5/7/10/20/25 s).
4. Sonido de cambio de workspace (`$mod+CTRL+left/right`).
5. Que el wallpaper no quede doble tras un reload (start + reload juntos).

### El incidente del STUB "autogenerated" (17:02)

Síntoma: cartel de error "usando una configuración autogenerada", sesión reducida
a 6 binds genéricos. Causa (reconstruida por timestamps y log):

1. El `hyprland.conf` desapareció/corrompió justo en un momento en que el
   `hyprland.lua` todavía tenía los 4 errores de §6.1.
2. Al recargar, Hyprland no encontró config válida y **escribió un STUB de 541
   bytes encima de `hyprland.conf`** (`This config is a STUB! This should never
   be generated.` + `autogenerated = 1`), cargándolo como config activa.
3. El overlay de errores de Hyprland es el cartel "espantoso".

Lección crítica descubierta aquí: **`hyprctl reload` NO re-escanea qué archivo
usar**. La elección `hyprland.lua` vs `hyprland.conf` se hace **solo al arrancar
la sesión**. Si arrancaste con `.conf`, ningún reload activará el Lua: hay que
cerrar sesión y volver a entrar.

Reparación aplicada: `hyprland.conf` restaurado desde
`hyprland.conf.bak-preluau-20260914`, reload verificado (158 binds,
`configerrors` vacío, sesión de vuelta en `.conf`), y el `.lua` ya validado
(`config ok`, también en carga doble simulando reload) esperando el reinicio de
sesión para activarse.

### Segunda sesión (Lua activo) — hallazgos del autostart

Activado el Lua (reinicio de sesión 17:23, log: `Using lua config found at
/home/n30/.config/hypr/hyprland.lua`), los programas "no abrieron". Diagnóstico:

1. **Los timers sí funcionaron**: steam y zapzap abrieron en el workspace 1 en
   modo *silent* (invisible desde el ws 2 donde estaba el usuario).
2. **Bug real del Lua config**: `hyprland.start` se dispara TAMBIÉN en cada
   `hyprctl reload` — cada reload re-ejecutaba todos los exec-once y
   re-agendaba los timers (copyq arrancó dos veces, apps a horas raras).
   FIX: guarda con `_G.__n30_autostart_done` — los globals de Lua persisten
   entre reloads, así que el bloque de autostart corre una sola vez por sesión
   (semántica real de exec-once).
3. **dolphin faltaba**: se quedó fuera de la migración (en el original tenía su
   propio `sleep 5`). Añadido como timer de 5s al workspace 3 silent.
4. El editor (`code`, timer de 3s) no arrancó en el primer intento (posible
   carrera al arrancar la sesión; hubo además un SIGSEGV de Hyprland durante
   ese login). Relanzado manualmente.
5. Dato nuevo de API: **`hyprctl dispatch` ahora evalúa expresiones Lua** —
   `hyprctl dispatch 'hl.dsp.exec_cmd("dolphin", { workspace = "3 silent" })'`.
   La sintaxis hyprlang antigua ya no funciona por ese camino.

### El espacio especial perdido (tecla Super sola)

Síntoma: tras migrar, la tecla Super sola ya no abría el workspace especial
(donde viven cider y btop). El bind era
`bindr = $mainMod, $mainMod_L, togglespecialworkspace` en n30.conf, que durante
la auditoría se marcó como roto por `$mainMod_L` sin definir — y se eliminó.

**Causa raíz del malentendido**: hyprlang hace sustitución de variables por
prefijo. `$mainMod_L` se expandía a `$mainMod`="SUPER" + sufijo "_L" → tecla
`SUPER_L` (la Super izquierda). Es decir, era un bind VÁLIDO desde hace años
(modificador SUPER + tecla Super_L, disparo al soltar por el flag `r`). Un
accidente afortunado de la sintaxis hyprlang.

**FIX en el `.lua`**, ahora explícito y documentado en el propio archivo:

```lua
hl.bind(mainMod .. " + SUPER_L",
    hl.dsp.workspace.toggle_special("special"),
    { release = true })
```

Verificado en tres niveles: `luac` OK, `--verify-config` = `config ok`, y tras
reload el bind aparece en `hyprctl binds` (`key: SUPER_L`, modmask SUPER,
dispatcher activo).

Moraleja para futuras migraciones: en hyprlang, un "variable sin definir" en un
bind puede ser en realidad una tecla escrita por concatenación accidental de
prefijo. Comprobar con `hyprctl binds` qué key registraba ANTES de darlo por
roto.

### Autostart v2: lanzamiento por conectividad real (sustituye a los sleeps)

Los sleeps fijos (7s/10s/20s) eran un parche: si la red tardaba más que el
sleep, zen/zapzap/steam arrancaban sin internet y pedían re-login/QR. Nuevo
diseño en el `.lua`:

1. **Un único proceso en background** hace `ping -c1 -W2 1.1.1.1` en bucle y
   toca el flag `$XDG_RUNTIME_DIR/hypr-online` cuando hay internet (muere al
   tocarlo — cero procesos residentes).
2. **Un timer de 1s en Lua** lee el flag con `io.open` (lectura de archivo
   local: no bloquea el event loop, sin procesos por chequeo).
3. Al detectar red, lanza **escalonado**: zen (ws2 silent) → +2s zapzap
   (ws1 silent) → +4s steam (ws1 silent) + el move de refuerzo 5s después.
   El timer se autodesactiva con `set_enabled(false)` (probado por probe que
   el handle de `hl.timer` lo expone).
4. **Timeout de gracia de 60s**: si iniciaste sin internet, lanza igual para
   no quedarte sin apps (las apps reintentan conectar por su cuenta).
5. editor (3s) y dolphin (5s) mantienen su secuencia fija: no dependen de red.
6. Todo dentro de la guarda `_G.__n30_autostart_done`: en un reload no se
   re-lanza el ping ni se duplica la cola (el flag persiste en la VM de Lua).

### Caza de bugs pre-reinicio (revisión final)

Cuatro bugs cazados en la revisión completa antes del siguiente login:

1. **Captura de región rota**: el bind de `Shift_R` quedó con modificador
   `SHIFT +` de más (en el `.conf` la tecla era Shift_R SIN modificador — la
   tecla derecha de shift ES la key). Corregido a `Shift_R` a secas.
2. **Dimming global pisando a las apps**: `global-inactive-opacity` estaba
   físicamente al FINAL del bloque de reglas; como la última coincidencia
   gana, el 0.9 global anulaba las opacidades específicas de apps en ventanas
   inactivas no flotantes (zapzap habría quedado a 0.9 en vez de 0.75). Movida
   al inicio del bloque (antes de las terminales), con comentarios zen/steam
   actualizados a la nueva posición.
3. **Ping sin límite**: el detector de red reintentaba para siempre si nunca
   había internet. Acotado a 120 intentos (~2 min) y el proceso muere solo.
4. **Resize sin repetición**: los binds de resize eran `binde` en el `.conf`
   (se repiten al mantener pulsado) y el Lua los registró sin `repeating`.
   Restaurado en los 6 binds (SHIFT+flechas y SHIFT+minus/equal).

Verificación final: `luac` OK, carga simple `config ok`, **doble carga
simulando reload `config ok`**, reload real OK, `hyprctl configerrors` vacío,
140 binds (Shift_R ×2, SUPER_L ×1).

### Login del 15/09 (15:14): autostart incompleto — causa raíz y fixes

Síntoma: solo abrieron genymotion, zen, CoreCtrl, cider y btop. Diagnóstico con
log de sesión (`..._1789506844_770639221`) y timeline de procesos:

1. **CAUSA RAÍZ — bug de la API Lua 0.56: los timers `type="oneshot"` nunca
   disparan.** El único timer `repeat` sí lo hizo (zen a +1s exacto por el flag
   de red); los 5 oneshot (editor 3s, dolphin 5s, zapzap +2s, steam +4s y su
   move) jamás se ejecutaron. Cero errores Lua en el log: el handler corrió
   completo. FIX: scheduler propio `after(ms, fn)` construido sobre `repeat`
   (cuenta ticks de 100ms, dispara y se autodesactiva). NO volver a usar
   oneshot en esta config.
2. **ksnip y megasync no están instalados** — sus `exec_cmd` fallan en silencio
   (copyq sí corre; es app de bandeja y no se ve). FIX: líneas comentadas con
   nota para descomentar si se reinstalan.
3. **chatgpt-open roto por sintaxis vieja**: línea 266 usaba
   `hyprctl dispatch exec "[workspace N silent] ..."` — en 0.56 `hyprctl
   dispatch` evalúa Lua y la sintaxis antigua ya no vale; con `set -e` el
   script moría sin lanzar la app. FIX: dispatch a
   `hl.dsp.exec_cmd("...", { workspace = "N silent" })` (probado en vivo:
   mascota abierta en ws2). Backup del script original:
   `chatgpt-open.bak-20260915`.

Extras del diagnóstico: el SEGV de las 15:14:03 era el Hyprland del GREETER de
dms (UID 941), no el de la sesión; el flag `hypr-online` se creó a los ~1s (la
red subió al instante) y el proceso de ping salió limpio.

Respaldos de este día: `hyprland.lua.bak-20260915` y
`chatgpt-open.bak-20260915`.

### Rollback

```bash
mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.pausa
hyprctl reload   # Hyprland cae de vuelta a hyprland.conf (intacto)
```

---

## 7. Estado final de `~/.config/hypr/`

| Archivo | Estado |
|---|---|
| `hyprland.lua` | **ACTIVO en la sesión** (desde el relogin de las 17:23; log: `Using lua config found at ...`). ~600 líneas, `luac` + `--verify-config` OK. Incluye todas las correcciones post-migración (§6.1, autostart, Super_L). |
| `hyprland.conf` | Restaurado tras el incidente del STUB; queda como fallback (Hyprland ya no lo lee mientras exista el `.lua`). |
| `n30.conf` | Intacto (idéntico al backup); queda como referencia. |
| `*.bak-preluau-20260914` | Snapshots previos a toda la operación. |
| `n30.lua`, `hyprland.lua.dms-*` | Experimentos previos, sin efecto. |

### Bitácora de la sesión Lua activa

- Confirmado en log y binds: 139 binds, 1 solo `Ctrl+Alt+Del` (processlist, ya
  no reboot), `hyprctl configerrors` vacío, wallpaper mpvpaper vivo.
- Corregido en caliente: autostart con guarda `_G` (exec-once real), dolphin
  re-añadido (5s, ws3), copyq duplicado eliminado, dolphin+editor lanzados a
  mano, bind del espacio especial restaurado (`SUPER_L` al soltar).
- Pendiente de probar a mano: zoom de cursor (`$mod+minus/equal/mouse_up`),
  `$mod+CTRL+F` (resize exact), sonido de workspace (**confirmado OK**),
  tecla Super sola (**restaurado, pendiente de confirmar**), y el autostart
  limpio completo en el próximo relogin (los 8 launches con sus workspaces).
- Cuando todo esté confirmado: archivar `hyprland.conf`, `n30.conf` y los
  `.bak` (o dejarlos, no molestan — Hyprland solo lee el `.lua`).
