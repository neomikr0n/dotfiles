# Bitácora — `audio-debug`

Registro de hallazgos del fallo intermitente de audio, de septiembre de 2026 en adelante.
**Detalle completo en `/home/n30/dotfiles/context/audio/diagnostico_distorsion_tiempo_real.md`.**
Aquí van las conclusiones; allí, el desarrollo y las pruebas.

## Las dos piezas

| Pieza | Ruta | Para qué |
|---|---|---|
| `audio-debug` | `share/scripts/audio-debug` (enlace en `~/.local/bin/audio-debug`) | Captura el estado **cuando** se oye el fallo |
| `audio-debug.md` | `share/scripts/audio-debug.md` | Esta bitácora: qué se ha concluido |
| `audio-debug.log` | `share/scripts/audio-debug.log` | Las capturas completas, para rehacer análisis |
| `vigilar.sh` (v4) | `~/.local/state/audio-debug/vigilar.sh` | Muestrea cada 200 ms; da **cobertura continua** |

**Las tres piezas del instrumento viven juntas:** script, bitácora y capturas están en
`share/scripts/`. El script localiza las otras dos **a partir de su propia ruta**, así que mover la
carpeta entera no rompe nada.

Hasta el 20-sep-2026 el log estaba en `~/.local/state/audio-debug/marcas.log`; se movió aquí para
tener todo en el mismo sitio. El `vigilar.sh` sigue en `~/.local/state/` porque es un proceso en
marcha y su log de eventos no es el mismo que este.

El enlace en `~/.local/bin` existe porque `share/scripts` no está en el PATH; así basta con escribir
`audio-debug`. Si se mueve la carpeta, basta con rehacer el enlace.

`marca-audio` (el nombre anterior) quedó retirado: es la misma herramienta con otro nombre.

## Cómo se usa

```
audio-debug "corte seco mientras jugaba"
```

La descripción es libre. Al terminar imprime una línea resumen y avisa **solo** si hay señal
inequívoca (`state != RUNNING` o CPU saturada). Si no avisa, es porque no hay nada anómalo que
avisar — no porque el script no haya funcionado.

### Si la captura sale con `estado=?`

**No es un fallo del script.** Significa que **no había ninguna sesión PCM abierta** en la placa
madre en ese momento: `pcm0p` y `pcm1p` contenían los dos la palabra `closed`.

Es lo normal si se ejecuta el script **sin audio sonando**, o si el flujo está en pausa. Comprobarlo
así:

```
cat /proc/asound/card1/pcm*p/sub*/status      # «closed» = no hay sesión
```

Con audio sonando, lo correcto es `state: RUNNING` con `trigger_time`, `tstamp`, `hw_ptr` y
`appl_ptr`. **Verificado el 20-sep-2026:** con audio, `estado=RUNNING delay=1981 delta=1908`; sin
audio, los dos subdevices en `closed` y todos los campos en `?`.

Un `?` en la captura de un evento real **sí** sería informativo: querría decir que el PCM se cerró
justo ahí, cosa que no ha pasado en ninguno de los nueve eventos (los nueve dieron `RUNNING`).

---

## El fallo que se investiga

Un **corte seco / chispa breve** de menos de un segundo, esporádico, mientras se juega.
(Debe describirse así; «distorsión robótica» condiciona el diagnóstico — llevó a culpar al
remuestreo, que resultó inocente.)

## La cadena

```
apps → placa madre iec958-stereo (S/PDIF) → CABLE ÓPTICO → RME ADI-2 DAC
USB = SÓLO CONTROL
```

El sink correcto es `alsa_output.pci-0000_00_1f.3.iec958-stereo`. Mandar el audio al sink del RME
por USB da silencio: ese enlace solo lleva comandos.

---

## Estado de la investigación (20-sep-2026, 18:50)

### Lo que está establecido

1. **Nueve eventos capturados, sin cambiar nada.**
   16:42:11 · 16:58:49 · 17:15:31 · 18:02:22 · 18:06:26 · 18:14:20 · 18:18:07 · 18:36:59 · 18:39:39.

2. **13 de 13 campos idénticos en los nueve.** Todos: `RUNNING`, `delay` sano, **0 xruns**,
   0 errores de kernel, 0 de gamescope, reloj `Sync` / `Source=SPDIF` / `Interface=Óptico`,
   enrutamiento correcto.

3. **El journal está literalmente vacío en las ventanas de los eventos:** las consultas devuelven
   «No entries» — **cero líneas, de ningún tipo.**

4. **Los 0 xruns son un dato válido, no un vacío de instrumentación.** `log.level = 2` está
   verificado con `pw-cli info 0` → un xrun **se habría registrado**. (El script comprueba este
   nivel por sí solo y avisa si bajara de 2.)

