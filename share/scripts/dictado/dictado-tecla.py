#!/usr/bin/env python3
"""dictado-tecla — dispara el dictado con un toque rápido de Ctrl izquierdo.

Vigila el teclado a nivel de evdev y detecta dos cosas. La primera es el patrón «Ctrl_L pulsado
y soltado sin que se haya pulsado ninguna otra tecla por medio, y en menos de UMBRAL ms»; cuando
lo ve, llama a `dictado-vivo.sh toggle`, que abre la capa con el texto mientras se forma. La
segunda es la tecla Escape, que cancela lo que esté grabando.

Escape vive aquí y no en un bind de Hyprland por el mismo motivo que el toque de Ctrl. Este
proceso solo LEE, así que Escape sigue llegando intacto a la aplicación con el foco. Un bind lo
consumiría, y atar Escape en el gestor de ventanas deja sin Escape a todo el escritorio.

Por qué así:

- **No remapea nada.** Este proceso solo LEE los eventos del teclado. Ctrl sigue siendo
  modificador y Ctrl+C / Ctrl+V / Ctrl+D llegan intactos a las aplicaciones. Un remapeador
  (keyd, xmodmap) sí cambiaría el comportamiento de Ctrl en todo el sistema; aquí no hace falta.
- **No necesita root.** n30 está en el grupo `input`, así que /dev/input/event3 es legible.
  (keyd sí necesitaría instalarse con sudo, y sudo pide contraseña en este equipo.)
- **Hyprland no puede hacerlo.** `hl.bind("Ctrl_L", …)` dispara al PULSAR, no al soltar tras un
  toque, y el wiki avisa de que al enlazar un modificador «las teclas ya no se tratan como
  modificadores». De las banderas disponibles (release, long_press, click, drag, non_consuming,
  auto_consuming, transparent, ignore_mods…) ninguna distingue «toque» de «combinado».

Modos:
    dictado-tecla.py                  vigila y dispara el dictado
    dictado-tecla.py --probar         vigila y solo IMPRIME lo que detecta (no ejecuta nada)
    dictado-tecla.py --simular        prueba la lógica con eventos sintéticos, sin teclado
    dictado-tecla.py --dispositivos   lista los teclados legibles y sale
    dictado-tecla.py --orden          imprime qué ejecuta al detectar el toque y sale
    dictado-tecla.py --orden-escape   imprime qué ejecuta al pulsar Escape y sale

Variables de entorno:
    DICTADO_TECLA_UMBRAL_MS   duración máxima del toque          (por defecto 300)
    DICTADO_TECLA_CODIGO      tecla que se vigila                (por defecto KEY_LEFTCTRL)
    DICTADO_TECLA_DISPOSITIVO ruta de /dev/input/eventN          (por defecto, autodetecta)
    DICTADO_TECLA_ORDEN       qué se ejecuta al detectar el toque (por defecto dictado-vivo.sh toggle)
    DICTADO_TECLA_ESPERA_MS   anti-rebote tras disparar          (por defecto 500)
    DICTADO_TECLA_GRACIA_MS   ventana de gracia antes de disparar (por defecto 100)
    DICTADO_TECLA_ESCAPE      tecla que cancela el dictado     (por defecto KEY_ESC)
    DICTADO_TECLA_ORDEN_ESCAPE qué se ejecuta al pulsarla       (por defecto dictado-vivo.sh cancelar)
"""

import os
import subprocess
import sys
import time

try:
    import evdev
    from evdev import ecodes
except ImportError:
    sys.exit("falta el modulo python-evdev (paquete python-evdev)")

