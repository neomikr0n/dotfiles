# Plan: pasar unslop por las skills propias

**Cerrado el 2026-10-11.** Los 11 ficheros que tenían hallazgos quedan a cero. El
plan se conserva como registro del método, porque hará falta otra vez cuando se
escriban skills nuevas.

## La cifra de cabecera estaba vieja

La primera versión de este plan decía «2193 hallazgos en 55 ficheros», medida el
9 de octubre. El corpus se limpió después, así que esa cifra ya no valía. La
medición del 11 de octubre, justo antes de empezar, daba esto:

| Medida | Valor |
|---|---|
| Skills propias con hallazgos | 11 |
| Hallazgos reales en ellas | 178 |
| Ficheros fuera de corpus con hallazgos | 3 |

Los tres de fuera no se tocan. `unslop_ESPAÑOL` (114) y `unslop_EN` (4) son los
diccionarios de reglas, y se señalan a sí mismos porque contienen justo las
palabras y los ejemplos que persiguen. `deep-research` (24) es un pack de
terceros, con licencia MIT y escrito en chino.

## Los 11 ficheros y lo que tenían

| Fichero | Hallazgos |
|---|---|
| `pago-tarjeta-credito-tiempos-mexico` | 30 |
| `hyprland-lua-keybinds` | 27 |
| `buro-credito-mexico-consulta` | 27 |
| `emulador-resolucion-modo-tablet` | 26 |
| `arnes-ia-portable-windows` | 24 |
| `mac-apple-silicon-para-linux` | 24 |
| `hyprwhspr-dictado-linux` | 11 |
| `forense-video-youtube` | 6 |
| `systemd-usuario-no-arranca-hyprland` | 1 |
| `mexico-precios-calidad-consumo` | 1 |
| `elegir-modelo-whisper-por-medicion` | 1 |

## De qué eran los hallazgos

Casi todos son puntuación, no reescrituras. En estos 11 ficheros el grueso fue
`negrita-encabezado` (una etiqueta en negrita con dos puntos, que pasa a negrita
con punto) y `dos-puntos` (dos puntos a mitad de frase, que pasan a coma o a
punto). El resto se reparte entre rayas, adverbios en -mente, algún `además`,
alguna negrita excesiva y dos falsos positivos de vocabulario.

Dos casos que piden criterio y no una regla:

- `**dinámico**` en `hyprland-lua-keybinds` era el nombre del grupo de efectos
  (la tabla del propio fichero dice «DINÁMICOS»). Se resolvió usando el plural,
  que es el término que ya estaba en la tabla, y no se tocó el comprobador.
- `se dice que no se pudo leer` en `mac-apple-silicon-para-linux` disparaba la
  regla de atribución vaga sin serlo. Se reescribió a `se declara tal cual`.

## Cómo se hace cada uno

El método está en la skill `unslop-corpus-documentacion`. En corto, por fichero:

```sh
cp -p SKILL.md SKILL.md.bak-$(date +%Y%m%d)-unslop
sha256sum -c <(sha256sum SKILL.md.bak-*-unslop | sed "s# .*/#  #")
python3 unslop-revisar.py SKILL.md        # lista lo que hay
# lote de sustituciones que aborta si una cadena no casa exactamente una vez
python3 unslop-revisar.py SKILL.md        # tiene que decir limpio
```

Y al terminar, dos comprobaciones que no son de estilo:

1. `yaml.safe_load` del frontmatter, porque un cambio de prosa puede dejar una
   comilla suelta en el `description`.
2. Números y tramos entre comillas invertidas idénticos antes y después, para
   demostrar que no se perdió ningún dato.

## Lo que no conviene hacer

Los ficheros de una tacada. Es un diff que no se puede revisar, y si una
reescritura cambia el sentido de una instrucción el fallo se descubre cuando la
skill se usa mal.

## Las copias de seguridad

Las copias previas de esta pasada, y las de la pasada de octubre, se movieron a
`~/.workbuddy-ai/skills/backups/`, con la ruta del skill delante del nombre. No
se borró ninguna.
