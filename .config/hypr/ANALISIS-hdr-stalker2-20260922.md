# HDR en STALKER 2 — diagnóstico y qué falta

**Fecha:** 2026-09-22
**Pregunta:** qué debe tener el `hyprland.lua`, qué le falta al sistema, o si ya está activado
**Método:** EDID del monitor, `hyprctl` sobre la sesión viva, opciones de lanzamiento de Steam,
config interna del juego y documentación oficial (wiki de Hyprland, ArchWiki)

---

## Respuesta en una línea

El HDR **no está funcionando**, y el bloqueo **no está en el Lua**: está en dos sitios fuera de
él — el juego tiene el HDR desactivado internamente, y a las opciones de lanzamiento les falta
una variable de entorno. El Lua ya tiene lo importante.

---

## 1. La cadena completa, eslabón por eslabón

Para que veas HDR hacen falta cinco piezas. Estado medido de cada una:

| # | Eslabón | Estado | Evidencia |
|---|---|---|---|
| 1 | Monitor soporta HDR | **OK** | EDID con EOTF SMPTE ST2084 y BT2020 |
| 2 | Hyprland configurado | **Casi** | `bitdepth=10` ✓, `cm_auto_hdr=1` ✓, pero `cm` sin fijar |
| 3 | gamescope pide HDR | **OK** | `--hdr-enabled` ya en las opciones de lanzamiento |
| 4 | Proton entrega HDR al juego | **FALTA** | no hay `DXVK_HDR=1` |
| 5 | El juego emite HDR | **FALTA** | `bUseHDRDisplayOutput=False` |

Los eslabones 4 y 5 son los que rompen la cadena. Sin ellos, los tres primeros no sirven de nada.

---

## 2. Lo que YA tienes (y probablemente no sabías)

Tres cosas ya están puestas. Esto responde a tu «o si ya lo tengo activado y no sepa»: **sí,
en parte.**

### 2.1 El monitor sí es HDR — y de qué clase

Decodificado del EDID real (`/sys/class/drm/card1-DP-2/edid`):

```
HDR Static Metadata Data Block:
  Electro optical transfer functions:
    Traditional gamma - SDR luminance range
    SMPTE ST2084                      <- PQ, el estándar de HDR10
  Supported static metadata descriptors:
    Static metadata type 1            <- HDR10
  Desired content max luminance: 115 (603.666 cd/m^2)
  Desired content min luminance: 1 (0.000 cd/m^2)
Colorimetry Data Block:
  BT2020YCC
  BT2020RGB
```

Traducido: soporta **HDR10 de verdad** (PQ + BT2020 + metadatos estáticos). Pero el pico
declarado es **~604 cd/m²**, que es clase **DisplayHDR 400-500**. No es un OLED ni un mini-LED
con local dimming por zonas; el HDR aquí se nota en color y en rango, no en negros ni en
destellos espectaculares. Expectativa realista, no decepción.

No declara **HLG**, sólo PQ. Irrelevante para juegos.

### 2.2 Hyprland ya está a medio camino

```bash
$ hyprctl monitors -j | ... currentFormat  -> XRGB2101010
$ hyprctl getoption render:cm_auto_hdr      -> int: 1
```

- **`currentFormat = XRGB2101010`**: los 10 bits ya están activos. Eso lo hace tu
  `bitdepth = 10` de la línea 30 del `hyprland.lua`. **Ese ya está bien puesto.**
- **`cm_auto_hdr = 1`**: significa «switch to `cm, hdr`». Es el valor por defecto y está activo,
  así que Hyprland **cambia solo a HDR** cuando detecta contenido fullscreen que lo pide.
  (Los valores son: `0` off, `1` → `cm, hdr`, `2` → `cm, hdredid`.)
- `render:send_content_type = true` — ya activo, es lo que permite al monitor autoconmutar de perfil.

Lo que **no** está fijado es `cm`, que por defecto es `srgb`. Por eso ahora mismo
`colorManagementPreset = srgb` en la sesión viva: **estás en SDR**.

### 2.3 gamescope ya pide HDR

Tus opciones de lanzamiento de STALKER 2, leídas del `localconfig.vdf`:

```
PROTON_USE_OPTISCALER=1 PROTON_FSR4_UPGRADE=1 gamescope -f -W 3440 -H 1440 -w 3440 -h 1440 \
  --hdr-enabled --force-grab-cursor --mangoapp -- %command%
```