UMBRAL_MS = int(os.environ.get("DICTADO_TECLA_UMBRAL_MS", "300"))
ESPERA_MS = int(os.environ.get("DICTADO_TECLA_ESPERA_MS", "500"))
GRACIA_MS = int(os.environ.get("DICTADO_TECLA_GRACIA_MS", "100"))
NOMBRE_TECLA = os.environ.get("DICTADO_TECLA_CODIGO", "KEY_LEFTCTRL")
NOMBRE_ESCAPE = os.environ.get("DICTADO_TECLA_ESCAPE", "KEY_ESC")
DISPOSITIVO = os.environ.get("DICTADO_TECLA_DISPOSITIVO", "")
# La orden por defecto se resuelve desde la carpeta de ESTE fichero, no con una ruta escrita a mano.
# Medido el 2026-10-10: con la ruta fija, mover el proyecto a scripts/dictado/ dejaba la tecla
# llamando a un fichero que ya no existía, y el dictado se rompía sin ningún aviso. El proceso vivo
# seguía corriendo con la ruta vieja en memoria, así que el fallo aparecía al pulsar, no al mover.
#
# Desde el 2026-10-11 el toque lanza el dictado EN VIVO, no el ciego. Decisión de n30: el vivo hace
# lo mismo y enseña la capa con el texto que se forma. El ciego sigue existiendo y se puede
# recuperar apuntando DICTADO_TECLA_ORDEN a dictado.sh toggle.
ORDEN = os.environ.get(
    "DICTADO_TECLA_ORDEN",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "dictado-vivo.sh") + " toggle",
)

# Al pulsar Escape. La orden resuelve sola si hay algo que cancelar y sale callada cuando no lo hay.
# Eso importa porque Escape se pulsa a menudo para cerrar diálogos, y este vigilante no distingue
# para qué se pulsa. Si la orden avisara siempre, cada Escape del sistema daría una notificación.
ORDEN_ESCAPE = os.environ.get(
    "DICTADO_TECLA_ORDEN_ESCAPE",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "dictado-vivo.sh") + " cancelar",
)

# No hay teclas exentas, porque si al pulsar la tecla vigilada hay CUALQUIER otra tecla sujeta, el
# toque no cuenta. Se probó a eximir los modificadores (que Shift sujeto no invalidase un toque
# de Ctrl) y se descartó: la regla estricta tiene menos falsos positivos y se explica en una
# línea. Una tecla pulsada y soltada ANTES no estorba, porque el conjunto solo tiene lo que
# está sujeto en ese instante.


class DetectorToque:
    """Máquina de estados pura: se le dan eventos y dice cuándo hubo un toque.

    Está separada del teclado a propósito, para poder probarla con secuencias sintéticas
    sin tocar el escritorio de nadie.
    """

    def __init__(self, codigo, umbral_ms=300, espera_ms=500):
        self.codigo = codigo
        self.umbral = umbral_ms / 1000.0
        self.espera = espera_ms / 1000.0
        self.bajada = None          # instante en que se pulsó la tecla vigilada
        self.limpio = False         # ¿no había nada más sujeto al pulsarla?
        self.otras = set()          # teclas que están sujetas ahora mismo
        # None, no 0.0: con 0.0 el anti-rebote bloqueaba el PRIMER toque si los sellos de
        # tiempo empezaban cerca de cero. Lo encontró la prueba sintética.
        self.ultimo_disparo = None

    def procesar(self, code, value, t):
        """Devuelve True si en este evento se completó un toque válido."""
        # value: 1 = pulsar, 0 = soltar, 2 = repetición automática (se ignora)

        if code == self.codigo:
            if value == 1:
                self.bajada = t
                self.limpio = not self.otras
                return False
            if value == 0:
                dispara = False
                if self.bajada is not None and self.limpio:
                    duracion = t - self.bajada
                    libre = self.ultimo_disparo is None or t - self.ultimo_disparo >= self.espera
                    if 0 <= duracion <= self.umbral and libre:
                        dispara = True
                        self.ultimo_disparo = t
                self.bajada = None
                self.limpio = False
                return dispara
            return False

        if value == 1:
            self.otras.add(code)
            if self.bajada is not None:
                self.limpio = False
        elif value == 0:
            self.otras.discard(code)
        return False


class EsperaGracia:
    """Retardo de confirmación: el toque no dispara hasta que pasa la ventana sin más teclas.

    Está separada del bucle para poder probarla con tiempos sintéticos. El bucle real solo
    la consulta: `armar()` al detectar el toque, `cancelar()` si llega otra tecla, y
    `vencida()` cuando toca disparar.
    """

    def __init__(self, segundos):
        self.segundos = segundos
        self.limite = None

    def armar(self, ahora):
        self.limite = ahora + self.segundos

    def cancelar(self):
        self.limite = None

    def armada(self):
        return self.limite is not None

    def vencida(self, ahora):
        return self.limite is not None and ahora >= self.limite

    def restante(self, ahora):
        if self.limite is None:
            return None
        return max(0.0, self.limite - ahora)


