# Análisis — Ajustes de brillo en `hyprland.lua`

**Fecha:** 18 de septiembre de 2026
**Archivo:** `/home/n30/.config/hypr/hyprland.lua` (líneas 213, 288-298)
**Hyprland:** 0.56.2 · **Monitor:** DP-2 3440×1440 (LG, EDID `GSM9E9A`)
**Alcance:** análisis y recomendaciones. **No se modificó el archivo.**

---

## 1. Veredicto rápido

| Mecanismo | Dónde | ¿Sirve? |
|---|---|---|
| `dms ipc call brightness increment/decrement` | `XF86MonBrightnessUp/Down` (289-290) | ✅ **SÍ — probado en vivo** |
| `ddccontrol -r 0x10 -w 10/100` | `SUPER+Ctrl_R+F1/F2` (293-298) | ⚠️ **Sí, pero hace otra cosa de la que parece** |
| `swayosd-on-demand --brightness lower/raise` | dentro de F1/F2 | ❌ **NO — imposible en este equipo** |
| `hyprshade toggle blue-light-filter` | dentro de F1/F2 | ⚠️ **Funciona, pero mal planteado** |
| `ddccontrol -r 0x10 -w 100` (autostart) | línea 213 | ⚠️ **Carrera con el monitor; no se aplicó** |

**Resumen:** el brillo **sí se controla**, y bien, por la vía de DMS. Lo que está roto es
todo lo que rodea a las teclas F1/F2: un OSD que no puede existir en este hardware, dos
valores absolutos disfrazados de "subir/bajar", un `&` que rompe la cadena de comandos,
y un filtro de luz azul que ambas teclas alternan sin criterio.

---

## 2. Evidencia (todo reproducible)

### 2.1 El brillo por DMS funciona — probado

```
-- antes:              Device: ddc:i2c-8 - Brightness: 62%
-- increment 5:        Brightness increased by 5%          (exit 0)
-- tras increment:     Device: ddc:i2c-8 - Brightness: 67%
-- decrement 5:        Brightness decreased by 5%          (exit 0)
-- tras restaurar:     Device: ddc:i2c-8 - Brightness: 62%
```

Verificación cruzada por una vía independiente:

```
$ ddccontrol -r 0x10 dev:/dev/i2c-8
Control 0x10: +/62/100 C [Brightness]
```

También verificadas las tres variantes que se recomiendan más abajo:

| Comando | Resultado |
|---|---|
| `dms ipc call brightness set 62 ""` | `Brightness set to 62% on ddc:i2c-8` |
| `dms ipc call brightness increment 10 ""` | `Brightness increased by 10%` → 72% |
| `dms ipc call brightness decrement 10 ""` | `Brightness decreased by 10%` → 62% |

DMS descubre el monitor solo: `Available devices: ddc:i2c-8 (ddc)`.
**El brillo se controla por DDC/CI sobre `/dev/i2c-8`.** Ese es el único camino real.

### 2.2 El OSD de swayosd no puede funcionar — probado

```
$ brightnessctl -l -c backlight
Failed to read any devices of class 'backlight'.        (exit 1)

$ ls /sys/class/backlight/
(vacío)

$ swayosd-client --brightness lower
Could not connect to SwayOSD Server with error: org.freedesktop.DBus.Error.ServiceUnknown
                                                        (exit 1)
```

Y ejecutando el script tal cual lo llaman los binds:

```
$ ~/dotfiles/share/scripts/swayosd-on-demand --brightness lower
   (exit 0, sin salida: el script silencia stderr con 2>/dev/null)
$ dms ipc call brightness status
Device: ddc:i2c-8 - Brightness: 62%      ← el brillo NO cambió
$ pgrep swayosd-server
143880                                   ← pero arrancó un daemon huérfano
```

**Conclusión:** `swayosd-client --brightness` depende de `brightnessctl` con clase
`backlight`. En este equipo **no existe ningún dispositivo de esa clase**: es un
escritorio con monitor externo, sin panel interno.

```
$ ls /sys/class/drm/ | grep -i edp
(ningún conector eDP)
Conectores: DP-1 disconnected · DP-2 connected · DP-3 disconnected · HDMI-A-1 disconnected
```

`swayosd` está pensado para paneles internos. Aquí **nunca** va a funcionar, por mucho
que se configure. El único efecto observable del script es arrancar un `swayosd-server`
que no sirve para nada.

### 2.3 El `&` rompe la cadena de comandos — demostrado

El comando de F1 es:

```lua
"ddccontrol -r 0x10 -w 10 dev:/dev/i2c-8 && " .. scriptsDir .. "swayosd-on-demand --brightness lower & hyprshade toggle blue-light-filter"
```

En shell, `&` tiene menor precedencia que `&&`. Eso se parsea como:

```
( ddccontrol && swayosd-on-demand --brightness lower )   &   hyprshade toggle blue-light-filter
└──────────────── en segundo plano ────────────────┘        └── en primer plano, YA ──┘
```

Demostración (con `false` en el papel de ddccontrol):

```
$ bash -c 'false && echo "[B] no debería salir" & echo "[C] hyprshade SÍ sale"; wait'
[C] hyprshade SÍ sale
```

Es decir: **`hyprshade` se ejecuta siempre**, aunque ddccontrol falle, y sin esperar a
que termine. No hay ninguna relación entre que el brillo cambie y que el filtro se
alterne.

### 2.4 `ddccontrol` no tiene perfil de este monitor

```
$ ddccontrol -r 0x10 dev:/dev/i2c-8
I/O warning : failed to load "/usr/share/ddccontrol-db/monitor/GSM9E9A.xml": No such file or directory
...
Identificación Plug and Play: [GSM9E9A]
=============================== AVISO ================================
No hay soporte para tu monitor en el base de datos, pero ddccontrol está
utilizando un perfíl genérico que corresponde al fabricante de tu monitor.
Algunos controles no serán soportados, o no funcionarán de la forma esperado.
======================================================================
Control 0x10: +/62/100 C [Brightness]
```

El control 0x10 **sí funciona** (leyó 62 correctamente), pero el perfil genérico implica
que otros controles pueden no comportarse como se espera. `ddcutil` está instalado y
maneja esto mejor; es una alternativa más robusta si se quiere seguir usando DDC directo.

