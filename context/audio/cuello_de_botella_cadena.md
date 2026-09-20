# ¿Dónde está el cuello de botella de la cadena?

Levantamiento: **20 de septiembre de 2026**, sobre la máquina del propietario.

Convención: **[verificado]** = leído de la configuración o el manual del equipo;
**[razonado]** = conclusión propia a partir de datos verificados; **[sin confirmar]** = no
se pudo comprobar.

---

## 0. Respuesta corta

**El cuello de botella no está en la electrónica.** Está en el material que suena, en el
interfaz entre el audífono y tu oído, y en tu propia audición — en ese orden.

Lo único de la electrónica que hoy sí limita algo es **el PEQ de 5 bandas, que está
saturado**. Y eso se arregla gratis.

---

## 1. Lo que se verificó en tu máquina

### 1.1 Grafo de audio (`wpctl status`)

| Dato | Valor |
|---|---|
| Versión de PipeWire | 1.6.8 |
| **Sink por defecto** | **«Audio Interno Estéreo digital (IEC958)»** — **y es lo correcto**: un cable óptico lleva esa señal al RME |
| Sink del RME | ADI-2 DAC (51100523) Pro, volumen **1.00** (unidad) |
| Fuente (captura) por defecto | ADI-2 DAC Pro, volumen 0.85 |
| **EasyEffects** | **No está corriendo** |
| Cliente usando el RME | `qemu`, como dispositivo de **captura** (`capture_AUX0`/`AUX1`) |

**[CORREGIDO 20-sep 15:30]** Este apartado se escribió antes de saber el montaje real.

- ~~**El sink por defecto no es el RME.**~~ **Sí lo es, indirectamente.** El S/PDIF de la placa
  madre va por **cable óptico** a la entrada del ADI-2. Ese es el camino correcto y deliberado;
  el USB del RME sólo transporta **control** (volumen, perfiles, ADI-2 Remote). Ver
  `enrutamiento_audio_al_rme.md` §8.8.
- **El volumen del RME está a 1.00**, es decir, sin atenuación por software. Es lo correcto:
  no hay pérdida de bits en el dominio digital de PipeWire.

### 1.1-bis El transporte: óptico frente a USB (dato del propietario, 20-sep-2026)

**Observación de escucha, no medición:** con el RME **por USB** se oía una **distorsión
«robótica» de ~1 segundo, varias veces por hora**. Con el RME alimentado por el **cable óptico**,
el mismo evento ocurre **como mucho un par de veces al día** (el día del cambio, ninguna).

**Consecuencia para el orden de cuellos de botella:** en esta instalación el **transporte** tiene
un efecto audible **medible en frecuencia de fallos**, muy por encima de cualquier diferencia de
DAC, amplificador o PEQ. No cambia el orden general del §2 (grabación y máster siguen primero),
pero **el enlace óptico se confirma como la elección correcta** y no hay que «mejorarlo» pasando
a USB.

**Lo que NO se afirma:** la causa del fallo del USB. Ver `enrutamiento_audio_al_rme.md` §8.9.4
para los candidatos y por qué ninguno está verificado.

### 1.2 Configuración de PipeWire

`~/.config/pipewire/pipewire.conf.d/99-rme-fix.conf` **[verificado]**:

```
default.clock.rate          = 48000
default.clock.allowed-rates = [ 44100 48000 88200 96000 192000 ]
default.clock.quantum       = 1024
default.clock.min-quantum   = 512
default.clock.max-quantum   = 2048
mem.allow-mlock             = true
```

Estado en vivo (`pw-metadata -n settings`) **[verificado]**: `clock.rate = 48000`,
`clock.quantum = 1024`, `clock.force-rate = 0`, `clock.force-quantum = 0`.

`~/.config/pipewire/client.conf.d/resampling.conf` **[verificado]**: `resample.quality = 4`.

`~/.config/pipewire/pipewire.conf.d/alsa-hardware.conf` **[verificado]**:
`api.alsa.headroom = 2048`, `api.alsa.period-size = 2048`,
`session.suspend-on-idle = false`, `node.pause-on-idle = false`.

> **Corrección a la memoria del proyecto.** La nota interna decía que este perfil «fuerza
> 192 kHz». **Es falso.** El archivo actual fija **48 kHz por defecto** y sólo *permite*
> hasta 192 kHz. La afirmación era de una versión anterior del archivo (existe un
> `99-rme-fix(44KHZ).conf.BAK`), y quedó obsoleta. Corregido.

