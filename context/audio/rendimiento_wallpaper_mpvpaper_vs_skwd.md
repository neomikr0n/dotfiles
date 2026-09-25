# Consumo: `mpvpaper` + `yellowmatrix.mp4` vs `skwd-wall` + `yellowmatrix-deepseek144.mp4`

Medido el **22-sep-2026**, ~15:30–21:45 CST, en DP-2 (LG UltraGear+ 411NTJJA4748, 3440×1440@144,05 Hz).
Arnés: `/tmp/wlbench/measure.py` (muestreo cada 0,5 s, media/mediana/min/máx/desviación).
GPU: **Radeon RX 9070 XT** (`card1`). CPU: i5-13600K, 20 hilos lógicos.

> **Cómo leer esto.** No hay una sola cifra: hay **dos condiciones** y la comparación honesta necesita
> las dos. Todo lo que sigue lleva su nivel de confianza explícito, y al final hay una lista de lo que
> **no** se puede concluir.

---

## 0. Un aviso previo que cambia el planteamiento

El `yellowmatrix.mp4` que reproducía `mpvpaper` **ya no está** en `~/dotfiles/share/wallpapers/`.
Sobrevive idéntico (md5 `5b8b550e2283fe9e21149c098264dac6`) en tres sitios:

| copia | ruta |
|---|---|
| Descargas | `/home/n30/Descargas/yellowmatrix.mp4` |
| respaldo ML4W | `~/.ml4w-hyprland/backup/dotfiles/share/wallpapers/yellowmatrix.mp4` |
| respaldo propio | `~/dotfiles/share/wallpapers/yellowmatrix-original.mp4` |

Las tres son el mismo fichero: **H.264 High, 3840×2160, 60 fps, 967 fotogramas, 14,86 Mbps, 29,9 MB**.
He usado la de Descargas para medir (solo lectura).

**Y aquí está el punto importante:** lo que se compara **no es solo el motor**. Son cuatro cosas a la vez:

| | `yellowmatrix.mp4` (antes) | `yellowmatrix-deepseek144.mp4` (ahora) |
|---|---|---|
| Códec | H.264 High | **AV1** Main |
| Resolución | 3840×2160 | 3440×1440 |
| Fotogramas/s | 60 | **144** |
| Píxeles/s | 497,7 M | **713,3 M** (1,43×) |
| Tamaño | 29,9 MB | 17,1 MB |
| Motor | `mpvpaper` (libmpv, OpenGL/EGL) | `skwd-wall-vk` (Vulkan) |

Atribuir toda la diferencia al motor sería un error. Por eso hay medidas de cruce (§3).

---

## 1. Método, y por qué los números de GPU son los difíciles

**Lo que sí es fiable por construcción:** CPU y RAM se leen **por proceso** (`/proc/<pid>/stat`,
`VmRSS`) → **inmunes a lo que haga el resto de la máquina**.

**Lo que no:** la GPU es **compartida**. `gpu_busy_percent`, `mem_busy_percent`, la potencia y la VRAM
son de sistema. Por eso cada medida lleva **una línea base adyacente** (12–15 s con todo parado
inmediatamente antes) y se reporta el **delta**.

Esa precaución no era teórica: la primera línea base dio **36,5 W** y las siguientes **27,4–28,8 W**.
La carga de fondo derivó (loadavg 6,85 → 3,02) porque hay un **`qemu-system-x86` de Genymotion a
209 % de CPU y 6,4 GB**. Restar una base vieja habría dado una potencia *negativa*.

### El sensor que resuelve el problema

`gpu_busy_percent` **no ve el decodificador de vídeo**. Hace falta `average_mm_activity` de
`/sys/class/drm/card1/device/gpu_metrics` (blob binario, `gpu_metrics_v3_0`). Validación cruzada:

| campo de `gpu_metrics` | valor | sensor independiente | valor |
|---|---|---|---|
| `average_gfx_activity` | 19 | `gpu_busy_percent` | 21 |
| `average_umc_activity` | 6 | `mem_busy_percent` | 6 |
| `average_socket_power` | 61 | `hwmon/power1_average` | 63 W |
| `temperature_edge` | 54 | `hwmon/temp1_input` | 54,0 °C |

Y lo mejor: **en la línea base `average_mm_activity` = 0 exacto**, con el emulador de Android a pleno
rendimiento. Es decir, **todo el VCN medido es atribuible al wallpaper**, sin restar nada. Es una
media móvil reciente (no acumulada desde el arranque), y eso se comprueba porque cae a 0 al parar.

