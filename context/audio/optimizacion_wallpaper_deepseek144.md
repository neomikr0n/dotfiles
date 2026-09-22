# `yellowmatrix-deepseek144.mp4` — 144 fps desde `yellowmatrix-deepseek.mp4`

Fecha: 21 de septiembre de 2026, 18:58–19:10.
Entregable: `/home/n30/dotfiles/share/wallpapers/yellowmatrix-deepseek144.mp4`
`sha256 = b8c7de0b4c0a824b5e5a038d3b914627140a9eacfeba9fb49cc878a9c6a774d2`

> **Sustituye** al entregable anterior del mismo nombre, que partía de `yellowmatrix.mp4`
> (el maestro H.264 de 70 MB). Aquel se conserva en `~/.cache/ym144/deepseek144-desde-maestro-h264.mp4`.

> **En uso** en DP-2 desde el 21-sep-2026, 19:20, a 144,05 Hz. Ponerlo en pantalla no fue trivial:
> el comando era correcto y aun así no se veía nada. Las dos causas están en **§9**.

---

## 1. Lo que se pidió

> «usa este video [`yellowmatrix-deepseek.mp4`] y sobreescribe `yellowmatrix-deepseek144.mp4` con 144fps»

## 2. Origen

`share/wallpapers/yellowmatrix-deepseek.mp4` — `sha256 e2671c4d3f9b150be87634075824755ea2f979cbc0845f2bb8fcd4500754991c`

| | |
|---|---|
| Códec | AV1 Main, 7,89 Mbps |
| Tamaño | 15.878.484 B |
| Resolución / cadencia | 3440×1440 · **30/1** |
| Cuadros / duración | 483 · 16,1 s |
| Color | yuv420p, rango limitado (tv), **BT.709 declarado en matriz, transferencia y primarios** |

Es el archivo que está puesto como fondo en DP-2, así que el encuadre y el color se heredan sin tocar
nada: no se aplicó ninguna LUT ni ningún recorte.

## 3. Método

1. **Extracción**: 483 fotogramas a PNG sin pérdida (814 MB).
2. **Cierre del bucle**: 4 fotogramas de contexto al final, copias de los 4 primeros. Sin ellos, la
   interpolación en la costura del bucle no tiene hacia dónde mirar. Se descartan al codificar.
3. **Interpolación**: RIFE v4.6 ncnn/Vulkan en la RX 9070 XT, `-n 2337 -g 0 -j 4:2:4 -z`, 208 s.
   TTA temporal activada (`-z`). Se descartó TTA espacial (`-x`) porque multiplicaba el tiempo por 5,4
   (80,4 s frente a 14,9 s en la muestra) sin que el material lo justifique.
4. **Codificación**: los **2318 primeros** cuadros de los 2337 → AV1.

### La aritmética de los recuentos

144/30 = **4,8 = 24/5**. Con 487 entradas (483 + 4 de contexto) y `n` salidas, la salida `j` cae en el
instante `j · 486/(n-1)` de la entrada. Para que las 2318 primeras salidas cubran exactamente el
material original hay que pedir `n = 2337`. Verificado: el cuadro de salida 1168 cae en el instante
exacto 243,0 y coincide con el fotograma 244 del origen.

**Ajustes finales:**

```
-framerate 144 -i rifeout/%08d.png -frames:v 2318 -an
-vf scale=out_color_matrix=bt709:out_range=tv,format=yuv420p,setsar=1
-c:v libsvtav1 -preset 6 -crf 30 -g 288 -svtav1-params lp=8:lookahead=20
-bsf:v av1_metadata=color_primaries=1:transfer_characteristics=1:matrix_coefficients=1:color_range=0
-movflags +faststart
```

El filtro de flujo `av1_metadata` es necesario porque `libsvtav1` **no escribe** las etiquetas de color
en la cabecera AV1: sin él la salida queda con `color_transfer` y `color_primaries` sin declarar. Hay
que usar **valores numéricos** (BT.709 = 1); los nombres simbólicos no se aceptan.

## 4. Resultado

| | Origen (30 fps) | **Entregable (144 fps)** | |
|---|---:|---:|---:|
| Tamaño | 15.878.484 B | 17.115.115 B | **+7,8 %** |
| Bitrate | 7,89 Mbps | 8,51 Mbps | +7,9 % |
| **Cadencia** | **30 fps** | **144 fps** | **×4,8** |
| Cuadros | 483 | 2318 | ×4,8 |
| Duración | 16,1 s | 16,097222 s | igual |
| Resolución | 3440×1440 | 3440×1440 | igual |
| Color | BT.709 tv | BT.709 tv | igual |

**4,8 veces más cuadros por un 7,8 % más de bytes.** La razón es que los cuadros interpolados son
casi idénticos entre sí, así que el residuo que codifica AV1 es mínimo.