5. **Cobertura de vigilancia DEMOSTRADA en tres eventos (7.º, 8.º y 9.º).** El vigilante muestreó
   cada ~234 ms en ventanas que **encierran** los fallos, y registró
   `cambios=0 sesiones=0 xruns=0`. → **«El fallo no deja rastro en el PCM de la placa madre» es
   observación directa, tres veces, no una inferencia.**

6. **La causa está descartada en el software**, no en el PCM de la placa madre.

### Lo que queda abierto

**Tres candidatos físicos, ninguno aislado:**

- el **cable óptico** (el más sospechoso)
- el **transmisor S/PDIF de la placa madre**
- la **recepción del RME**

**Hipótesis principal, NO verificada:** el SteadyClock del RME mantiene el enganche **aunque el flujo
llegue degradado** (manual §31.3). Un cable marginal daría exactamente el cuadro observado:
*enganche estable + artefactos esporádicos + CERO rastro en software + correlación con la carga*.

**Límite de esta hipótesis:** un error de bit en la luz **no mueve el `hw_ptr`** → el contador
**no corrobora ni refuta** el cable. La hipótesis es plausible, no está probada.

**Pruebas que falta hacer** (ninguna cuesta dinero si hay material a mano):

1. **Cambiar el cable óptico.** La más directa.
2. **Escuchar sin el juego abierto.** Los nueve eventos fueron con Stalker 2; **no hay ninguno en
   escucha pasiva.** Es la prueba más informativa y la más barata.
3. Mismo PC por **coaxial**.
4. Otro DAC por el mismo cable.

---

## Los números de la tasa

Medida contando frames con el contador continuo:

| ventana | duración | tasa | desviación |
|---|---|---|---|
| Sesión A | 2982 s | 47 939,19 Hz | −0,1267 % |
| Sesión C (4 marcas) | 701 s | 47 940,09 Hz | −0,1248 % |
| Sesión C (6 marcas) | 1994 s | 47 922,08 Hz | **−0,1623 %** |

**La desviación ~0,13–0,16 % es estable y no hay xruns** → el reloj no es exacto pero **no está
averiado**. Que un reloj de audio de consumo no dé los 48 000 Hz exactos es normal.

**Corrección que hay que conservar:** al principio se destacó una diferencia de **0,0019 puntos**
entre las dos sesiones como prueba fuerte. **Era optimista.** Al añadir marcas a la sesión C la tasa
se movió y la dispersión real entre ventanas largas resultó **0,0375 puntos, el triple**. La cifra se
obtuvo comparando dos ventanas elegidas, no todas. **La conclusión general se mantiene; esa
interpretación concreta, no.**

**Regla: los tramos cortos no valen.** La sesión C con 2 marcas (31,8 s) daba **−0,60 %**. El
criterio operativo es la **convergencia**: si añadir una marca mueve poco el resultado, la ventana
basta — pero con 4 puntos todavía se movía.

**No hay período.** Los ocho intervalos entre los nueve eventos:
**2811 · 244 · 32 · 443 · 226 · 275 · 857 · 161 s**.
Rango de **32 s a 47 min**: son **ráfagas separadas por calma**, no un goteo regular. La media
(~10,5 min bajo juego) **describe mal la distribución y no sirve para predecir**.

---

## Las trampas del instrumento (aprendidas a golpes)

Estas son las que costaron tiempo y están comentadas dentro del script:

1. **No meter la salida de `pw-dump` en una variable exportada.** Devuelve **5,7 MB** y `ARG_MAX` son
   **2 MB**. Al exportarla, **todo proceso hijo siguiente muere** con «La lista de argumentos es
   demasiado larga». El síntoma engaña: señala a `head`, `sed`, `cat`… y el culpable es **el entorno
   que heredan**. Solución: **fichero temporal**, que no pasa por el entorno.

2. **`pcm0p/sub0/status` contiene solo la palabra `closed`.** En card1 hay dos subdevices de
   reproducción y **el primero por orden alfabético está cerrado**, sin ningún campo. Tomarlo con un
   `break` deja **todas las variables vacías, sin dar error**. Hay que seleccionar por **contenido**
   (que tenga `state`), no por posición del glob.

3. **Los campos alinean los dos puntos con espacios** (`delay       : 775`), **pero `trigger_time:`
   no los lleva.** Un patrón `s/^delay: //p` **nunca casa**. Usar siempre `s/^NOMBRE *: *//p`.
   Peligroso porque falla **en silencio**: imprime `?` donde va un número, y eso se lee como
   «no hay dato» en vez de «el patrón está mal».

4. **Un aviso que salta en estado sano es peor que no tener aviso.** Se probó a avisar por `delay` y
   saltaba siempre, porque **`delay` y `delta` son la misma distancia** medida desde los dos extremos
   del búfer (en las 6 marcas de una sesión sana: 829/829, 979/979, 745/745, 550/550, 862/862,
   524/524). Se retiró. El único aviso que queda es el de **`state != RUNNING`**.

