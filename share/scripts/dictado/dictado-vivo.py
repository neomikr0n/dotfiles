#!/usr/bin/env python3
"""dictado-vivo.py — motor del dictado en vivo.

Lanza `whisper-stream` sobre el microfono, lee sus hipotesis parciales y las publica en un
fichero de estado que la capa de Quickshell (`dictado-vivo.qml`) dibuja. En paralelo mide el
nivel de audio para la barra de "esto esta captando".

Por que whisper-stream y no el servidor. El informe de autocritica lo decidio midiendo. Una
llamada a /inference cada 300 ms sobre el audio acumulado es viable porque turbo resuelve en
0,10 s por el servidor, pero gasta mucho mas computo para el mismo resultado. El ejemplo
`examples/stream/stream.cpp` de whisper.cpp ya hace la ventana deslizante y el detector de voz,
y compilarlo fue el camino corto.

DOS COSAS DISTINTAS: LO QUE SE VE Y LO QUE SE GRABA
===================================================
Esto es lo que hay que entender antes de tocar nada.

  whisper-stream   solo PINTA. Su hipotesis es una ventana deslizante que cubre los ultimos
                   `--ventana` ms, no todo lo hablado, y se reescribe entera cada paso.
  pw-record        GRABA. Es el WAV que se transcribe al final, y es el que manda.

Al principio esto usaba el WAV que whisper-stream guarda con `-sa`, y NO sirve. Medido el
2026-10-10 leyendo el bucle de stream.cpp: ese WAV se escribe UNA VEZ POR VENTANA, al principio
de cada vuelta, asi que al cortar se queda sin escribir todo lo acumulado desde la ultima
escritura, hasta 2 s. O sea que se pierde justo la ultima palabra, que es la que mas importa.
pw-record escribe segun llega y cierra el fichero al recibir SIGINT (es lo que hace dictado.sh
en el dictado normal), asi que no se pierde cola.

Consecuencia practica: whisper-stream NO lleva `-sa`. No hace falta y solo confundiria.

LAS SENALES NO SON INTERCAMBIABLES
==================================
Medido el 2026-10-10: whisper-stream NO muere con SIGINT. SDL lo captura y lo convierte en un
evento SDL_QUIT que el bucle solo mira en ciertos puntos, asi que se queda vivo. Muere con
SIGTERM, que es lo que se le manda. pw-record, al reves, necesita SIGINT para cerrar el WAV
sin cortarlo. Cada uno con la suya.

Uso (lo normal es no llamarlo a mano, lo llama dictado-vivo.sh):
    dictado-vivo.py --runtime DIR --modelo M.bin --fuente <nombre pactl> --patron "Wireless Mic"
"""

import argparse
import json
import math
import os
import re
import signal
import subprocess
import sys
import threading
import time

# Secuencias ANSI que whisper-stream usa para reescribir la linea. \33[2K la borra.
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
# Linea de la lista de dispositivos que imprime al arrancar.
RE_DISPOSITIVO = re.compile(r"Capture device #(\d+): '([^']*)'")


def limpiar(trozo):
    """Quita secuencias ANSI y espacios sobrantes. Devuelve '' si no queda texto."""
    return ANSI.sub("", trozo).strip()


def indice_dispositivo(binario, patron, entorno, segundos=20):
    """Indice SDL del dispositivo de captura cuyo nombre contiene `patron`, o None.

    SDL no deja elegir por nombre, solo por indice, y el indice depende de cuantos
    dispositivos haya enchufados. Por eso se pregunta al propio binario, que imprime la lista
    en stderr al arrancar (antes de cargar el modelo). Se lanza con un indice imposible para
    que no abra nada de verdad.
    """
    try:
        p = subprocess.run([binario, "-c", "99999", "-m", "/no-existe.bin"],
                           capture_output=True, text=True, timeout=segundos, env=entorno)
        salida = (p.stderr or "") + (p.stdout or "")
    except Exception:
        return None
    for m in RE_DISPOSITIVO.finditer(salida):
        if patron.lower() in m.group(2).lower():
            return int(m.group(1))
    return None


