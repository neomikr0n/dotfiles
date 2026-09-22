# optimizar-wallpaper.md — bitácora del instrumento

Compañero de `optimizar-wallpaper.sh`. Convención del proyecto: cada script lleva su `.md` al lado.

## Qué hace

Reescribe un vídeo-wallpaper **horneando en los píxeles** lo que antes hacía mpvpaper en tiempo de
ejecución:

| opción de mpvpaper | cómo se reproduce ahora |
|---|---|
| `--gamma=-5` | exponente `1/8^(-0.05) = 1.1095694721` aplicado con `lutrgb` sobre `gbrp16le` |
| `--contrast=88` | matriz 3×3 (no diagonal) sobre `yuv→rgb` en coma flotante |
| `--saturation=79` | idem, aplicada sobre los canales Cb/Cr |
| `--brightness=1` | desplazamiento `+b` inyectado por el **canal alfa** (que vale 1.0 y no se usa) |
| `--video-unscaled=no --panscan=1` | `zscale` a 3440×1935 (bilineal) + `crop=3440:1440:0:247` |
| `--mute=yes` | `-an` (fuera la pista de audio) |

**Por qué existe:** `skwd-wall-v2` sirve el vídeo con `skwd-wall-vk` (FFmpeg + VAAPI → import a Vulkan)
y **no acepta ninguna opción de mpv**. Lo único que sí aporta es `--fill-mode fill` y `--mute true`, que
son equivalentes exactos de `--panscan=1` y `--mute=yes`. Todo lo demás hay que grabarlo en la imagen.

## Uso

```bash
optimizar-wallpaper.sh <entrada> <salida> [args del codificador...]

# ejemplos
optimizar-wallpaper.sh original.mp4 salida.mp4 \
  -c:v libsvtav1 -preset 6 -crf 26 -g 250 -pix_fmt yuv420p
optimizar-wallpaper.sh original.mp4 salida.mp4 \
  -c:v libx265 -preset medium -crf 18 -tag:v hvc1 -pix_fmt yuv420p
```

Los parámetros del ecualizador y la geometría están en las primeras líneas del script
(`EQ_BRIGHTNESS`, `EQ_CONTRAST`, `EQ_SATURATION`, `EQ_GAMMA`, `W`, `H`). Si cambia el monitor, cambian
`W` y `H`; `Hsc` y `Yoff` se recalculan solos.

## La matemática (mpv 0.41)

De `video/csputils.c`:

```
brightness = v/100          contrast = (v+100)/100
saturation = (v+100)/100    gamma    = exp(log(8)·v/100)
```

El ecualizador **no** se aplica como paso suelto: se pliega dentro de la matriz `yuv→rgb`.
`pass_convert_yuv()` (`video/out/gpu/video.c`) construye `colormatrix` + `colormatrix_c` y el shader hace
`color.rgb = mat3(colormatrix)·color.rgb + colormatrix_c`. La gamma va **después**, en
`pass_draw_to_screen()`, como `pow(color.rgb, vec3(user_gamma))` con
`user_gamma = 1/(cparams.gamma · opts.gamma)`, y **con un `clamp(0,1)` previo**.

Coeficientes BT.709 (`luma_coeffs()`): `lr,lg,lb = 0.2126,0.7152,0.0722`. Niveles: entrada limitada (tv),
salida **completa** (forzada en `video.c` cuando `vo=gpu`).

Con eso:

```
base = [[1, 0, 2(1-lr)], [1, -2(1-lb)lb/lg, -2(1-lr)lr/lg], [1, 2(1-lb), 0]]
A0   = base · diag(ymul0, cmul0, cmul0)                    # yuv→rgb normalizada
Aeq  = base · diag(ymul0·c, cmul0·c·sat, cmul0·c·sat)      # con contraste y saturación
M    = Aeq · inv(A0)
```