### Líneas base (para poder auditar los deltas)

| fichero | gpu_busy | potencia | VRAM | VCN | CPU sistema |
|---|---|---|---|---|---|
| `run0-base` | 6,41 % | 36,49 W | 4187,6 MB | 0 | 20,67 % |
| `base1` | 6,13 % | 27,74 W | 4252,8 MB | 0 | 17,77 % |
| `base2` | 6,11 % | 27,37 W | 4293,3 MB | 0 | 17,20 % |
| `base3` | 6,00 % | 27,58 W | 4359,6 MB | 0 | 18,21 % |
| `base4` | 6,22 % | 28,17 W | 4683,6 MB | 0 | 19,76 % |
| `base5` | 6,00 % | 28,22 W | 4724,1 MB | 0 | 16,66 % |
| `base6` | 6,11 % | 28,79 W | 4764,7 MB | 0 | 16,84 % |
| `base7` | 6,05 % | 28,21 W | 5048,2 MB | 0 | 17,89 % |

La VRAM de base **sube de forma monótona** (4187 → 5048 MB) en dos horas: algo va creciendo (navegadores
/ Electron). Los deltas de VRAM siguen valiendo porque cada uno se calcula contra su base inmediata,
pero conviene saberlo.

---

## 2. La comparación principal — misma capa (`bottom`), estado real de tu escritorio

Ambos motores en la **misma capa**, con tu escritorio tal como está (el workspace especial tapa el
100 % del fondo). Ventanas de 20–22 s, línea base adyacente.

| | `mpvpaper` + 4K60 H.264 | `skwd-wall-vk` + 1440p144 AV1 | quién gana |
|---|---|---|---|
| **CPU** (% de 1 núcleo) | **1,9 %** | 3,2 % | mpvpaper (1,7×) |
| CPU (% de los 20 hilos) | 0,10 % | 0,16 % | mpvpaper |
| **RAM RSS** | 223 MB | **57,4 MB** | **skwd (3,9×)** |
| Hilos | 31 | **7** | skwd |
| **VRAM** (Δ) | +447 MB | **+162 MB** | **skwd (2,8×)** |
| GPU busy (Δ) | **+0,26 pp** | +0,78 pp | mpvpaper |
| **VCN mediana** | 16 % | 47 % | mpvpaper |
| VCN media | **17,0 %** | 37,4 % | mpvpaper |
| **Potencia GPU** (Δ) | **+1,73 W** | +3,17 W | mpvpaper |
| CPU del sistema (Δ) | −0,23 pp | +1,44 pp | mpvpaper |
| Fotogramas tirados | **573 en 27 s** | no aplica | — |

**Confianza:** CPU y RAM, **alta** (medida directa por proceso, repetida en 2–3 tandas con resultados
iguales: RAM 223–237 MB vs 57,2–57,5 MB; CPU 1,9–2,0 % vs 3,2 %). VRAM, **media** (deriva de base).
VCN y potencia, **media** (media móvil, y ver §4).

### Pero el titular crudo engaña, y hay que decirlo

`skwd` consume más GPU **porque hace más trabajo**, y no es una impresión: son números.

| | `mpvpaper` | `skwd` |
|---|---|---|
| Fotogramas entregados | ~60/s (**menos los tirados**) | 144/s |
| Píxeles/s | 497,7 M | 713,3 M (1,43×) |
| VCN por (Mpix/s) | **0,0342 %** | 0,0524 % (1,53× peor) |
| CPU por (Mpix/s) | **0,00382 %** | 0,00449 % (1,17× peor) |
| VCN por fotograma | 0,283 % | **0,260 %** |

Normalizado por **fotograma**, `skwd` es **ligeramente más barato** (0,260 vs 0,283 % de VCN). Y eso
**antes** de descontar los fotogramas que `mpvpaper` tira: si de verdad entrega ~39/s, su coste real
por fotograma mostrado sube a **0,44 %**, casi el doble que `skwd`.

Es decir: **el AV1 a 144 fps cuesta ~1,5× más por píxel que el H.264 a 60 fps** (esperable, AV1 es un
decodificador más complejo), pero **por fotograma entregado `skwd` gana**.

---

## 3. Cruces para aislar las causas (§0)

### 3.1 Códec, mismo motor y mismo tamaño/fps

`mpvpaper` con los dos ficheros de 3440×1440@144, en capa `overlay` (visible, sin oclusión):

| | H.264 1440p144 | AV1 1440p144 |
|---|---|---|
| CPU (% 1 núcleo) | 3,9 % | 2,5 % |
| RAM | 195,9 MB | 131,8 MB |
| VCN media | 38,5 % | 29,0 % |
| **Fotogramas tirados** | **2** | **1.660** |

