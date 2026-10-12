#!/usr/bin/env python3
"""dictado-normalizar-medir — mide, sobre el corpus ya transcrito, dos capas candidatas.

Las mejoras 5 y 9 de la autocritica piden lo mismo antes de escribir codigo de produccion:
medir sobre el corpus cuanto error quita cada una. Este medidor hace esa cuenta, y ademas
cuenta los falsos positivos, que es lo que decide si una capa se puede encender o no.

NO transcribe nada. Lee las hipotesis que ya estan guardadas en
informes/dictado-modelos-medidas.json y las pasa por cada capa. El error se calcula con
normalizar() y wer() de dictado-bench.py, importadas y no reimplementadas. Un medidor
paralelo ya dio cifras distintas una vez (14/16/12/16 frente a 15/16/12/17) y no se repite.

Las dos capas:

  correccion   cambia una palabra rara por el termino de vocabulario mas cercano, por
               distancia de edicion, solo si la palabra no esta en un diccionario general
  normalizacion  escribe de una sola forma los numeros y las unidades

Uso:
    dictado-normalizar-medir.py [--modelo NOMBRE] [--json RUTA] [--coste] [--detalle]

Por defecto:
    --modelo  ggml-large-v3-turbo.bin
    --json    informes/dictado-modelos-medidas.json

El diccionario general en español es el hunspell que ya trae el runtime de Flatpak de GNOME,
en disco, sin descargar nada. La guarda inglesa es /usr/share/dict/cracklib-small, que es una
lista de contrasenas y solo se usa como tope basto para que las palabras inglesas no se toquen.
"""

import argparse
import glob
import importlib.util
import json
import os
import re
import subprocess
import sys
import time

DIR = os.path.dirname(os.path.abspath(__file__))
JSON_DEF = os.path.join(DIR, "informes", "dictado-modelos-medidas.json")
MODELO_DEF = "ggml-large-v3-turbo.bin"

PATRON_HUNSPELL = ("/var/lib/flatpak/runtime/org.gnome.Platform.Locale/x86_64/*/*-es/"
                   "files/es/share/es/hunspell/es_ES.dic")
RUTA_CRACKLIB = "/usr/share/dict/cracklib-small"


# ---------------------------------------------------------------- banco