**Lo que esto implica [razonado]:** la frecuencia por defecto del grafo es 48 kHz. Un
archivo de 44,1 kHz se remuestrea a 48 kHz —una conversión **no entera**, el caso menos
limpio— salvo que el cliente pida su frecuencia nativa y el grafo esté inactivo, que es
justo lo que `allowed-rates` permite. `resample.quality = 4` es el valor por defecto de
PipeWire, **no el máximo** de la escala.

### 1.3 El PEQ: está lleno

Tu preset más reciente, `HEKSE-HarmanV4.adieqpr` (13-sep-2026) **[verificado]**:

| Elemento | Valor |
|---|---|
| Banda 1 | **+2,5 dB @ 40 Hz**, Q 0,90 |
| Banda 2 | **+3,0 dB @ 1950 Hz**, Q 1,50 |
| Banda 3 | **−2,5 dB @ 3600 Hz**, Q 2,50 |
| Banda 4 | **−3,0 dB @ 6000 Hz**, Q 3,50 |
| Banda 5 | **−1,5 dB @ 8200 Hz**, Q 3,00 |
| Shelf de graves | **+3,0 dB @ 105 Hz**, Q 0,70 |
| Shelf de agudos | 0,0 dB @ 10 kHz |
| DualEQ | Desactivado |

**Las cinco bandas paramétricas están ocupadas.** El RME tiene exactamente cinco, más los
dos shelves de bass/treble: **siete filtros en total, y los siete están en uso.**

Una corrección tipo Harman para un auricular de esta clase necesita típicamente **siete a
diez filtros** (los presets publicados por oratory1990 para modelos comparables usan diez).
El HE1000se tiene estructura fina en los agudos por encima de 10 kHz que cinco bandas no
alcanzan a modelar.

**Consecuencia [razonado]:** tu corrección está limitada por el número de bandas, no por su
calidad. Para añadir un filtro tienes que quitar otro.

El archivo `.adieqpr` **sólo contiene datos de EQ** —no guarda preamp, loudness, filtro DA
ni nivel de referencia—, así que el «preamp a −7,5 dB» que menciona el comentario del V3.1
hay que ajustarlo a mano en el equipo.

### 1.4 El amplificador: potencia real

Manual del Aune S17 Pro EVO **[verificado]**, salida **balanceada**, ganancia alta (G-H):

| Carga | Tensión | Potencia |
|---|---|---|
| 32 Ω | 15,5 V | **7.500 mW** |
| 55 Ω | 16 V | 4.654 mW |
| 90 Ω | 16,35 V | 2.970 mW |
| 100 Ω | 16,35 V | 2.673 mW |
| 300 Ω | 16,6 V | 918 mW |

En ganancia baja (G-H Low): 32 Ω → 9,6 V / 2.880 mW; 55 Ω → 1.764 mW.

Salida no balanceada, ganancia alta: 32 Ω → 8,1 V / 2.050 mW.

Impedancia de salida del Aune: **1 Ω** (las tres tomas del panel frontal).

### 1.5 La cuenta que cierra el tema del amplificador

HE1000se: **35 Ω, 96 dB de sensibilidad** **[verificado]**. Con 96 dB/mW:

| Nivel objetivo | Potencia necesaria |
|---|---|
| 110 dB SPL | ~25 mW |
| **120 dB SPL** | **~250 mW** |

El Aune entrega, interpolando entre 32 Ω y 55 Ω, unos **6.900 mW a 35 Ω**. Eso son
**unos 14 dB por encima de 120 dB de SPL** [razonado].

**El amplificador no es el cuello de botella. Es, con enorme margen, el eslabón más
sobredimensionado de toda la cadena.**

---

## 2. El ranking, de mayor a menor