Y la identidad que permite meter el brillo sin tocar los canales de color: `M·1 = c·1`, así que sumar
`+b` en RGB equivale a desplazar la señal de entrada en `b/c` **antes** de la matriz. Como el
desplazamiento tiene que ser igual en los tres canales, se inyecta por el alfa (`ra=ga=ba=b/c`).

```
gamma_exp = 1/8^(-0.05) = 1.1095694721
pre       = b/c         = 0.0053191489
```

## Trampas de ffmpeg encontradas (todas costaron tiempo)

1. **`colorchannelmixer` limita los coeficientes a [-2, 2]**. `M` tiene `rr=3.049`, fuera de rango.
   Solución: aplicar `M/2` y luego un `colorchannelmixer=rr=2:gg=2:bb=2:aa=1`. El alfa hay que volver a
   fijarlo en 1 en el primer paso para que el desplazamiento `b/c/2` no se duplique.
2. **En coma flotante `colorchannelmixer` NO recorta** (blanco ×2 → 1.9923). Eso es lo que permite que el
   desplazamiento de brillo no se pierda. El recorte a `[0,1]` ocurre después, al pasar a `gbrp16le`.
3. **`lutrgb` en coma flotante no sirve**: la LUT se indexa con la vista entera 0–255, así que un valor
   cercano a 0.5 indexa la posición 0 y la operación se pierde. Funciona bien sobre `gbrp16le` con
   `pow(val/65535,exp)*65535`.
4. **`colorlevels` en coma flotante está roto** (salida basura, tamaño de bytes disparado).
5. **`zscale=w=3440:h=1935` falla**: «image dimensions must be divisible by subsampling factor» (1935 es
   impar). Hay que subir a `yuv444p16le` **antes** de escalar y recortar después.
6. **Orden de coeficientes**: hay que apilar el alfa por filas
   (`hstack([M/2, full((3,1), pre/2)])` y luego `flatten()`). Añadir los tres valores al final de la lista
   plana asigna `ra` a `rg` y `gb` y **el resultado parece casi correcto pero no lo es**.

## Geometría del `--panscan=1`

3840×2160 (16:9) en un monitor 3440×1440 (21:9). El bucle de panscan de mpv hace `floor` sobre pasos no
enteros, lo que equivale a **escalar a 3440×1935 y recortar 247 px arriba y abajo**. `Hsc = W*2160//3840`
y `Yoff = (Hsc-H)//2` lo reproducen exactamente. Barrido de desplazamiento vertical: el mínimo está en
0 px (validado contra una captura real de mpv con `--panscan=1`).

Escalador: **bilineal**. Es el `--scale` por defecto de mpv en SDR y gana a bicúbico/lanczos/spline36
contra la captura real.

## Validación

| comprobación | resultado |
|---|---|
| Cadena horneada vs render real de mpv (`vo=gpu`) a resolución nativa | **44,43 dB PSNR** (RMS 1,53/255) |
| Modelo diagonal (solo contraste) como control | 30,07 dB → confirma que la matriz no diagonal es necesaria |
| Solo ida y vuelta de códec (x264 sin pérdidas) | ≈51 dB |
| Recorte centrado: barrido de deslizamiento | mínimo en 0 px |
| **El negro sigue siendo negro** | 0 → 0, el vídeo sigue componiendo bien sobre el escritorio |

**No es error de modelo**: el residuo es el submuestreo de croma 4:2:0 en los bordes.

## Verificación después de usarlo

```bash
ffprobe -v error -show_entries stream=codec_name,profile,width,height,pix_fmt,r_frame_rate -of default=nw=1 salida.mp4
skwd-wall-vk --decode-probe salida.mp4     # ¿lo acepta la app y por qué backend?
```

`--decode-probe` informa del tiempo de decodificación por backend (cascade / vaapi / vulkan / software)
**sin tocar el escritorio**. Es la comprobación barata antes de sustituir el fichero en uso.
