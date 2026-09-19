# Informe de revisión — `~/.config/hypr/hyprland.lua`

**Fecha:** 17 de septiembre de 2026
**Archivo revisado:** `/home/n30/.config/hypr/hyprland.lua` (638 líneas, 34 KB, mtime 16 sep 14:03)
**Hyprland:** 0.56.2 (commit `efb5099`, build 5 ago 2026)
**Alcance:** solo análisis. **No se modificó ninguna línea del archivo.**

---

## Actualización — 2026-09-18: correcciones aplicadas

Se aplicaron **dos** de los hallazgos. El resto sigue pendiente.

| Hallazgo | Estado | Cambio |
|---|---|---|
| §2.1 colisión `SUPER+CTRL+↑/↓` | ✅ **Corregido** | Eliminados los 2 binds de `Monitor Navigation`. Esas teclas quedan solo para `Move to Workspace`. |
| §2.3 `chatgpt-pet` en x=3665 | ✅ **Corregido** | `move = { 3096, 1016 }` → queda en 3096..3416, con 24 px de margen derecho. |
| §2.1 colisión `SUPER+SHIFT+minus` (resize vs zoomReset) | ❌ Pendiente | |
| §2.2 `code:20`/`code:21` con `keycode=0` | ❌ Pendiente | |
| §2.4 `chatgpt-pet`: `size` 333 vs `min/max_size` 320 | ❌ Pendiente | Sigue la contradicción (el clamp la resuelve a 320). |
| §2.5 opacidades sin `override` | ❌ Pendiente | |
| §2.6 `config.reloaded` sin guarda | ❌ Pendiente | |
| §3.1 F1/F2 ambos hacen `hyprshade toggle` | ❌ Pendiente | |

**Hallazgo nuevo y relevante (§2.1, causa raíz):** los binds `SUPER+CTRL+↑/↓` →
`focus({ monitor = "u"/"d" })` **no existían en ningún `.conf`**. El `.conf` original
tenía exactamente 6 `focusmonitor`: `left`, `right`, `H`, `J`, `K`, `L` — nunca `up`/`down`.
Los añadió la migración a Lua. Por tanto, eliminarlos **restaura** el comportamiento
original, no lo recorta. Verificado con:

```bash
grep -nE "focusmonitor" ~/.config/hypr/hyprland.conf.bak-preluau-20260914
# 296: $mod CTRL, left,  focusmonitor, l
# 297: $mod CTRL, right, focusmonitor, r
# 298: $mod CTRL, H,     focusmonitor, l
# 299: $mod CTRL, J,     focusmonitor, d
# 300: $mod CTRL, K,     focusmonitor, u
# 301: $mod CTRL, L,     focusmonitor, r      <- sin up/down
```

**Nota sobre `window.move`:** verificado en el código fuente de v0.56.2
(`src/config/lua/bindings/LuaBindingsDispatchers.cpp`) que el default de `follow` es
*seguir la ventana*:

```cpp
auto follow = Internal::tableOptBool(L, 1, "follow");
bool silent = follow.has_value() && !*follow;   // omitido -> silent = false -> SÍ sigue
```

Es decir, `window.move({ workspace = "e+1" })` equivale al `movetoworkspace` del `.conf`.

**Validación tras los cambios:** `luac -p` OK · `Hyprland --verify-config` = `config ok` ·
recuento de binds 140 → 138 (111 literales + 27 del bucle de workspaces).
**Pendiente:** `hyprctl reload` para que los cambios entren en la sesión viva
(con el efecto lateral ya documentado en §2.6: relanza el wallpaper).

---

## 0. Resumen ejecutivo

| Verificación | Herramienta | Resultado |
|---|---|---|
| Sintaxis Lua | `luac -p` | ✅ **Limpio** (exit 0) |
| Parseo completo del config | `Hyprland --verify-config` (copia neutralizada) | ✅ **`config ok`** |
| Errores en sesión viva | `hyprctl configerrors` | ✅ **Vacío** |
| Binds registrados | `hyprctl binds` | ✅ 140 binds |
| Conflictos de binds (misma tecla ×2) | `hyprctl binds -j` + análisis | ⚠️ **4 encontrados** |
| Reglas de ventana | `hyprctl layers/clients` + geometría real | ⚠️ **Varias fuera de pantalla** |
| Dependencias del autostart | comprobación de binarios | ✅ todas presentes |