Tiempos: interpolación 208 s + codificación 40,1 s. Pico de memoria del codificador 6.286 MB.

## 5. Verificación

**Fluidez real** (lo único que distingue un 144 fps auténtico de uno rellenado con cuadros repetidos).
Diferencia media entre cuadros consecutivos, escala 0–255:

| | Diferencia media | Intervalo temporal |
|---|---:|---|
| Origen | 0,8138 | 1/30 s |
| Entregable | 0,1675 | 1/144 s |
| **Cociente** | **4,858** | esperado 4,8 |

Y **0 de 23** pares consecutivos son idénticos. El movimiento es continuo.

**Color y geometría**, en los instantes que caen exactos (salida 0 ↔ origen 0; salida 1168 ↔ origen 243):

| Par | Diferencia media | máx | p99 | Medias RGB (mío / origen) |
|---|---:|---:|---:|---|
| 0 ↔ 0 | 0,490 | 50 | 6 | [19,29 13,64 7,12] / [19,60 13,99 7,20] |
| 1168 ↔ 243 | 0,674 | 214 | 8 | [18,99 13,29 6,89] / [19,32 13,65 6,99] |

Desvío de ~0,3 niveles sobre 255 (0,12 %), uniforme en los tres canales: sin cambio de tono.

**Distribución del error** (cuadro 1168): >2 niveles el 13,1 % · >8 el 1,87 % · >32 el 0,17 %.
Los 8.437 píxeles con error >32 están repartidos por todo el cuadro, sobre los bordes de alto contraste
del oro, no concentrados en ningún artefacto. Panel de diferencia ×8 revisado a ojo: grano de 1–2
niveles y bordes, **sin banding ni imágenes fantasma**.

**Banding**: niveles tonales en la fila central 151 (origen) → 156 (entregable). No se pierde gradación.

**Decodificación:**
- VA-API: archivo completo, sin errores.
- Caudal real: 2318 cuadros en 3,557 s ≈ **652 fps**; memoria de decodificación 85 MB.
- Sonda `skwd-wall-vk --decode-probe`: los 7 backends aceptados. `cascade` 4,5 ms · `vaapi` 4,7 ms ·
  `vaapi-device-only` 2,7 ms. El presupuesto a 144 fps es **6,94 ms por cuadro**: entra con margen.

## 6. El disco: aviso dado y **retirado**

Durante el trabajo `/` (btrfs, `/dev/nvme0n1p2`, compresión `zstd:3`) llegó a estar **al 100 %, con
1,2 GB libres**, y avisé de ello. **El aviso era precipitado y queda retirado.**

Los intermedios de este trabajo (hasta 6,5 GB de PNG) se borraron, y **btrfs tardó unos minutos en
devolver el espacio**: referencias diferidas y `discard=async`. Medido después, dos veces y con 4 s de
separación:

| Momento | Usado | Libre |
|---|---:|---:|
| Al empezar la sesión | 140 GB | 11 GB (94 %) |
| Peor momento (intermedios en disco) | 149 GB | 1,2 GB (100 %) |
| **Estado final** | **135 GB** | **15 GB (91 %)** |

El disco acaba **mejor que como estaba**. No hace falta liberar nada para la próxima operación.

Lo que sí queda son **1,3 GB de volcados de fallo** en `/var/lib/systemd/coredump/`, propiedad de
`root` (modo 0640), entre ellos uno de **440 MB** del encode fallido de las 18:41. Confirman el
diagnóstico: `TID: svt-srcops0`, `SEGV_MAPERR`, con la cadena de filtros pesada más `preset 6` — es
decir, **el segfault fue por memoria dentro de `libSvtAv1Enc.so`, no por el vídeo**. Se pueden retirar
con `sudo coredumpctl --no-pager list` + `sudo rm`, pero **no se ha tocado nada**: es un directorio del
sistema y requiere root.

## 7. Qué NO se hizo

- **No se cambió el fondo activo** en el momento de entregar el vídeo: DP-2 seguía con
  `yellowmatrix-deepseek.mp4`. (Se cambió después, a petición del usuario; ver §9.)
- **No se generó una versión de 240 fps**, aunque el panel anuncia 3440×1440@240,09 Hz y ahora corre a
  144,05 Hz. Requeriría otra pasada de RIFE y cambiar el monitor de modo.
- **No se borró nada del usuario** ni nada del sistema.

## 8. Cómo ponerlo en uso

**El comando sin `--layer` NO basta**, y el motivo está en §9. La secuencia que funciona es limpiar
primero y aplicar después, en la capa `bottom`:

```bash
skwd-paper-v2 stop DP-2
pkill -TERM -x mpvpaper
pkill -TERM -x gslapper
pkill -TERM -x skwd-wall-vk
sleep 1
skwd-paper-v2 apply DP-2 /home/n30/dotfiles/share/wallpapers/yellowmatrix-deepseek144.mp4 \
  --kind video --engine default --fill-mode fill --mute true --layer bottom
```