**Hallazgo, y es el más contundente de todo el informe:** `mpvpaper` **no puede** con AV1 a
3440×1440@144. Tira 1.660 fotogramas y su VCN cae a una mediana de 4 % (decodifica a ráfagas, no
sostiene el ritmo). Con H.264 al mismo tamaño y los mismos fps tira **2**. El cuello de botella no es
la GPU: es la ruta de AV1 de mpv en este equipo.

**Consecuencia práctica:** si hubieras puesto `yellowmatrix-deepseek144.mp4` con `mpvpaper`, el fondo
habría ido a tirones. `skwd` lo sostiene (VCN 47 % sostenido). **Esto es, por sí solo, una razón
técnica para el cambio.**

### 3.2 Motor, mismo fichero

`mpvpaper` con el **mismo** AV1 1440p144 que usa `skwd`: 2,8 % de CPU, 132 MB RAM, 27 hilos
(frente a 3,2 % / 57 MB / 7 hilos de `skwd`). Mismo orden de CPU; `skwd` gana en memoria.

### 3.3 El original completo

`mpvpaper` + 4K60 H.264 en `background` (su capa por defecto) y en `overlay`: CPU 2,0 %, RAM 228–234 MB,
VCN 14,5–14,9 %. Coherente con §2.

---

## 4. Cinco cosas que descubrí midiendo y que no esperaba

1. **`mpvpaper` deja de trabajar cuando el fondo no se ve.** En `background`, con el workspace especial
   delante, tira **el 100 % de los fotogramas** (864 en 31 s). Con `--auto-pause` se pausa de verdad
   (0 ticks de CPU en 3 s). **`skwd` no hace eso**: sigue a VCN 47 % con el fondo tapado.
   → La comparación de GPU **favorece a `mpvpaper`** cuando el fondo está oculto, que es la mayor parte
   del tiempo en uso normal.

2. **`skwd` no arranca en la capa `overlay`.** Devuelve
   `renderer_startup: compositor did not confirm presentation of rendered frame within 2 seconds`,
   porque en ese nivel ya hay una capa `dms:fade-to-dpms` a pantalla completa. Por eso no pude poner
   los dos motores en la misma capa superior.

3. **`grim` se cuelga mientras `mpvpaper` corre.** Reproducible: `timeout 10 grim` → rc=124, con
   `hyprctl` respondiendo con normalidad. No pude capturar pantalla para verificar visualmente.

4. **Los descartes de `mpvpaper` escalan con los fps**: 30 fps pocos, 60 fps ~76 %, 144 fps ~100 %.

5. **`skwd` no está por encima de tus ventanas.** Va en `bottom`; las ventanas del workspace especial
   son ventanas normales, que van por encima de todas las capas. Con el workspace especial visible,
   **el fondo que ves es el 15–21 % que dejan pasar** las ventanas semitransparentes
   (`kitty` 0,85, `cider` 0,79, `zapzap` 0,85), no el vídeo a plena vista.

---

## 5. Conclusión

**En memoria, `skwd` gana con claridad y es el resultado más sólido del informe:**

- **RAM: 57 MB frente a 223 MB** → **3,9× menos**. Confirmado en tres tandas independientes.
- **VRAM: +162 MB frente a +447 MB** → **2,8× menos**.
- **7 hilos frente a 31.**

**En CPU están empatados en la práctica** (3,2 % vs 1,9 % de un núcleo; en total, 0,16 % vs 0,10 % de
la máquina). Los dos son irrelevantes para un i5-13600K. Normalizado por píxel/s, `skwd` usa 1,17×
más CPU.

**En GPU `skwd` consume más en crudo** (+3,17 W frente a +1,73 W; VCN 37,4 % frente a 17,0 %), **pero**:

- entrega **2,4× más fotogramas** y **1,43× más píxeles**;
- `mpvpaper` está **tirando ~44 % de sus fotogramas** en esa misma medida;
- por fotograma entregado, `skwd` sale **más barato** (0,260 % vs 0,283 %, y 0,44 % si se cuenta solo
  lo que `mpvpaper` realmente muestra).

**Y el dato que probablemente decide:** `mpvpaper` **no puede reproducir AV1 a 144 fps** en este
equipo (1.660 fotogramas tirados). El cambio a `skwd` no solo ahorra memoria: es lo que hace posible
el vídeo nuevo.

