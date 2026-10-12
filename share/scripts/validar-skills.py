#!/usr/bin/env python3
"""
Valida el frontmatter YAML de todas las skills y avisa de las que estan rotas.

Por que existe
--------------
Una skill con el frontmatter mal formado NO aparece para las sesiones siguientes:
se intenta leer y `yaml.safe_load` revienta. El trabajo se pierde en silencio, y
el sintoma no dice cual es el fichero ni por que.

El fallo mas comun, y van cuatro veces, es un `description:` sin comillas que
lleva `: ` dentro:

    description: Diagnostica X cuando pasa Y: la causa es Z
                                        ^
    yaml: mapping values are not allowed here

La regla de YAML es esa: un escalar plano no puede contener `: ` (dos puntos
seguido de espacio o fin de linea). La reparacion es comillar el escalar entero
y escapar las comillas simples internas duplicandolas.

Uso
---
    validar-skills.py                # todas las skills
    validar-skills.py <ruta> ...     # solo esas (fichero o carpeta)
    validar-skills.py --quiet        # solo el resumen

Salida: exit 0 si todas estan bien, exit 1 si hay alguna rota. Pensado para
encadenarlo despues de crear o editar una skill.
"""

import glob
import os
import sys

try:
    import yaml
except ImportError:
    print("Hace falta PyYAML: `python3 -m pip install --user pyyaml`", file=sys.stderr)
    sys.exit(2)

RAICES = [
    os.path.expanduser("~/.workbuddy-ai/skills"),
    os.path.expanduser("~/.workbuddy-ai/plugins"),
]

# YAML de mentira con el que comprobamos que el cargador distingue una descripcion
# valida de una rota. Si esta diera por buena una descripcion sin comillas, la
# prueba entera estaria midiendo otra cosa.
CONTROL_MALO = "description: algo con dos puntos: y mas texto"
# Y el bueno: el MISMO texto, comillado. Tiene que cargar sin queja.
CONTROL_BUENO = "description: 'algo con dos puntos: y mas texto'"


def skills_a_revisar(argumentos):
    if argumentos:
        rutas = []
        for a in argumentos:
            a = os.path.abspath(a)
            if os.path.isdir(a):
                rutas.extend(glob.glob(os.path.join(a, "**", "SKILL.md"), recursive=True))
            elif os.path.isfile(a):
                rutas.append(a)
        return sorted(set(rutas))
    rutas = []
    for raiz in RAICES:
        if os.path.isdir(raiz):
            rutas.extend(glob.glob(os.path.join(raiz, "**", "SKILL.md"), recursive=True))
    return sorted(set(rutas))


def frontmatter(texto):
    """Devuelve (cabeza, error). La cabeza es el texto entre los dos `---`."""
    lineas = texto.split("\n")
    if not lineas or lineas[0].strip() != "---":
        return None, "no empieza por la linea `---` del frontmatter"
    try:
        cierre = lineas.index("---", 1)
    except ValueError:
        return None, "abre el frontmatter y no lo cierra (falta el `---` de cierre)"
    return "\n".join(lineas[1:cierre]), None


def revisa(ruta):
    """Devuelve (estado, mensaje). estado en {'ok', 'roto'}."""
    try:
        texto = open(ruta, encoding="utf-8").read()
    except OSError as e:
        return "roto", "no se puede leer: %s" % e

    cabeza, error = frontmatter(texto)
    if error:
        return "roto", error

    try:
        datos = yaml.safe_load(cabeza)
    except yaml.YAMLError as e:
        primero = str(e).splitlines()
        # la linea util del error de PyYAML suele ser la que trae el caret
        pista = next((l.strip() for l in primero if "column" in l), "")
        return "roto", "YAML invalido: %s%s" % (primero[0], ("  [" + pista + "]") if pista else "")

    if not isinstance(datos, dict):
        return "roto", "el frontmatter no es un mapa de claves y valores"
    if not datos.get("description"):
        return "roto", "le falta `description`"
    # Hay dos esquemas en este equipo y los dos son validos:
    #   - `name` + `description`  (las que escribo)
    #   - `user-invocable: true` + `allowed-tools`  (las de paquete tipo
    #     deep-research, donde el nombre lo da la carpeta)
    # Exigir `name` a las segundas seria marcar como rota una skill que funciona.
    if not datos.get("name") and not datos.get("user-invocable"):
        return "roto", "no tiene ni `name` ni `user-invocable`"
    return "ok", datos.get("name", "(sin name, por carpeta)")


def autoprueba():
    """La guarda no vale si no distingue lo roto de lo bueno.

    Se comprueban las DOS mitades: que el malo revienta y que el bueno carga.
    Con solo la primera, un cargador roto que rechazara todo pasaria por bueno.
    """
    import yaml as _y
    try:
        _y.safe_load(CONTROL_BUENO)
    except _y.YAMLError:
        return False
    try:
        _y.safe_load(CONTROL_MALO)
    except _y.YAMLError:
        return True
    return False


def main():
    argumentos = [a for a in sys.argv[1:] if not a.startswith("--")]
    quiet = "--quiet" in sys.argv[1:]

    if not autoprueba():
        print("RESULT: no puede juzgar — el control malo se colo como valido.")
        return 2

    rutas = skills_a_revisar(argumentos)
    if not rutas:
        print("No hay ningun SKILL.md en %s" % ", ".join(RAICES))
        return 0

    rotas = []
    for r in rutas:
        estado, detalle = revisa(r)
        corto = os.path.relpath(r, os.path.expanduser("~/.workbuddy-ai"))
        if estado == "ok":
            if not quiet:
                print("OK    %-58s %s" % (corto, detalle))
        else:
            rotas.append((corto, detalle))
            print("ROTO  %-58s %s" % (corto, detalle))

    print()
    if rotas:
        print("RESULT: %d rotas de %d. Una skill con el frontmatter roto no existe" % (len(rotas), len(rutas)))
        print("        para las sesiones siguientes. Comilla el escalar y duplica las")
        print("        comillas simples internas:")
        print("            description: 'texto con dos puntos: y comillas ''asi'''")
        return 1
    print("RESULT: %d de %d con el frontmatter valido." % (len(rutas), len(rutas)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
