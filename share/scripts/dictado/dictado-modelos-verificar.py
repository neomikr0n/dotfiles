#!/usr/bin/env python3
"""dictado-modelos-verificar — comprueba que los modelos de whisper descargados son los oficiales.

Responde a "¿este fichero de 3 GB es el modelo, o está roto?". Compara cada .bin local contra el
manifiesto oficial de `ggerganov/whisper.cpp` en dos cosas, el tamaño y el sha256, y dice cuál está
en uso y cuál no lo usa nadie.

Por qué existe. El 2026-10-10 apareció un `ggml-large-v3.bin` de 2,88 GiB que tenía EXACTAMENTE el
tamaño oficial y transcribía en varios idiomas a la vez. No estaba truncado: estaba corrompido por
dentro. El tamaño no lo delata, el sha256 sí. Nadie lo había detectado porque ningún script de
dictado miraba los modelos, y la medición de WER que lo destapó fue por casualidad.

Uso:
    dictado-modelos-verificar.py
    dictado-modelos-verificar.py --dir ~/.local/share/whisper --cargar
    dictado-modelos-verificar.py --buscar
    dictado-modelos-verificar.py --json modelos.json

Opciones:
    --dir CARPETA   se puede repetir; por defecto ~/.local/share/whisper y su subcarpeta candidatos
    --buscar        busca también ggml-*.bin por todo $HOME, fuera de las carpetas de siempre, y
                    marca los duplicados por sha256. Se añadió el 2026-10-10, cuando apareció una
                    copia suelta de ggml-tiny.bin en ~/Documentos que el inventario no veía porque
                    solo miraba la carpeta de modelos
    --cargar        y también intenta cargar cada modelo con whisper-cli sobre un segundo de
                    silencio. Es la prueba definitiva, pero levanta el modelo entero en memoria, así
                    que con un large-v3 pide 3 GB y tarda. Con el sha256 ya basta para detectar
                    corrupción; esto es la red de seguridad por si el hash no se puede consultar.
    --sin-red       no consulta el manifiesto; usa la copia en caché y avisa si no la hay
    --json SALIDA   guardar el resultado en JSON
    --solo-uso      comprueba solo el modelo y el VAD que están en uso, no toda la carpeta. Es
                    más rápido porque no hashea los candidatos que no dictan
    --estricto      sale con código 1 si encuentra algún CORRUPTO. Por defecto informa y sale 0
    --servicio      modo para el arranque del servicio del servidor. Implica --solo-uso y
                    --estricto, y si no hay ni red ni caché para comparar, avisa y sale 0 en vez
                    de bloquear el arranque por un corte de red

Variable de entorno:
    DICTADO_CACHE_MODELOS   dónde vive la caché del manifiesto. Sirve para probar el caso sin
                            red y sin caché sin tocar la de verdad

Veredictos:
    OK          tamaño y sha256 coinciden con el oficial
    CORRUPTO    el nombre es oficial pero el contenido no. No se usa y no se arregla, se borra
    NO OFICIAL  el fichero no está en el manifiesto (por ejemplo el VAD de silero). Ni bien ni mal
    EN USO      lo apunta actual.bin, que es lo que dicta
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

MANIFIESTO = "https://huggingface.co/api/models/ggerganov/whisper.cpp/tree/main"
# La caché se puede mover con DICTADO_CACHE_MODELOS, para poder probar el caso "sin red y sin
# caché" sin tocar la de verdad.
CACHE = os.path.expanduser(
    os.environ.get("DICTADO_CACHE_MODELOS", "~/.cache/dictado/modelos-oficiales.json"))
CACHE_TTL = 7 * 24 * 3600          # una semana; los modelos oficiales no cambian a diario
WHISPER = os.path.expanduser("~/.local/bin/whisper-cli")
VAD = os.path.expanduser("~/.local/share/whisper/ggml-silero-v6.2.0.bin")
ES_WHISPER = re.compile(r"^ggml-(tiny|base|small|medium|large)")


def manifiesto_oficial(sin_red, tolerante=False):
    """{nombre: (tamano, sha256)} de los .bin del repositorio oficial. Se cachea en disco.

    Con tolerante=True no aborta cuando no hay ni caché ni red, devuelve None y deja que quien
    llama decida. Lo usa el modo --servicio, que prefiere arrancar sin verificar antes que dejar
    el dictado sin modelo por un corte de red.
    """
    if os.path.isfile(CACHE):
        edad = time.time() - os.path.getmtime(CACHE)
        if sin_red or edad < CACHE_TTL:
            with open(CACHE, encoding="utf-8") as f:
                return json.load(f)
    if sin_red:
        if tolerante:
            return None
        sys.exit(f"--sin-red y no hay caché en {CACHE}. Quita --sin-red una vez.")
    try:
        with urllib.request.urlopen(MANIFIESTO, timeout=30) as r:
            datos = json.load(r)
    except Exception as e:
        if os.path.isfile(CACHE):
            print(f"aviso: no se pudo consultar el manifiesto ({e}); se usa la caché", file=sys.stderr)
            with open(CACHE, encoding="utf-8") as f:
                return json.load(f)
        if tolerante:
            print(f"aviso: no se pudo consultar el manifiesto ({e}) y no hay caché", file=sys.stderr)
            return None
        sys.exit(f"no se pudo consultar el manifiesto y no hay caché: {e}")
    tabla = {}
    for e in datos:
        if e.get("path", "").endswith(".bin") and "lfs" in e:
            tabla[e["path"]] = [e["lfs"]["size"], e["lfs"]["oid"]]
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    with open(CACHE, "w", encoding="utf-8") as f:
        json.dump(tabla, f, indent=2, sort_keys=True)
    return tabla


def sha256(ruta):
    h = hashlib.sha256()
    with open(ruta, "rb") as f:
        for bloque in iter(lambda: f.read(4 * 1024 * 1024), b""):
            h.update(bloque)
    return h.hexdigest()


def recolectar(carpetas):
    """Ficheros .bin, sin repetir el mismo contenido por culpa de un enlace simbólico."""
    vistos, salida = {}, []
    for c in carpetas:
        if not os.path.isdir(c):
            continue
        for raiz, _, ficheros in os.walk(c):
            for nombre in sorted(ficheros):
                if not nombre.endswith(".bin"):
                    continue
                ruta = os.path.join(raiz, nombre)
                real = os.path.realpath(ruta)
                if real in vistos:
                    continue
                vistos[real] = True
                salida.append((ruta, real))
    return salida


def buscar_en_casa(raiz, minimo=20 * 2**20):
    """Todos los ggml-*.bin bajo $HOME, saltando la papelera y los árboles de compilación.

    El mínimo de tamaño deja fuera los for-tests-*.bin que trae el código de whisper.cpp, que son
    fixturas de medio mega y no modelos de verdad. Devuelve pares (ruta, real), como recolectar.
    """
    saltar = {os.path.expanduser("~/.local/share/Trash"), os.path.expanduser("~/.cache")}
    ignorar = {".git", "node_modules", "build", "spirv"}
    vistos, salida = {}, []
    for raiz_dir, dirs, ficheros in os.walk(raiz):
        dirs[:] = [d for d in dirs
                   if d not in ignorar and os.path.join(raiz_dir, d) not in saltar]
        for nombre in ficheros:
            if not (nombre.startswith("ggml-") and nombre.endswith(".bin")):
                continue
            ruta = os.path.join(raiz_dir, nombre)
            try:
                if os.path.getsize(ruta) < minimo:
                    continue
            except OSError:
                continue
            real = os.path.realpath(ruta)
            if real in vistos:
                continue
            vistos[real] = True
            salida.append((ruta, real))
    return salida


def probar_carga(modelo, carpeta_temp):
    """Transcribe un segundo de silencio. Devuelve None si carga, o el motivo del fallo."""
    if not os.path.isfile(WHISPER):
        return f"no encuentro {WHISPER}"
    wav = os.path.join(carpeta_temp, "silencio.wav")
    if not os.path.isfile(wav):
        if not shutil.which("sox"):
            return "falta sox para fabricar el silencio"
        subprocess.run(["sox", "-n", "-r", "16000", "-c", "1", wav, "trim", "0", "1.0"],
                       check=False, capture_output=True)
    salida = os.path.join(carpeta_temp, "carga")
    p = subprocess.run(
        [WHISPER, "-m", modelo, "-f", wav, "-l", "es", "-nt", "-np", "-otxt", "-of", salida],
        capture_output=True, text=True, errors="replace",
    )
    err = p.stderr or ""
    if "failed to initialize whisper context" in err:
        return "no pudo cargar el modelo"
    if p.returncode != 0:
        for linea in err.splitlines():
            if "error" in linea.lower():
                return linea.strip()[:90]
        return f"código de salida {p.returncode}"
    return None


def clasificar_uso(real):
    """Para qué sirve este fichero, si sirve para algo.

    Hay dos papeles, y solo el primero se nota si desaparece. Son el modelo que dicta (actual.bin) y
    el VAD que recorta silencios. Hasta el 2026-10-10 había un tercero, el respaldo ggml-medium.bin
    que usaba dictado.sh cuando no encontraba el conf; se borró porque turbo lo dominaba en error y
    en velocidad, y su papel se repuntó a actual.bin.
    """
    actual = os.path.expanduser("~/.local/share/whisper/actual.bin")
    if os.path.isfile(actual) and os.path.realpath(actual) == real:
        return "modelo"
    if os.path.isfile(VAD) and os.path.realpath(VAD) == real:
        return "vad"
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", action="append", default=None)
    ap.add_argument("--cargar", action="store_true")
    ap.add_argument("--sin-red", action="store_true")
    ap.add_argument("--buscar", action="store_true")
    ap.add_argument("--json", default=None)
    ap.add_argument("--solo-uso", action="store_true")
    ap.add_argument("--estricto", action="store_true")
    ap.add_argument("--servicio", action="store_true")
    a = ap.parse_args()

    if a.servicio:
        a.solo_uso = True
        a.estricto = True

    base = os.path.expanduser("~/.local/share/whisper")
    carpetas = a.dir or [base, os.path.join(base, "candidatos")]

    oficial = manifiesto_oficial(a.sin_red, tolerante=a.servicio)
    if oficial is None:
        print("dictado: no se pudo verificar el modelo en uso (sin red y sin caché). Arranco igual.")
        return 0
    ficheros = recolectar(carpetas)
    if a.solo_uso:
        ficheros = [(ruta, real) for ruta, real in ficheros if clasificar_uso(real)]
    if a.buscar:
        ya = {real for _, real in ficheros}
        for ruta, real in buscar_en_casa(os.path.expanduser("~")):
            if real not in ya:
                ya.add(real)
                ficheros.append((ruta, real))
    if not ficheros:
        if a.solo_uso:
            sys.exit("no encuentro el modelo en uso (actual.bin) ni el VAD")
        sys.exit(f"no hay ningún .bin en {', '.join(carpetas)}")

    carpeta_temp = tempfile.mkdtemp(prefix="verificar-modelos-")
    filas = []
    for ruta, real in ficheros:
        nombre = os.path.basename(ruta)
        tam = os.path.getsize(real)
        digest = sha256(real)
        # actual.bin es un enlace, así que su nombre no es oficial aunque su contenido sí lo sea.
        # Cuando el nombre no está en el manifiesto se prueba con el del fichero real.
        nombre_oficial = nombre if nombre in oficial else os.path.basename(real)
        esperado = oficial.get(nombre_oficial)
        if esperado is None:
            veredicto = "NO OFICIAL"
        elif tam != esperado[0] or digest != esperado[1]:
            veredicto = "CORRUPTO"
        else:
            veredicto = "OK"
        fila = {
            "fichero": ruta,
            "nombre": nombre,
            "bytes": tam,
            "sha256": digest,
            "veredicto": veredicto,
            "uso": clasificar_uso(real),
            "probado": False,
            "carga": None,
        }
        if a.cargar and ES_WHISPER.match(nombre_oficial) and veredicto != "CORRUPTO":
            fila["probado"] = True
            fila["carga"] = probar_carga(real, carpeta_temp)
        filas.append(fila)

    print(f"{'fichero':<52}{'GiB':>7}  {'papel':<10}{'carga':<7}veredicto")
    print("-" * 96)
    for f in filas:
        rel = f["fichero"].replace(os.path.expanduser("~"), "~")
        if not f["probado"]:
            carga = ""
        elif f["carga"] is None:
            carga = "OK"
        else:
            carga = "FALLA"
        print(f"{rel:<52}{f['bytes'] / 2**30:7.2f}  {f['uso']:<10}{carga:<7}{f['veredicto']}")
        if f["carga"]:
            print(f"{'':<52}{'':>7}  {'':<10}{'':<7}{f['carga']}")

    malos = [f for f in filas if f["veredicto"] == "CORRUPTO"]
    huerfanos = [f for f in filas if not f["uso"]]
    print()
    print(f"  corruptos: {len(malos)}   espacio en ellos: "
          f"{sum(f['bytes'] for f in malos) / 2**30:.2f} GiB")
    print(f"  sin papel (ni modelo ni vad): {len(huerfanos)}   espacio: "
          f"{sum(f['bytes'] for f in huerfanos) / 2**30:.2f} GiB")
    for f in huerfanos:
        print(f"    {f['fichero'].replace(os.path.expanduser('~'), '~')}   "
              f"{f['bytes'] / 2**30:.2f} GiB")

    por_hash = {}
    for f in filas:
        por_hash.setdefault(f["sha256"], []).append(f["fichero"])
    repetidos = {h: v for h, v in por_hash.items() if len(v) > 1}
    if repetidos:
        print()
        print(f"  copias repetidas (mismo sha256): {len(repetidos)}")
        for h, v in repetidos.items():
            print(f"    {h[:12]}…")
            for ruta in v:
                print(f"      {ruta.replace(os.path.expanduser('~'), '~')}")

    if malos:
        print()
        print("  Los corruptos no se arreglan: el fichero está mal por dentro. Se vuelven a bajar.")
        for f in malos:
            print(f"    {f['fichero']}")

    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(filas, f, ensure_ascii=False, indent=2)
        print(f"\nJSON en {a.json}")

    shutil.rmtree(carpeta_temp, ignore_errors=True)

    if a.servicio:
        estado = "CORRUPTO" if malos else "verificado"
        print(f"\n  servicio: modelo en uso {estado}")
    if a.estricto and malos:
        print(f"  ESTRICTO: {len(malos)} modelo(s) corrupto(s), salgo con error")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