### 2.5 El flag relativo `-W` existe (y no está documentado)

El manual no lo lista, pero el binario sí:

```
-W : relatively change ctrl value (+/-)
```

Probado: `ddccontrol -r 0x10 -W +3 dev:/dev/i2c-8` llevó el brillo de **62 a 65**.
Es decir, **sí se puede hacer relativo con ddccontrol** — pero el config no lo usa.

---

## 3. Los problemas, en orden de gravedad

### 🔴 P1 — El OSD es imposible en este hardware

`swayosd-on-demand --brightness lower/raise` no puede mostrar nada útil ni cambiar el
brillo. Es código muerto que solo arranca un daemon inútil. Ver §2.2.

### 🔴 P1 — F1/F2 usan valores absolutos disfrazados de pasos

```lua
ddccontrol -r 0x10 -w 10  ...  swayosd-on-demand --brightness lower   -- "bajar"
ddccontrol -r 0x10 -w 100 ...  swayosd-on-demand --brightness raise   -- "subir"
```

`-w` es **valor absoluto**. F1 no "baja el brillo": lo **pone al 10%**. F2 no lo "sube":
lo **pone al 100%**. El texto `lower`/`raise` del OSD describe una acción que no ocurre.
Para pasos reales hay que usar `-W` (relativo), que sí funciona (§2.5).

### 🟠 P2 — Ambas teclas alternan el filtro de luz azul

F1 **y** F2 ejecutan `hyprshade toggle blue-light-filter`. Es un interruptor, no un
estado:

| Secuencia | Resultado del filtro |
|---|---|
| F1 | encendido |
| F1 otra vez | **apagado** |
| F1, F2 | encendido |
| F2, F2 | apagado |

El estado del filtro depende del **historial de pulsaciones**, no de lo que quieras.
Además, como el `&` lo desacopla (§2.3), el filtro cambia incluso si el brillo no se
pudo ajustar. Con `hyprshade on` / `hyprshade off` sería determinista.

### 🟠 P2 — `release = true` impide repetir

```lua
hl.bind(mainMod .. " + Control_R + F1", ..., { release = true })
```

Un bind de tipo *release* no admite repetición. No se puede mantener F1/F2 pulsado para
barrer el brillo. Es incoherente con las teclas de brillo del teclado (289-290), que sí
llevan `{ repeating = true, locked = true }`.

### 🟠 P2 — Dos mecanismos compitiendo por el mismo bus

DMS y `ddccontrol` escriben **el mismo control VCP 0x10 en el mismo `/dev/i2c-8`**. DMS
mantiene su propio valor en memoria; `ddccontrol` escribe a ciegas. Si se mezclan los
dos (F1/F2 con ddccontrol, teclas de brillo con DMS), DMS puede quedar desincronizado y
su siguiente `increment` partir de un valor equivocado.

### 🟡 P3 — El autostart pone 100% y no se aplicó

```lua
-- línea 213
hl.exec_cmd("ddccontrol -r 0x10 -w 100 dev:/dev/i2c-8")
```

La sesión arrancó con la marca de autostart puesta, pero el brillo está en **62%**, no en
100%. Lo más probable: **carrera con el monitor**, que aún no responde a DDC/CI cuando el
comando se lanza. Es un clásico de DDC. Si quieres brillo fijo al iniciar, hay que
reintentar o esperar a que el monitor esté listo.

### 🟡 P3 — `brightnessctl` no sirve para nada aquí

Solo ve LEDs de teclado y de red (`input3::numlock`, `igc-0800-led*`). No hay backlight.
Cualquier herramienta que dependa de `brightnessctl -c backlight` (swayosd incluido) es
inútil en este equipo.

---

## 4. Recomendaciones

### Opción A — Todo por DMS (recomendada)

Una sola vía, la que funciona y ya trae OSD propio (`osdAlwaysShowValue = true`).
Sustituye el bloque de las líneas 288-298 por:

```lua
-- === Brightness ===
-- Todo por DMS: descubre el monitor por DDC/CI (ddc:i2c-8) y trae su propio OSD.
-- No usar ddccontrol en paralelo: escribirían el mismo VCP 0x10 a la vez.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("dms ipc call brightness increment 5 \"\""),
    { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 5 \"\""),
    { repeating = true, locked = true })

-- Pasos grandes
hl.bind("SHIFT + XF86MonBrightnessUp",   hl.dsp.exec_cmd("dms ipc call brightness increment 10 \"\""),
    { repeating = true, locked = true })
hl.bind("SHIFT + XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 10 \"\""),
    { repeating = true, locked = true })

-- Extremos (mismos valores absolutos de antes, pero por la vía que funciona)
hl.bind(mainMod .. " + Control_R + F1", hl.dsp.exec_cmd("dms ipc call brightness set 10 \"\""),
    { repeating = true })
hl.bind(mainMod .. " + Control_R + F2", hl.dsp.exec_cmd("dms ipc call brightness set 100 \"\""),
    { repeating = true })

-- Filtro de luz azul: teclas propias y deterministas (no toggle)
hl.bind(mainMod .. " + Control_R + F3", hl.dsp.exec_cmd("hyprshade on blue-light-filter"))
hl.bind(mainMod .. " + Control_R + F4", hl.dsp.exec_cmd("hyprshade off"))
```

Ventajas: un solo mecanismo, OSD real, sin daemons huérfanos, filtro determinista,
y las teclas F1/F2 conservan exactamente el comportamiento absoluto que ya tenían.

### Opción B — Mantener ddccontrol, pero arreglado

Si prefieres no depender de DMS:

```lua
-- -W es RELATIVO (verificado: 62 -> 65 con +3). Quitar el OSD (no puede funcionar).
hl.bind(mainMod .. " + Control_R + F1",
    hl.dsp.exec_cmd("ddccontrol -r 0x10 -W -5 dev:/dev/i2c-8"),
    { repeating = true })
hl.bind(mainMod .. " + Control_R + F2",
    hl.dsp.exec_cmd("ddccontrol -r 0x10 -W +5 dev:/dev/i2c-8"),
    { repeating = true })
```

Cambios: `-w` → `-W` (relativo), se elimina `swayosd-on-demand` (no puede funcionar),
se elimina el `&` (ya no hay cadena que romper), y `release = true` → `repeating = true`.

### Sugerencias adicionales