> **Ver el añadido del 22-sep al final del informe (§8)**: la comparación a **igualdad de fps**
> (`skwd` con el fichero de 30 fps) y la recomendación sobre si conviene el cambio. Resumen: 3,65×
> menos CPU, 5,2× menos VCN, **4,37 W menos**, RAM igual, y **sin coste perceptivo medible**.

---

## 6. Lo que NO se puede concluir (y por qué)

- **No hay una medida con el fondo a plena vista y sin oclusión para los dos motores.** `skwd` no
  arranca en `overlay` y el workspace especial tapa el 100 %. Para cerrarlo habría que **ocultar el
  workspace especial y usar un workspace vacío** durante ~3 minutos. No lo hice porque cambia tu
  pantalla y no me lo pediste; se hace en un minuto si quieres.
- **Los deltas de VRAM son de confianza media**, porque la base crece de forma monótona (~860 MB en
  dos horas) por otro proceso.
- **La potencia de GPU y el VCN son medias móviles** del firmware con dispersión alta (desviación
  típica 18–33 puntos). Uso mediana además de media por eso; la mediana de `mpvpaper` cambia mucho
  según la capa (0 en `background`, 16 en `bottom`), lo que refleja su comportamiento a ráfagas.
- **No sé si los descartes de `mpvpaper` existían en tu montaje original o son una regresión.** Si
  recuerdas el fondo fluido con `mpvpaper`, entonces es una regresión (una actualización de Hyprland
  o de mpv) y **todas las cifras de GPU de `mpvpaper` están sesgadas a su favor**.
- **La máquina no estaba en reposo**: `qemu-system-x86` (Genymotion) a 209 % de CPU y 6,4 GB, más Zen,
  WorkBuddy, Cider y Steam. Afecta poco a CPU/RAM por proceso; a la GPU, la línea base adyacente lo
  cancela en su mayor parte.

---

## 7. Reproducir

```bash
# Arnés (muestrea CPU/RAM por proceso + GPU de sistema)
python3 /tmp/wlbench/measure.py --label X --pids <pid> --duration 25 --warmup 5 --out x.json

# Motor
skwd-paper-v2 apply DP-2 <fichero> --kind video --engine default --fill-mode fill --mute true --layer bottom
mpvpaper -l bottom -o "hwdec=vaapi loop-file=inf gamma=-5 contrast=88 saturation=79 \
  brightness=1 mute=yes video-unscaled=no panscan=1" DP-2 <fichero>

# OJO: pgrep -x skwd-wall-vk devuelve primero un ZOMBI. Filtrar por estado != Z.
# OJO: gpu_metrics es BINARIO; leerlo en modo texto falla en silencio.
# OJO: grim se cuelga con mpvpaper corriendo.
```

---

# AÑADIDO (22-sep, 16:00) — `skwd` a 30 fps frente a 144 fps

n30 objeta, con razón, que la comparación de §2 **no era justa**: `skwd` corría a 144 fps mientras
`mpvpaper` corría a 60. Aquí está la medida que faltaba, con el fichero `yellowmatrix-deepseek.mp4`
(**AV1 3440×1440 a 30 fps**, 483 fotogramas, 15,88 MB, verificado con `ffprobe`).

## 8.1 Medidas intercaladas (30 / 144 / 30 / 144 / 30 / 144)

La carga de fondo **volvió a derivar** entre tandas: la línea base pasó de 28 W a **45 W** (y el
`gpu_busy` de `skwd` a 144 fps de 6,78 a 15,09). Comparar contra las líneas base de §2 ya no valía.
Por eso esta vez **intercalé las dos configuraciones**, que cancela la deriva: la diferencia entre
ellas es válida aunque el fondo se mueva.

Línea base de referencia (`base-10`): gpu_busy 7,21 % · 44,95 W · VRAM 4229,9 MB · CPU sistema 23,87 %.

| | **30 fps** (148,6 Mpx/s) | **144 fps** (713,3 Mpx/s) | factor |
|---|---|---|---|
| **CPU** (% de 1 núcleo) | **1,00 %** (0,94–1,05) | 3,64 % (3,49–3,88) | **3,65× menos** |
| CPU (% de los 20 hilos) | **0,05 %** | 0,18 % | 3,65× |
| **RAM RSS** | 58,2 MB | 57,4 MB | **igual** (diferencia dentro del ruido) |
| VRAM | 4521 MB | 4551 MB | −30 MB |
| GPU busy (Δ sobre base) | **+3,60 pp** | +7,88 pp | 2,2× |
| **VCN media** | **7,0 %** | 36,4 % | **5,21× menos** |
| VCN mediana | 6–8 % | 27–43 % | — |
| **Potencia GPU** (Δ sobre base) | **+4,75 W** | +9,12 W | **ahorro 4,37 W** |