---

## Criterios válidos — la lista que evita perder el tiempo

- **Señal inequívoca de fallo: `state: XRUN`.** Todo lo demás no distingue sano de averiado.
- **`hw_ptr` NO sirve como prueba.** Es **RELATIVO a la sesión PCM**: vuelve a 0 en cada reapertura.
- **Antes de restar dos lecturas de punteros, comparar el `trigger_time`.** Si no coincide,
  **no hay resta** — son sesiones distintas.
- **`avail_max` NO cuenta xruns.**
- **`delay` NO es alarma.** Es la misma distancia que `delta`.
- **Un journal limpio solo vale con `log.level >= 2`.** El script lo comprueba.
- **`RUNNING` en `/proc/asound` no prueba que suene**: el nodo puede estar `corked` o suspendido.

---

## El límite del instrumento — y por qué hay dos

`audio-debug` tarda **~0,5 s**, pero entre oír el fallo y ejecutarlo pasan **2–5 s** (oído → cambiar
de ventana → teclear). **Esa brecha es tiempo de reacción humano.** Como el fallo dura <1 s, todo lo
que captura es el **estado posterior**, nunca el instante del fallo.

**Ninguna versión más rápida cambiaría eso.** Para cubrir el «durante» hace falta **registro
continuo**, y para eso está `vigilar.sh`. Los dos son complementarios:

| instrumento | captura | no puede capturar |
|---|---|---|
| `audio-debug` | el estado **posterior**, completo y legible | el instante del fallo |
| `vigilar.sh` | **ausencia de rastro DURANTE**, por latidos | el detalle completo del instante |

---

## Afirmaciones propias que resultaron FALSAS

Se dejan escritas para no repetirlas. El patrón es siempre el mismo: **la lectura parecía confirmar
lo plausible, y el sesgo iba hacia lo cómodo.**

1. `delta ≈ 970–1020` como «firma normal» — era un artefacto de muestreo.
2. «Saltos de `hw_ptr`» — era el contador reiniciándose entre sesiones.
3. Los errores de gamescope como «hilo más prometedor» — **0 en los eventos capturados**.
4. 「Cuadre por múltiplos del buffer」 — válido solo en tramos cortos, y se aplicó a largos.
5. 「La regularidad de 16,7 min」 — refutada por el cuarto y el quinto evento.
6. 「La regla ALSA no cubre `iec958`」 — al medir el nodo, tiene las mismas propiedades.
7. 「La convergencia limpia a −0,1248 %」 — con más marcas se movió a −0,1623 %.

**Reglas que salieron de aquí:**
**medir el nodo con `pw-dump`, no leer el `.conf`** ·
**antes de restar dos punteros, comparar el `trigger_time`** ·
**una cifra que impresiona puede ser un artefacto de qué ventanas se eligieron para comparar.**

---

## Historial del instrumento

- **v1** — versión inicial: captura completa de 10 secciones, sin resumen.
- **v2 (20-sep-2026)** — una sola llamada a `pw-dump` (antes dos), `trigger_time` y `delta` en el
  encabezado, línea `RESUMEN` grepeable, **carga instantánea** por `/proc/pressure/cpu` en lugar de
  `ps -eo pcpu` (que da media de vida del proceso, no del instante), aviso si `log.level < 2`,
  selección correcta del subdevice, y el subdevice cerrado marcado como tal.
  **Tiempo medido: 0,61 s → 0,53 s.**

En la reescritura a v2 aparecieron **los tres fallos de la sección «trampas»**: uno **introducido por
mí** (el `export` de 5,7 MB), uno **latente de v1** (el subdevice cerrado) y uno **silencioso** (los
patrones de `sed`).

**Cambios de ubicación:**

| fecha | qué | dónde estaba antes |
|---|---|---|
| 20-sep-2026 | el script y la bitácora | `~/.local/bin/marca-audio` y la raíz del proyecto |
| 20-sep-2026 | el log de capturas | `~/.local/state/audio-debug/marcas.log` |

**Estado al mover el log:** las 13 capturas se conservaron íntegras (`grep -c '^MARCA'` →
13). El fichero se movió con `mv -n` y se verificó el contenido en el destino antes de dar por bueno
el cambio.

---

## Pendiente

- [ ] **Escuchar sin el juego abierto** y capturar el primer evento que ocurra ahí. Es la prueba
      más informativa que falta: los nueve eventos fueron con Stalker 2.
- [ ] Cambiar el cable óptico.
- [ ] Probar coaxial / otro DAC por el mismo cable.
- [ ] `api.alsa.headroom = 0` en `iec958` mientras el RME pide 2048 — **el margen está en el nodo
      equivocado.** Se descartó como causa; no se ha cambiado.