Comprobación de que de verdad está en pantalla:

```bash
pgrep -af 'skwd-wall-vk|mpvpaper' | grep -v defunct    # debe salir UNO, con la ruta nueva
hyprctl layers | sed -n '/DP-2/,/^$/p'                 # una sola capa a 3440x1440
```

Mantener el monitor en su modo actual de **144,05 Hz**.

## 9. Ponerlo en pantalla: dos fallos, y ninguno era el comando

El comando de §8 **estaba bien**: `skwd-paper-v2 apply` devolvía `ready: true`. Aun así no se veía
nada. Eran **dos fallos independientes**, y el primero rompía toda la configuración del escritorio.

### 9.1 `hyprland.lua` no compilaba — el archivo entero estaba muerto

La línea añadida a las 19:06 era:

```lua
hl.exec_cmd(skwd-paper-v2 apply DP-2 /home/n30/.../yellowmatrix-deepseek144.mp4 --kind video ...)
```

`hl.exec_cmd` recibe una **cadena de shell**. Sin comillas, Lua lee `skwd - paper - v2 apply ...` y
aborta el análisis:

```
$ hyprctl configerrors
/home/n30/.config/hypr/hyprland.lua:136: ')' expected near 'apply'
```

Es un error de **sintaxis**, no de ejecución: **no se carga nada del archivo** — ni un bind, ni el
autostart. Y como Hyprland **conserva en memoria la última versión que sí compiló**, la sesión
seguía con sus 140 binds y **parecía sana**. El síntoma no es un error visible, es **silencio**: lo
que se edite en el archivo simplemente no ocurre.

Había además un segundo problema en el mismo sitio: `wallpaperStart()` seguía **llamándose** en las
líneas 184 y 225 con su definición comentada con `--[[ ... ]]`. Aunque se hubiera arreglado la línea
136, habría fallado igual por «attempt to call a nil value».

### 9.2 Un renderizador viejo tapaba al nuevo (orden de capas)

En DP-2 convivían **tres** capas a 3440×1440: `quickshell` y `mpvpaper` en *background*, y un
`skwd-wall-vk` **huérfano** en *bottom*. `apply` crea la asignación en **`background`** por defecto, y
los niveles de Hyprland se apilan `background < bottom < top < overlay`: **el viejo tapaba al nuevo**.

De ahí la conclusión práctica, que es la que pidió el usuario: **hay que matar el proceso antes de
iniciarlo**. El huérfano venía de una invocación anterior con `--layer bottom`, y `mpvpaper` seguía
vivo debajo descodificando el máster de 70 MB para nada (y era, además, una trampa de **doble
ecualizador**, porque el archivo ya lleva el ecualizador grabado en los píxeles).

### 9.3 Lo que se arregló

- **`hyprland.lua`**: `wallpaperStart()` reconstruida en Lua válido (cadena armada con
  `table.concat`) y con la **limpieza dentro**, antes del arranque. Se quitó la línea rota. El bind
  muerto `killall mpvpaper` pasó a `skwd-paper-v2 stop`. Respaldo:
  `hyprland.lua.bak-2026-09-21`.
- **El fondo**: limpieza + `apply` con `--layer bottom`.

### 9.4 Cómo se validó sin romper la sesión

- `luac -p` para la sintaxis.
- **Un arnés propio con un `hl` de mentira** que carga el archivo sin ejecutar nada, captura los
  manejadores de eventos y los dispara a mano. Resultado: **140 binds** (los mismos que la sesión
  viva) y «OK» en `hyprland.start` y en `config.reloaded`.
- **Nunca `Hyprland --verify-config` sobre el archivo real**: carga la config de verdad y ejecuta el
  autostart.
- La prueba de que la ruta de recarga funciona: **Hyprland recarga solo al guardar**, y el pid del
  renderizador cambió en cada guardado (300030 → 300492 → 301337).

### 9.5 Estado final

| | |
|---|---|
| renderizadores vivos | **1** (`skwd-wall-vk`, pid 301337) |
| capa | `bottom` |
| archivo | `yellowmatrix-deepseek144.mp4` |
| `skwd-paper-v2 status` | `ready: true`, `paused: false` |
| `hyprctl configerrors` | vacío |
| binds | 140 |
| `yellowmatrix-original.mp4` | intacto (`5b8b550e2283fe9e21149c098264dac6`) |

Queda un **proceso zombi** (`207226`, `<defunct>`) cuyo padre es `skwd-walld`: es inofensivo y no se
tocó, porque matar al demonio apagaría el fondo. **No se ha probado un reinicio real**: el arranque
limpio (`hyprland.start` con el marcador de autostart borrado) sí se verificó en el arnés.