Dispersión entre las tres rondas: **±0,06 pp** en CPU a 30 fps y **±0,20 pp** a 144 fps. El resultado
es muy estable.

**Normalizado por trabajo hecho:**

| | 30 fps | 144 fps | quién |
|---|---|---|---|
| VCN por (Mpix/s) | **0,0470** | 0,0510 | 30 fps un 8 % mejor |
| CPU por (Mpix/s) | 0,00671 | **0,00510** | 144 fps un 32 % mejor |

O sea: **por píxel decodificado el coste es casi el mismo** (el VCN es proporcional al trabajo). El
ahorro viene de hacer **4,8× menos trabajo**, no de hacerlo mejor.

Y la CPU **no escala linealmente con los fps**, porque `skwd` tiene un coste fijo por fotograma.
Ajustando los dos puntos: `CPU% ≈ 0,305 + 0,0232 × fps`. A 0 fps `skwd` ya costaría ~0,31 % de un
núcleo (su bucle de render). Por eso bajar de 144 a 30 reduce la CPU **3,65× y no 4,8×**.

## 8.2 ¿Se nota? Medido, no opinado

n30 dice que no nota la diferencia. Lo comprobé sobre los píxeles del fichero de 30 fps:

| medida | valor |
|---|---|
| Diferencia media entre fotogramas consecutivos | **0,671 / 255** (0,26 % del rango) |
| **Mediana** de esa diferencia | **0,000** → más de la mitad del cuadro no cambia **nada** |
| Percentil 99 / 99,9 | 16,5 / 55,1 |
| **Correlación entre fotogramas consecutivos** | **r = 0,9949** |
| Correlación a 10 fotogramas (0,33 s) | r = 0,937 |
| Correlación a 39 fotogramas (1,30 s) | r = 0,798 |
| Desplazamiento global dominante por fotograma | **0 px** (en los 20 pares medidos) |

Y el dato que lo cierra, **independiente de mi análisis de píxeles**, porque lo dice el propio códec:

| fichero | fotogramas | tamaño |
|---|---|---|
| 30 fps | 483 | 15,88 MB |
| 144 fps | 2318 (4,8×) | 17,12 MB (**solo 7,8 % más**) |

**1.835 fotogramas extra aportan un 7,8 % más de bits.** El codificador, que no sabe nada de
percepción, está diciendo que esos fotogramas son casi redundantes. Eso es exactamente lo que se ve
en `r = 0,9949` y en la mediana de 0,000.

## 8.3 Recomendación

**Sí, el cambio a 30 fps tiene sentido — pero no por rendimiento, sino porque los fotogramas extra no
compran nada visible.**

- **No hay coste perceptivo medible.** La correlación entre fotogramas consecutivos es 0,9949 y la
  mitad del cuadro no cambia entre fotogramas. No hay desplazamiento global (0 px en 20 pares): el
  contenido evoluciona, pero a escala de ~1 segundo. Tu observación («no noto tanta diferencia») no es
  impresión: es lo que dicen los píxeles y el tamaño del fichero.
- **El ahorro es real pero pequeño en absoluto:** 4,37 W de GPU y 2,64 pp de un núcleo (0,13 % de la
  máquina). En un sobremesa con una 9070 XT eso es ruido de factura; cuenta si te importan el calor y
  el ventilador, no si buscas rendimiento.
- **El número grande es el VCN: 36,4 % → 7,0 %** (5,2×). Es el bloque que se calienta decodificando.
  Ese es el argumento de peso, no los vatios.
- **RAM no cambia** (58 MB los dos). Si esperabas ahorrar memoria, no está ahí.

**Lo que NO recomiendo: fabricar una versión a 60 fps como término medio.** Sería el punto que iguala
tu montaje original (que iba a 60), pero con `r = 0,9949` por fotograma y 0 px de desplazamiento, 30 fps
ya está muy por encima de lo que este contenido necesita. El término medio sería gastar el doble para
seguir sin notarse.

**Lo que sí conviene saber:** esto también significa que el pase de RIFE a 144 fps fue un esfuerzo que
este contenido concreto no aprovecha. No es un error — el fichero es un 7,8 % más grande y ya está —,
pero conviene no repetirlo para un vídeo de movimiento lento sin comprobar antes cuánto se mueve.
El método está en §8.2 y es barato: dos `ffmpeg` y una correlación.

