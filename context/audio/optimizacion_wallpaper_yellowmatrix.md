# Optimización del wallpaper `yellowmatrix.mp4`

**Fecha:** 21 de septiembre de 2026
**Objetivo:** que `skwd-wall-v2` reproduzca el vídeo con las mismas características visuales que
producía `mpvpaper`, grabándolas en los píxeles.

---

## 1. Resumen

| | Antes | Ahora |
|---|---|---|
| Fichero | `yellowmatrix.mp4` | `yellowmatrix.mp4` |
| Códec | H.264 High | **AV1 Main** |
| Resolución | 3840×2160 (16:9) | **3440×1440 (nativa del monitor)** |
| Cadencia | 60 fps | **30 fps** |
| Fotogramas | 967 | 483 |
| Duración | 16,1 s | 16,1 s |
| Peso | 29 918 020 B (30 MB) | **15 878 484 B (15,9 MB)** |
| Bitrate | 14,87 Mbps | **7,89 Mbps** |

**Reducción de peso: 46,9 %.** El ecualizador y el encuadre de `mpvpaper` van ahora **grabados en la
imagen**; no dependen de ninguna opción de reproducción.

`yellowmatrix-original.mp4` **no se ha tocado**: md5 `5b8b550e2283fe9e21149c098264dac6`, idéntico al
del principio y al final del proceso.

---

## 2. Los dos hallazgos

### 2.1 El vídeo original no era realmente de 60 fps

El contenedor declara 60 fps, pero **el contenido es de 30 fps duplicado**. Tres mediciones
independientes lo confirman:

| Prueba | Resultado | Lectura |
|---|---|---|
| Remuestrear a 30 fps y volver a 60, y comparar con el original | **PSNR 62,99 dB** | los fotogramas impares son copias de los pares |
| Autocorrelación lag-1 de la curva de movimiento | **−0,71** | el movimiento alterna fuerte/débil |
| Variación total: 60 fps vs 30 fps | razón **1,077** | los impares solo aportan el 7,7 % del movimiento |

Con 63 dB de similitud, los fotogramas descartados no llevan información: **no se pierde nada visible
al codificar a 30 fps.** Esto encaja con que solo 117 de 967 fotogramas fueran duplicados *exactos* —
el resto son casi-duplicados que el codificador anterior ya estaba gastando bits en almacenar.

### 2.2 A igual tamaño, 30 fps da mucha más calidad

Comparación justa (misma referencia sin pérdidas, decimada a 30 fps para las dos variantes):

| Variante | Peso proyectado a 16,1 s | PSNR |
|---|---|---|
| **30 fps, CRF 26** | **13,3 MB** | **47,92 dB** |
| 60 fps, CRF 30 | 14,0 MB | 42,22 dB |
| **30 fps, CRF 24** *(el elegido)* | **15,9 MB** (real) | **48,51 dB** |

A igual tamaño, **5,7 dB de diferencia**. El motivo es aritmético: a 60 fps hay el doble de
fotogramas, así que con el mismo presupuesto cada uno recibe la mitad de bits — y la mitad de esos
fotogramas no aporta información nueva.

---

## 3. Qué se grabó en los píxeles

Las opciones de `mpvpaper` y su equivalente permanente:

| Opción de mpvpaper | Cómo queda ahora |
|---|---|
| `--gamma=-5` | exponente `1/8^(-0.05) = 1.1095694721` aplicado con `lutrgb` sobre 16 bits |
| `--contrast=88` | matriz 3×3 **no diagonal** sobre la conversión YUV→RGB |
| `--saturation=79` | la misma matriz, sobre los canales Cb/Cr |
| `--brightness=1` | desplazamiento `+b/c` inyectado por el canal alfa |
| `--video-unscaled=no --panscan=1` | `zscale` a 3440×1935 (bilineal) + `crop=3440:1440:0:247` |
| `--mute=yes` | `-an`, sin pista de audio |

`skwd-wall-vk` no acepta ninguna opción de mpv, pero su `--fill-mode fill` es el equivalente exacto de
`--panscan=1` y su `--mute true` el de `--mute=yes`. Como el vídeo ya viene recortado a la relación del
monitor, `fill` pasa a ser una operación nula: mismo resultado.

La derivación de la matriz está en `share/scripts/optimizar-wallpaper.md`, junto al script
`share/scripts/optimizar-wallpaper.sh`, que rehace todo el proceso.

---

## 4. Validación