1. **Activa el escalado exponencial.** DMS expone `enableExponential`. Con DDC/CI los
   pasos lineales se sienten mal en brillos bajos (un 5% abajo del 10% es un salto
   enorme en percepción). Pruébalo:
   ```bash
   dms ipc call brightness enableExponential
   ```
2. **Quita el `-w 100` del autostart** (línea 213) o hazlo tolerante a fallos. Como
   mínimo, no fuerces 100% en cada login; si quieres un valor fijo, usa
   `dms ipc call brightness set N ""` con un pequeño retardo para que el monitor esté
   listo.
3. **Actualiza `ddccontrol-db`** si vas a seguir usando ddccontrol. El perfil de tu
   `GSM9E9A` no existe y estás sobre un perfil genérico. Alternativa: usar `ddcutil`,
   que ya está instalado y maneja mejor los perfiles.
4. **No mezcles las dos vías.** Elige DMS **o** ddccontrol, no ambas: escriben el mismo
   control en el mismo bus y DMS cachea su propio valor.
5. **Si algún día conectas un panel interno**, `brightnessctl`/`swayosd` empezarían a
   funcionar. Hoy no hay conector eDP, así que no cuentes con ello.

---

## 5. Qué está bien y no hay que tocar

- Las teclas `XF86MonBrightnessUp/Down` con `dms ipc call brightness increment/decrement 5`
  están **correctas y funcionan**. El `{ repeating = true, locked = true }` es adecuado:
  `locked` permite ajustar brillo con la pantalla bloqueada.
- El uso de `""` como tercer argumento (dispositivo) es válido: DMS resuelve el único
  dispositivo DDC disponible. Verificado con `set`, `increment` y `decrement`.
- `/dev/i2c-8` es accesible por tu usuario (grupo `video`), así que no hay problema de
  permisos en ninguna de las dos vías.

---

## 7. ¿Es `ddccontrol` más seguro? — No

Comparativa con evidencia medida en esta sesión:

| | `ddccontrol` | `ddcutil` | DMS |
|---|---|---|---|
| Versión / estado | **1.0.3** (era 2005, sin mantenimiento real) | Actual y mantenido | Actual |
| Cómo accede al bus | **Daemon root siempre activo** (`ddccontrol.service` → `/usr/libexec/ddccontrol/ddccontrol_service`, PID 1541, corre como root desde el arranque) | Directo como usuario (`/dev/i2c-8`, grupo `video`) | Implementación propia en Go (`brightness/ddc_filter.go`), como usuario |
| Perfil del monitor | **No tiene perfil de tu `GSM9E9A`** → usa uno genérico de LG y avisa de que "algunos controles no funcionarán de la forma esperada" | Lee las **capacidades reales** del monitor (VCP 2.1, lista completa) | Funciona (verificado) |
| Procesos | Uno por invocación | Uno por invocación | Ninguno extra (daemon propio) |
| Verificado aquí | Lee 0x10 = 62 ✓ | Lee todo ✓ | 62 → 67 → 72 → 62 ✓ |

**Conclusión: no, `ddccontrol` es la opción menos segura de las tres.**

- **Privilegios:** enruta cada escritura DDC por un **daemon root permanente**. DMS y
  `ddcutil` escriben como tu usuario a través del grupo `video`. Menos privilegio = menos
  superficie de ataque.
- **Corrección:** al no tener perfil de tu monitor, `ddccontrol` trabaja a ciegas sobre un
  perfil genérico. Para el brillo (0x10) da igual, pero para cualquier otro control puede
  escribir valores equivocados. `ddcutil` consulta las capacidades reales antes de tocar
  nada, y por eso leyó correctamente los 25 VCP de tu LG.
- **Antigüedad:** 1.0.3 es de la época de VESA DDC/CI temprano. `ddcutil` es el estándar
  de facto actual.

**Sobre riesgo de hardware:** para el brillo (VCP 0x10) **no hay diferencia real** entre
las tres vías — es el control más estándar y benigno de DDC/CI. El riesgo aparece al tocar
controles menos comunes, y ahí `ddcutil` es más seguro porque conoce el monitor.

⚠️ Un detalle a evitar: `ddccontrol` tiene un flag `-f` (*force, bypass validity checks*)
que salta las comprobaciones de rango. **El config no lo usa** — bien hecho, porque
escribir un valor fuera de rango en un VCP puede dejar el monitor en un estado raro.

**Recomendación:** si quieres una vía DDC por línea de comandos, usa **`ddcutil`**, no
`ddccontrol`. Y si te vale la que ya funciona, quédate con **DMS**.

---

## 8. Filtro nocturno: por qué `gammastep` no sirve aquí, y qué usar

### 8.1 El diagnóstico

`gammastep` (instalado) **no funciona**:

```
$ gammastep -O 4000
Warning: Zero outputs support gamma adjustment.
Warning: 1/1 output(s) do not support gamma adjustment.
```

**No es culpa del `bitdepth = 10`.** Lo comprobé aislando la variable con `hyprctl eval`:
en 8 bits falla exactamente igual. El protocolo `zwlr_gamma_control_manager_v1` **sí se
anuncia** (`wayland-info` lo lista), pero el output DP-2 no obtiene tabla de gamma: en
`GammaControl.cpp` de v0.56.2 la puerta es `getGammaSize() <= 0`, y aquí no pasa.

Consecuencia: **`gammastep`, `wlsunset` y `redshift` quedan descartados** — todos dependen
del LUT de gamma. No pierdas tiempo con ellos.

### 8.2 Las tres alternativas que sí sirven

#### Opción 1 — `hyprsunset` (la más recomendable)

```
extra/hyprsunset 0.4.0-3
    An application to enable a blue-light filter on Hyprland
```

Está **en los repos oficiales** y **Hyprland 0.56.2 ya lo integra**: `hyprctl --help` lista
`hyprsunset ... → Issue a hyprsunset request`. Usa la **matriz de transformación de color
(CTM)**, que es un camino distinto al LUT de gamma — precisamente el que aquí no funciona.
Hyprland 0.56.2 incluye `CTMControl.cpp` y anuncia `wp_color_manager_v1` v3, así que la
infraestructura está puesta.

Ventajas: es la solución nativa del ecosistema, ajusta por temperatura (K) de forma
continua, y soporta horario automático. **Es lo que yo instalaría.**

