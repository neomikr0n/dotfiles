# Bitácora — `audio-debug`

Registro del fallo intermitente de audio. Septiembre de 2026.
Detalle completo: `/home/n30/dotfiles/context/audio/diagnostico_distorsion_tiempo_real.md`.

---

## Cómo leer esta bitácora

**Los hechos y las interpretaciones van en secciones separadas, y es a propósito.**

El error más repetido de esta investigación ha sido leer un dato y sacar de él una conclusión más
fuerte de la que el dato sostiene. Poner los dos juntos en el mismo párrafo hace invisible ese salto.
Separarlos lo deja a la vista.

- **PARTE A — Observado.** Lo que se midió, cuándo y con qué. Sin interpretar.
- **PARTE B — Interpretado.** Lo que se cree que significa, **con su nivel de confianza y con qué lo
  refutaría.**
- **PARTE C — El instrumento.** Qué puede ver cada herramienta y **qué no puede ver**. Sin esta parte,
  cualquier silencio se lee como una ausencia, y no lo es.

**Regla de vocabulario:** las palabras con que el propietario describe lo que oye se copian
**literales** y no se normalizan. Son el único dato directo del síntoma. (Ver A1.)

---

## Las piezas

| Pieza | Ruta | Para qué |
|---|---|---|
| `audio-debug` | `share/scripts/audio-debug` (enlace en `~/.local/bin/`) | Captura el estado cuando se oye el fallo |
| `audio-debug.md` | `share/scripts/audio-debug.md` | Esta bitácora |
| `audio-debug.log` | `share/scripts/audio-debug.log` | Las capturas completas, en bruto |
| `vigilar.sh` (v4) | `~/.local/state/audio-debug/vigilar.sh` | Muestrea cada ~234 ms. **Ver C2: sus puntos ciegos** |

Las tres primeras viven juntas; el script localiza las otras dos desde su propia ruta. El enlace en
`~/.local/bin` existe porque `share/scripts` no está en el PATH. `marca-audio` (nombre anterior)
quedó retirado: es la misma herramienta.

## Cómo se usa

```
audio-debug "lo que oí"
```

Al terminar imprime una línea resumen y avisa **solo** si hay señal inequívoca (`state != RUNNING` o
CPU saturada). Si no avisa, es que no había nada anómalo que avisar.

### Si la captura sale con `estado=?`

**No es un fallo del script.** Significa que **no había sesión PCM abierta**: `pcm0p` y `pcm1p`
contenían los dos la palabra `closed`. Es lo normal si se ejecuta **sin audio sonando** o en pausa.

**Verificado el 20-sep-2026:** con audio → `estado=RUNNING delay=1981 delta=1908`; sin audio → los
dos en `closed` y todos los campos en `?`.

---
---

# PARTE A — OBSERVADO

## A1. Las capturas, y las palabras exactas del propietario

Once capturas con descripción, dos de ellas de verificación del instrumento. **Estas son las
palabras literales, copiadas del log sin tocar:**

| hora | descripción literal | ¿evento? |
|---|---|---|
| 16:25:48 | «verificación con traducción» | no |
| 16:27:25 | «prueba final» | no |
| 16:42:11 | **«corte seco mientras jugaba»** | sí (1.º) |
| 16:58:49 | **«audio robotico»** | sí (2.º) |
| 17:15:31 | **«audio robotico»** | sí (3.º) |
| 18:02:22 | **«audio robotico»** | sí (4.º) |
| 18:06:26 | **«audio robotico»** | sí (5.º) |
| 18:06:58 | **«audio robotico»** | sí (6.º) |
| 18:14:20 | **«audio robotico»** | sí (7.º) |
| 18:18:07 | **«audio robotico»** | sí (8.º) |
| 18:22:41 | **«audio robotico»** | sí (9.º) |
| 18:36:59 | **«audio robotico»** | sí (10.º) |
| 18:39:39 | **«audio robotico»** | sí (11.º) |

**El recuento, sin interpretar: 10 capturas de evento dicen «audio robotico» y 1 dice «corte seco».**

**Contexto declarado por el propietario, en sus propias palabras:**

