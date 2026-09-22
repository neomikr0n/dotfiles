# Anexo — Distorsión: detalle completo

Movido aquí el 21-sep-2026 para que `MEMORY.md` quepa en su límite.
`MEMORY.md` conserva las REGLAS y el ESTADO; aquí está el detalle de las mediciones.
El desarrollo completo, con secciones y correcciones, sigue en
`/home/n30/dotfiles/context/audio/diagnostico_distorsion_tiempo_real.md` (2 117 líneas).

---

## Distorsión — investigación 20-21 sep-2026 (leer esto primero)
→ **Todo el detalle está en `diagnostico_distorsion_tiempo_real.md`** (2 117 líneas, 21 secciones).
Bitácora legible: **`share/scripts/audio-debug.md`** (Parte A observado / B interpretado / C
instrumento). **NUEVE EVENTOS en una tarde, sin cambiar nada** (16:42:11 → 18:39:39); el usuario
ejecuta `audio-debug` al oírlos. **13 de 13 campos idénticos:** `RUNNING`, `delay` sano, 0 xruns, 0 de
kernel, 0 de gamescope, `Sync`/`Source=SPDIF`/`Interface=Óptico`, enrutamiento correcto. El journal de
la ventana da **«No entries»**. **La marca va DESPUÉS del fallo** (~2 s de reacción humana; el script
tarda 0,53 s) y el fallo dura <1 s → lo medido es estado POSTERIOR. **Esa brecha no se cierra
mejorando el script.** **Un log limpio que NO abarque la ventana del fallo no es negativo, es un vacío.**
**NO HAY PERÍODO.** Intervalos: 2811 · 244 · 32 · 443 · 226 · 275 · 857 · 161 s → **rango de 32 s a
47 min: son RÁFAGAS, no un goteo**; la media engaña, no sirve para predecir.
**Tasa:** desviación ~0,13–0,16 % estable → el reloj no es exacto pero no está averiado. **REGLA: los
tramos cortos no valen** (una ventana de 31,8 s daba −0,60 %); la dispersión real entre ventanas largas
es 0,0375 puntos. **Tres sesiones PCM distintas; `hw_ptr` vuelve a 0 por sesión.**

### ★ CORRECCIÓN 21-sep-2026: «el software está descartado» SE RETIRA (8.ª afirmación falsa)
**Error de ALCANCE, no de datos: «mi instrumento no lo vio» NO es «no ocurrió».** El silencio se usó
como prueba. **Cinco puntos ciegos del vigilante** (verificados en `vigilar.sh`): (1) **muestrea** cada
~234 ms, no observa; (2) **omite los PCM cerrados** (línea 86: sin `state:` → se salta **sin dejar
línea**); (3) **solo ve SEIS formas** de fallo (XRUN · cambio de `state:` · cambio de `trigger_time` ·
`delta<200` · subdispositivo nuevo · kernel) → **cualquier otra firma es invisible POR CONSTRUCCIÓN**;
(4) `prev_state` es una variable **compartida** entre subdispositivos (latente); (5) `delta<200` es de
un instante. **Y la hipótesis del cable predice silencio → era NO FALSABLE con este instrumento.**
**Segundo motivo, independiente:** el síntoma aparece **por USB y por óptico**, y esos dos caminos **no
comparten hardware** (driver, cable, transmisor, receptor) → **ni el cable ni el transmisor ni el
receptor del RME pueden ser causa suficiente solos**; lo común es **la pila de software**, la etapa
interna del RME y lo de después → **el software es FACTOR COMÚN, no descartado.** Ojo: «varias/hora por
USB» vs «un par al día por óptico» **no son comparables** (distinta condición de escucha); bajo juego
medimos ~6/hora → **puede que la diferencia fuera jugar vs no jugar.**
**FALTA EL CONTROL POSITIVO:** **0 xruns desde el 1-sep** → **no hay ni un ejemplo de cómo se ve un
xrun en el log de PipeWire** → «0 xruns ⇒ se habría registrado» es una suposición **sin verificar**.
**Prueba que va LA PRIMERA:** provocar un xrun a propósito y ver si queda registrado.

**Estado de la causa: NO atribuida.** Cuatro candidatos sin aislar: **pila de software · cable óptico ·
transmisor S/PDIF de la placa · recepción del RME**. Orden de pruebas: **0) control positivo del
instrumento** · 1) **escucha pasiva sin juego** · 2) cambiar el cable · 3) mismo PC por **coaxial** ·
4) otro DAC por el mismo cable · 5) volver a USB y medir frecuencia.
**Hipótesis (no verificada, §31.3):** el SteadyClock engancha **aunque el flujo llegue degradado** →
cable marginal daría *enganche estable + artefactos esporádicos + silencio en los registros + bajo
carga*. **Alcance:** un error de bit en la luz **no mueve el `hw_ptr`** → el contador **no corrobora ni
refuta** el cable. **Los 9 eventos fueron con Stalker abierto; falta uno fuera.**

**Criterios válidos:** la señal inequívoca es **`state: XRUN`**; los punteros NO sirven. **`hw_ptr` es
RELATIVO a la sesión PCM.** **`avail_max` NO cuenta xruns.** **`delay` NUNCA es alarma** (= `delta`).
**Un silencio en el log NO es una ausencia** — es «no se vio ninguna de las formas que se buscan».
Medir el nodo con `pw-dump`, no leer el `.conf`. Antes de restar dos punteros, comparar `trigger_time`.

**Nomenclatura — prescripción RETIRADA:** el log dice **«audio robotico» en 10 capturas de evento y
«corte seco» en 1**, y «corte seco» **lo propuse yo** (el usuario lo usó una vez aclarando que oyó
«algo robótico»). **No consta que sean el mismo síntoma: cuestión ABIERTA.** Copiar sus palabras
**literales**. Lo que sí sigue en pie: no usar la palabra como **afirmación causal**.

**OCHO afirmaciones propias FALSAS** (§10) — las 7 anteriores (`delta ≈ 970–1020` · saltos de
`hw_ptr` · gamescope como «hilo más prometedor» · cuadre por múltiplos del buffer · la regularidad de
16,7 min · «la regla ALSA no cubre `iec958`» · «convergencia limpia a −0,1248 %») **+ la 8.ª: «la
cobertura del vigilante descarta el software»**. **Las 7 primeras son de contabilidad/muestreo; la 8.ª
es de ALCANCE DEL INSTRUMENTO y es la más peligrosa, porque no se apoya en un dato dudoso sino en un
silencio.** Regla: **antes de usar un silencio como prueba, poder enumerar qué habría aparecido en el
log si la hipótesis fuera cierta.**

**Instrumentos:** `audio-debug` (**v2**) → estado posterior completo;
`~/.local/state/audio-debug/vigilar.sh` (**v4**, 200 ms, latido 300 s) → **NO es registro continuo**:
muestrea y solo ve seis formas de fallo (ver arriba).