class Vigilante:
    """Decide qué hacer con cada tanda de eventos.

    No toca el teclado ni el reloj: se le pasan los eventos y el instante. Así toda la lógica
    del bucle (umbral, anti-rebote y ventana de gracia) se puede probar con secuencias
    sintéticas, sin depender de que alguien pulse teclas.

    Devuelve:
        None         nada que hacer
        "disparar"   el toque se confirmó, hay que lanzar el dictado
        "abortar"    llegó otra tecla en la ventana de gracia, era un descuido
        "escape"     se pulsó la tecla de cancelar, hay que tirar lo que se esté grabando
    """

    def __init__(self, codigo, umbral_ms=300, espera_ms=500, gracia_ms=100, codigo_escape=None):
        self.detector = DetectorToque(codigo, umbral_ms, espera_ms)
        self.gracia = EsperaGracia(gracia_ms / 1000.0)
        self.codigo_escape = codigo_escape

    def espera(self, ahora):
        """Cuánto puede dormir el bucle; None si no hay nada pendiente."""
        return self.gracia.restante(ahora)

    def paso(self, eventos, ahora):
        for code, value, t in eventos:
            # Escape va primero y manda sobre lo demás. Desarma el toque pendiente, porque si no
            # el toque que estaba en la ventana de gracia dispararía justo después de cancelar y
            # volvería a arrancar el dictado que se acaba de tirar.
            if self.codigo_escape is not None and code == self.codigo_escape and value == 1:
                if self.gracia.armada():
                    self.gracia.cancelar()
                self.detector.procesar(code, value, t)
                return "escape"
            # La comprobación va ANTES de procesar: así la pulsación y la suelta del propio
            # toque no se cuentan como «otra tecla» y no se autodestruyen.
            if self.gracia.armada():
                self.gracia.cancelar()
                return "abortar"
            if self.detector.procesar(code, value, t):
                self.gracia.armar(ahora)
        if not self.gracia.armada():
            return None
        if self.gracia.vencida(ahora):
            self.gracia.cancelar()
            return "disparar"
        return None


def buscar_teclados():
    """Todos los dispositivos que parezcan un teclado de verdad.

    Se vigilan TODOS y no el primero. Si algún día se enchufa un segundo teclado, el toque
    tiene que funcionar en los dos. Quedarse con el primero es el fallo clásico aquí.
    """
    codigo = getattr(ecodes, NOMBRE_TECLA)
    encontrados = []
    for ruta in sorted(
        evdev.list_devices(), key=lambda s: int(s.replace("/dev/input/event", ""))
    ):
        try:
            d = evdev.InputDevice(ruta)
        except Exception:
            continue
        teclas = set(d.capabilities().get(ecodes.EV_KEY, []))
        if ecodes.KEY_A in teclas and codigo in teclas:
            encontrados.append(d)
    return encontrados


def listar_dispositivos():
    codigo = getattr(ecodes, NOMBRE_TECLA)
    print(f"tecla vigilada: {NOMBRE_TECLA} (codigo {codigo})")
    print()
    for ruta in sorted(
        evdev.list_devices(), key=lambda s: int(s.replace("/dev/input/event", ""))
    ):
        try:
            d = evdev.InputDevice(ruta)
        except Exception as e:
            print(f"  {ruta:<22} {type(e).__name__}")
            continue
        teclas = set(d.capabilities().get(ecodes.EV_KEY, []))
        es_teclado = ecodes.KEY_A in teclas and codigo in teclas
        marca = "TECLADO" if es_teclado else "-"
        print(f"  {ruta:<22} {marca:<8} {d.name}")
    print()
    print("(se vigilan todos los marcados TECLADO)")


def lanzar(orden):
    # setsid: el dictado no debe morir si este vigilante se reinicia.
    subprocess.Popen(
        ["setsid", "sh", "-c", orden],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
    )


def disparar():
    lanzar(ORDEN)


def cancelar_dictado():
    lanzar(ORDEN_ESCAPE)