- 20-sep 16:43 — sobre el evento de 16:42: *«era algo robotico de menos de un segundo pero lo puse
  como corte seco»*.
- 20-sep 18:02 — sobre el de 18:02: *«otra vez audio robotico, tardó como 5 segundos en cambiar de
  ventana y poner el comando»*.
- Antes, con el RME **por USB** como transporte de audio: *«varias veces por hora oía distorsión
  robótica por un segundo»*. Por **óptico**: *«un par de veces al día, si acaso»*.

**Hecho, no interpretación:** el término «corte seco» **lo propuse yo** (20-sep 16:24) y el
propietario lo usó **una vez**, aclarando a la vez que lo que oyó fue «algo robótico». Las diez
capturas siguientes volvieron a su propia palabra. **«Robótico» es su descripción; «corte seco» es
la mía, adoptada una vez.**

## A2. Lo que muestran las once capturas

En las **once** capturas de evento, medido entre 2 y 5 s **después** de oído el fallo:

| campo | valor observado |
|---|---|
| `state` (card1) | `RUNNING` en las once |
| `delay` | entre 473 y 1981 frames — dentro del ciclo normal del búfer |
| `appl_ptr − hw_ptr` | idéntico a `delay` en todas |
| xruns de PipeWire (ventana 60 s) | **0** |
| errores de kernel (ventana 60 s) | **0** |
| errores de gamescope (ventana 60 s) | **0** |
| `Sync Source` | `SPDIF` |
| `SPDIF Sync` | `Sync` |
| `SPDIF Interface` | `Óptico` |
| sink por defecto | `alsa_output.pci-0000_00_1f.3.iec958-stereo` |
| `log.level` de PipeWire | `"2"` (medido con `pw-cli info 0`) |

**Los nueve eventos ocurrieron con S.T.A.L.K.E.R. 2 abierto** (declarado por el propietario).

## A3. El journal en las ventanas de los eventos

Las consultas a `journalctl` en las ventanas de los eventos **no devuelven ninguna línea**, ni de
audio ni de otro tipo. Literalmente: `-- No entries --`.

## A4. La vigilancia continua

`vigilar.sh` v4 corrió sin interrupción durante las ventanas de los eventos 8.º, 9.º, 10.º y 11.º.
Sus latidos, medidos:

| latido | hora | `iter` acumuladas | intervalo real |
|---|---|---|---|
| #1 | 18:14:27.223 | 1 | — |
| #2 | 18:19:27.210 | 1279 | **234,7 ms/vuelta** |
| #5 | 18:34:27.168 | 5136 | — |
| #6 | 18:39:27.173 | 6421 | **233,5 ms/vuelta** |

En todos los latidos: `cambios=0 sesiones=0 xruns=0 delta_bajo=0`.

**Lo que eso significa, literalmente:** entre dos latidos consecutivos, el vigilante no encontró
ninguna de las cosas que sabe buscar (C2). **No significa «no pasó nada»** — ver C2.

## A5. Los relojes y las tasas

Medido contando frames del contador continuo:

| ventana | duración | tasa medida | desviación |
|---|---|---|---|
| Sesión A | 2982 s | 47 939,19 Hz | −0,1267 % |
| Sesión C (4 marcas) | 701 s | 47 940,09 Hz | −0,1248 % |
| Sesión C (6 marcas) | 1994 s | 47 922,08 Hz | −0,1623 % |

Sub-ventanas de la sesión C, por duración: `31,8 s → −0,5214 %` · `474,7 s → −0,1055 %` ·
`700,9 s → −0,1306 %` · `975,5 s → −0,1697 %` · `1993,6 s → −0,1623 %`.

**Dispersión entre las tres ventanas largas: 18,01 Hz = 0,0375 puntos porcentuales.**

Sesiones PCM identificadas por `trigger_time`:
`22831,259838722` (A) · `28660,621866239` (B) · `29113,226834977` (C, seis capturas) ·
`35167,544656583` (posterior, ya sin eventos).

## A6. Los intervalos entre eventos

**2811 · 244 · 32 · 443 · 226 · 275 · 857 · 161 s** (ocho intervalos, 5048 s = 84,1 min).

