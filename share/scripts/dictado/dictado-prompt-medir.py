#!/usr/bin/env python3
"""dictado-prompt-medir — compara variantes del vocabulario de dictado (--prompt) midiendo el WER.

Responde a "¿mejora la lista si añado o quito estas palabras?". No cambia nada por su cuenta, solo
mide y dice qué variante gana y con qué margen.

Por qué existe este script y no vale un bucle suelto. El WER tiene que salir de `normalizar()` y
`wer()` de dictado-bench.py, importadas, no de una reimplementación paralela. Medido el 2026-10-10:
un arnés propio que quitaba los acentos y no unía los dígitos separados por espacio daba 14, 16, 12 y
16 errores donde el banco da 15, 16, 12 y 17, porque «lánzame» contra «lanzame» cuenta como error si
se conservan los acentos. Se escribió un informe entero con las cifras equivocadas antes de notarlo.

Uso:
    dictado-prompt-medir.py --variantes base=dictado-vocabulario.txt ampliada=/tmp/x.txt vacio

Cada variante es `etiqueta=RUTA_DEL_PROMPT`, o la palabra `vacio` para no pasar prompt ninguno.
Con `--base ETIQUETA` se elige la variante de referencia para la comprobación de dominancia.

Opciones:
    --dir CARPETA      corpus de pares <nombre>.wav + <nombre>.txt   (por defecto el del proyecto)
    --modelo RUTA      modelo ggml                                   (por defecto actual.bin)
    --sin-vad          quitar el VAD de silero
    --repetir N        pasadas completas para comprobar determinismo (por defecto 1)
    --base ETIQUETA    variante de referencia para la dominancia
    --json SALIDA      guardar la medición en JSON
    --detalle          imprimir el par «se dijo / obtuvo» de cada error

Criterio que aplica, y que conviene entender antes de mirar la tabla. El total no decide. Una
variante que baja el total empeorando alguna frase es un intercambio, no una mejora. Lo que decide es
la dominancia frase por frase, que es lo que este script comprueba y reporta al final.
"""

import argparse
import glob
import importlib.util
import json
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
BANCO = os.path.join(AQUI, "dictado-bench.py")

# El fichero de vocabulario del proyecto no es un prompt suelto, es un script de shell con los
# comentarios delante y una asignación al final. Si se le pasa el fichero tal cual, hay que quedarse
# con el VALOR de la variable y no con las 4770 letras del fichero entero.
RE_VAR = re.compile(r'^\s*DICTADO_VOCABULARIO="([^"]*)"\s*$', re.MULTILINE)


def cargar_banco():
    """Importa dictado-bench.py como módulo para reutilizar su normalización y su WER."""
    if not os.path.isfile(BANCO):
        sys.exit(f"no encuentro el banco del proyecto en {BANCO}")
    spec = importlib.util.spec_from_file_location("dictado_bench", BANCO)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def parsear_variantes(items):
    """`etiqueta=RUTA`, `RUTA` suelta (etiqueta = nombre sin extensión) o `vacio`."""
    variantes = []
    vistas = set()
    for it in items:
        if it == "vacio":
            etq, ruta = "vacio", None
        elif "=" in it:
            etq, ruta = it.split("=", 1)
        else:
            etq, ruta = os.path.splitext(os.path.basename(it))[0], it
        if etq in vistas:
            sys.exit(f"etiqueta repetida: {etq}")
        vistas.add(etq)
        if ruta is not None and not os.path.isfile(ruta):
            sys.exit(f"no existe el fichero de prompt de «{etq}»: {ruta}")
        variantes.append((etq, ruta))
    return variantes


def leer_prompt(ruta):
    """El prompt tal cual, sin el salto de línea final. None para la variante sin prompt.

    Acepta dos formas de fichero. Un prompt suelto, que se usa entero, y el vocabulario del
    proyecto, que es un script de shell y del que solo interesa el valor de la variable.
    """
    if ruta is None:
        return None
    with open(ruta, encoding="utf-8") as f:
        contenido = f.read()
    m = RE_VAR.search(contenido)
    return m.group(1) if m else contenido.strip()