| # | Eslabón | ¿Limita? | Por qué |
|---|---|---|---|
| 1 | **La grabación y el máster** | **Domina** | Un máster con la dinámica aplastada pierde 6–10 dB de rango **antes** de llegar a ti. Ningún DAC los devuelve. |
| 2 | **El formato de entrega** | **Domina** | Si la fuente es con pérdida, el códec limita muchísimo más que cualquier diferencia de hardware. |
| 3 | **Tu propia audición** | **Domina** | La pérdida de agudos por edad y, sobre todo, la curva de igual sonoridad: a bajo volumen el grave y el agudo se perciben menos. Es el techo real y no se compra. |
| 4 | **Almohadillas y sellado** | **Contribuye** | Varios dB en graves (sellado) y agudos (absorción y distancia al oído). Es el cambio físico de mayor rendimiento. |
| 5 | **El PEQ de 5 bandas** | **Contribuye** | Saturado. Limita la corrección, no la calidad. Se arregla gratis por software. |
| 6 | **La cadena de software** | **Menor pero real** | Sink por defecto equivocado; 44,1 kHz remuestreado a 48 kHz; calidad de remuestreo en el valor por defecto. |
| 7 | **El amplificador Aune** | **No limita** | 6.900 mW a 35 Ω frente a los ~250 mW necesarios. 14 dB de margen sobre 120 dB. |
| 8 | **El DAC RME** | **No limita** | 123 dBA, THD+N −116 dB, distorsión < −120 dB. |
| 9 | **Cables y conectores** | **No limita** | Tu propio cálculo: 0,1 dB entre 8 y 16 núcleos; la profundidad de penetración a 20 kHz (0,468 mm) es 2,3 veces el radio de un hilo de 26 AWG, así que el baño de plata nunca conduce corriente. |
| 10 | **Alimentación** | **No limita** | UPS de onda senoidal pura. |

---

## 3. Acciones gratuitas, en orden de rendimiento

1. **Confirmar el nivel de suscripción de la fuente.** Si es con pérdida, cambiarla es la
   mejora más grande disponible en todo el sistema, y cuesta una suscripción, no un equipo.
2. **Probar el loudness a tu nivel real de escucha.** Tu protocolo lo tiene en **OFF**. El
   loudness del RME existe precisamente para compensar que a bajo volumen se percibe menos
   grave y menos agudo. Si escuchas a niveles moderados o bajos, encenderlo puede cambiar
   más que cualquier DAC. Ojo: interactúa con tu shelf de +2,5 dB @ 40 Hz, así que hay que
   probar los dos estados y comparar, no encenderlo a ciegas.
3. **La prueba de las almohadillas.** Aleja las copas **un centímetro** de las orejas y
   escucha. Si ganas escenario y foco, las almohadillas son el cuello de botella y la compra
   está justificada. Si casi no cambia, no lo son.
4. **Mover el PEQ al software.** EasyEffects **ya está instalado** (8.2.9) y **no está
   corriendo**. Su EQ paramétrico tiene muchas más bandas que cinco, y su motor de
   convolución permite cargar una corrección medida del HE1000se — algo que un EQ
   paramétrico no puede igualar. Es la única vía que rompe el límite de 5 bandas, y es
   gratis.
5. **Poner el RME como sink por defecto** (o al menos saber que hoy no lo es).
6. **Subir `resample.quality`** de 4 al máximo que aguante sin xruns, y considerar permitir
   la frecuencia nativa del contenido en lugar de fijar 48 kHz por defecto.
7. **Alinear el volumen.** Volumen fijo en el RME y control en el Aune —que es analógico—
   evita la atenuación digital. Hoy el sink está a 1.00, así que el punto de partida es
   correcto.

---

## 4. Si te importan las bocinas

Ahí el cuello de botella es otro y es enorme:

- **La sala.** Por debajo de unos 300 Hz la sala domina la respuesta por 10–20 dB. Ningún
  DAC arregla eso.
- **Las Edifier R1855DB** son una bocina activa de ~$2,500 MXN. Ese es el eslabón débil.
- **Las Sony pasivas con el TP30**: el Tripath TA2024 entrega unos 10 W por canal. Es un
  límite real, no un matiz.

---

## 5. Lo que no se pudo verificar

- **El nivel de suscripción de la fuente** (con o sin pérdida): no se puede comprobar desde
  la máquina.
- **La curva de impedancia contra frecuencia del HE1000se**: no se encontró. Los cálculos de
  potencia usan la sensibilidad nominal de 96 dB/mW.
- **Si el HE1000se mide 96 dB/mW o 96 dB/V**: HIFIMAN publica el valor sin aclarar la
  referencia en la documentación revisada. Si fuera dB/V, la potencia necesaria cambiaría.
  **Esto afecta sólo a la magnitud del margen, no a la conclusión**: incluso en el caso más
  desfavorable el Aune sobra.
- **La calidad de remuestreo óptima para tu equipo**: hay que probarla, no deducirla.