class Estado:
    """El fichero que lee la capa. Se escribe entero cada vez, con reemplazo atomico.

    El reemplazo importa: si la capa leyera un fichero a medio escribir, un JSON cortado la
    dejaria en blanco. Con os.replace el lector siempre ve una version completa, la vieja o
    la nueva.
    """

    def __init__(self, ruta):
        self.ruta = ruta
        self.tmp = ruta + ".tmp"
        self.lock = threading.Lock()
        self.estado = "escuchando"
        self.texto = ""
        self.nivel = 0.0
        self.ultimo_escrito = 0.0

    def fijar(self, estado=None, texto=None, nivel=None, forzar=False):
        with self.lock:
            hay_texto = False
            if estado is not None and estado != self.estado:
                self.estado = estado
                hay_texto = True
            if texto is not None and texto != self.texto:
                self.texto = texto
                hay_texto = True
            if nivel is not None:
                self.nivel = nivel
            ahora = time.monotonic()
            # El texto y el estado se escriben en cuanto cambian. El nivel cambia 20 veces por
            # segundo y no merece 20 escrituras, asi que se limita a 10 por segundo. Medido el
            # 2026-10-10: sin esta separacion, la ultima hipotesis se quedaba en memoria y no
            # llegaba al fichero, porque el limitador la frenaba como si fuera un nivel.
            if not (forzar or hay_texto or (ahora - self.ultimo_escrito) >= 0.1):
                return
            self.ultimo_escrito = ahora
            datos = {
                "estado": self.estado,
                "texto": self.texto,
                "nivel": round(self.nivel, 3),
                "ms": int(ahora * 1000),
            }
        try:
            with open(self.tmp, "w", encoding="utf-8") as f:
                json.dump(datos, f, ensure_ascii=False)
            os.replace(self.tmp, self.ruta)
        except OSError:
            pass


def medidor_nivel(fuente, estado, parar):
    """Nivel 0..1 del microfono, en su propio hilo. Si falla, no tumba nada.

    Se lee con parec, no con SDL, para no abrir el receptor dos veces por el mismo camino.
    El nivel se mapea de decibelios: -60 dB es 0 y 0 dB es 1, que es como se lee un medidor
    de verdad y no como una raiz cuadrada suelta.
    """
    if not fuente:
        return
    # --latency-msec es lo que hace que la barra se mueva. Medido el 2026-10-10: sin el, parec
    # acumula en su buffer de salida y solo entrega cada ~2 s, asi que el nivel daba un salto
    # cada dos segundos en vez de seguir la voz. Con 50 ms entrega una lectura cada 50 ms.
    cmd = ["parec", "--device=" + fuente, "--format=s16le", "--rate=16000",
           "--channels=1", "--raw", "--latency-msec=50"]
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except Exception:
        return
    # 1600 bytes = 50 ms de s16 mono a 16 kHz.
    tam = 1600
    try:
        while not parar.is_set():
            datos = p.stdout.read(tam)
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
            estado.fijar(nivel=nivel)
    except Exception:
        pass
    finally:
        try:
            p.terminate()
        except Exception:
            pass