| Comprobación | Resultado | Confianza |
|---|---|---|
| **Modelo del ecualizador** vs render real de mpv (`vo=gpu`), mismo encuadre, sin escalado | **46,67 dB** (R 48,25 · G 45,77 · B 46,37) | alta |
| Control negativo: modelo solo diagonal (contraste sin matriz cruzada) | 30,07 dB | alta |
| Barrido del multiplicador de saturación | óptimo en el valor derivado (1,00); cualquier desvío empeora | alta |
| **Encuadre**: barrido de desplazamiento contra captura real de `--panscan=1` | mínimo en **dx=0, dy=0** | alta |
| Escalador: bilineal vs bicúbico / lanczos / spline36 | bilineal gana (es el `--scale` por defecto de mpv) | alta |
| **Pérdida del códec** (segmento, contra referencia sin pérdidas) | 48,51 dB | alta |
| **Extremo a extremo** vs captura del render de mpv | 36,25 dB, error medio 1,44/255 | media |
| La captura X11 es fiable | control sin ecualizador: desvío de 0,1/255 | alta |
| **La app acepta el fichero** (`--decode-probe`) | los 6 backends: `accepted` | alta |
| Decodificación por hardware | VAAPI ~4,5 ms/fotograma (presupuesto a 30 fps: 33 ms) | alta |

**Sobre el 36,25 dB de extremo a extremo:** no es error del modelo. Se descompone así: 46,67 dB es la
fidelidad del ecualizador; el reescalado bilineal 3840→3440 (no entero) y el códec bajan el conjunto a
~37 dB, y el resto es que la referencia es una **captura de pantalla** por X11, no el búfer real de mpv.
Queda un residuo de croma (media de verde 1,1/255 más baja, azul 0,5 más alta) que viene del
submuestreo 4:2:0 combinado con el recorte del ecualizador, no del códec: **está idéntico en la cadena
sin pérdidas**.

---

## 5. Estado en el sistema

- **Sustituido** `yellowmatrix.mp4` mediante copia a nombre temporal y `mv` atómico (nunca hubo un
  fichero a medio escribir en la carpeta).
- La app **reanalizó el fichero sola**: su base de datos ya muestra `15878484` bytes y 3440×1440.
- **Reaplicado en caliente** con `skwd-helm apply video:yellowmatrix.mp4`. El registro confirma:
  ```
  swap to .../yellowmatrix.mp4 (0ms, style None, effect None)
  swap complete
  86400 frames, 30.5 video fps     ← antes marcaba 57.9
  ```
- Sin errores. El aviso `lazy hybrid NV12 unavailable` es **preexistente** (aparece en todos los
  arranques anteriores), no lo provoca el cambio.

---

## 6. Cómo deshacerlo o rehacerlo

**Volver al original** (el respaldo está intacto):

```bash
cp ~/dotfiles/share/wallpapers/yellowmatrix-original.mp4 \
   ~/dotfiles/share/wallpapers/yellowmatrix.mp4
skwd-helm apply video:yellowmatrix.mp4
```

**Rehacer la optimización** (si cambia el monitor o el ecualizador):

```bash
PRE_FILTRO=fps=30 ~/dotfiles/share/scripts/optimizar-wallpaper.sh \
  ~/dotfiles/share/wallpapers/yellowmatrix-original.mp4 \
  /tmp/yellowmatrix.mp4 \
  -c:v libsvtav1 -preset 6 -crf 24 -g 125 -pix_fmt yuv420p
```

**Si se prefiere conservar los 60 fps** (a costa de ~2,7 MB más y 5,7 dB menos de calidad):

```bash
~/dotfiles/share/scripts/optimizar-wallpaper.sh \
  ~/dotfiles/share/wallpapers/yellowmatrix-original.mp4 \
  /tmp/yellowmatrix60.mp4 \
  -c:v libsvtav1 -preset 6 -crf 28 -g 250 -pix_fmt yuv420p
```

**Otras opciones de códec medidas**, si se quisiera más compatibilidad que AV1:

| Códec | Ajustes | Peso (16,1 s) | PSNR | VAAPI |
|---|---|---|---|---|
| H.264 | libx264 slow CRF 17 | 26,6 MB | ~45,1 dB | 23,2 ms |
| HEVC | libx265 medium CRF 20 | 18,1 MB | ~44,9 dB | 8,8 ms |
| **AV1** | **libsvtav1 preset 6 CRF 24** | **15,9 MB** | **48,5 dB** | **4,5 ms** |

AV1 gana en peso **y** en velocidad de decodificación, y la GPU (RX 9070 XT) lo acelera por hardware.

---

## 7. Avisos

- **La cadencia es el único punto donde el fichero no es literalmente idéntico al original.** La
  evidencia de que el contenido ya era de 30 fps es fuerte (62,99 dB), pero es una afirmación sobre
  *contenido*, no sobre el contenedor. Si al verlo en movimiento se notara algo raro, la sección 6 tiene
  el comando para volver a 60 fps.
- El **grosor del respaldo**: `yellowmatrix-original.mp4` es la única copia intacta. Conviene no
  borrarlo mientras no se esté seguro del resultado.
- Las cifras de PSNR/SSIM **no capturan bien este contenido** (89 % de píxeles oscuros, distorsión
  concentrada en bordes): entre CRF 22 y 34 el PSNR apenas se mueve (43,5 → 42,7 dB) mientras el peso
  cae un 59 %. La elección de CRF se hizo por peso y por inspección del error por píxel
  (error medio ~0,9/255), no por la métrica global.