Rango: **de 32 s a 47 min.**

## A7. La cadena y el sistema

```
apps → placa madre iec958-stereo (S/PDIF) → CABLE ÓPTICO → RME ADI-2 DAC
USB = SÓLO CONTROL
```

El sink correcto es `iec958-stereo`. Mandar el audio al sink del RME por USB da silencio.

El RME, cuando se usaba **como transporte de audio por USB**, daba el mismo síntoma con mucha más
frecuencia percibida (A1).

---
---

# PARTE B — INTERPRETADO

**Cada punto lleva su nivel de confianza y qué lo refutaría.** Si algo no lleva nivel, es un hecho y
está en la Parte A.

## B1. El fallo es transitorio y se recupera solo — **confianza alta**

Las once capturas, tomadas 2–5 s después, muestran todo sano. No hay estado de error persistente.

*Lo refutaría:* una captura que mostrara `XRUN` o el PCM cerrado, o que el audio no volviera solo.

## B2. No es un underrun sostenido — **confianza media-alta**

Un vaciado de búfer sostenido dejaría `XRUN` o un cambio de sesión visible 2–5 s después. No aparece.

*Lo debilita:* el canal que lo sostiene es de muestreo (C2). Un vaciado **breve**, recuperado dentro
del intervalo, no se vería. Es decir: **excluye el underrun sostenido, no el breve.**

## B3. «El software está descartado» — **RETIRADO. No está establecido.**

Esta conclusión estaba en la versión anterior de esta bitácora y **era un salto lógico**. Se retira.

Se sostenía en: «el vigilante registró 0 cambios, 0 sesiones, 0 xruns → el fallo no deja rastro en el
software → no es software».

**El fallo del razonamiento:** «mi instrumento no lo vio» **no es** «no ocurrió». Para que la
ausencia de rastro signifique algo, el instrumento tendría que ser **capaz de ver** un fallo de ese
tipo. Y no lo es, por cinco razones medidas (C2) más una suposición sin verificar (C3).

**Y hay un segundo problema, independiente del primero:** el fallo aparece en **dos transportes
distintos** (USB y óptico) **con la misma pila de software** (A1, A7). Eso hace del software un
**factor común**, no un descartado. Es exactamente lo contrario de lo que decía la conclusión.

**Estado correcto: el software NO está descartado. Es una de las hipótesis vivas, y la prueba que la
discrimina sigue pendiente (B7).**

## B4. El dato de USB contra óptico — y una advertencia sobre él

**Lo que se sabe (A1):** con el RME por **USB** como transporte de audio, el propietario oía el
síntoma *«varias veces por hora»*. Por **óptico**, *«un par de veces al día, si acaso»*.

**Lo que se concluyó antes:** «el óptico falla mucho menos → el cable óptico es el sospechoso».

**Lo que ese dato implica de verdad, y que se pasó por alto:** si el síntoma aparece por dos
transportes que **no comparten hardware** —USB no usa el cable, ni el transmisor S/PDIF de la placa,
ni el receptor óptico del RME—, entonces **ninguno de esos tres elementos puede ser la causa
suficiente por sí solo.** Los elementos comunes a los dos caminos son:

- la pila de software (apps → PipeWire → ALSA),
- la etapa interna del RME posterior al receptor,
- y todo lo de después (conversión D/A, amplificador, audífonos).

**Advertencia sobre la comparación de frecuencias:** los «varias veces por hora» y el «un par al
día» **no son comparables**, porque no se midieron en la misma condición. La medición de hoy da
**~1 evento cada 10,5 min bajo juego** (A6) — es decir, unas **6 por hora**, del mismo orden que lo
que se atribuía al USB. **Puede que la diferencia percibida entre USB y óptico fuera en realidad la
diferencia entre jugar y no jugar**, y no entre los dos transportes.

**Confianza en esta relectura: media.** Se apoya en que el síntoma aparece en dos caminos sin
hardware común, que es un dato declarado y consistente. *Lo refutaría:* que los dos síntomas no
fueran el mismo fenómeno (que es justamente lo que A1 deja abierto).