`--hdr-enabled` ya está. Y gamescope 3.16.29 lo soporta:

```
--hdr-enabled    enable HDR output (needs Gamescope WSI layer enabled for support from clients)
                 If this is not set, and there is a HDR client, it will be tonemapped SDR.
```

Y bien: **`ENABLE_HDR_WSI` no está puesto**, que es lo correcto. La ArchWiki es explícita:
*«Ensure `ENABLE_HDR_WSI` is not `1`»* con gamescope. Ese flag es sólo para NVIDIA con drivers
antiguos y rompe gamescope.

---

## 3. Lo que FALTA — los dos bloqueos reales

### 3.1 Bloqueo 1: al lanzamiento le falta `DXVK_HDR=1`

La ArchWiki da la receta exacta para gamescope:

```
DXVK_HDR=1 gamescope -f --hdr-enabled -- %command%
```

Tú tienes todo eso **menos `DXVK_HDR=1`**.

Sin esa variable, DXVK no expone capacidades HDR al juego. Resultado: el juego no ve una
pantalla HDR, así que o no ofrece la opción, o emite SDR. Y cuando gamescope recibe SDR, hace
exactamente lo que dice su ayuda: lo **tonemapea a SDR**. El monitor nunca entra en modo HDR.

**Confirmado en la documentación oficial.** Es la variable central en todos los ejemplos de
lanzamiento con gamescope.

### 3.2 Bloqueo 2: el juego tiene el HDR apagado

Config interna de STALKER 2
(`.../compatdata/1643320/pfx/.../Stalker2/Saved/Config/Windows/GameUserSettings.ini`):

```ini
bUseHDRDisplayOutput=False
HDRDisplayOutputNits=1000
```

**`False`.** El juego no emite HDR, punto. Aunque arregles todo lo demás, esto lo anula.

Y hay un segundo detalle: **`HDRDisplayOutputNits=1000`** es demasiado alto para tu panel, que
declara ~604 cd/m² de pico. UE5 usa ese valor para decidir a qué luminancia mapea el contenido;
pedirle 1000 nits a un panel de 604 significa recortar las altas luces y perder detalle en las
zonas brillantes. Un valor realista para tu monitor estaría en el entorno de **400-600**.

### 3.3 Detalle adicional: el modo de pantalla

```ini
FullscreenMode=1
PreferredFullscreenMode=1
LastConfirmedFullscreenMode=2
```

En UE5, `FullscreenMode=1` es **ventana completa sin bordes**, no pantalla completa exclusiva.

