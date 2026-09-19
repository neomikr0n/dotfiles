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