def vigilar(solo_probar=False):
    codigo = getattr(ecodes, NOMBRE_TECLA)
    if DISPOSITIVO:
        disp = [evdev.InputDevice(DISPOSITIVO)]
    else:
        disp = buscar_teclados()
    if not disp:
        sys.exit(
            "no encuentro ningun teclado legible. Comprueba que estas en el grupo input "
            "y que hay una sesion de teclado activa."
        )

    for d in disp:
        print(f"vigilando {d.path} ({d.name})", flush=True)
    print(f"tecla {NOMBRE_TECLA}, toque <= {UMBRAL_MS} ms", flush=True)
    print(f"tecla {NOMBRE_ESCAPE} cancela el dictado", flush=True)
    print("accion:", ORDEN, flush=True)
    if solo_probar:
        print("MODO PRUEBA: no se ejecuta nada, solo se imprime lo detectado", flush=True)
    print()

    # Toda la decisión vive en Vigilante (umbral + anti-rebote + ventana de gracia), que está
    # probada con secuencias sintéticas. Aquí solo queda leer del teclado y ejecutar la orden.
    vigilante = Vigilante(codigo, UMBRAL_MS, ESPERA_MS, GRACIA_MS,
                          getattr(ecodes, NOMBRE_ESCAPE))

    # Se usa select en vez de read_loop() para poder escuchar varios teclados a la vez:
    # read_loop() se queda bloqueado en uno solo.
    import selectors

    sel = selectors.DefaultSelector()
    for d in disp:
        sel.register(d, selectors.EVENT_READ)

    def confirmar():
        marca = time.strftime("%H:%M:%S")
        if solo_probar:
            print(f"[{marca}] TOQUE DETECTADO (no se ejecuta nada)", flush=True)
        else:
            print(f"[{marca}] toque -> dictado", flush=True)
            disparar()

    try:
        while True:
            espera = vigilante.espera(time.monotonic())
            eventos = []
            for clave, _ in sel.select(timeout=espera):
                d = clave.fileobj
                try:
                    for ev in d.read():
                        if ev.type == ecodes.EV_KEY:
                            eventos.append((ev.code, ev.value, ev.timestamp()))
                except OSError:
                    print(f"se perdio {d.path}; se deja de vigilar ese teclado", flush=True)
                    sel.unregister(d)
                    if not sel.get_map():
                        sys.exit("no queda ningun teclado que vigilar")
            accion = vigilante.paso(eventos, time.monotonic())
            if accion == "disparar":
                confirmar()
            elif accion == "escape":
                marca = time.strftime("%H:%M:%S")
                if solo_probar:
                    print(f"[{marca}] ESCAPE (no se ejecuta nada)", flush=True)
                else:
                    print(f"[{marca}] escape -> cancelar dictado", flush=True)
                    cancelar_dictado()
            elif accion == "abortar":
                print("  (toque cancelado: llegó otra tecla en la ventana de gracia)", flush=True)
    except KeyboardInterrupt:
        print("\nfin.")
    finally:
        sel.close()