#### Opción 2 — Ganancia de azul por DDC (nivel hardware) — **probado**

Tu LG ULTRAGEAR+ expone controles de color por DDC/CI. Medido:

```
0x12 (Contrast)          = 100 / 100
0x14 (Select color preset)= User 1   [disponibles: 6500 K, 9300 K, User 1]
0x16 (Video gain: Red)   = 50 / 100
0x18 (Video gain: Green) = 50 / 100
0x1A (Video gain: Blue)  = 50 / 100
```

**Bajar el azul calienta la pantalla en el propio monitor.** Probado en vivo:

```
$ ddcutil getvcp 1a   → current value = 50
$ ddcutil setvcp 1a 35 → (exit 0)
$ ddcutil getvcp 1a   → current value = 35      ← funcionó
$ ddcutil setvcp 1a 50 → restaurado
```

Ventajas: **coste cero de GPU**, funciona con juegos y vídeo a pantalla completa, y no
interfiere con HDR ni con el color de 10 bits (es procesado del propio monitor).

Inconvenientes: granularidad gruesa, **afecta a todas las entradas del monitor** (si
conectas otro equipo, seguirá cálido), y requiere que el monitor esté despierto para
aceptar la escritura DDC.

Valores orientativos: azul `35` = cálido suave · `25` = noche · `15` = muy cálido.
Ojo: bajar solo el azul también baja el brillo percibido; compensa con `0x10` si hace falta.

#### Opción 3 — `hyprshade` con shader afinado (lo que ya tienes)

Verificado que funciona en esta sesión:

```
$ hyprshade on blue-light-filter-50
$ hyprctl getoption decoration:screen_shader
  str: /home/n30/.config/hypr/shaders/blue-light-filter-50.glsl   ← aplicado
$ hyprshade off   → vuelve a [[EMPTY]]
```

Ya tienes tres presets (`blue-light-filter-25/50/75`). El shader de origen es un *mustache*
parametrizable con **temperatura** (1000–40000 K, por defecto 2600 K) y **strength**
(0.0–1.0), así que puedes generar el punto exacto que te resulte cómodo.

Inconvenientes: **coste de GPU** (es un shader de post-proceso sobre toda la salida) y, en
algunos setups, puede interferir con capturas o con HDR. Para un escritorio de 3440×1440 a
144 Hz el coste es bajo, pero no es cero.

Mejora recomendable si te quedas aquí: **automatízalo por horario** con
`hyprshade auto` (y `hyprshade install` para las unidades systemd de usuario), en vez de
depender de pulsar una tecla.

### 8.3 Resumen de la recomendación

| Prioridad | Qué | Por qué |
|---|---|---|
| 1 | **`hyprsunset`** | Nativo de Hyprland, vía CTM (esquiva el fallo de gamma), continuo y programable |
| 2 | **Ganancia azul DDC** (`ddcutil setvcp 1a N`) | Coste GPU cero, funciona en pantalla completa; probado |
| 3 | **`hyprshade` afinado + `auto`** | Ya funciona hoy; añade coste de GPU |
| ❌ | `gammastep` / `wlsunset` / `redshift` | Bloqueados: el output no soporta LUT de gamma |

---

## 6. Nota de limpieza

Durante las pruebas arranqué un `swayosd-server` (PID 143880) al ejecutar el script real.
Lo detuve al terminar (`pkill -x swayosd-server`); el estado final es **ninguno corriendo**.

Estado restaurado tras todas las pruebas: **brillo 62 %**, **ganancia de azul 50**,
**`decoration:screen_shader` vacío**, monitor de vuelta en **10 bits**.

---

*Análisis sin modificar `hyprland.lua`. Ninguna corrección aplicada.*

---

# 9. Incidente de shaders (2026-09-18) — RESUELTO

## 9.1 El error

Durante las pruebas del apartado 8 ejecuté `hyprshade on blue-light-filter-50`. Apareció:

```
screen shader parser error
error linking program: all shaders must use same shading language version
```

**Causa mía**: probé el filtro en vivo sin haber validado antes los shaders.

## 9.2 Causa raíz

Hyprland 0.56.2 compila su vertex shader interno como **GLSL ES 3.00** (`#version 300 es`).
Los cuatro shaders de usuario de `~/.config/hypr/shaders/` estaban escritos en
**GLSL ES 1.00** (sin directiva `#version`, usando `varying` / `texture2D` / `gl_FragColor`).

Un programa GLSL no puede enlazar un vertex shader ES 3.00 con un fragment shader ES 1.00.
De ahí el "all shaders must use same shading language version".

## 9.3 Corrección aplicada

Los cuatro shaders se migraron a ES 3.00. Tabla de equivalencias usada:

| GLSL ES 1.00 (roto) | GLSL ES 3.00 (corregido) |
|---|---|
| *(sin `#version`)* | `#version 300 es` (primera línea, obligatorio) |
| `varying vec2 v_texcoord;` | `in vec2 v_texcoord;` |
| `texture2D(tex, uv)` | `texture(tex, uv)` |
| `gl_FragColor = ...` | `out vec4 fragColor;` + `fragColor = ...` |

Archivos corregidos (respaldo de cada uno en `*.bak-glsl100-20260918`):

- `blue-light-filter-25.glsl`
- `blue-light-filter-50.glsl`
- `blue-light-filter-75.glsl`
- `invert-colors.glsl`

Los tres presets de filtro azul comparten el mismo cuerpo; solo difieren en
`temperatureStrength` (0.25 / 0.50 / 0.75) y en el valor de `temperature` (3000 K).

## 9.4 Verificación

1. `glslangValidator -S frag` → los cuatro: **OK**.
2. Prueba en vivo `hyprshade on blue-light-filter-50` → `rc=0`, sin salida de error,
   `decoration:screen_shader` apuntando al archivo.
3. Prueba en vivo `hyprshade on invert-colors` → `rc=0` (estructura distinta, también OK).
4. `hyprshade off` → `decoration:screen_shader` de vuelta a `[[EMPTY]]`.
5. `grep -c "same shading language"` sobre `hyprland.log` (2,1 MB) → **0**.

## 9.5 Segundo fallo descubierto (NO resuelto)

Los binds F1/F2 **nunca han funcionado** en su parte de filtro azul. Usan:

```lua
hyprshade toggle blue-light-filter    -- sin sufijo numérico
```

Ese nombre sin sufijo resuelve a la plantilla del sistema
`/usr/share/hyprshade/shaders/blue-light-filter.glsl.mustache`, que requiere
renderizado Mustache con el módulo Python `chevron`. El resultado real es:

```
Error: No module named 'chevron'
```

**Por qué falla**, aunque `python-chevron` figura como instalado:

```
python-chevron   →  /usr/lib/python3.13/site-packages/chevron/   ← instalado aquí
/usr/bin/python  →  /usr/bin/python3.14                          ← hyprshade usa esto
/usr/bin/python3.13  →  no existe (fue eliminado en el upgrade)
```

Es un salto de Python 3.13 → 3.14 en Arch. Los paquetes AUR de Python no se
reconstruyeron y quedaron huérfanos en el directorio de la versión antigua.

### Alcance: no es solo `chevron`

Paquetes registrados en pacman cuyos archivos solo existen bajo `python3.13`:

| Paquete | Contenido | Nota |
|---|---|---|
| `python-chevron` | 0.14.0-1 | rompe `hyprshade` con plantillas |
| `python-caffeine` | 4.2.0.r53.g1957335-2 | |
| `python-gpt4all` | 2.2.1-1 | |
| `python-newspaper` | 0.2.8-4 | |
| `python-pyqtws` | 0.2.9-1 | |
| `python-backports-zstd` | 1.2.0-3 | **único con extensión compilada** (`.cpython-313-*.so`) |

Los cinco primeros son Python puro y bastaría con reconstruirlos.
`backports-zstd` sí necesita recompilar su `.so`.

### Dos vías de arreglo

**Vía A — reconstruir los paquetes (arregla el sistema):**

```bash
paru -S --rebuild python-chevron python-caffeine python-gpt4all \
                 python-newspaper python-pyqtws python-backports-zstd
```

Restaura la plantilla `blue-light-filter` y también `color-filter`, `grayscale`
y `vibrance`, que sufren el mismo problema.

**Vía B — no depender de plantillas (arregla el bind):**
apuntar F1/F2 a los presets propios `blue-light-filter-25/50/75`, que son
archivos `.glsl` planos y **no necesitan `chevron`**. Ver §9.6.

## 9.6 Defecto de lógica en los binds F1/F2

```lua
-- actual
F1 → ddccontrol -w 10  ... & hyprshade toggle blue-light-filter
F2 → ddccontrol -w 100 ... & hyprshade toggle blue-light-filter
```

Tres problemas:

1. **Ambos teclas llaman al MISMO toggle.** F1 y F2 no son "bajar" y "subir" del
   filtro: son dos interruptores del mismo estado. Pulsar F1 dos veces apaga el
   filtro dejando el brillo en 10.
2. **`toggle` no es determinista.** El estado depende de cuántas veces se pulsó antes,
   no de qué tecla se pulsó.
3. **`&` rompe la cadena `&&`.** `a && b & c` se evalúa como `(a && b) & c`: `c` arranca
   en paralelo, sin esperar a que `ddccontrol` termine, y el `&&` deja de garantizar nada.

Lo correcto sería `on` / `off` explícitos, con el brillo y el filtro atados al mismo perfil.

## 9.7 Estado del sistema tras el incidente

- `decoration:screen_shader` → **`[[EMPTY]]`** (sin tinte)
- Los 4 shaders de usuario → **funcionales** (ES 3.00)
- `hyprland.lua` → **sin cambios** por este incidente
- Binds F1/F2 → **siguen rotos**, pendiente de decisión

---

# 10. Brillo al máximo en cada arranque (2026-09-22) — IMPLEMENTADO

## 10.1 Lo que se pidió

Que el brillo del monitor externo quede al máximo en cada inicio del PC, implementado en
`hyprland.lua`, con cuidado especial de que no pueda dañar el monitor.

## 10.2 Lo que ya había — y por qué no servía

La línea 225 del autostart ya intentaba exactamente eso:

```lua
hl.exec_cmd("ddccontrol -r 0x10 -w 100 dev:/dev/i2c-8")
```

**Nunca funcionó.** Comprobado el 2026-09-22:

```
$ ddccontrol -r 0x10 -w 100 dev:/dev/i2c-8
Leendo EDID e incializando DDC/CI en el bus dev:/dev/i2c-8...
Open monitor failed: GDBus.Error:ddccontrol.DDCControl.Error.OpenFailed: Failed to open monitor
DDC/CI en dev:/dev/i2c-8 es inutilizable (-1).
$ echo $?
0
```

Dos problemas, y el segundo es el grave:

1. La 1.0.3 instalada no consigue abrir el monitor a través de su daemon D-Bus.
2. **Devuelve código de salida 0 pese a fallar.** Un fallo silencioso: nadie se enteró en
   meses porque el comando "tenía éxito".

Que el brillo estuviera en 100 no era mérito de esa línea, sino del NVRAM del propio monitor,
que conserva el último valor entre apagados.

## 10.3 La corrección

Sustituida por una función `brightnessStart()` que usa **`ddcutil` 3.0.1**, que sí funciona
(verificado: escribe y relee).

```lua
local function brightnessStart()
    local script = table.concat({
        "set -- $(ddcutil getvcp 10 --brief 2>/dev/null)",
        "cur=$4; max=$5",
        'case "$max" in ""|*[!0-9]*) exit 0 ;; esac',
        '[ "$cur" = "$max" ] && exit 0',
        'ddcutil setvcp 10 "$max"',
    }, "; ")
    hl.exec_cmd("timeout 15 sh -c " .. shellQuote(script))
end
```

Y en el handler de arranque:

```lua
    brightnessStart()
```

## 10.4 Protección del monitor — las siete barreras

El requisito era que **no pueda dañar el monitor**. Estas son las medidas, cada una con su
motivo:

| # | Medida | Qué evita |
|---|---|---|
| 1 | Sólo se escribe el código VCP **0x10** (brillo) | Nunca se toca 0x12 (contraste), 0x14 (preset de color), 0x16/0x18/0x1A (ganancias) ni 0x04/0x05/0x08, que son «restaurar valores de fábrica» y sí serían destructivos |
| 2 | El valor se lee del monitor, no se fija a mano: se escribe **el máximo que él declara** | Imposible salirse del rango soportado. El LG ULTRAGEAR+ declara `max=100` para VCP 0x10 |
| 3 | **Se lee antes de escribir**: si ya está en el máximo, no se escribe | El brillo vive en NVRAM y cada escritura gasta un ciclo. Evitarla cuando es innecesaria es lo que de verdad protege el hardware |
| 4 | Validación numérica del máximo (`case ... *[!0-9]*`) | Si la lectura devuelve `ERR` o basura, se aborta sin escribir. Un valor basura sería el único camino realista a un ajuste incorrecto |
| 5 | **Una sola escritura por arranque**, sin bucle. No va en `config.reloaded` | Recargar la config no escribe. Sólo `hyprland.start` |
| 6 | `timeout 15` | ddcutil tarda ~3,5 s por invocación; si el bus I2C se cuelga, no bloquea el autostart |
| 7 | `ddcutil` verifica releyendo tras escribir (no se usa `--noverify`) | Detecta una escritura que no se aplicó |

Sobre el desgaste de NVRAM, con orden de magnitud: la medida 3 hace que en régimen normal
**no haya ninguna escritura**. Sólo se escribe si alguien bajó el brillo antes de apagar.
Incluso en el peor caso serían 1-3 escrituras al día, frente a una resistencia típica de
10 000-100 000 ciclos.

## 10.5 Verificación

| Prueba | Resultado |
|---|---|
| `luac -p`, `luajit`, `lua` cargan el fichero | **OK** |
| `Hyprland --verify-config` (copia en `/tmp` con shim) | **`config ok`** |
| `hyprctl configerrors` tras recarga en vivo | **vacío** |
| Ruta de omisión (brillo ya en 100) | 3,43 s, **no escribe**, valor intacto |
| Ruta de escritura (brillo bajado a 99) | 6,93 s, **devuelve a 100** |
| Ejecución vía `/bin/sh -c` (igual que Hyprland) | `rc=0`, valor intacto |
| Handler de arranque simulado con `exec_cmd` capturado | Envía el comando correcto; **no aparece ningún `ddccontrol`** |

Datos del monitor: **GSM:LG ULTRAGEAR+** (modelo WK95U, MCCS 2.1), en `/dev/i2c-8`,
conector `card1-DP-2`.

## 10.6 Lo que queda roto — mismo origen

Los binds **F1/F2** siguen usando `ddccontrol`, así que fallan igual:

```lua
F1 → ddccontrol -r 0x10 -w 10  dev:/dev/i2c-8 && ...
F2 → ddccontrol -r 0x10 -w 100 dev:/dev/i2c-8 && ...
```

Es decir: la parte de brillo de esos binds **nunca ha funcionado**. Y arrastran los defectos ya
documentados en §9.6: ambos llaman al mismo `hyprshade toggle`, el `&` rompe la cadena `&&`, y
el filtro apunta a una plantilla que necesita `chevron`.

No se han tocado porque no formaban parte de lo pedido. Sustituir `ddccontrol` por `ddcutil`
ahí es el mismo cambio que aquí, con los mismos guardas.

---

# 11. El slider de brillo de DMS no cambiaba el monitor (2026-09-24) — RESUELTO

## 11.1 Lo que se pidió

> «por qué no funciona los sliders de mi dms para cambiar el brillo de mi monitor, algo moviste
> en las configuraciones? las teclas de función suben y bajan el slider pero el brillo nunca
> cambia, como se arregla»

## 11.2 Respuesta directa: no se tocó nada de DMS

`git diff` sobre `hyprland.lua` muestra **cuatro** bloques con cambios. Los míos son dos, ambos de
brillo y documentados (§10 y §11.4):

| Bloque | Autoría | Contenido |
|---|---|---|
| `wallpaperFile`: `yellowmatrix-deepseek144.mp4` → `yellowmatrix-deepseek.mp4` | No mío | Ya estaba sin confirmar antes de esta consulta |
| `brightnessStart()` + su llamada (§10) | Mío, 2026-09-22 | Brillo al máximo en cada arranque |
| Espera de `/dev/i2c-8` antes de `dms run` (§11.4) | Mío, 2026-09-24 | Este arreglo |
| Bind del ratón de STALKER 2 (`non_consuming` eliminado) | No mío | Ya estaba sin confirmar antes de esta consulta |

**Nada bajo `~/.config/DankMaterialShell/` fue editado.** El problema no venía de una edición de
configuración: venía de una carrera de arranque que dependía del tiempo de encendido, y por eso
podía aparecer y desaparecer entre reinicios sin que nadie tocara nada.

## 11.3 Causa raíz: carrera de arranque, con cronología medida

DMS sondea los buses DDC **una sola vez** al arrancar y no reintenta salvo que haya un cambio de
pantalla (hotplug), que en este equipo nunca ocurre. En el arranque analizado el sondeo llegó
antes de que existieran los nodos `/dev/i2c-*`:

| Hora | Evento | Fuente |
|---|---|---|
| 14:49:07 | arranque del sistema | `uptime -s` |
| 14:49:14 | módulo `i2c_dev` cargado | `journalctl -k` |
| 14:49:16 | `/dev/i2c-0` (SMBus del chipset, `i2c_i801`) | `journalctl -k` + `stat` |
| 14:49:37 | arranca Hyprland (PID 1381) | `ps -o lstart` |
| **14:49:38** | **arranca `dms run` (PID 1461) → sólo existía i2c-0** | `ps -o lstart` |
| **14:49:39,40** | **aparecen `/dev/i2c-1..9`** (buses DDC de la GPU; **i2c-8 = DP-2**) | `stat -c '%n %y'` |

DMS pierde la carrera por **1,4 s**. Sin ningún dispositivo DDC, su «dispositivo por defecto» cae
en lo primero que encuentra: los **LEDs de la NIC ethernet** (`leds:igc-0800-led0/1/2`, del driver
`igc` de `enp8s0`). De ahí el síntoma exacto: el slider se mueve, el OSD cambia de valor, y el
monitor no hace nada. Las teclas `XF86MonBrightnessUp/Down` llaman a `increment/decrement` con
dispositivo vacío (= «el de por defecto»), así que movían ese mismo LED.

