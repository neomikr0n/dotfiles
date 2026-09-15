#!/usr/bin/env bash
#
# batch.sh — despliegue de dotfiles para una instalación nueva
#
# QUÉ HACE:
#   Coloca cada archivo/carpeta de ESTA carpeta (el .config del repo de
#   dotfiles) en su ubicación real dentro de $HOME, aunque el archivo
#   esté suelto en la raíz del .config del repo (p. ej. "Xresources"
#   acaba en ~/.Xresources, "environment.d" acaba en ~/.config/environment.d).
#
# USO EN INSTALACIÓN NUEVA:
#   1. clona el repo:      git clone <tu-repo> ~/dotfiles
#   2. corre el script:    bash ~/dotfiles/.config/batch.sh
#
# Es idempotente: se puede correr varias veces sin romper nada.
# Para agregar más archivos, añade una entrada a COPIAR o ENLAZAR abajo.
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # raíz del repo
CFG="$REPO/.config"                                       # este .config

# --- COPIAR: "archivo_en_repo:ruta_real_destino" --------------------------
# Se copia el archivo a su ubicación final.
COPIAR=(
  "Xresources:$HOME/.Xresources"
)

# --- ENLAZAR (symlink): "carpeta_en_repo:ruta_real_destino" ---------------
# La ruta real se reemplaza por un symlink a la copia del repo, así que
# editar el archivo aquí aplica directo en el sistema.
ENLAZAR=(
  "environment.d:$HOME/.config/environment.d"
)

echo "== Desplegando dotfiles desde $CFG =="

for entrada in "${COPIAR[@]}"; do
  origen="$CFG/${entrada%%:*}"
  destino="${entrada#*:}"
  if [[ ! -e "$origen" ]]; then
    echo "  [aviso] no existe $origen, se omite" >&2
    continue
  fi
  mkdir -p "$(dirname "$destino")"
  cp -v "$origen" "$destino"
done

for entrada in "${ENLAZAR[@]}"; do
  origen="$CFG/${entrada%%:*}"
  destino="${entrada#*:}"
  if [[ ! -e "$origen" ]]; then
    echo "  [aviso] no existe $origen, se omite" >&2
    continue
  fi
  if [[ -L "$destino" && "$(readlink "$destino")" == "$origen" ]]; then
    echo "  [ok] symlink ya correcto: $destino -> $origen"
    continue
  fi
  if [[ -L "$destino" ]]; then
    rm -v "$destino"
  elif [[ -e "$destino" ]]; then
    # conserva el contenido actual por si difiere del repo
    mv -v "$destino" "$destino.bak.$(date +%Y%m%d%H%M%S)"
  fi
  mkdir -p "$(dirname "$destino")"
  ln -sv "$origen" "$destino"
done

echo "== Listo. Cierra sesión o reinicia para que el entorno tome los cambios =="