def simular():
    """Prueba de la lógica con eventos sintéticos. No toca teclado ni escritorio."""
    codigo = ecodes.KEY_LEFTCTRL
    otra = ecodes.KEY_C
    shift = ecodes.KEY_LEFTSHIFT
    umbral = 300
    casos = [
        # (nombre, secuencia, disparos esperados)
        ("toque limpio", [(codigo, 1, 0.000), (codigo, 0, 0.120)], 1),
        ("Ctrl+C: no debe disparar", [(codigo, 1, 0.0), (otra, 1, 0.05), (otra, 0, 0.09), (codigo, 0, 0.12)], 0),
        ("soltar muy tarde: no dispara", [(codigo, 1, 0.0), (codigo, 0, 0.900)], 0),
        ("dos toques separados", [(codigo, 1, 0.0), (codigo, 0, 0.100), (codigo, 1, 1.0), (codigo, 0, 1.100)], 2),
        ("dos toques pegados: el segundo lo frena el anti-rebote", [(codigo, 1, 0.0), (codigo, 0, 0.100), (codigo, 1, 0.200), (codigo, 0, 0.300)], 1),
        ("Shift suelto + toque de Ctrl: si dispara", [(shift, 1, 0.0), (shift, 0, 0.02), (codigo, 1, 0.05), (codigo, 0, 0.150)], 1),
        ("Shift sujeto mientras se toca Ctrl: NO dispara", [(shift, 1, 0.0), (codigo, 1, 0.05), (codigo, 0, 0.150), (shift, 0, 0.2)], 0),
        ("otra tecla ya sujeta antes de Ctrl: no dispara", [(otra, 1, 0.0), (codigo, 1, 0.05), (codigo, 0, 0.150), (otra, 0, 0.2)], 0),
        ("Ctrl derecho no cuenta como toque", [(ecodes.KEY_RIGHTCTRL, 1, 0.0), (ecodes.KEY_RIGHTCTRL, 0, 0.1)], 0),
        ("repeticion automatica no dispara", [(codigo, 1, 0.0), (codigo, 2, 0.05), (codigo, 2, 0.10), (codigo, 0, 0.150)], 1),
        ("tecla suelta tras el toque: no dispara", [(codigo, 1, 0.0), (codigo, 0, 0.100), (otra, 1, 0.200), (otra, 0, 0.250)], 1),
        ("toque en el limite exacto del umbral", [(codigo, 1, 0.0), (codigo, 0, 0.300)], 1),
        ("un pelo por encima del umbral", [(codigo, 1, 0.0), (codigo, 0, 0.301)], 0),
    ]

    ok = 0
    mal = 0
    for nombre, secuencia, esperado in casos:
        det = DetectorToque(codigo, umbral, ESPERA_MS)
        disparos = sum(1 for c, v, t in secuencia if det.procesar(c, v, t))
        if disparos == esperado:
            print(f"  OK   {nombre}")
            ok += 1
        else:
            print(f"  MAL  {nombre} (esperado {esperado}, obtenido {disparos})")
            mal += 1

    # El Vigilante anade dos cosas sobre el detector: la ventana de gracia y el Escape. Se prueban
    # igual, con eventos y tiempos sinteticos, sin tocar el teclado y sin lanzar ninguna orden.
    print()
    print("  --- Vigilante: ventana de gracia y Escape ---")
    esc = ecodes.KEY_ESC
    casos_v = [
        # (nombre, secuencia, instante final, acciones esperadas en orden)
        ("toque limpio confirma tras la gracia",
         [(codigo, 1, 0.0), (codigo, 0, 0.100)], 0.200, ["disparar"]),
        ("otra tecla en la gracia aborta",
         [(codigo, 1, 0.0), (codigo, 0, 0.100), (otra, 1, 0.120)], 0.120, ["abortar"]),
        ("Escape cancela",
         [(esc, 1, 0.0)], 0.0, ["escape"]),
        ("soltar Escape no cancela",
         [(esc, 0, 0.0)], 0.0, []),
        ("Escape desarma el toque pendiente y no dispara despues",
         [(codigo, 1, 0.0), (codigo, 0, 0.050), (esc, 1, 0.060)], 0.900, ["escape"]),
        ("una tecla normal no cancela",
         [(ecodes.KEY_A, 1, 0.0), (ecodes.KEY_A, 0, 0.050)], 0.0, []),
    ]
    for nombre, secuencia, t_final, esperado in casos_v:
        v = Vigilante(codigo, umbral, ESPERA_MS, GRACIA_MS, esc)
        acciones = []
        for c, val, t in secuencia:
            r = v.paso([(c, val, t)], t)
            if r:
                acciones.append(r)
        r = v.paso([], t_final)
        if r:
            acciones.append(r)
        if acciones == esperado:
            print(f"  OK   {nombre}")
            ok += 1
        else:
            print(f"  MAL  {nombre} (esperado {esperado}, obtenido {acciones})")
            mal += 1

    print()
    print(f"RESUMEN: {ok} correctos, {mal} fallidos")
    return 1 if mal else 0


def main():
    args = sys.argv[1:]
    if "--simular" in args:
        return simular()
    if "--dispositivos" in args:
        listar_dispositivos()
        return 0
    if "--orden" in args:
        # Solo imprime la orden resuelta. Sirve para comprobarla sin tocar el teclado ni el
        # escritorio, y para que la suite pueda vigilar que sigue apuntando al dictado en vivo.
        print(ORDEN)
        return 0
    if "--orden-escape" in args:
        # Lo mismo para la orden de Escape, por el mismo motivo: es una ruta que, si se rompe,
        # no falla al cargar sino al pulsar, y entonces ya no hay dictado que cancelar.
        print(ORDEN_ESCAPE)
        return 0
    vigilar(solo_probar="--probar" in args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
