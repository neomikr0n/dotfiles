#!/usr/bin/env python3
"""Las dos mitades del banco de medida del medidor de nivel.

    dictado-nivel-medir.py comparar <fuente>
        Replica el medidor de nivel de dictado-vivo.py, que es parec a 16 kHz mono con bloques
        de 1600 bytes y RMS pasado a decibelios. En vez de escribir el fichero de estado imprime
        una linea por lectura, con marca de tiempo, para poder alinearla con la otra via.

    dictado-nivel-medir.py analizar <registro-qml> <registro-parec>
        Lee los dos registros, saca el ritmo real de cada via, los canales que negocio el
        monitor, y compara las dos curvas sobre la misma senal.
"""
import math
import re
import statistics as st
import subprocess
import sys
import time

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def comparar(fuente):
    cmd = [
        "parec",
        "--device=" + fuente,
        "--format=s16le",
        "--rate=16000",
        "--channels=1",
        "--raw",
        "--latency-msec=50",
    ]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        while True:
            # OJO. read() sobre una tuberia devuelve lo que haya, no lo que se pide. Es el mismo
            # detalle que tiene el medidor de produccion, asi que se deja igual a proposito. Si
            # aqui se arreglara, la comparacion dejaria de ser entre las dos cosas reales.
            datos = p.stdout.read(1600)
            if not datos:
                break
            n = len(datos) // 2
            if n == 0:
                continue
            suma = 0
            for i in range(n):
                v = int.from_bytes(datos[2 * i:2 * i + 2], "little", signed=True)
                suma += v * v
            rms = math.sqrt(suma / n) / 32768.0
            db = 20.0 * math.log10(rms + 1e-6)
            nivel = max(0.0, min(1.0, (db + 60.0) / 60.0))
            print(f"R {int(time.time() * 1000)} {nivel:.6f}", flush=True)
    finally:
        p.terminate()


def ritmo(serie, nombre):
    if len(serie) < 3:
        print(f"  {nombre} {len(serie)} emisiones, no hay medida")
        return
    huecos = sorted(
        serie[i + 1][0] - serie[i][0] for i in range(len(serie) - 1)
        if 0 < serie[i + 1][0] - serie[i][0] < 5000
    )
    mediana = st.median(huecos)
    print(f"  {nombre} {len(serie)} emisiones, mediana {mediana:.1f} ms, "
          f"p10 {huecos[len(huecos) // 10]} ms, p90 {huecos[9 * len(huecos) // 10]} ms, "
          f"ritmo {1000 / mediana:.1f} Hz")
    largos = [h for h in huecos if h > 100]
    cola = f", el mayor {max(largos)} ms" if largos else ""
    print(f"      intervalos por encima de 100 ms = {len(largos)}{cola}")


def correlacion(x, y):
    mx, my = st.mean(x), st.mean(y)
    cov = sum((i - mx) * (j - my) for i, j in zip(x, y)) / len(x)
    sx = (sum((i - mx) ** 2 for i in x) / len(x)) ** 0.5
    sy = (sum((j - my) ** 2 for j in y) / len(y)) ** 0.5
    return cov / (sx * sy)


def en_decibelios(valor):
    """El pico real sale de deshacer la raiz cubica que aplica Quickshell."""
    pico = valor ** 3
    if pico <= 0:
        return 0.0
    return max(0.0, min(1.0, (20 * math.log10(pico) + 60.0) / 60.0))