## B5. La causa está en la capa física — **hipótesis, confianza baja-media**

Sigue siendo la hipótesis que encabeza la lista, pero **por eliminación débil, no por evidencia
directa**. No hay ninguna medición del cable, ni de la señal óptica, ni de la tasa de error de nada.

**Hipótesis concreta, no verificada:** el SteadyClock del RME mantiene el enganche **aunque el flujo
llegue degradado** (manual §31.3). Un cable marginal daría *enganche estable + artefactos
esporádicos + cero rastro en los registros*.

**Límite duro de esa hipótesis:** un error de bit en la luz **no mueve el `hw_ptr`** ni cambia el
estado del PCM. Por tanto **el contador y el vigilante no pueden corroborarla ni refutarla.** La
hipótesis es compatible con los datos, y eso no es lo mismo que estar apoyada por ellos.

**Lo que la debilita:** B4. Si el síntoma también aparece por USB, el cable no puede ser la causa
única.

## B6. El reloj no está averiado — **confianza media, con una condición**

La desviación de ~0,13–0,16 % es estable entre ventanas largas y no hay xruns. Que un reloj de audio
de consumo no dé los 48 000 Hz exactos es normal.

**La condición:** «no hay xruns» descansa en la suposición **sin verificar** de C3. Sin el control
positivo, esta parte de B6 es más débil de lo que parece.

*Lo refutaría:* una desviación que cambiara de signo o de orden entre ventanas, o un xrun registrado.

## B7. Qué prueba discrimina qué — **esto es lo que convierte la lista en algo útil**

| prueba | qué separa | coste | estado |
|---|---|---|---|
| **Control positivo del instrumento** (provocar un xrun a propósito y ver si queda registrado) | si el «0 xruns» significa algo | bajo | **pendiente, y es previa a todo lo demás** |
| **Escuchar sin el juego abierto** | causa dependiente de carga vs. independiente | 0 | pendiente |
| **Cambiar el cable óptico** | el cable | bajo | pendiente |
| **Mismo PC por coaxial** | transmisor de la placa vs. receptor óptico del RME | bajo | pendiente |
| **Otro DAC por el mismo cable** | el receptor del RME | 0 | pendiente |
| **Volver a USB y medir la frecuencia con el instrumento** | si el «USB falla más» es real o era la condición de escucha | bajo | pendiente |

**La primera es nueva y va antes que las demás:** sin saber si el instrumento *puede* registrar un
xrun, todos los «0 xruns» de esta bitácora son un dato de valor desconocido.

---
---

# PARTE C — EL INSTRUMENTO

## C1. Qué ve `audio-debug`

Es una foto del estado **2–5 s después** del fallo. Tarda ~0,53 s, pero la brecha la pone el tiempo
de reacción humano (oír → cambiar de ventana → teclear). **Ninguna versión más rápida cambiaría
eso**, porque la brecha no está en el script.

## C2. Qué ve `vigilar.sh` — y sus cinco puntos ciegos

**Esto es lo que faltaba en la versión anterior de la bitácora.** El vigilante **no es un registro
continuo**: es un muestreador que solo escribe para ciertas formas de cambio.

**Lo que sabe buscar** (líneas 88–144 de `vigilar.sh`):

- `state: XRUN` literal
- un cambio en el campo `state:`
- un cambio en `trigger_time` (sesión PCM nueva)
- `delta < 200` frames
- un subdispositivo nuevo
- eventos de kernel de audio/USB

**Sus cinco puntos ciegos, todos verificados en el código:**

1. **Muestrea, no observa continuamente.** `sleep 0.2` más el coste del bucle dan **~234 ms por
   vuelta** (medido, A4). **Un fallo más corto que el intervalo puede caer entero entre dos
   muestras y no verse nunca.**

2. **Omite los PCM cerrados.** Línea 86: `[ -n "$ST" ] || continue`. Si el fichero de estado dice
   `closed`, no tiene línea `state:` y **el subdevice se salta sin dejar rastro en el log**. Un corte
   en que el PCM se cierre no se registra mientras está cerrado.