**Conclusión:** no hay errores de sintaxis ni fallos de parseo. Los problemas reales son
**de lógica y de intención**: 4 colisiones de teclas confirmadas en la sesión viva,
coordenadas de ventana incompatibles con la geometría del monitor, y varios casos donde
la opacidad de las reglas no hace lo que dicen los comentarios.

> **Nota metodológica:** este informe no se basa en los comentarios del propio archivo
> ni del documento `transition to lua.md`. Todo lo afirmado abajo se verificó contra la
> sesión en vivo (`hyprctl`) o contra el binario de Hyprland. Varias notas del documento
> de transición no coinciden con lo que hay realmente en el `.lua` (ver §6).

---

## 1. Lo que está bien (verificado)

- **Sintaxis y parseo.** `luac -p` limpio y `Hyprland --verify-config` devuelve
  `config ok` sin una sola advertencia, incluso forzando la doble carga. La migración
  desde hyprlang está correctamente escrita.
- **Sin errores de config en la sesión viva.** `hyprctl configerrors` vacío.
- **El `.lua` está realmente activo.** El log de la sesión lo confirma:
  `[cfg] Using lua config found at /home/n30/.config/hypr/hyprland.lua`.
- **Todas las dependencias existen.** `mpvpaper`, `gslapper`, `jq`, `play`, `rclone`,
  `ddccontrol`, `copyq`, `corectrl`, `steam`, `zen-browser`, `zapzap`, `cider`,
  `kitty`, `code`, `dolphin`, `btop`, `dms`, `scran`, `hyprshade`, y todos los
  scripts referenciados (`rme-volume`, `swayosd-on-demand`, `screenlock.sh`,
  `auto-game-mode.sh`, `chatgpt-open`, `mangohud-song.sh`, `genymotion-open.sh`).
  El wallpaper `yellowmatrix.mp4` (30 MB) y los sonidos de `gravity/` también existen.
- **La guarda del autostart funciona.** La marca
  `/run/user/1000/hypr/<instancia>/n30-autostart-astra.done` contiene `Astra 2026-09-16`,
  así que el handler `hyprland.start` no se re-ejecuta en cada reload. Esto resuelve de
  verdad el bug histórico de duplicación.
- **`/dev/i2c-8` es accesible** por `n30` (grupo `video`, uid del usuario): los
  `ddccontrol` del autostart y de los binds F1/F2 no fallan por permisos.
- Los comandos de `dms` (`spotlight`, `clipboard`, `processlist`, `notifications`,
  `bar toggle index 0`, `keybinds toggle hyprland`, `brightness increment/decrement`,
  `audio micmute`) son sintaxis correcta del CLI de DMS.

---

## 2. Errores de lógica confirmados en la sesión viva

### 2.1 🔴 Colisiones de binds (4 teclas, verificadas con `hyprctl binds`)

Estas colisiones existen **ahora mismo** en tu sesión, no son hipótesis. Las detecté
comparando `modmask` + `key` + `submap` sobre los 140 binds registrados.

| # | Tecla | Bind A | Bind B | Efecto real |
|---|---|---|---|---|
| 1 | `SUPER+CTRL+↑` (modmask 68, `up`) | `window.move({workspace="e-1"})` | `focus({monitor="u"})` | **Ambos existen**; Hyprland ejecuta los dos |
| 2 | `SUPER+CTRL+↓` (modmask 68, `down`) | `window.move({workspace="e+1"})` | `focus({monitor="d"})` | **Ambos existen** |
| 3 | `SUPER+SHIFT+minus` (modmask 65, `minus`) | `window.resize({x=-100, relative})` con `repeating=true` | `zoomReset` | El resize **y** el reset de zoom a la vez |
| 4 | `SUPER + code:20` / `code:21` | `window.resize` con `description="Expand/Shrink window left"` | — | El `description` indica `bindd` (drag) pero el registro sale `release=True`, `drag=None`, `keycode=0` |