def bombear(salida, estado):
    """Lee la salida de whisper-stream y publica la hipotesis vigente.

    El binario reescribe una sola linea con `\\33[2K\\r` + texto. Se parte por `\\r`. Cada trozo
    completo es una version; la cola sin `\\r` todavia es la version en curso. Se procesan las
    dos, para que el texto no llegue un paso tarde. La cola se ignora si trae un escape a
    medias, que si no se colaria como texto.
    """
    buf = ""
    while True:
        try:
            trozo = os.read(salida.fileno(), 4096)
        except OSError:
            break
        if not trozo:
            break
        buf += trozo.decode("utf-8", "replace")
        piezas = buf.split("\r")
        buf = piezas.pop()
        for pieza in piezas:
            t = limpiar(pieza)
            if t:
                estado.fijar(estado="transcribiendo", texto=t)
        if buf and "\x1b" not in buf:
            t = limpiar(buf)
            if t:
                estado.fijar(estado="transcribiendo", texto=t)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runtime", required=True)
    ap.add_argument("--modelo", required=True)
    ap.add_argument("--fuente", default="")
    ap.add_argument("--patron", default="Wireless Mic")
    ap.add_argument("--idioma", default="es")
    ap.add_argument("--paso", type=int, default=2000)
    ap.add_argument("--ventana", type=int, default=12000)
    ap.add_argument("--hilos", type=int, default=4)
    ap.add_argument("--binario", default=None)
    ap.add_argument("--grabadora", default="pw-record")
    a = ap.parse_args()

    dir_bin = os.path.expanduser("~/.local/share/dictado/bin")
    binario = a.binario or os.path.join(dir_bin, "whisper-stream")
    if not os.path.isfile(binario):
        print(f"dictado-vivo: falta {binario}", file=sys.stderr)
        return 1

    os.makedirs(a.runtime, exist_ok=True)
    estado = Estado(os.path.join(a.runtime, "estado.json"))
    estado.fijar(estado="escuchando", texto="", nivel=0.0, forzar=True)

    entorno = dict(os.environ)
    entorno["LD_LIBRARY_PATH"] = dir_bin + (":" + entorno["LD_LIBRARY_PATH"]
                                            if entorno.get("LD_LIBRARY_PATH") else "")

    idx = indice_dispositivo(binario, a.patron, entorno)
    if idx is None:
        estado.fijar(estado="error", texto="No encuentro el microfono", forzar=True)
        print(f"dictado-vivo: ningun dispositivo contiene '{a.patron}'", file=sys.stderr)
        return 2

    parar = threading.Event()
    hilo_nivel = threading.Thread(target=medidor_nivel, args=(a.fuente, estado, parar),
                                  daemon=True)
    hilo_nivel.start()

    wav = os.path.join(a.runtime, "audio.wav")
    try:
        os.unlink(wav)
    except OSError:
        pass

    # whisper-stream: la vista. Sin -sa a proposito, ver la cabecera del fichero. Su WAV
    # perderia la cola al cortar, y la cola es lo que se acaba de decir.
    cmd = [binario, "-m", a.modelo, "-c", str(idx), "-l", a.idioma,
           "--step", str(a.paso), "--length", str(a.ventana), "--keep", "200",
           "-t", str(a.hilos)]
    proc = subprocess.Popen(cmd, cwd=a.runtime, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, bufsize=0, env=entorno)

    # pw-record: la grabacion de verdad. Cierra el WAV al recibir SIGINT.
    cmd_rec = [a.grabadora, "--target", a.fuente, "--rate", "16000",
               "--channels", "1", "--format", "s16", wav]
    rec = subprocess.Popen(cmd_rec, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def apagar(_sig, _frm):
        parar.set()
        # Cada uno con la senal que le corresponde, y no la misma para los dos.
        for p, s in ((proc, signal.SIGTERM), (rec, signal.SIGINT)):
            try:
                p.send_signal(s)
            except Exception:
                pass

    signal.signal(signal.SIGINT, apagar)
    signal.signal(signal.SIGTERM, apagar)

    hilo_texto = threading.Thread(target=bombear, args=(proc.stdout, estado), daemon=True)
    hilo_texto.start()

    try:
        proc.wait()
    except KeyboardInterrupt:
        apagar(None, None)
        proc.wait()

    # whisper-stream ya salio. El grabador necesita un momento para cerrar el WAV. Su SIGINT
    # puede haberlo recibido ya desde apagar(), o no si whisper-stream murio por su cuenta.
    if rec.poll() is None:
        try:
            rec.send_signal(signal.SIGINT)
        except Exception:
            pass
    try:
        rec.wait(timeout=5)
    except subprocess.TimeoutExpired:
        rec.terminate()
        try:
            rec.wait(timeout=3)
        except subprocess.TimeoutExpired:
            rec.kill()
    parar.set()

    # Deja constancia del audio para que el puente lo transcriba con el vocabulario. Se
    # comprueba que haya algo mas que la cabecera. Un WAV de 44 bytes es una grabacion vacia.
    if os.path.isfile(wav) and os.path.getsize(wav) > 44:
        try:
            with open(os.path.join(a.runtime, "audio.txt"), "w", encoding="utf-8") as f:
                f.write(wav)
        except OSError:
            pass
    # NO se marca "listo" aqui. Al salir de este motor el texto final todavia no existe. Lo
    # produce el puente con la ruta buena de dictado.sh. Se deja el estado en "transcribiendo"
    # y se conserva la ultima hipotesis, que es la verdad de este momento. Se sigue
    # transcribiendo. Marcar "listo" aqui seria mentir durante los segundos que tarda la
    # pasada final. El "listo" lo escribe el puente, con el texto ya en la mano.
    estado.fijar(estado="transcribiendo", forzar=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