3. **Solo escribe para las formas de la lista de arriba.** Un fallo que no adopte ninguna de esas
   formas **es invisible por construcción, no por ausencia.** Y ese es precisamente el caso de la
   hipótesis principal (B5): un error de bit en la luz no cambia ninguna de esas seis cosas.

4. **`prev_state` es una sola variable compartida entre subdispositivos** (líneas 97–121). Con dos
   subdispositivos abiertos a la vez, compararía uno contra otro y podría reportar un cambio de
   sesión falso. Hoy no ocurre porque normalmente solo hay uno abierto, pero **es un fallo latente**,
   no una garantía.

5. **La comprobación `delta < 200` es de un instante.** Un vaciado breve del búfer que no coincida
   con una muestra no se ve.

**Conclusión honesta:** el silencio del vigilante significa **«no ocurrió ninguna de las seis cosas
que sabe buscar, con una resolución de ~234 ms»**. Eso es un dato real y útil. **No significa «no
ocurrió ningún fallo», y no puede usarse para descartar una causa cuya firma esté fuera de esa
lista.**

## C3. La suposición sin verificar: no hay control positivo

Todo el argumento «0 xruns ⇒ no hubo xrun» descansa en que **PipeWire registre los xrun a
`log.level=2`**. Eso **no está verificado**.

**El dato que lo muestra:** desde el 1-sep-2026 hay **0 líneas con xrun** en el journal de PipeWire.
**No existe ni un solo ejemplo de cómo se ve un xrun en ese log.** Sin un caso positivo, no se puede
afirmar que un xrun *se habría* registrado: podría estar registrándose a un nivel superior, o no
registrarse.

**Cómo se cierra:** provocar un xrun a propósito —carga alta con un quantum pequeño— y comprobar si
aparece en el journal. Es barato y **convierte todos los «0 xruns» de la Parte A de un dato de valor
desconocido en un dato sólido.**

## C4. Las trampas de `audio-debug` (las cuatro de antes, siguen vigentes)

1. **No meter la salida de `pw-dump` en una variable exportada.** Devuelve **5,7 MB** y `ARG_MAX` son
   **2 MB**. Al exportarla, **todo proceso hijo siguiente muere** con «La lista de argumentos es
   demasiado larga». El síntoma engaña: señala a `head`, `sed`, `cat`… y el culpable es **el entorno
   que heredan**. Solución: **fichero temporal**.

2. **`pcm0p/sub0/status` contiene solo la palabra `closed`.** En card1 hay dos subdispositivos y **el
   primero por orden alfabético está cerrado**, sin ningún campo. Tomarlo con un `break` deja **todas
   las variables vacías, sin dar error**. Seleccionar por **contenido**, no por posición del glob.

3. **Los campos alinean los dos puntos con espacios** (`delay       : 775`), **pero `trigger_time:`
   no los lleva.** Un patrón `s/^delay: //p` **nunca casa**, y falla **en silencio**: imprime `?`
   donde va un número, y eso se lee como «no hay dato».

4. **Un aviso que salta en estado sano es peor que no tener aviso.** Se probó con `delay` y saltaba
   siempre, porque **`delay` y `delta` son la misma distancia** (829/829, 979/979, 745/745, 550/550,
   862/862, 524/524). Se retiró. El único aviso que queda es `state != RUNNING`.

## C5. Criterios válidos

- **Señal inequívoca de fallo: `state: XRUN`.** Todo lo demás no distingue sano de averiado.
- **`hw_ptr` NO sirve como prueba.** Es **RELATIVO a la sesión PCM**: vuelve a 0 en cada reapertura.
- **Antes de restar dos punteros, comparar el `trigger_time`.** Si no coincide, **no hay resta**.
- **`avail_max` NO cuenta xruns.**
- **`delay` NO es alarma.** Es la misma distancia que `delta`.
- **`RUNNING` en `/proc/asound` no prueba que suene**: el nodo puede estar `corked` o suspendido.
- **Un silencio en el log NO es una ausencia** — es «no se vio ninguna de las formas que se buscan».
  Ver C2.

---
---

## Afirmaciones propias que resultaron FALSAS

Ocho. Se dejan escritas para no repetirlas.