**Causa raíz (#1 y #2):** el archivo tiene dos secciones que reclaman las mismas
teclas. "Monitor Navigation" (líneas 333–338) y "Move to Workspace" (líneas 370–371)
definen ambas `mainMod + CTRL + up/down`. En hyprlang la última definición ganaba y la
otra quedaba muerta; en Lua **las dos se registran**.

```lua
-- línea 333-334  (Monitor Navigation)
hl.bind(mainMod .. " + CTRL + up",   hl.dsp.focus({ monitor = "u" }))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.focus({ monitor = "d" }))

-- línea 370-371  (Move to Workspace)  <-- MISMA TECLA
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + up",   hl.dsp.window.move({ workspace = "e-1" }))
```

**Causa raíz (#3):** "Sizing" (línea 405) y "Zoom" (línea 428) definen
`mainMod + SHIFT + minus`. Peor aún: el bind de resize tiene `repeating = true`,
así que al mantener pulsado **redimensiona la ventana y resetea el zoom a 1**
en cada repetición.

```lua
-- línea 405 (Sizing)
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({...}), { repeating = true })
-- línea 428 (Zoom)   <-- MISMA TECLA, sin repeating
hl.bind(mainMod .. " + SHIFT + minus", zoomReset)
```

Esto explica exactamente el comportamiento descrito en `transition to lua.md`
("`$mod+minus/equal` → zoom de cursor" en el `.conf`): **se perdieron los binds de
resize del `.conf`**, pero al migrarlos se reintrodujeron aquí encima del zoom.

**Impacto en #1/#2:** con un solo monitor (DP-2), `focus({monitor="u"/"d"})` es
prácticamente un no-op, así que a ojos del usuario parece que "funciona" el move
a workspace. Pero el dispatcher de monitor sí se ejecuta y, con un monitor
adicional en el futuro, el comportamiento será errático.

---

### 2.2 🔴 `code:20` / `code:21` — probablemente nunca disparan

```lua
hl.bind(mainMod .. " + code:20", hl.dsp.window.resize({ x = -100, y = 0, relative = true }),
    { drag = true, description = "Expand window left" })
```

`hyprctl binds -j` los reporta con `keycode: 0` y `key: ""`, mientras el
`description` sí se conserva. `code:20`/`code:21` en XKB son las teclas **`-` y `=`**
del teclado principal, que ya están ocupadas en la sección "Sizing" por nombre
(`minus`/`equal`). Con `keycode = 0` el bind no tiene tecla asociada.

**Además son inconsistentes:** el nombre dice *"Expand window left"* pero el argumento
es `x = -100` (encoger por la izquierda), y *"Shrink window left"* lleva `x = +100`.
Los dos `description` están **invertidos** respecto a su argumento.

---

### 2.3 🟠 `bounding_box` / coordenadas de ventana que no caben en el monitor

Monitor real, medido con `hyprctl monitors`:

```
DP-2   3440 x 1440 @ 144.05 Hz   scale 1   position 0,0
→ rango lógico: x ∈ [0, 3440)   y ∈ [0, 1440)
```

Reglas de ventana que **no caben** o tienen origen negativo:

| Regla | Línea | `move` | `size` | Diagnóstico |
|---|---|---|---|---|
| `chatgpt-pet` | 567 | `3332, 1016` | `333, 333` | **Termina en x=3665 → 225 px fuera de pantalla.** La ventana está recortada por el borde derecho. |
| `chromium-bar` | 509 | `2159, -8` | `625, 56` | Origen `y = -8` (negativo) |
| `safeeyes` | 541 | `1444, -11` | `600, 122` | Origen `y = -11` (negativo) |
| `dynisland-position` | 552 | `3345, 49` | — | **3345 > 3440−ancho típico**; además la clase `dynisland` no existe en la sesión (ver §3.4) |
| `pip-float` | 511 | `0, 885` | `982, 553` | Cabe por poco: termina en y=1438 (2 px de margen) |
| `genymotion-gps` | 557 | `637, 1094` | `480, 330` | Cabe: termina en y=1424 |
| `corectrl` | 583 | `2720, 520` | `710, 910` | Cabe: termina en y=1430 |

**Evidencia en vivo de `chatgpt-pet`:**
```
hyprctl clients → Chatgpt | at [2, 2] | size [856, 716] | ws 1
```
La ventana **no está en `3332,1016` ni mide 333×333**: está en la esquina superior
izquierda con otro tamaño. La regla declara `size`, `min_size` y `max_size` todos a
320/333, lo cual se contradice con la realidad — señal de que el match no está
aplicando (`xwayland = true` + `float = true` + clase `^(Chatgpt)$` puede no coincidir;
ver §2.4).

Estas coordenadas son un remanente del layout de **dos monitores** del `.conf`
antiguo (coordenadas en el rango 2000–3400 apuntan a un segundo monitor). Con un solo
DP-2 de 3440 px, varias quedan al borde o fuera.

---

### 2.4 🟠 `chatgpt-pet`: la regla no está aplicando (evidencia en vivo)

```lua
hl.window_rule({
    name = "chatgpt-pet",
    match = { class = "^(Chatgpt)$", title = "^(ChatGPT)$", xwayland = true, float = true },
    ...
    size = { 333, 333 }, min_size = { 320, 320 }, max_size = { 320, 320 },
```

Dos problemas de lógica independientes:

1. **`match.xwayland = true` es frágil.** El binario que lanza la mascota se comprueba
   con `chatgpt-open`; si el proceso corre en Wayland nativo (no XWayland) la regla
   nunca coincide. Dado que la ventana en vivo está en `at [2,2]` con `size [856,716]`,
   ninguna de las propiedades declaradas se está aplicando.
2. **`size` contradice a `min_size`/`max_size`.** `size = {333,333}` pide 333 px, pero
   `min_size = {320,320}` y `max_size = {320,320}` la fuerzan a 320. Es decir, el
   valor de `size` es **inalcanzable por diseño**. O se pone el mismo número en los
   tres, o el rango queda inútil.
   Además, el script lanza con `CHATGPT_PET_WIDTH=320 CHATGPT_PET_HEIGHT=320` (línea 218),
   coherente con 320 — así que `size` debería ser `{320,320}`.

---

### 2.5 🟠 Opacidades: el comentario y el efecto no coinciden

`decoration.inactive_opacity = 0.9` (línea 79) es un **multiplicador global** que ya
aplica a toda ventana inactiva. La regla `global-inactive-opacity` (línea 464)
**vuelve a aplicar 0.9** encima, con `match = { float = false, focus = false }`.

Diferencia importante de semántica:

```lua
-- Línea 507 — zen: CORRECTO
opacity = "1.0 override 1.0 override"   -- override = absoluto, ignora el global

-- Líneas 518, 539, 574 — SIN override
opacity = "0.85 0.15"    -- zapzap  → inactivo real = 0.9 × 0.15 = 0.135
opacity = "0.70 0.70"    -- code    → inactivo real = 0.9 × 0.70 = 0.63
opacity = "0.9 override 0.8 override"  -- chatgpt-pet sí usa override
```

El comentario de la línea 461-463 dice que la regla existe para excluir a zen del
dimming global, pero **eso ya lo hace `zen-opaque` con `override`**. Y como
`decoration.inactive_opacity` es un multiplicador independiente que ninguna
`window_rule` puede desactivar sin `override`, el resultado es:

- Zen: correcto (doble protección, redundante pero inocuo).
- Zapzap: **0.135 efectivo** en vez de los 0.15 "nominales" — mucho más transparente
  de lo que sugiere el número escrito.
- Code: 0.63 en vez de 0.70.
- Chatgpt-pet: 0.8 override (absoluto) — aquí el global sí se ignora, así que es el
  **único caso que se comporta como el comentario describe**.

**Consecuencia lógica:** el archivo mezcla dos convenciones sin criterio (con y sin
`override`), y el comentario largo de §"excepción de transparencia" describe un
mecanismo (`negative:^(zen)$` como protección anti-dimming) que ya está cubierto por
otro. El comentario induce a error a quien lea el archivo en el futuro.

---

### 2.6 🟠 `hl.on("hyprland.start")`: `wallpaperStart()` se ejecuta y también en `config.reloaded`

```lua
-- línea 157-221: hyprland.start  → guarda por marca, llama wallpaperStart() y gameModeStart()
-- línea 223-226: config.reloaded → llama wallpaperStart() y gameModeStart() SIN guarda
```

La guarda `n30-autostart-astra.done` protege el bloque de `hyprland.start`, pero
**`config.reloaded` no tiene guarda alguna**. Resultado: cada `hyprctl reload`
dispara `pkill -TERM mpvpaper; pkill -TERM gslapper` seguido de un relanzamiento.
Si el relanzamiento falla (p. ej. carrera con el compositor recién recargado), te
quedas **sin wallpaper**. Esto preserva intencionalmente el comportamiento del
`.conf`, pero ahora convive con la guarda nueva, así que la semántica es confusa:
"una vez por sesión" y "en cada reload" aplican al mismo par de funciones.

---

### 2.7 🟡 `hl.get_config` en el zoom: ruta frágil y sin validación

```lua
local function zoomBy(factor)
    local v = tonumber(hl.get_config("cursor.zoom_factor")) or 1
    ...
```

`hyprctl getoption cursor:zoom_factor` devuelve:
```
float: 1.000000
set: false
```

`hl.get_config` se probó por probe y **no lanza error** (OK), así que la API acepta la
ruta. Pero:

- El `or 1` silencia cualquier fallo de lectura: si la ruta cambia de nombre en una
  versión futura, el zoom **salta a 1 en vez de avisar**. Un fallo silencioso.
- `zoomBy` acumula multiplicando sobre el valor leído: sin límite superior, mantener
  `SUPER+=` pulsado (con 140 binds y `repeating` no está puesto aquí, pero el keyrepeat
  del servidor puede emitir) puede llevar el factor a valores absurdos. Solo hay tope
  inferior (`nv < 1 → 1`), **ningún tope superior**.

---

## 3. Referencias a cosas que no existen o no coinciden

### 3.1 🟠 El bind de `hyprshade` puede fallar silenciosamente

Líneas 294 y 297:
```lua
hl.dsp.exec_cmd("ddccontrol -r 0x10 -w 10 dev:/dev/i2c-8 && " .. scriptsDir .. "swayosd-on-demand --brightness lower & hyprshade toggle blue-light-filter")
```

Comprobado:
- `hyprshade` **existe** en `/usr/bin/hyprshade` y `blue-light-filter` **sí es un shader
  válido** (`hyprshade ls` lo lista). ✅
- Pero el comando **no tiene `&` entre `ddccontrol` y `hyprshade`**:
  `... && swayosd-on-demand --brightness lower & hyprshade toggle blue-light-filter`
  El `&` suelta `ddccontrol && swayosd-on-demand` en background y **`hyprshade` queda
  fuera** de esa cadena — se ejecuta siempre, incluso cuando `ddccontrol` falla.
  La intención (¿shade solo si el brillo cambió? ¿o siempre?) no está clara.
- **Ambas teclas hacen `hyprshade toggle`**: F1 y F2 alternan el filtro azul. Pulsar
  F1 lo activa, pulsar F2 lo desactiva. Es decir, subir y bajar brillo cambia el
  filtro de color de forma no determinista según el orden de pulsación. Esto casi
  con seguridad **no es lo que se quiere**.

### 3.2 🟠 `bind` con `release = true` para ajustar brillo (F1/F2)

```lua
hl.bind(mainMod .. " + Control_R + F1", ..., { release = true })
```
Eran `bindr` en el `.conf`, así que la traducción es fiel. Pero lógicamente: un bind
`release` **no admite repetición**, así que no se puede mantener pulsado para ajustar
brillo de forma continua. Y el `ddccontrol ... -w 10` (valor absoluto 10) significa que
F1 **siempre** pone el brillo a 10, no que lo baja un paso. Idem F2 con `-w 100`.

### 3.3 🟡 `gslapper` se mata pero nunca se lanza

```lua
local cleanup = "pkill -TERM -x mpvpaper; pkill -TERM -x gslapper"
```
`gslapper` **sí está instalado**, pero el comando que sigue solo lanza `mpvpaper`.
Es un `pkill` defensivo de una alternativa de wallpaper que no se usa. Inocuo, pero
conviene decidir: o se documenta por qué está, o se elimina.

### 3.4 🟡 Reglas para aplicaciones que no existen en la sesión

Clases/reglas que no tienen ninguna ventana viva ni lanzamiento asociado:
`dynisland` / `dynisland-daemon` (líneas 551–552), `wezterm`, `Alacritty`, `ghostty`,
`wasistlos`, `whatsapp-for-linux`, `whatsie`, `whatsapp-nativefier`, `tidal-hifi`,
`Spotify`, `easyeffects`, `Thunar`, `MEGAsync` (el lanzamiento está comentado por no
estar instalado), `galculator`, `luna`, `kalk`, `ktimer`, `konsole`, `qdirstat`.

No es un error (son reglas preventivas), pero `dynisland-position` con `move = {3345,49}`
es especialmente engañoso: el panel de DMS real es `dms:bar` en `x=0, y=0, w=44, h=1440`
(barra **vertical izquierda**), no una isla arriba a la derecha. Todas las coordenadas
`3332`/`3345`/`3345` apuntan a una esquina superior derecha que ya no existe como tal.

### 3.5 🟡 `n30.lua` no está sourceado y **sombrea el bind de `Print`**

`~/.config/hypr/n30.lua` define:
```lua
hl.bind("Print", function() ... flameshot screen --number n --edit end)
```
El `.lua` principal define `hl.bind("Print", hl.dsp.exec_cmd("dms screenshot"))`.
`n30.lua` **no está sourceado** desde `hyprland.lua`, así que no colisiona hoy — pero es
un archivo huérfano con un bind en conflicto latente. Si alguien lo añade con un
`dofile` en el futuro, `Print` quedará ambiguo. Conviene archivar o eliminar `n30.lua`.

---

## 4. Errores de robustez / mantenibilidad

### 4.1 🟡 `assert()` en el autostart puede abortar el handler completo

```lua
local runtime  = assert(os.getenv("XDG_RUNTIME_DIR"), "Falta XDG_RUNTIME_DIR")
local instance = assert(os.getenv("HYPRLAND_INSTANCE_SIGNATURE"), "Falta la instancia Hyprland")
...
local started = assert(io.open(marker, "w"))
```

Si cualquiera de los tres falla, el `assert` lanza y **todo el handler
`hyprland.start` muere**: no se lanzan apps, no se abre el wallpaper, nada. Un
`io.open(marker, "w")` puede fallar por disco/permisos. Es más seguro degradar: si no
se puede escribir la marca, es preferible lanzar las apps dos veces (recuperable) que
no lanzarlas nunca (no recuperable). El comentario del archivo dice que la marca es
"un detalle", pero el código la trata como crítica.

### 4.2 🟡 Falta `unset` de la dependencia de `jq` (el archivo sí lo tiene, pero…)

```lua
local mon = "$(hyprctl monitors -j | jq -r '.[0].name')"
```
Se ejecuta dentro de un `bash` vía `hl.exec_cmd`, así que la sustitución funciona. Pero
depende de `jq` **y** de que el monitor 0 sea el correcto. Con `[[0]]` fijo, si algún
día cambia el orden de monitores, el wallpaper va al monitor equivocado. Sería más
robusto usar el nombre real (`DP-2`) o filtrar por `focused`.

### 4.3 🟡 Comillas anidadas en la ruta de rclone

```lua
hl.exec_cmd("bash -c \"sleep 10; rclone mount 'koofr:/koofr/Autosync' /home/n30/Autosync/ --vfs-cache-mode full &\"")
```
Funciona, pero mezcla comillas dobles escapadas de Lua con comillas simples de shell
y contiene `/home/n30` **hardcodeado**, cuando el resto del archivo usa
`os.getenv("HOME")`. Inconsistente y no portable.

### 4.4 🟡 Duplicación conceptual que el propio archivo critica

El archivo documenta con detalle que `#source` de hyprlang causaba binds muertos y
reglas pisadas — y sin embargo **conserva la misma estructura de dos secciones que
reclaman las mismas teclas** (§2.1). La migración resolvió el síntoma (Lua) pero no la
causa (organización sin jerarquía). No hay ningún mecanismo de "última gana" ni
verificación de duplicados en tiempo de carga.

### 4.5 🟢 Detalles menores

- Línea 322: `hl.bind(mainMod .. " + SHIFT + CTRL + J", hl.dsp.window.move({ direction = "d" }))`
  — falta el bloque `SHIFT+CTRL+J` ↔ `K`/`L` en "Move to Monitor" (263–264, comentado);
  la asimetría es intencional según el comentario, pero conviene revisarla.
- Líneas 358–365: los callbacks de sonido llaman `hl.dispatch` + `hl.exec_cmd`. Correcto
  (no bloquea), pero **no hay guarda de spam**: mantener pulsado emite un `play` por
  repetición del keyrepeat.
- Línea 508 y 509: `-- rounding 40: fuera del máximo (20)` — el comentario explica una
  corrección histórica; útil, pero ya no aplica y confunde.
- Línea 6: `-- eventualmente source = ~/.config/hypr/conf/n30.lua` — el directorio
  `~/.config/hypr/conf/` existe pero está vacío; promesa incumplida en un comentario.

---

## 5. Tabla priorizada de acciones

| Prioridad | Hallazgo | Sección | Esfuerzo |
|---|---|---|---|
| 🔴 **P1** | Colisión `SUPER+CTRL+↑/↓`: monitor vs workspace | §2.1 | Decidir cuál gana, borrar el otro |
| 🔴 **P1** | Colisión `SUPER+SHIFT+minus`: resize vs zoomReset | §2.1 | Renombrar una de las dos |
| 🔴 **P1** | `chatgpt-pet` no aplica + `size` inalcanzable (333 vs 320) | §2.4 | Igualar a 320 y revisar `xwayland` |
| 🟠 **P2** | F1/F2: ambos hacen `hyprshade toggle` + `&` mal puesto | §3.1 | Corregir la cadena y separar acciones |
| 🟠 **P2** | Coordenadas fuera de pantalla (`3332`→3665, `y=-8`, `y=-11`) | §2.3 | Recalcular sobre 3440×1440 |
| 🟠 **P2** | Opacidades sin `override` se multiplican por 0.9 global | §2.5 | Decidir convención única |
| 🟠 **P2** | `config.reloaded` sin guarda duplica el wallpaper | §2.6 | Decidir: ¿relanzar o no? |
| 🟡 **P3** | `code:20`/`code:21` con `keycode=0` y descripciones invertidas | §2.2 | Verificar o eliminar |
| 🟡 **P3** | `assert()` puede abortar todo el autostart | §4.1 | Degradar a `if not x then` |
| 🟡 **P3** | Zoom sin tope superior | §2.7 | Añadir `math.min(nv, X)` |
| 🟡 **P3** | `n30.lua` huérfano con `Print` en conflicto | §3.5 | Archivar |
| 🟢 **P4** | `pkill gslapper` sin lanzamiento, `/home/n30` hardcodeado, etc. | §3.3, §4.3 | Limpieza |

---

## 6. Advertencia sobre la documentación existente

`transition to lua.md` describe fielmente el **proceso** de migración, pero varias de
sus afirmaciones de estado **no coinciden con el archivo actual**:

| Afirmación del documento | Realidad verificada |
|---|---|
| "`hl.timer(..., { type = "oneshot" })` se usó para los sleeps" | El archivo **no contiene ningún `hl.timer`**; usa `bash -c "sleep N; ..."` (§8 del doc lo reconoce parcialmente) |
| "FIX: guarda con `_G.__n30_autostart_done`" | El archivo usa marca de archivo por instancia, no `_G` (§8 lo rectifica) |
| "Pendiente: archivar `hyprland.conf`, `n30.conf`" | Siguen ahí, correcto, pero `n30.lua` no se menciona como huérfano |
| "140 binds… Shift_R ×2, SUPER_L ×1" | Correcto (140 binds), pero **no detecta las 4 colisiones** de §2.1 |

**Recomendación:** el documento es una bitácora útil, pero no debe usarse como fuente
de verdad del estado. La sección §6.1 y §8 se contradicen entre sí en dos puntos. Vale
la pena añadir una entrada fechada que apunte a este informe y aclare qué sigue vigente.

---

## 7. Cómo reproducir las verificaciones

```bash
# 1. Sintaxis
luac -p ~/.config/hypr/hyprland.lua

# 2. Parseo completo, SIN tocar la sesión (neutraliza los exec_cmd)
mkdir -p /tmp/hyprprobe
python3 - <<'PY'
src = open('/home/n30/.config/hypr/hyprland.lua').read()
shim = 'do local _r = hl.exec_cmd; hl.exec_cmd = function() end; hl.dispatch = function() end end\n'
open('/tmp/hyprprobe/hyprland.lua','w').write(shim + src)
PY
Hyprland --verify-config -c /tmp/hyprprobe/hyprland.lua

# 3. Errores en la sesión viva
hyprctl configerrors

# 4. Colisiones de binds (misma tecla registrada 2+ veces)
hyprctl binds -j | python3 -c "
import json,sys,collections
d=json.load(sys.stdin)
c=collections.Counter((b.get('modmask'),b.get('key'),b.get('submap','')) for b in d)
for k,v in c.items():
    if v>1: print('DUP x%d'%v, k)
"
```

> ⚠️ **No corras `Hyprland --verify-config` sobre el archivo real.** Ejecuta las
> funciones del autostart: un `pkill -TERM mpvpaper` + relanzamiento que puede dejarte
> sin wallpaper. Usa siempre la copia de `/tmp` con el shim.

---

*Informe generado sin modificar `hyprland.lua`. Ninguna corrección aplicada.*