def analizar(ruta_qml, ruta_parec):
    P, PM, H, canales = [], [], [], []
    for linea in open(ruta_qml, encoding="utf-8", errors="replace"):
        m = re.search(r"qml: (\S+) ?(.*)$", ANSI.sub("", linea))
        if not m:
            continue
        etq, resto = m.group(1), m.group(2).strip()
        campos = resto.split()
        if etq in ("P", "PM") and len(campos) >= 2:
            (P if etq == "P" else PM).append((int(campos[0]), float(campos[1])))
        elif etq == "H" and len(campos) >= 2:
            H.append((int(campos[0]), float(campos[1])))
        elif etq.startswith("CANALES"):
            canales.append((etq, resto))

    R = []
    for linea in open(ruta_parec, encoding="utf-8", errors="replace"):
        campos = linea.split()
        if len(campos) >= 3 and campos[0] == "R":
            R.append((int(campos[1]), float(campos[2])))

    print()
    print("=== canales que negocia el monitor ===")
    if canales:
        for etq, valor in canales:
            print(f"  {etq} {valor}")
    else:
        print("  ninguno. Si el nodo no entrega F32, Quickshell descarta el formato y los picos")
        print("  se quedan vacios. Busca 'Unsupported peak monitor format' en el registro.")

    print()
    print("=== ritmo real de actualizacion ===")
    ritmo(P, "P  sumidero, con audio")
    ritmo(PM, "PM microfono        ")
    ritmo(R, "R  parec, el de hoy ")

    print()
    print("=== misma senal, las dos curvas ===")
    if len(H) < 6 or len(R) < 6:
        print("  faltan muestras para comparar")
        return
    t0, t1 = max(H[0][0], R[0][0]), min(H[-1][0], R[-1][0])
    hs = [(t, v) for t, v in H if t0 <= t <= t1]
    rs = [(t, v) for t, v in R if t0 <= t <= t1]
    print(f"  ventana comun {t1 - t0} ms, {len(hs)} muestras de la capa, {len(rs)} de parec")
    print(f"  capa   min {min(v for _, v in hs):.3f}  max {max(v for _, v in hs):.3f}  "
          f"media {st.mean(v for _, v in hs):.3f}")
    print(f"  parec  min {min(v for _, v in rs):.3f}  max {max(v for _, v in rs):.3f}  "
          f"media {st.mean(v for _, v in rs):.3f}")

    # Las dos series se promedian en cajas de 200 ms. Emparejar por vecino mas cercano movia la
    # correlacion tres centesimas entre pasadas, y quedarse con el maximo de la caja tambien,
    # porque las dos vias no leen con el mismo desfase ni a la misma frecuencia. Promediar en una
    # caja ancha para las dos quita el desfase de la ecuacion, y ademas es lo que hace la barra,
    # que suaviza el valor con una animacion de 70 ms.
    lado = 200
    def en_cajas(serie):
        cajas = {}
        for t, v in serie:
            cajas.setdefault((t - t0) // lado, []).append(v)
        return {k: sum(vs) / len(vs) for k, vs in cajas.items()}

    caja_capa = en_cajas(hs)
    caja_parec = en_cajas(rs)
    claves = sorted(set(caja_capa) & set(caja_parec))
    if len(claves) < 6:
        print("  no se pudieron alinear suficientes muestras")
        return

    crudo = [caja_capa[k] for k in claves]
    viejo = [caja_parec[k] for k in claves]
    remedido = [en_decibelios(v) for v in crudo]
    print(f"  cajas de {lado} ms con datos en las dos series {len(claves)}"
          f"  (capa {len(caja_capa)}, parec {len(caja_parec)})")
    print(f"  correlacion  valor de la capa tal cual      {correlacion(crudo, viejo):.3f}")
    print(f"  correlacion  valor de la capa pasado a dB   {correlacion(remedido, viejo):.3f}")
    for umbral in (0.2, 0.5, 0.8):
        print(f"      por encima de {umbral}   capa {sum(1 for v in crudo if v > umbral)}"
              f"   capa en dB {sum(1 for v in remedido if v > umbral)}"
              f"   parec {sum(1 for v in viejo if v > umbral)}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    if sys.argv[1] == "comparar" and len(sys.argv) == 3:
        comparar(sys.argv[2])
        return 0
    if sys.argv[1] == "analizar" and len(sys.argv) == 4:
        analizar(sys.argv[2], sys.argv[3])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