| # | afirmación | por qué era falsa |
|---|---|---|
| 1 | `delta ≈ 970–1020` como «firma normal» | artefacto de muestreo: el delta hace diente de sierra |
| 2 | «saltos de `hw_ptr`» | el contador se reinicia entre sesiones PCM |
| 3 | gamescope como «hilo más prometedor» | 0 errores en los eventos capturados |
| 4 | «cuadre por múltiplos del búfer» | válido solo en tramos cortos, y se aplicó a largos |
| 5 | «la regularidad de 16,7 min» | refutada por el 4.º y el 5.º evento |
| 6 | «la regla ALSA no cubre `iec958`» | al medir el nodo, tiene las mismas propiedades |
| 7 | «la convergencia limpia a −0,1248 %» | con más marcas se movió a −0,1623 % |
| 8 | **«la cobertura del vigilante descarta el software»** | **un instrumento que muestrea no puede establecer la ausencia de fallos cuya firma no sabe ver (C2), y además el fallo aparece en dos transportes con la misma pila de software (B4)** |

**Las siete primeras son de la misma familia: contabilidad y muestreo** —tratar como continuo o como
completo algo que se reinicia, que se promedia mal o que se muestrea. **La octava es de otra familia,
y por eso vale la pena nombrarla: es un error de ALCANCE DEL INSTRUMENTO.** Confundir «mi
instrumento no lo vio» con «no ocurrió». Es la más peligrosa de las ocho, porque **produce
conclusiones que parecen las más sólidas**: no se apoya en un dato dudoso, sino en un silencio.

**Regla que sale de la octava:**
**antes de usar un silencio como prueba, hay que poder enumerar qué formas de fallo ese instrumento
sería capaz de ver. Si la hipótesis que se quiere descartar no está en esa lista, el silencio no
dice nada sobre ella.**

---

## Historial del instrumento

- **v1** — versión inicial: captura completa de 10 secciones, sin resumen.
- **v2 (20-sep-2026)** — una sola llamada a `pw-dump` (antes dos), `trigger_time` y `delta` en el
  encabezado, línea `RESUMEN` grepeable, **carga instantánea** por `/proc/pressure/cpu` en lugar de
  `ps -eo pcpu`, aviso si `log.level < 2`, selección correcta del subdevice. **0,61 s → 0,53 s.**

En la reescritura a v2 aparecieron **tres de las trampas de C4**: una **introducida por mí** (el
`export` de 5,7 MB), una **latente de v1** (el subdevice cerrado) y una **silenciosa** (los patrones
de `sed`).

**Cambios de ubicación:** el script y la bitácora pasaron a `share/scripts/`; el log pasó de
`~/.local/state/audio-debug/marcas.log` a `share/scripts/audio-debug.log`. Las 13 capturas de
entonces se conservaron íntegras.

---

## Pendiente

Por orden, y con el motivo:

- [ ] **Control positivo del instrumento.** Provocar un xrun a propósito y ver si PipeWire lo
      registra. **Va primero**: sin esto, todos los «0 xruns» de esta bitácora valen un valor
      desconocido (C3).
- [ ] **Escuchar sin el juego abierto** y capturar el primer evento de ahí. Discrimina si la causa
      depende de la carga (B7).
- [ ] **Cambiar el cable óptico.** La prueba más directa del candidato principal (B5).
- [ ] **Mismo PC por coaxial** y **otro DAC por el mismo cable**: separan transmisor, cable y
      receptor.
- [ ] **Volver a USB y medir la frecuencia con el instrumento**, para saber si el «USB falla más» es
      real o era la condición de escucha (B4).
- [ ] `api.alsa.headroom = 0` en `iec958` mientras el RME pide 2048 — **el margen está en el nodo
      equivocado.** Descartado como causa; sin cambiar.

## Cuestiones abiertas que no son pruebas

- [ ] **¿«Corte seco» y «robótico» son el mismo síntoma?** No se puede resolver con los datos de
      este sistema: hace falta el oído del propietario. **Mientras no se sepa, tratar las once
      capturas como un solo fenómeno es una suposición**, no un hecho (A1).