Esto importa porque hay un caso reportado que es exactamente el tuyo. En la discusión oficial de
Hyprland sobre auto-HDR ([#11083](https://github.com/hyprwm/Hyprland/discussions/11083)), un
usuario con un ultrapanorámico 3440×1440 escribe:

> *«One thing I noticed in some games is that they need to be explicitly set to fullscreen mode
> ingame, or sometimes even set to borderless and then back to fullscreen, and then restarted,
> otherwise auto-HDR doesn't work properly. **Had this issue with STALKER 2** and Dragon Age
> Veilguard iirc.»*

**Nivel de confianza:** esto es un reporte de la comunidad sobre STALKER 2 concreto, no algo que
yo haya podido verificar en tu máquina. Lo doy como pista fuerte, no como hecho. Pero coincide
con tu configuración actual, así que vale la pena probarlo.

---

## 4. Qué añadir al `hyprland.lua`

### 4.1 Lo que NO hace falta tocar

- **`bitdepth = 10`** — ya está, y es correcto. Verificado activo (`XRGB2101010`).
- **`render:cm_auto_hdr`** — ya vale `1` por defecto, que es «cambiar a HDR cuando haga falta».
  No hace falta fijarlo salvo que quieras forzar `2` (`hdredid`, primarias del EDID).

### 4.2 Lo que sí conviene añadir

La regla de monitor actual (líneas 25-31):

```lua
hl.monitor({
    output   = "DP-2",
    mode     = "3440x1440@144.05",
    position = "auto",
    scale    = 1,
    bitdepth = 10,
})
```

Campos que existen y no estás usando, según la wiki de Hyprland:

| Campo | Por defecto | Para qué |
|---|---|---|
| `supports_hdr` | `0` | Forzar soporte HDR. `-1` off, `0` auto, `1` on. Auto-detección puede fallar; forzarlo a `1` es lo que hace la config que funciona en el hilo oficial |
| `supports_wide_color` | `0` | Ídem para gama amplia (BT2020) |
| `sdrbrightness` | `1.0` | Brillo del SDR **mientras estás en modo HDR**. Rango típico 1.0-2.0 |
| `sdrsaturation` | `1.0` | Saturación del SDR en modo HDR |
| `max_luminance` | `-1` (auto) | Pico del monitor. Auto detecta 604 desde el EDID |
| `max_avg_luminance` | `-1` (auto) | Luminancia media máxima |
| `min_luminance` | `-1` (auto) | Negro mínimo |

### 4.3 La decisión de fondo: `cm` fijo o auto

Hay dos caminos, y **no son equivalentes**:

**Camino A — dejar `cm_auto_hdr` haciendo su trabajo (recomendado para empezar).**
No se toca `cm`. Hyprland conmuta a HDR sólo cuando el juego va a pantalla completa y lo pide.
El escritorio sigue en sRGB. Ventaja: no cambia nada de lo que ves hoy. Riesgo: el auto-HDR
tiene fama de fallar en algunos juegos — el hilo oficial está lleno de gente a la que no le
funciona, y varios acabaron poniendo `cm = "hdr"` a mano.

**Camino B — `cm = "hdr"` fijo.**
Todo el escritorio pasa a HDR permanente. Es la vía que la ArchWiki documenta como «para usar
HDR en el escritorio», y la que reportan como **fiable** cuando el auto-HDR falla. Pero tiene
coste: el SDR se ve distinto (de ahí `sdrbrightness` y `sdrsaturation`), y la wiki avisa de que
*«ICCs are fundamentally incompatible with HDR gaming. Funky stuff may happen.»* Si usas un
perfil ICC, se rompe.

**Mi recomendación:** probar primero el camino A con los dos bloqueos de §3 arreglados. Si el
monitor no conmuta a HDR con el juego, pasar al camino B. Cambiar `cm` es una línea y se
revierte igual de fácil.

---

## 5. Qué hacer, en orden

Por relación entre esfuerzo y probabilidad de arreglarlo:

| Orden | Acción | Dónde |
|---|---|---|
| 1 | Activar HDR **en el juego**: Ajustes → Vídeo → HDR | Menú de STALKER 2 |
| 2 | Poner el juego en **pantalla completa exclusiva** (no sin bordes) | Menú de STALKER 2 |
| 3 | Añadir `DXVK_HDR=1` a las opciones de lanzamiento | Steam → Propiedades → Opciones de lanzamiento |
| 4 | Bajar `HDRDisplayOutputNits` a ~500 en vez de 1000 | Menú del juego (o el `.ini`) |
| 5 | Si aún no conmuta: `cm = "hdr"` + `supports_hdr = 1` en el Lua | `hyprland.lua` |

Las opciones de lanzamiento quedarían así:

```
PROTON_USE_OPTISCALER=1 PROTON_FSR4_UPGRADE=1 DXVK_HDR=1 gamescope -f -W 3440 -H 1440 -w 3440 -h 1440 --hdr-enabled --force-grab-cursor --mangoapp -- %command%
```

### Cómo comprobar si funcionó

Con el juego corriendo y en partida, en otra terminal:

```bash
hyprctl monitors -j | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['colorManagementPreset'])"
```

- `srgb` → sigue en SDR, el HDR no entró
- `hdr` o `hdredid` → **está funcionando**

Y el monitor debe mostrar su propio aviso de «HDR activado» en el OSD.

---

## 6. Notas y límites

- **No he tocado nada.** Ni el Lua, ni las opciones de lanzamiento, ni la config del juego.
- **No he podido verificar el resultado final** porque no he lanzado el juego. Los eslabones 4 y
  5 los doy como «falta» por evidencia documental y por el contenido medido de los ficheros, no
  por haber visto la pantalla en HDR.
- **El detalle del modo de pantalla (§3.3)** es un reporte de terceros, no medición propia.
- **No he verificado si tu Proton concreto auto-activa HDR.** Algunas versiones de Proton lo
  hacen al detectar gamescope. Si tras añadir `DXVK_HDR=1` sigue igual, merece la pena mirar los
  logs buscando líneas `[HDR Layer]` — es lo que sugiere el hilo oficial para diagnosticar.
- `render:cm_fs_passthrough` **no existe en tu versión** (0.56.2), aunque aparezca en recetas
  antiguas de la 0.50. No lo busques.