def cargar_muestras(carpeta):
    muestras = []
    for wav in sorted(glob.glob(os.path.join(carpeta, "*.wav"))):
        ref = wav[:-4] + ".txt"
        if not os.path.isfile(ref):
            continue
        with open(ref, encoding="utf-8") as f:
            muestras.append((os.path.basename(wav)[:-4], wav, f.read().strip()))
    return muestras


def medir(bench, variantes, muestras, modelo, con_vad, repetir):
    """Devuelve {etiqueta: [pasada, ...]} y cada pasada es {nombre: (errores, palabras, hipotesis)}."""
    salida = "/tmp/prompt-medir-out"
    resultados = {etq: [] for etq, _ in variantes}
    for rep in range(repetir):
        for etq, ruta in variantes:
            prompt = leer_prompt(ruta)
            pasada = {}
            for nombre, wav, ref in muestras:
                _, texto, _, fallo = bench.correr(modelo, wav, salida, con_vad, prompt)
                if fallo:
                    sys.exit(f"la transcripción falló en {nombre} ({etq}): {fallo}")
                _, errores, palabras = bench.wer(ref, texto)
                pasada[nombre] = (errores, palabras, texto)
            resultados[etq].append(pasada)
        if repetir > 1:
            print(f"  pasada {rep + 1}/{repetir} hecha", file=sys.stderr)
    return resultados


def comprobar_determinismo(resultados):
    """Compara las pasadas celda a celda. Si bailan, la diferencia es del arnés, no del prompt."""
    problemas = []
    for etq, pasadas in resultados.items():
        if len(pasadas) < 2:
            continue
        primera = pasadas[0]
        for i, pasada in enumerate(pasadas[1:], 2):
            for nombre in primera:
                if pasada[nombre][0] != primera[nombre][0]:
                    problemas.append(
                        f"{etq} · {nombre}: pasada 1 dio {primera[nombre][0]} errores y "
                        f"la pasada {i} dio {pasada[nombre][0]}"
                    )
    return problemas


def totales(resultados):
    return {etq: sum(v[0] for v in p[0].values()) for etq, p in resultados.items()}


def palabras_ref(resultados):
    """Las palabras de referencia no dependen de la variante, así que se leen de la primera."""
    primera = next(iter(resultados.values()))[0]
    return sum(v[1] for v in primera.values())


def imprimir_tabla(resultados, orden, n_ref, detalle):
    ancho = max(9, max(len(e) for e in orden))
    cabecera = f"{'frase':<13}{'pal':>4}" + "".join(f"{e:>{ancho}} " for e in orden)
    print(cabecera)
    print("-" * len(cabecera))
    nombres = list(next(iter(resultados.values()))[0].keys())
    for nombre in nombres:
        pal = resultados[orden[0]][0][nombre][1]
        fila = f"{nombre:<13}{pal:>4}"
        for etq in orden:
            fila += f"{resultados[etq][0][nombre][0]:>{ancho}} "
        print(fila)
    fila = f"{'TOTAL':<13}{n_ref:>4}"
    for etq in orden:
        fila += f"{sum(v[0] for v in resultados[etq][0].values()):>{ancho}} "
    print("-" * len(cabecera))
    print(fila)
    print()
    for etq in orden:
        e = sum(v[0] for v in resultados[etq][0].values())
        print(f"  {etq:<{ancho}}  errores={e:<4} WER={100.0 * e / n_ref:.1f}%")
    if detalle:
        print()
        for etq in orden:
            print(f"--- {etq} ---")
            for nombre, (err, _, texto) in resultados[etq][0].items():
                if err:
                    print(f"  {nombre}: {texto}")