def cargar_banco():
    spec = importlib.util.spec_from_file_location("bench", os.path.join(DIR, "dictado-bench.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


BENCH = cargar_banco()


# ---------------------------------------------------------------- diccionarios

def diccionario_espanol():
    """Hunspell anota banderas tras una barra, y la primera linea es el recuento."""
    hits = sorted(glob.glob(PATRON_HUNSPELL))
    if not hits:
        return set()
    palabras = set()
    with open(hits[-1], encoding="utf-8", errors="replace") as f:
        for i, linea in enumerate(f):
            if i == 0:
                continue
            w = linea.strip().split("/")[0].strip().lower()
            if w:
                palabras.add(w)
    return palabras


def guarda_inglesa():
    palabras = set()
    try:
        with open(RUTA_CRACKLIB, encoding="utf-8", errors="replace") as f:
            for linea in f:
                w = linea.strip().lower()
                if w:
                    palabras.add(w)
    except OSError:
        pass
    return palabras


# ---------------------------------------------------------------- vocabulario

def leer_vocabulario():
    ruta = os.path.join(DIR, "dictado-vocabulario.txt")
    for linea in open(ruta, encoding="utf-8"):
        m = re.match(r'DICTADO_VOCABULARIO="(.*)"\s*$', linea.strip())
        if m:
            return [t.strip() for t in m.group(1).split(",") if t.strip()]
    return []


def palabras_objetivo(terminos):
    """Un termino de varias palabras aporta cada palabra suelta como objetivo."""
    fuera = []
    for t in terminos:
        for p in re.split(r"\s+", t):
            p = p.strip(".,;:")
            if p and p.lower() not in [x.lower() for x in fuera]:
                fuera.append(p)
    return fuera


# ---------------------------------------------------------------- alineacion

def alinear(r, h):
    """Alineacion palabra a palabra, con la misma distancia que usa el WER."""
    n, m = len(r), len(h)
    d = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        d[i][0] = i
    for j in range(m + 1):
        d[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1,
                          d[i - 1][j - 1] + (r[i - 1] != h[j - 1]))
    ops = []
    i, j = n, m
    while i > 0 or j > 0:
        if i > 0 and j > 0 and d[i][j] == d[i - 1][j - 1] + (r[i - 1] != h[j - 1]):
            ops.append(("=" if r[i - 1] == h[j - 1] else "S", r[i - 1], h[j - 1]))
            i -= 1
            j -= 1
        elif i > 0 and d[i][j] == d[i - 1][j] + 1:
            ops.append(("D", r[i - 1], ""))
            i -= 1
        else:
            ops.append(("I", "", h[j - 1]))
            j -= 1
    return list(reversed(ops))


# ---------------------------------------------------------------- capa 5

def corregir(texto, objetivos, filtro, tope):
    """Devuelve (texto_corregido, cambios). Un cambio es (original, nuevo, distancia)."""
    salida, cambios = [], []
    for tok in re.split(r"(\W+)", texto):
        if not tok or not tok.isalpha():
            salida.append(tok)
            continue
        bajo = tok.lower()
        if filtro is not None and bajo in filtro:
            salida.append(tok)
            continue
        mejor, dist = None, tope + 1
        for o in objetivos:
            d = BENCH.levenshtein(bajo, o.lower())
            if d < dist:
                mejor, dist = o, d
        if mejor is not None and dist <= tope and mejor.lower() != bajo:
            cambios.append((bajo, mejor, dist))
            salida.append(mejor)
        else:
            salida.append(tok)
    return "".join(salida), cambios


# ---------------------------------------------------------------- capa 9

UNIDADES = [
    (re.compile(r"(\d)\s*%"), r"\1 por ciento"),
    (re.compile(r"(\d)\s*km/h"), r"\1 kilometros por hora"),
]

UNI = ["", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
       "diez", "once", "doce", "trece", "catorce", "quince", "dieciseis", "diecisiete",
       "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidos", "veintitres",
       "veinticuatro", "veinticinco", "veintiseis", "veintisiete", "veintiocho",
       "veintinueve"]
DEC = {30: "treinta", 40: "cuarenta", 50: "cincuenta", 60: "sesenta", 70: "setenta",
       80: "ochenta", 90: "noventa"}
CENT = {100: "ciento", 200: "doscientos", 300: "trescientos", 400: "cuatrocientos",
        500: "quinientos", 600: "seiscientos", 700: "setecientos", 800: "ochocientos",
        900: "novecientos"}


def numero_a_palabras(n):
    if n < 30:
        return UNI[n]
    if n < 100:
        d, u = divmod(n, 10)
        return DEC[d * 10] + (" y " + UNI[u] if u else "")
    if n < 1000:
        c, r = divmod(n, 100)
        base = "cien" if (c == 1 and r == 0) else CENT[c * 100]
        return base + (" " + numero_a_palabras(r) if r else "")
    if n < 1000000:
        m, r = divmod(n, 1000)
        base = "mil" if m == 1 else numero_a_palabras(m) + " mil"
        return base + (" " + numero_a_palabras(r) if r else "")
    return str(n)


def simbolos_a_palabras(t):
    for rx, rep in UNIDADES:
        t = rx.sub(rep, t)
    return t


def digitos_a_palabras(t):
    return re.sub(r"\b(\d+)\b", lambda m: numero_a_palabras(int(m.group(1))), t)


# ---------------------------------------------------------------- medidas

def cargar_detalle(ruta_json, modelo):
    datos = json.load(open(ruta_json, encoding="utf-8"))
    filas = [r for r in datos if r.get("modelo") == modelo]
    if not filas:
        disponibles = ", ".join(str(r.get("modelo")) for r in datos)
        raise SystemExit(f"no hay fila para {modelo!r}. Hay: {disponibles}")
    return filas[0]["detalle"]


def total_palabras(detalle):
    return sum(len(BENCH.normalizar(x["ref"]).split()) for x in detalle)


def errores_base(detalle):
    return sum(BENCH.wer(x["ref"], x["texto"])[1] for x in detalle)


def medir_corrector(detalle, objetivos, filtro, tope, total):
    err, aciertos, falsos = 0, 0, 0
    for x in detalle:
        corr, cambios = corregir(x["texto"], objetivos, filtro, tope)
        err += BENCH.wer(x["ref"], corr)[1]
        refpal = set(BENCH.normalizar(x["ref"]).split())
        for a, _b, _d in cambios:
            if a in refpal:
                falsos += 1
            else:
                aciertos += 1
    return err, aciertos, falsos


def medir_normalizador(detalle, fn):
    return sum(BENCH.wer(x["ref"], fn(x["texto"]))[1] for x in detalle)


def medir_coste(detalle, objetivos, filtro):
    """Coste de una pasada, en un proceso hijo, para que cuente tambien el arranque."""
    # El hijo no puede importar este fichero, porque su nombre lleva guiones, asi que la carga
    # de diccionarios se mide con un guion minimo propio dentro del proceso hijo.
    guion = os.path.join("/tmp", "dictado-normalizar-coste.py")
    codigo = (
        "import glob,time\n"
        "t0=time.perf_counter()\n"
        "s=set()\n"
        f"p=sorted(glob.glob({PATRON_HUNSPELL!r}))[-1]\n"
        "f=open(p,encoding='utf-8',errors='replace')\n"
        "next(f)\n"
        "for l in f:\n"
        "    w=l.strip().split('/')[0].strip().lower()\n"
        "    if w: s.add(w)\n"
        f"g=set(open({RUTA_CRACKLIB!r},encoding='utf-8',errors='replace'))\n"
        "t1=time.perf_counter()\n"
        "print(f'{(t1-t0)*1000:.1f} {len(s)} {len(g)}')\n"
    )
    with open(guion, "w", encoding="utf-8") as f:
        f.write(codigo)
    tiempos = []
    for _ in range(10):
        t = time.perf_counter()
        r = subprocess.run([sys.executable, guion], capture_output=True, text=True)
        tiempos.append((time.perf_counter() - t) * 1000)
        interno = r.stdout.strip().split()[0]
    tiempos.sort()
    return tiempos[len(tiempos) // 2], float(interno)


# ---------------------------------------------------------------- principal

def main():
    ap = argparse.ArgumentParser(description="Mide las capas de correccion y normalizacion.")
    ap.add_argument("--json", default=JSON_DEF)
    ap.add_argument("--modelo", default=MODELO_DEF)
    ap.add_argument("--coste", action="store_true", help="mide tambien la latencia de la capa")
    ap.add_argument("--detalle", action="store_true", help="desglosa los errores uno a uno")
    a = ap.parse_args()

    detalle = cargar_detalle(a.json, a.modelo)
    terminos = leer_vocabulario()
    objetivos = palabras_objetivo(terminos)
    es = diccionario_espanol()
    en = guarda_inglesa()

    total = total_palabras(detalle)
    base = errores_base(detalle)

    print(f"modelo {a.modelo}")
    print(f"muestras {len(detalle)}   palabras {total}")
    print(f"vocabulario {len(terminos)} terminos, {len(objetivos)} palabras objetivo")
    print(f"diccionario es {len(es)} palabras   guarda inglesa {len(en)} palabras")
    print()
    print(f"base: {base} errores ({base/total*100:.1f} %)")

    if a.detalle:
        print("\n--- errores uno a uno ---")
        for x in detalle:
            r = BENCH.normalizar(x["ref"]).split()
            h = BENCH.normalizar(x["texto"]).split()
            malas = [o for o in alinear(r, h) if o[0] != "="]
            if malas:
                print(f"  {x['muestra']} ({len(malas)} de {len(r)})")
                for op, u, v in malas:
                    print(f"      {({'S': 'sust', 'D': 'omis', 'I': 'inse'}[op])}  {u!r} -> {v!r}")

    print("\n=== mejora 5: correccion por distancia de edicion ===")
    print(f"  {'filtro':16} {'tope':>4} {'errores':>8} {'aciertos':>9} {'falsos':>7}")
    for etq, filtro in (("sin filtro", None), ("espanol", es), ("espanol+ingles", es | en)):
        for tope in (1, 2):
            err, ac, fa = medir_corrector(detalle, objetivos, filtro, tope, total)
            print(f"  {etq:16} {tope:>4} {err:>8} {ac:>9} {fa:>7}")

    print("\n=== mejora 9: numeros y unidades ===")
    for etq, fn in (("simbolos a palabras", simbolos_a_palabras),
                    ("digitos a palabras", digitos_a_palabras),
                    ("las dos", lambda t: digitos_a_palabras(simbolos_a_palabras(t)))):
        err = medir_normalizador(detalle, fn)
        marca = "MEJORA" if err < base else ("EMPEORA" if err > base else "igual")
        print(f"  {etq:20} {err:>3} errores ({err/total*100:4.1f} %)  {marca}")

    if a.coste:
        ms, interno = medir_coste(detalle, objetivos, es)
        print("\n=== coste de una pasada (mediana de 10, proceso hijo entero) ===")
        print(f"  proceso completo {ms:.0f} ms   dentro del proceso {interno:.0f} ms")
        print("  la ruta de datos del portapapeles mide 3,3 ms, asi que la capa la multiplica")
    return 0


if __name__ == "__main__":
    sys.exit(main())
