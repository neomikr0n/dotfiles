#!/bin/bash
# ---------------------------------------------------------------------------
# Optimiza un video-wallpaper horneando el ecualizador de mpv en los píxeles.
#
# Replica exactamente la ruta gl_video de mpv (la que usa mpvpaper via vo=libmpv)
# para:  --gamma=-5 --contrast=88 --saturation=79 --brightness=1
#        --video-unscaled=no --panscan=1  (rellenar recortando, centrado)
#
# uso: optimizar-wallpaper.sh <entrada> <salida> [args del codificador...]
# ---------------------------------------------------------------------------
set -euo pipefail

IN="$1"; shift
OUT="$1"; shift

# --- parámetros del ecualizador (deben coincidir con la línea de mpvpaper) ---
EQ_BRIGHTNESS=1.0
EQ_CONTRAST=88.0
EQ_SATURATION=79.0
EQ_GAMMA=-5.0

# --- geometría de destino (monitor DP-2) ---
W=3440
H=1440

# --- cadena de color: calculada a partir de video/csputils.c de mpv 0.41 ---
FILTRO=$(python3 - "$EQ_BRIGHTNESS" "$EQ_CONTRAST" "$EQ_SATURATION" "$EQ_GAMMA" "$W" "$H" <<'PY'
import sys, numpy as np
b_, c_, s_, g_ = (float(x) for x in sys.argv[1:5])
W, H = int(sys.argv[5]), int(sys.argv[6])

b = b_ / 100.0
c = (c_ + 100) / 100.0
sat = (s_ + 100) / 100.0
g_eq = float(np.exp(np.log(8.0) * g_ / 100.0))   # mpv: gamma = 8^(v/100)
exp_gamma = 1.0 / g_eq                           # shader: pow(color, 1/gamma)

lr, lg, lb = 0.2126, 0.7152, 0.0722
base = np.array([[1.0, 0.0, 2*(1-lr)],
                 [1.0, -2*(1-lb)*lb/lg, -2*(1-lr)*lr/lg],
                 [1.0, 2*(1-lb), 0.0]])
s = 1.0/255.0
ymin, ymax, cmax, cmid = 16*s, 235*s, 240*s, 128*s
ymul0, cmul0 = 1.0/(ymax-ymin), 0.5/(cmax-cmid)

A0 = base.copy(); A0[:,0] *= ymul0; A0[:,1] *= cmul0; A0[:,2] *= cmul0
Aeq = base.copy()
Aeq[:,1] *= sat; Aeq[:,2] *= sat
Aeq[:,0] *= ymul0*c; Aeq[:,1] *= cmul0*c; Aeq[:,2] *= cmul0*c
M = Aeq @ np.linalg.inv(A0)
pre = b / c                                     # M*1 = c*1  =>  desplazamiento previo

rows = ["rr","rg","rb","ra","gr","gg","gb","ga","br","bg","bb","ba"]
H4 = np.hstack([M/2.0, np.full((3,1), pre/2.0)])
mix1 = ":".join("%s=%.9f" % (k,v) for k,v in zip(rows, H4.flatten().tolist())) + ":aa=1"

# altura de escalado exacta 16:9 -> W*9/16 ; el recorte centrado deja H
Hsc = W * 2160 // 3840
Yoff = (Hsc - H) // 2

f = [
  # 1) subir el croma a 4:4:4 y 16 bits (sin redimensionar) para poder escalar
  "zscale=matrixin=bt709:rangein=limited:matrix=bt709:range=limited:"
  "transferin=bt709:transfer=bt709:primariesin=bt709:primaries=bt709:dither=none",
  "format=yuv444p16le",
  # 2) escalado al ancho del monitor manteniendo 16:9 exacto
  "zscale=w=%d:h=%d:filter=bilinear:dither=none" % (W, Hsc),
  # 3) recorte centrado = lo que hace --panscan=1
  "crop=%d:%d:0:%d" % (W, H, Yoff),
  # 4) YUV -> RGB en coma flotante (rango completo)
  "zscale=matrixin=bt709:rangein=limited:matrix=bt709:range=full:"
  "transferin=bt709:transfer=bt709:primariesin=bt709:primaries=bt709:dither=none",
  "format=gbrapf32le",
  # 5) matriz del ecualizador (mitad, para respetar el límite [-2,2]) + brillo por alfa
  "colorchannelmixer=" + mix1,
  "colorchannelmixer=rr=2:gg=2:bb=2:aa=1",
  # 6) a 16 bits enteros: aquí ocurre el recorte a [0,1] previo a la gamma
  "format=gbrp16le",
  # 7) gamma final del ecualizador
  "lutrgb=r='pow(val/65535,%.10f)*65535':g='pow(val/65535,%.10f)*65535':b='pow(val/65535,%.10f)*65535'"
  % (exp_gamma, exp_gamma, exp_gamma),
  # 8) vuelta a YUV 4:2:0 rango limitado bt709
  "zscale=matrixin=bt709:rangein=full:matrix=bt709:range=limited:"
  "transferin=bt709:transfer=bt709:primariesin=bt709:primaries=bt709:dither=none",
  "format=yuv420p",
]
print(",".join(f))
PY
)

# --- filtros opcionales ------------------------------------------------------
# PRE_FILTRO  se aplica ANTES de la cadena (barato: menos fotogramas que procesar).
#             Ej.: PRE_FILTRO=fps=30  -> decima a 30 fps antes de todo lo demás.
# POST_FILTRO se aplica DESPUÉS de la cadena.
if [ -n "${PRE_FILTRO:-}" ];  then FILTRO="$PRE_FILTRO,$FILTRO";  fi
if [ -n "${POST_FILTRO:-}" ]; then FILTRO="$FILTRO,$POST_FILTRO"; fi

echo "== cadena de filtros =="
echo "$FILTRO"
echo
echo "== codificando -> $OUT =="
ffmpeg -hide_banner -v warning -stats -i "$IN" \
  -vf "$FILTRO" -an \
  -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
  -movflags +faststart \
  "$@" -y "$OUT"
echo
ls -la "$OUT"
ffprobe -v error -show_entries format=duration,size,bit_rate:stream=codec_name,profile,width,height,pix_fmt,avg_frame_rate,nb_frames -of default=nw=0 "$OUT"