Prueba de que el daemon nunca re-sondea: llevaba **2,5 h** en marcha, con `/dev/i2c-8` existiendo
desde 1,4 s después de su arranque, y seguía sin ver el monitor:

```
$ dms ipc call brightness list
Available devices:
leds:igc-0800-led0 (leds)
leds:igc-0800-led1 (leds)
leds:igc-0800-led2 (leds)
```

## 11.4 Hipótesis descartadas, con la evidencia que las descarta

| Hipótesis | Veredicto | Evidencia |
|---|---|---|
| Edición mía en la config de DMS | **Descartada** | `git diff`: nada bajo `DankMaterialShell/` tocado |
| `DMS_NO_DDC` puesta (opt-out) | **Descartada** | Es la única variable DDC del binario; no está en `/proc/1461/environ` |
| Permisos sobre `/dev/i2c-8` | **Descartada** | Nodo `root:969 crw-rw----`; n30 no está en el gid 969 **pero** tiene ACL `user:n30:rw-` (`getfacl`) |
| Hardware / DDC roto | **Descartada** | `ddcutil detect --brief` → `card1-DP-2` / `GSM:LG ULTRAGEAR+`; `getvcp 10 --brief` → `VCP 10 C 100 100` |
| Conflicto entre DMS y `ddcutil` | **Descartada** | DMS **no** enlaza `libddcutil`: usa su propio código i2c (`/dev/i2c-%d`) |
| El widget está mal configurado | **Descartada** | `settings.json` ya tenía `deviceName: "ddc:i2c-8"` en el `brightnessSlider` |

## 11.5 Corrección aplicada

En `hyprland.lua`, dentro de `hyprland.start`, sustituido `hl.exec_cmd("dms run")`:

```lua
hl.exec_cmd("i=0; while [ $i -lt 150 ] && [ ! -e /dev/i2c-8 ]; do sleep 0.1; i=$((i+1)); done; exec dms run")
```

Tope de **15 s**: si el bus nunca aparece, DMS arranca igual (degradado, como antes), así que **no
puede bloquear la sesión**. Nota de honestidad: aquí se fija el número de bus a mano, lo que
contradice la regla general de §«no fijar el bus» — pero es inevitable, porque DMS identifica los
monitores por bus (`ddc:i2c-<N>`). El tope es lo que hace que un cambio de numeración **degrade en
vez de romper**; si algún día el monitor cambia de bus, hay que actualizar el número en el Lua.

### Verificación

| Comprobación | Resultado |
|---|---|
| `luac -p hyprland.lua` | sintaxis OK |
| `sh -n` del comando | sintaxis OK |
| `Hyprland --verify-config` (copia en `/tmp` con `hl.exec_cmd` anulado) | `config ok` |
| `hyprctl reload` + `hyprctl configerrors` | sin errores |
| Espera con el bus presente | 0 iteraciones, 0,001 s (sin retardo en recargas) |
| Espera con el bus ausente | agota el tope y continúa (2,021 s con tope corto de prueba) |

### Comprobación de extremo a extremo

Reiniciado el daemon en caliente (autorizado por el usuario). **Atención al método**: en Hyprland
0.56.2 con parser Lua, `hyprctl dispatch exec "dms run"` **falla** — el argumento se interpreta
como Lua (`hl.dispatch(exec dms run)` → `')' expected near 'dms'`). Hay que usar:

```bash
hyprctl eval 'hl.exec_cmd("dms run")'
```

| Paso | Resultado |
|---|---|
| `dms ipc call brightness list` (antes) | sólo `leds:igc-0800-led*` |
| `dms ipc call brightness list` (después) | **incluye `ddc:i2c-8 (ddc)`** |
| `dms ipc call brightness status` | `Device: ddc:i2c-8 - Brightness: 100%` — el **por defecto** ya es el monitor |
| `ddcutil getvcp 10 --brief` antes de escribir | `VCP 10 C 100 100` |
| `dms ipc call brightness set 80 ""` | «Brightness set to 80% on ddc:i2c-8» |
| `ddcutil getvcp 10 --brief` después | **`VCP 10 C 80 100`** — baja de verdad |
| `dms ipc call brightness increment 5 ""` (ruta de las teclas) | 80 → **`VCP 10 C 85 100`** |
| `dms ipc call brightness set 100 ""` | restaurado → `VCP 10 C 100 100` |

Cinco escrituras en total en NVRAM durante la prueba (bajar, subir, restaurar y las dos de DMS),
frente a 10 000-100 000 ciclos de resistencia. Aceptable para una verificación de una sola vez.

## 11.6 Firmas del IPC de brillo de DMS 1.6.2 (útiles para futuros binds)

| Función | Firma |
|---|---|
| `status` | 0 argumentos; devuelve el dispositivo **por defecto** |
| `set` | `set(percentage, device)` — **2 obligatorios** |
| `increment` / `decrement` | `(amount, device)`; `device=""` = por defecto |
| `list` | dispositivos que ve el daemon |

**No existe función IPC de reescaneo.** Probados `rescan`, `Rescan`, `rescanDevices`, `refresh`
→ `Function not found`. El literal `brightness.rescan` que aparece en el binario **no** es
alcanzable ni por IPC ni por CLI (`dms brightness --help` sólo tiene `get`, `list`, `set`).
Reiniciar el daemon es la única forma de que vuelva a sondear los buses.

## 11.7 Nivel de confianza

- **Causa raíz (carrera de arranque): confirmada.** No es una inferencia: el reinicio del daemon
  hizo aparecer `ddc:i2c-8` y `ddcutil` verificó que el brillo real cambia. Es una prueba
  reproducible.
- **Generalización a «cualquier arranque»: alta, no total.** La carrera depende de cuándo termine
  udev de crear los nodos. En este arranque perdió por 1,4 s; en otros podría ganarla. El arreglo
  cubre ambos casos (0 s de espera si el bus ya está).
- **Efecto del arreglo en el próximo arranque: no verificado todavía.** Se ha verificado la
  sintaxis, el verificador de Hyprland y la lógica del bucle por separado, pero el handler de
  `hyprland.start` no se puede disparar sin un inicio de sesión nuevo. Se confirmará en el próximo
  arranque con `dms ipc call brightness list`.

## 11.8 Pendiente, detectado de paso