def dominancia(resultados, orden, base):
    """Comprueba si una variante da lo mismo o mejor que la base en TODAS las frases."""
    nombres = list(resultados[base][0].keys())
    print()
    print(f"dominancia contra «{base}» (mejor = menos errores, y nunca peor en ninguna frase)")
    for etq in orden:
        if etq == base:
            continue
        mejores = peores = 0
        donde_peor = []
        for nombre in nombres:
            a = resultados[etq][0][nombre][0]
            b = resultados[base][0][nombre][0]
            if a < b:
                mejores += 1
            elif a > b:
                peores += 1
                donde_peor.append(f"{nombre} ({b}->{a})")
        delta = sum(v[0] for v in resultados[base][0].values()) - \
            sum(v[0] for v in resultados[etq][0].values())
        veredicto = "DOMINA" if peores == 0 and mejores > 0 else (
            "empata" if peores == 0 else "no domina")
        print(f"  {etq:<10} {veredicto:<11} total {delta:+d}   mejor en {mejores}, peor en {peores}"
              + (f"   peor en: {', '.join(donde_peor)}" if donde_peor else ""))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variantes", nargs="+", required=True,
                    help="etiqueta=RUTA_DEL_PROMPT, o vacio para no pasar prompt")
    ap.add_argument("--dir", default=os.path.expanduser("~/.local/share/dictado/corpus"))
    ap.add_argument("--modelo", default=os.path.expanduser("~/.local/share/whisper/actual.bin"))
    ap.add_argument("--sin-vad", action="store_true")
    ap.add_argument("--repetir", type=int, default=1)
    ap.add_argument("--base", default=None, help="variante de referencia para la dominancia")
    ap.add_argument("--json", default=None)
    ap.add_argument("--detalle", action="store_true")
    a = ap.parse_args()

    bench = cargar_banco()
    variantes = parsear_variantes(a.variantes)
    orden = [etq for etq, _ in variantes]
    base = a.base or orden[0]
    if base not in orden:
        sys.exit(f"--base {base} no está entre las variantes: {', '.join(orden)}")

    if not os.path.isfile(a.modelo):
        sys.exit(f"no existe el modelo: {a.modelo}")
    muestras = cargar_muestras(a.dir)
    if not muestras:
        sys.exit(f"no hay pares .wav/.txt en {a.dir}")

    print(f"corpus: {len(muestras)} frases en {a.dir}")
    print(f"modelo: {a.modelo}")
    print(f"vad:    {'no' if a.sin_vad else bench.VAD}")
    for etq, ruta in variantes:
        p = leer_prompt(ruta)
        print(f"  {etq:<10} {len(p) if p is not None else 0:>4} caracteres"
              + (f"   {ruta}" if ruta else "   (sin prompt)"))
    print()

    resultados = medir(bench, variantes, muestras, a.modelo, not a.sin_vad, a.repetir)

    if a.repetir > 1:
        problemas = comprobar_determinismo(resultados)
        if problemas:
            print("AVISO: las pasadas NO coinciden, así que las diferencias no son del prompt:")
            for p in problemas:
                print(f"  {p}")
            print()
        else:
            print(f"{a.repetir} pasadas idénticas celda a celda\n")

    n_ref = palabras_ref(resultados)
    imprimir_tabla(resultados, orden, n_ref, a.detalle)
    dominancia(resultados, orden, base)

    if a.json:
        volcado = {
            "corpus": a.dir,
            "modelo": a.modelo,
            "vad": None if a.sin_vad else bench.VAD,
            "repetir": a.repetir,
            "palabras_ref": n_ref,
            "variantes": [
                {
                    "etiqueta": etq,
                    "prompt": leer_prompt(ruta),
                    "caracteres": len(leer_prompt(ruta)) if ruta else 0,
                    "errores": sum(v[0] for v in resultados[etq][0].values()),
                    "wer": sum(v[0] for v in resultados[etq][0].values()) / n_ref,
                    "detalle": {n: {"errores": v[0], "palabras": v[1], "texto": v[2]}
                                for n, v in resultados[etq][0].items()},
                }
                for etq, ruta in variantes
            ],
        }
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(volcado, f, ensure_ascii=False, indent=2)
        print(f"\nJSON en {a.json}")


if __name__ == "__main__":
    main()