Los binds **F1/F2** de §10.6 siguen igual: `ddccontrol` (fallo silencioso, rc=0), `&` que rompe la
cadena `&&`, ambos llamando al mismo `hyprshade toggle`, y un filtro que necesita `chevron`. Es
decir, siguen siendo no-ops. Candidatos a migrar a `dms ipc call brightness set <pct> ""` ahora
que el dispositivo por defecto ya es el monitor.

---

# 12. El mismo fallo afectaba al brillo máximo al arrancar (2026-09-24) — CORREGIDO

## 12.1 La pregunta que lo destapó

> «si quedó configurada para que cada vez que inicio mi pc sea a máximo brillo?»

La respuesta honesta al comprobarlo fue: **el código estaba, pero no era fiable.** El §10 había
verificado la *lógica* del script (que lee antes de escribir, que no usa `ddccontrol`, que el
verificador de Hyprland acepta el fichero), pero **no** se había verificado en un arranque real.

## 12.2 El fallo: la barrera nº 4 convertía la carrera en un no-op silencioso

`brightnessStart()` corre en el mismo autostart que `dms run`, es decir en el mismo instante en que
`/dev/i2c-8` todavía no existe (§11.3). La secuencia real era:

1. `ddcutil getvcp 10 --brief` no encuentra ningún monitor → **stdout vacío**, rc=1.
2. `set --` no asigna nada → `$4` y `$5` quedan vacíos.
3. La barrera nº 4 («valida que el máximo leído sea numérico») ve `max` vacío y **aborta sin
   escribir**.

O sea: la barrera diseñada para *proteger* el monitor era también la que **ocultaba** el fallo. El
brillo máximo al arrancar nunca se aplicaba, sin un solo mensaje de error. Verificado el
2026-09-24 simulando un bus sin monitor:

```
$ out=$(ddcutil --bus 0 getvcp 10 --brief 2>/dev/null); echo "[$out] rc=$?"
[] rc=1
$ set -- $out; max=$5; case "$max" in ""|*[!0-9]*) echo "GUARD: aborta sin escribir" ;; esac
GUARD: aborta sin escribir
```

Lo único que se interponía entre el usuario y su objetivo era **1,4 s de reloj**, y no había forma
de saberlo porque el fallo era deliberadamente silencioso.

## 12.3 La corrección

Extraída la espera a un único helper reutilizable, `waitForDdcBus()`, que devuelve el fragmento de
shell y lo consumen **los dos** sitios que necesitan el bus:

```lua
local function waitForDdcBus()
    return "i=0; while [ $i -lt 150 ] && [ ! -e /dev/i2c-8 ]; do sleep 0.1; i=$((i+1)); done; "
end
```

```lua
hl.exec_cmd(waitForDdcBus() .. "exec dms run")                                    -- DMS
hl.exec_cmd(waitForDdcBus() .. "timeout 15 sh -c " .. shellQuote(script))         -- brillo
```

La espera va **fuera** del `timeout 15`, para que sus 15 s no se coman el margen de `ddcutil` (que
necesita hasta 7 s para leer + escribir).

Además, cada rama deja ahora rastro en el journal (`logger -t astra-brillo`), precisamente para
que un fallo silencioso deje de serlo:

| Rama | Mensaje |
|---|---|
| Lectura DDC inválida | `lectura DDC invalida (max=[...]): NO se escribe` |
| Ya en el máximo | `ya en el maximo (100): no se escribe` |
| Hay que escribir | `escribiendo maximo 100 (estaba en 90)` |

El journal de este equipo es **persistente** (`/var/log/journal` existe), así que la traza
sobrevive al reinicio y el próximo arranque se puede auditar con
`journalctl -t astra-brillo`.

## 12.4 Verificación

Se construyó un arnés con un `hl` de mentira que carga el fichero **real** y ejecuta el handler
`hyprland.start` capturando las cadenas exactas que se enviarían. Los 20 comandos del autostart se
volcaron a `/tmp/astra-harness/cmds/`. Los dos relevantes, tal cual salen del fichero:

```
[06] i=0; while [ $i -lt 150 ] && [ ! -e /dev/i2c-8 ]; do sleep 0.1; i=$((i+1)); done; exec dms run
[17] i=0; while [ $i -lt 150 ] && [ ! -e /dev/i2c-8 ]; do sleep 0.1; i=$((i+1)); done; timeout 15 sh -c '<script>'
```

Los tres escenarios, con un `ddcutil` falso para no gastar NVRAM:

| Escenario | Resultado esperado | Resultado real |
|---|---|---|
| Sin monitor (`rc=1`, stdout vacío) | registra y **no escribe** | `lectura DDC invalida (max=[]): NO se escribe`, `setvcp` no llamado |
| Ya en el máximo (`100 100`) | **no escribe** | `ya en el maximo (100): no se escribe`, `setvcp` no llamado |
| Brillo en 90 (`90 100`) | escribe **el máximo leído**, no un valor fijo | `escribiendo maximo 100 (estaba en 90)`, `setvcp` llamado con `100` |

Y contra el monitor **real** (que está en 100, así que no hubo escritura):

```
brillo antes:  VCP 10 C 100 100
ejecutando cmd-17 real -> 3,43 s
journal:       ya en el maximo (100): no se escribe
brillo despues: VCP 10 C 100 100     (sin cambios, cero escrituras)
```

`luac -p` OK · `Hyprland --verify-config` → `config ok` · `hyprctl reload` sin errores.

## 12.5 Nivel de confianza y límite conocido

- **Lógica del script: verificada contra el hardware real.** Los tres caminos se probaron.
- **Efecto en el próximo arranque: todavía NO verificado.** El handler `hyprland.start` no se puede
  disparar sin un inicio de sesión nuevo. Pero ahora hay forma de comprobarlo: tras reiniciar,
  `journalctl -t astra-brillo` dirá exactamente qué pasó, y `ddcutil getvcp 10 --brief` dará el
  valor real.
- **Límite conocido: si el monitor está apagado o dormido al arrancar**, DDC no responde y el
  brillo no se aplica (queda en lo que tenga la NVRAM). El log lo dirá con
  `lectura DDC invalida`. Si eso ocurre, la solución sería reintentar unas cuantas veces a lo largo
  del primer minuto — **no implementado a propósito**, a la espera de la evidencia del primer
  arranque en vez de añadir complejidad por si acaso.


