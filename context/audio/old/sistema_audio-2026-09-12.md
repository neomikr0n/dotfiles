# Sistema de audio

> **[SUPERADO 20-sep-2026]** Documento histórico. La configuración que describe ha cambiado:
> ver `enrutamiento_audio_al_rme.md` (§8.8 la cadena real, §8.9 el reloj) y
> `audio_context.md`. Lo que sigue es el registro de lo que se creía el 12-sep.

Inventario, conexiones, funcionamiento y configuración de casa y trabajo. **Revisión: 12 de septiembre de 2026.** Importes en pesos mexicanos.

Este informe describe un sistema con el que su propietario está muy satisfecho. Reúne el inventario declarado, especificaciones de fabricantes, archivos locales y observaciones de la PC. Las especificaciones describen modelos; no son mediciones de estas unidades. La configuración guardada del RME tampoco equivale a una lectura de su pantalla. Las experiencias de escucha y las críticas de terceros aparecen identificadas como tales.

## 1. Inventario y costo histórico

Los importes proceden del registro del propietario, sin comprobación de facturas. No representan precios actuales, valores de reventa ni costo de reposición.

| Componente | Función y estado registrado | Pagado |
|---|---|---:|
| HIFIMAN HE1000se | Audífonos principales de casa; compra registrada el 15/01/2026 | $20,000 |
| RME ADI-2 DAC FS | Receptor digital, DAC y procesamiento de casa | $13,000 |
| Aune S17 Pro EVO | Amplificador de audífonos; versión de 220 V declarada | $11,000 |
| Eversolo DMP-A6, modelo original | Reproductor de red de casa | $13,500 |
| CyberPower CP1500PFCLCD | Respaldo eléctrico de casa | $4,500 |
| Par XLR Worlds Best Cables | Interconexión de línea RME–Aune; referencia exacta desconocida | $1,000 |
| USB Oyaide Neo d+ | Cable disponible para la conexión alternativa PC–RME; clase exacta desconocida | $700 |
| Toslink KabelDirekt, 0.5 m | Enlace óptico utilizado alternativamente con PC y Eversolo | $150 |
| HIFIMAN Arya Stealth | Segundo audífono registrado; hubo intención de venta, sin venta confirmada | $8,000 |
| FiiO K7BT | DAC, preamplificador y amplificador de audífonos de trabajo | $4,500 |
| Edifier R1855DB | Par de bocinas activas de trabajo | $2,500 |
| Apple AirPort Express | Receptor de red de trabajo; generación por confirmar | $630 |
| Apple AirPods Pro 2 | Audio portátil; variante del estuche por confirmar | $3,000 |
| **Total conocido** | **13 partidas, sin sumar otra vez los subtotales** | **$82,480** |

Distribución contable: **casa principal $63,850**, incluyendo Eversolo, UPS y los tres cables; **Arya $8,000** por separado; **trabajo $7,630**; **portátil $3,000**. Casa principal más Arya suma $71,850.

También están registrados un elevador externo de tensión, un iPhone 15 Pro Max, la PC y protectores EarDial HiFi. No hay importes suficientes para integrarlos al total. Tampoco están desglosados el cable de audífonos de cuatro pines, los accesorios RCA/mini-Toslink de trabajo, suscripciones, envíos ni mantenimiento. No se asigna costo cero a estas partidas desconocidas.

Como contexto financiero, el propietario había establecido un límite de hasta $120,000 para un sistema completo, conservando el equipo actual cuando no hubiera una mejora significativa. Ese límite no es una compra realizada ni un presupuesto adicional al inventario.

El consumo eléctrico real de la instalación y su costo mensual no se han medido. Cuando se disponga de una medición, la energía se calcula como `kWh = potencia media en W × horas / 1000`; el costo depende de la tarifa aplicable. Los watts nominales de una fuente de PC o los VA de un UPS no sustituyen esa medición.

## 2. Conexiones y reparto de funciones

### Casa

```text
PC Linux: aplicaciones → PipeWire → salida óptica de la placa ─┐
                                                             ├→ RME ADI-2 DAC FS
Eversolo DMP-A6: reproducción de red → salida óptica ──────────┘       │
                 Se alterna el mismo cable Toslink                   │ DSP/EQ → DAC
                                                                    ↓
                                                        XLR de línea, L y R
                                                                    ↓
                                                           Aune S17 Pro EVO
                                                                    ↓
                                                        XLR de audífonos, 4 pines
                                                                    ↓
                                                             HIFIMAN HE1000se

Alternativa disponible: PC → USB Oyaide → RME.
```

La ruta actual declarada desde la PC es óptica. El esquema USB de documentos anteriores quedó desactualizado. Al escuchar el Eversolo, el propietario apaga la PC. No está confirmado si retira físicamente cualquier conexión USB adicional al RME.

La fuente obtiene y decodifica la grabación. PipeWire, cuando se usa la PC, organiza los flujos y puede mezclar, ajustar volumen y remuestrear. Toslink transporta PCM digital. El RME aplica el procesamiento elegido y convierte a señal analógica. El Aune recibe esa señal de línea y proporciona tensión y corriente al audífono. El HE1000se convierte la energía eléctrica en presión acústica.

La sinergia documentable consiste en esa distribución de funciones, las conexiones compatibles, la relación entre impedancias y el margen de nivel. La preferencia sonora por la combinación se registra aparte: no se deduce automáticamente de una marca, del circuito clase A o de la potencia máxima.

### Trabajo

El registro previo describe esta instalación; no se ha inspeccionado físicamente durante esta revisión:

```text
iPhone 15 Pro Max → red/AirPlay → AirPort Express
                                      ↓ salida óptica mini-Toslink
                                  FiiO K7BT
                                      ↓ RCA de línea o preamplificador
                                 Edifier R1855DB
                                      ↓ amplificación incorporada
                                   Altavoces

Ruta alternativa registrada: iPhone → Bluetooth → K7BT.
```

No hay un subwoofer comprado confirmado. La intención histórica de un sistema 2.1 no se incorpora como equipo poseído.

## 3. HE1000se y Aune: carga, sensibilidad y margen de amplificación

### El audífono

El HE1000se es un audífono planar magnético abierto. Su diafragma lleva conductores sobre los que actúa un campo magnético. HIFIMAN publica **35 Ω**, **96 dB de sensibilidad**, **440 g** y un intervalo de frecuencia de **8 Hz–65 kHz**. La ficha resumida no indica tolerancia para ese intervalo ni explicita allí la referencia de sensibilidad. Esos extremos no significan respuesta plana ni audibilidad humana hasta 65 kHz. [Ficha del HE1000se](https://www.hifiman.com/products/detail/295).

La impedancia describe la carga eléctrica; la sensibilidad relaciona una excitación de referencia con presión sonora. Son magnitudes distintas: un audífono de baja impedancia no es necesariamente sensible, y otro de alta impedancia no necesariamente necesita mucha potencia. La capacidad necesaria depende de ambas, del nivel de escucha y de la EQ.

Un artículo de prueba reproducido en el sitio de HIFIMAN expresa la sensibilidad como **96 dB/mW**. Se utiliza esa referencia sólo para el cálculo ilustrativo siguiente; no es una calibración de la unidad del propietario. [Artículo alojado por HIFIMAN](https://hifiman.com/articles/detail/442).

Suponiendo 96 dB SPL a 1 mW, impedancia resistiva de 35 Ω y comportamiento lineal:

```text
P_mW = 10^((L_dB_SPL − 96) / 10)
V_RMS = √(P_W × 35 Ω)
I_RMS = V_RMS / 35 Ω
```

| Nivel nominal del ejemplo | Potencia calculada | Tensión calculada | Corriente calculada |
|---|---:|---:|---:|
| 90 dB SPL | 0.251 mW | 0.094 V RMS | 2.68 mA RMS |
| 100 dB SPL | 2.512 mW | 0.297 V RMS | 8.47 mA RMS |
| 110 dB SPL | 25.119 mW | 0.938 V RMS | 26.79 mA RMS |

Son relaciones de referencia, no niveles recomendados de escucha ni mediciones en el oído. La sensibilidad real depende de frecuencia, ajuste y método de medición. La música tiene picos y la EQ modifica la demanda por frecuencia. La tabla permite entender por qué no se consumen continuamente varios watts sólo porque el amplificador pueda entregarlos.

### El amplificador

El manual específico del **S17 Pro EVO** declara entrada RCA y XLR de **10 kΩ**, impedancia de salida de audífonos de **1 Ω**, dos ganancias y polarización de **50 o 100 mA por transistor**. Tiene salidas de audífonos de 6.35 mm, 4.4 mm y XLR de cuatro pines; también salidas de preamplificador. Su control de volumen usa una red de resistencias R2R: aquí R2R describe la atenuación analógica, no un DAC de escalera. [Manual del EVO, páginas PDF 3–6](/home/n30/dotfiles/context/manual-aune-s17-evo.pdf).

Para una carga de 32 Ω, el manual publica:

| Salida y ganancia | Tensión publicada | Potencia publicada |
|---|---:|---:|
| 6.35 mm, baja | 5 V RMS | 780 mW |
| 6.35 mm, alta | 8.1 V RMS | 2,050 mW |
| Balanceada, baja | 9.6 V RMS | 2,880 mW |
| Balanceada, alta | 15.5 V RMS | 7,500 mW |

Los redondeos explican pequeñas diferencias con `P = V²/R`. Estas cifras corresponden a 32 Ω; no son ensayos del HE1000se de 35 Ω. El manual no vincula cada fila a un umbral completo de distorsión, duración y condiciones térmicas, por lo que no se presentan como potencia de distorsión idéntica frente a otros amplificadores.

Incluso tomando la fila balanceada de baja ganancia, existe un margen nominal amplio frente a la tensión de los ejemplos de sensibilidad. Su utilidad es poder reproducir transitorios y compensar el nivel global reducido por la EQ sin alcanzar el límite del amplificador. La ganancia alta aumenta la amplificación disponible; no es una mejora sonora automática si la ganancia baja ya alcanza el nivel deseado con margen.

Con 1 Ω de salida y 35 Ω de carga, el divisor resistivo ideal entrega `35/(35+1) = 0.972` de la tensión en vacío: aproximadamente **−0.24 dB**. La relación carga/salida es 35. Una impedancia de salida pequeña reduce la interacción entre la salida del amplificador y las variaciones de impedancia del audífono. Este cálculo no mide por sí solo control del diafragma, distorsión o calidad percibida.

Los 50/100 mA de polarización describen el punto de operación de los transistores. **No son el límite de corriente del audífono.** La polarización en clase A mantiene conducción durante el ciclo de señal dentro de su región de operación y produce disipación incluso sin música. El calor es una consecuencia del diseño, no una medida de fidelidad. No se registraron la selección A-L/A-H, la ganancia ni la temperatura de la unidad del propietario.

### Qué significa aquí la salida balanceada de audífonos

El conector de cuatro pines separa los terminales de ambos canales: L+, L−, R+ y R−. En una salida diferencial ambos terminales de cada canal participan en la excitación. El EVO publica mayor tensión disponible en esa salida que en 6.35 mm, ventaja concreta cuando se necesita margen. No es el mismo mecanismo de rechazo de ruido de una entrada XLR de línea. Los terminales negativos de una salida de este tipo no se deben tratar como una masa común mediante un adaptador improvisado.

El propietario ya comparó la salida directa del RME con el Aune y prefiere claramente el Aune. Se conserva esa experiencia como descripción de uso; la salida del RME queda como respaldo disponible. No hay una medición que identifique qué diferencia eléctrica explica esa preferencia.

## 4. RME y XLR: conversión, procesamiento y niveles

El **ADI-2 DAC FS** recibe audio digital y lo convierte a analógico. Incorpora EQ paramétrica de cinco bandas, controles Bass/Treble, Loudness, Crossfeed, análisis de señal y salidas de audífonos. Las salidas y sus ajustes deben distinguirse: la cadena con Aune utiliza la salida de línea. No se atribuyen al ADI-2 DAC las entradas analógicas y funciones de conversión A/D del ADI-2 Pro. [Manual local RME](/home/n30/dotfiles/context/MANUAL-RMEadi2dac_e.pdf).

Se consultó la revisión **1.8** del manual disponible localmente. El fabricante ha comercializado revisiones de hardware; no se identificó el chip DAC ni el firmware de esta unidad. Las cifras siguientes pertenecen a esa documentación, no a una inspección de su circuito.

### Acoplamiento RME–Aune

El manual da **200 Ω** para la salida XLR balanceada del RME. Frente a los **10 kΩ** nominales de entrada del Aune, la relación es 50:1. En audio de línea se busca que la entrada cargue poco a la fuente: no se pretende igualar ambas impedancias para transferir potencia máxima.

Con esos valores, el divisor ideal es `10000/(10000+200) = 0.9804`, o **−0.17 dB**. La entrada del Aune recibe casi toda la tensión de línea mientras exige poca corriente al DAC. Éste es un aspecto concreto de compatibilidad entre ambos.

Los niveles de referencia XLR publicados por RME son +1, +7, +13 y +19 dBu a 0 dBFS. Con `V_RMS = 0.775 × 10^(dBu/20)`:

| Referencia XLR | Tensión nominal correspondiente |
|---|---:|
| +1 dBu | 0.87 V RMS |
| +7 dBu | 1.74 V RMS |
| +13 dBu | 3.46 V RMS |
| +19 dBu | 6.91 V RMS |

**dBFS** compara una señal digital con su escala máxima; **dBu** expresa una tensión analógica respecto a 0.775 V RMS. Son referencias diferentes. La tensión real también depende del contenido, volumen y DSP. No se comprobó la referencia seleccionada, Auto Ref Level ni el volumen del RME; tampoco hay un dato suficiente del máximo de entrada sin saturación del Aune para declarar que +19 dBu sea siempre la elección óptima.

El manual publica para la salida de línea 117 dB de relación señal/ruido sin ponderación y 120 dBA con ponderación A en las referencias indicadas de +7/+13/+19 dBu, y THD+N de −110 dB a −1 dBFS. La relación señal/ruido compara señal y ruido; THD+N agrega distorsión armónica y ruido bajo condiciones de prueba. La ponderación A reduce la contribución de ciertas frecuencias al resultado. Estas cifras no se deben comparar con otras medidas a diferente nivel, carga o ancho de banda como si fueran equivalentes. [Manual RME, especificaciones de salida](/home/n30/dotfiles/context/MANUAL-RMEadi2dac_e.pdf).

### Por qué XLR de línea es una elección coherente

Cada canal usa un XLR de tres pines: pantalla y dos conductores de señal. La entrada diferencial responde a la diferencia entre los conductores y puede rechazar interferencia que llegue de forma semejante a ambos. Esa capacidad depende del equilibrio de impedancias, la entrada y el cableado; no es una propiedad aislada del conector o de la marca del cable. Es especialmente útil entre aparatos alimentados por separado. [RaneNote 110](https://www.ranecommercial.com/legacy/note110.html).

RME y Aune disponen de interfaces XLR de línea compatibles. Usarlas aprovecha esa arquitectura sin adaptaciones RCA. XLR no proporciona aislamiento galvánico ni garantiza ausencia de cualquier bucle de tierra. En un tramo doméstico corto y sin ruido, no está demostrada una diferencia audible respecto a una conexión RCA correctamente implementada. La ficha del RME especifica además 6 dB más de nivel por XLR que por RCA: comparar ambas sin igualar volumen introduce una diferencia de nivel.

Del par Worlds Best Cables se conocen marca, función y costo; no se conoce referencia, longitud o fabricante de sus conductores y conectores. No se le atribuyen materiales específicos, un rechazo de ruido numérico ni cambios de timbre sin esa información.

## 5. Ecualización del HE1000se

El propietario declara que utiliza la EQ del RME con ambas fuentes y que ya no aplica EQ convencional en la PC. El archivo de referencia es [HEKSE-HarmanV3.1.adieqpr](/home/n30/dotfiles/context/HEKSE-HarmanV3.1.adieqpr). Se verificaron sus valores, **no su carga actual en el aparato**.

| Filtro | Frecuencia | Ganancia | Q | Efecto previsto sobre la respuesta |
|---|---:|---:|---:|---|
| Bass, shelf bajo | 105 Hz | +4.5 dB | 0.70 | Eleva progresivamente el grave por debajo de la transición |
| Paramétrico 1, campana | 40 Hz | +2.5 dB | 0.90 | Añade énfasis alrededor del subgrave, superpuesto al shelf |
| Paramétrico 2, campana | 1,950 Hz | +3.0 dB | 1.50 | Aumenta la presencia relativa de esa región de medios |
| Paramétrico 3, campana | 3,600 Hz | −2.5 dB | 2.50 | Reduce energía alrededor de esa región de presencia |
| Paramétrico 4, campana | 6,000 Hz | −3.0 dB | 3.50 | Reduce energía en esa zona de agudos |
| Paramétrico 5, campana | 8,200 Hz | −1.5 dB | 3.00 | Atenúa localmente otra región de agudos |
| Treble, shelf alto | 10,000 Hz | 0.0 dB | 0.70 | No introduce realce ni recorte con esa ganancia |

La frecuencia sitúa el filtro; la ganancia determina cuánto se realza o atenúa; Q controla su anchura y forma. En una campana, un Q mayor concentra la intervención en un intervalo más estrecho. Un shelf modifica una región extendida a un lado de su transición, por lo que no equivale a una campana centrada en la misma frecuencia.

Esta curva permite ajustar el balance tonal del HE1000se: más grave relativo y menos energía en determinadas zonas de presencia/agudos. Ese objetivo es compatible con las observaciones de brillo de algunas reseñas del modelo, pero no demuestra que cada recorte corrija una resonancia de esta unidad o del oído del propietario. La geometría del oído, colocación y almohadillas influyen especialmente en agudos. [Reseña con mediciones de Unheard Lab](https://unheardlab.com/2024/12/16/review-of-hifiman-he1000se-2023/).

Al aplicarla en el RME, el ajuste tonal se conserva para distintas fuentes sin depender de cargar un preset en cada aplicación. El beneficio verificable de la EQ es modificar la respuesta según esos parámetros. Que resulte más natural, agradable o menos fatigante es una valoración del oyente. El nombre “Harman” del archivo no acredita una coincidencia medida con una curva objetivo ni existe aquí una medición individual que la demuestre. Se omiten las afirmaciones históricas de “resolución pura”, “resonancia metálica” u optimización especial a 192 kHz.

Los cinco filtros coinciden entre canales. El archivo contiene `DualEQ=0`, `EQEnable=1`, `BassTrebleEn=1` y `Load BT w. EQ=1`; Bass/Treble están registrados en el bloque izquierdo con uso conjunto. No se interpreta su ausencia en el bloque derecho como un canal sin graves.

### Margen digital y relación con el amplificador

Los realces aumentan el nivel de determinadas frecuencias. Sus respuestas se superponen: el máximo conjunto no se obtiene tomando simplemente el mayor valor de la tabla ni sumando todos los números sin considerar frecuencia. Hace falta margen para evitar que el procesamiento alcance el límite digital.

El comentario del archivo menciona **−7.5 dB de preamplificación**, pero no hay un parámetro ejecutable que pruebe que esa atenuación esté instalada. No se documenta como ajuste activo. Tampoco se equipara Auto Ref Level con un preamplificador digital fijo. Deben distinguirse el margen dentro del DSP, la escala analógica seleccionada y el volumen final.

Como cálculo general, un realce de 6 dB demanda aproximadamente el doble de tensión y cuatro veces la potencia en la región afectada si se conserva la referencia de nivel en el resto del espectro. Un realce de 7.5 dB equivaldría a 2.37 veces la tensión y 5.62 veces la potencia. Esto explica la utilidad de la reserva del Aune, sin afirmar que esta EQ tenga exactamente ese máximo combinado.

En el registro previo figura el filtro de reconstrucción **SD Slow**. No se comprobó su selección actual. Los filtros de reconstrucción intercambian características de transición en frecuencia, rechazo fuera de banda y respuesta temporal. No se atribuye a SD Slow una superioridad audible universal. Loudness y Crossfeed también pueden cambiar la señal: su estado actual está pendiente. [Funciones DSP y filtros en el manual RME](/home/n30/dotfiles/context/MANUAL-RMEadi2dac_e.pdf).

## 6. Fuentes digitales: óptico, USB y Eversolo

### Qué aporta Toslink

Toslink transmite información mediante luz. En este enlace no hay un conductor eléctrico que una las masas de los puertos, por lo que evita esa vía de corriente de tierra entre la fuente y el DAC. La fibra es inmune a la captación electromagnética que afecta a conductores eléctricos. Es un beneficio físico pertinente cuando se conecta una PC a un equipo de audio alimentado por separado. [Guía técnica Toshiba sobre Toslink](https://media.digikey.com/pdf/data%20sheets/toshiba%20pdfs/fiber-optic%20devices%20toslink.pdf).

El aislamiento corresponde al enlace óptico: una conexión USB adicional, otras interconexiones o la alimentación pueden establecer rutas eléctricas por separado. También permanecen el ruido acústico de ventiladores y posibles acoplamientos por otros mecanismos. Por eso, apagar la PC cambia más de una variable aunque se conserve el mismo cable óptico.

S/PDIF transporta datos junto con información temporal. El receptor recupera el reloj y gestiona su sincronización. El RME incorpora SteadyClock FS para reducir la influencia del jitter, la variación temporal de los instantes del reloj. El fabricante ha publicado una prueba con jitter inyectado sin degradación apreciable en su ensayo; corresponde a aquella unidad, firmware y método, no a una medición de esta instalación. [Prueba de RME](https://forum.rme-audio.de/viewtopic.php?id=33497).

Un cable óptico necesita suficiente margen de transmisión y conectores correctamente asentados. Sus fallos pueden causar errores o pérdida de sincronía. No hay evidencia local para atribuir mayor densidad o nitidez al material o al precio del KabelDirekt. Tampoco se ha medido su margen a cada frecuencia.

### Formatos y límites de la ruta

Una tasa de 48 kHz significa 48,000 muestras por segundo y canal; no expresa el bitrate comprimido de Apple Music. La profundidad de bits describe la representación de cada muestra. Remuestrear a 192 kHz no recupera información que una fuente no contenía.

El DMP-A6 original admite por óptico/coaxial PCM hasta **24 bits/192 kHz**; la salida USB admite otros límites superiores. Su DAC interno y sus salidas analógicas quedan fuera del trayecto cuando entrega señal óptica al RME. En esa ruta contribuye como reproductor, interfaz, almacenamiento/red y transporte digital. No se suman las prestaciones de su DAC interno a las del RME. La cadena óptica tiene como máximo de formato la capacidad común entre transmisor, receptor y contenido; el máximo USB del Eversolo no amplía el límite de Toslink. [Manual original DMP-A6](/home/n30/dotfiles/context/EVERSOLO-DMP-A6-User-Manual-v1.0.pdf).

Su ventaja funcional concreta es reproducir sin mantener encendida la PC. Apple Music ejecutado en el aparato y AirPlay desde un teléfono son rutas distintas. El propietario describe reproducción mediante la red, pero no se identificó cuál de ellas está activa ni su formato efectivo. La capacidad máxima del equipo no demuestra la resolución de una sesión concreta.

El USB Oyaide está disponible como alternativa. USB transmite datos y también incorpora conexiones eléctricas; eso hace diferentes las condiciones de acoplamiento respecto a Toslink. No se ha demostrado que el cable poseído introduzca ruido, ni que otro cable USB mejore el sonido. Tampoco está identificada su clase dentro de la familia Neo d+.

## 7. PC: hardware y estado de audio observado

### Hardware y aplicaciones

| Elemento | Dato registrado y alcance |
|---|---|
| Placa base | ASUS PRIME Z690-A, identificada mediante DMI |
| Salida utilizada | S/PDIF óptica integrada; ALSA la identifica como ALC1220 Digital |
| Audio de la placa | ASUS denomina su solución Realtek S1220A; el nombre del controlador ALSA no implica una segunda tarjeta |
| CPU | Intel Core i5-13600K, según inventario |
| GPU | Familia AMD Navi 48 identificada; variante comercial exacta sin confirmar |
| Memoria | 32 GB DDR5, según inventario |
| Fuente | Corsair RM750x de 750 W, según inventario; 750 W es capacidad nominal |
| Entorno | Garuda Linux/Hyprland; auditoría del 11/09: kernel 7.2.3-zen1-2-zen |
| Servidor de audio | PipeWire y pipewire-pulse 1.6.8; WirePlumber 0.5.17 |
| Aplicaciones | Cider 4.0.9.1 y tidal-hifi 7.0.1 registrados; también reproducción desde navegador |

La salida óptica evita utilizar la conversión D/A y la salida analógica de la placa. La carga del sistema, el controlador y la entrega a tiempo de los buffers siguen importando para la continuidad digital. Las especificaciones analógicas del códec de la placa no describen la salida analógica final del RME. [Manual ASUS PRIME Z690-A](https://dlcdnets.asus.com/pub/ASUS/mb/LGA1700/PRIME_Z690-A/E18708_PRIME_Z690-A_UM_WEB.pdf).

### Fotografía de funcionamiento del 12/09/2026

| Lectura | Resultado |
|---|---|
| Nodo físico activo | `alsa_output.pci-0000_00_1f.3.iec958-stereo` |
| Dispositivo ALSA | `iec958:0`, controlador `snd_hda_intel` |
| Formato hardware observado | S32_LE, estéreo, 48,000 Hz |
| Volumen de salida observado | 48%, aproximadamente −19.13 dB; sin mute |
| Periodo y buffer ALSA | 1,024 y 32,768 frames, respectivamente |
| Forzado global en metadatos | `clock.force-rate=0`, `clock.force-quantum=0` |
| Ahorro de energía HDA | `power_save=0`, `power_save_controller=N` |

Son valores de esa lectura: el volumen y la frecuencia pueden cambiar después. S32_LE es el contenedor de muestras de ALSA; no prueba 32 bits útiles por S/PDIF. El dispositivo anuncia 16/20/24 bits digitales. Una propiedad de nodo también indicaba `alsa.resolution_bits=16`, por lo que no se certifica la profundidad efectiva únicamente con esos metadatos.

Las frecuencias anunciadas por el transmisor son 32/44.1/48/88.2/96/192 kHz; no aparece 176.4 kHz. La configuración permite las compatibles desde 44.1 kHz. La frecuencia final depende del grafo y de los clientes, no sólo de la canción elegida.

### Configuración actual de PipeWire

Archivo: [99-rme-fix.conf](/home/n30/dotfiles/.config/pipewire/pipewire.conf.d/99-rme-fix.conf).

```ini
context.properties = {
    default.clock.rate = 48000
    default.clock.allowed-rates = [ 44100 48000 88200 96000 192000 ]
    default.clock.quantum = 1024
    default.clock.min-quantum = 512
    default.clock.max-quantum = 2048
    mem.allow-mlock = true
}

context.modules = [
    { name = libpipewire-module-rt
      args = {
          nice.level = -15
          rt.prio = 88
          rt.time.soft = 500000
          rt.time.hard = 500000
      }
      flags = [ ifexists nofail ]
    }
]
```

Se transcriben valores, omitiendo comentarios históricos. Estos ajustes no se presentan como parámetros universalmente óptimos ni como solución comprobada del fallo intermitente.

`default.clock.rate` fija la frecuencia de partida. `allowed-rates` autoriza alternativas; no garantiza cambios mientras otros clientes mantienen activo el grafo. El quantum es la cantidad de frames procesada por ciclo. A 48 kHz, 1,024 frames representan **21.33 ms**; 512 y 2,048 representan **10.67 y 42.67 ms**. La latencia total incluye más etapas y no se deduce de un solo quantum. PipeWire puede adaptar estos valores con la frecuencia y las solicitudes de clientes. [Configuración de PipeWire](https://docs.pipewire.org/page_man_pipewire_conf_5.html).

Un buffer mayor puede dar margen frente a retrasos de planificación, a costa de latencia. No modifica intencionalmente el timbre. `mem.allow-mlock` permite bloquear memoria para evitar paginación de las regiones correspondientes; la prioridad de tiempo real busca atender el audio a tiempo. Que el archivo solicite prioridad 88 no prueba por sí solo que todos los hilos la hayan obtenido. `ifexists` y `nofail` hacen tolerable el fallo de carga del módulo; tampoco certifican su aplicación efectiva.

Archivo de clientes nativos: [resampling.conf](/home/n30/dotfiles/.config/pipewire/client.conf.d/resampling.conf).

```ini
stream.properties = {
    resample.quality = 10
    node.latency = 2048/192000
}
```

`2048/192000` es una solicitud de latencia de aproximadamente **10.67 ms**; **no fuerza por sí misma 192 kHz**. El valor `resample.quality=10` selecciona un nivel de calidad del remuestreador. La escala documentada va de 0 a 14; aumentar el valor modifica el compromiso de filtrado, carga y latencia. No es una escala de calidad audible del sistema. [Propiedades de audio de PipeWire](https://docs.pipewire.org/devel/page_man_pipewire-props_7.html).

Archivo de compatibilidad PulseAudio: [force-192k.conf](/home/n30/dotfiles/.config/pipewire/pipewire-pulse.conf.d/force-192k.conf).

```ini
stream.properties = {
    resample.quality = 10
}
```

El nombre es histórico: su contenido actual ya no fuerza 192 kHz ni el quantum. La separación de archivos importa porque los clientes nativos y los que usan la compatibilidad PulseAudio no leen necesariamente las mismas propiedades. [Configuración de pipewire-pulse](https://docs.pipewire.org/page_man_pipewire-pulse_conf_5.html).

### Procesamiento de las aplicaciones

En [spa-config.yml de Cider](/home/n30/.config/sh.cider.genten/spa-config.yml) quedaron guardados estos valores, comprobados durante la auditoría:

| Función | Estado guardado |
|---|---|
| Cider Audio | Desactivado |
| PPE | Desactivado |
| Atmos | Desactivado |
| Ecualizador | Desactivado |
| Crossfade y Automix | Desactivados |
| Normalización | Activada; objetivo guardado −14 LUFS |
| Volumen propio de Cider | 1 |

EasyEffects figura en bypass y no apareció en la ruta activa inspeccionada. Por tanto, no hay evidencia de otra EQ activa en esa lectura. Sin embargo, **normalización y volumen de la PC siguen siendo procesamiento previo al RME**. Normalizar puede aplicar una ganancia constante por pista y no equivale necesariamente a comprimir su dinámica; no se capturó aquí su comportamiento pista por pista.

El propietario declara Cider/Apple Music a 256 kbps y Tidal con máxima calidad seleccionada, sin distinguir diferencia entre ambos en sus pruebas personales. No se analizó el flujo de red para certificar el formato de cada reproducción. Apple distribuye AAC y ALAC; un indicador de 48 o 192 kHz en el DAC no identifica el códec original. [Apple, audio sin pérdida](https://support.apple.com/en-us/118295).

### Continuidad y comparación con Eversolo

El propietario reporta episodios de audio robótico de aproximadamente un segundo en distintas aplicaciones, con menor frecuencia por óptico que por USB. Las estimaciones previas fueron un par de veces por hora por óptico y alrededor de diez por USB; no son un conteo instrumental. No se ha establecido una causa: retrasos de entrega, controlador, sincronización u otros fallos siguen sin diagnóstico concluyente.

En las pruebas del 11/09, con Cider abierto el dispositivo permaneció a 192 kHz durante solicitudes de otras frecuencias. Con Cider cerrado se observó cambio a 44.1/48/96/192 kHz al reproducir archivos de silencio de cuatro segundos. Es evidencia del comportamiento de negociación de tasas, no de integridad bit a bit, ausencia de fallos durante horas o calidad analógica. [Auditoría y metodología local](/home/n30/dotfiles/share/scripts/audio-audit-2026-09-11/reporte.md).

La preferencia por el Eversolo cuando ambos reproducen sin fallar es una observación distinta. Con la PC apagada cambian simultáneamente fuente, procesamiento posible y ruido ambiental. Conservar la misma EQ en el RME no iguala la normalización ni el nivel anterior al DAC. No se ha demostrado en esta instalación que la interferencia de una PC gamer degrade de forma continua el audio óptico. Tampoco se ha demostrado equivalencia audible entre ambas fuentes mediante una prueba controlada.

## 8. Equipo de trabajo y portátil

### AirPort Express e iPhone

El registro antiguo identifica el AirPort como A1392, pero no se verificó su etiqueta. Para el **AirPort Express de segunda generación**, Apple documenta puerto combinado de audio analógico/óptico, Wi-Fi 802.11n de doble banda y Ethernet de 10/100 Mbps. Su USB está destinado a impresoras; no se documenta como salida USB de audio para un DAC. [Especificaciones Apple](https://support.apple.com/en-la/112421).

La salida mini-Toslink comparte la forma física del minijack, pero transporta luz cuando se usa el accesorio óptico. En esa conexión la conversión analógica queda a cargo del K7BT. Ethernet de 100 Mbps supera ampliamente el caudal de PCM estéreo sin comprimir de 16 bits/44.1 kHz, que es `2 × 16 × 44100 = 1.4112 Mbps`, antes de la sobrecarga de red. Ese cálculo no demuestra qué formato negocia AirPlay ni elimina posibles problemas de cobertura o software.

No se verificaron firmware, protocolo AirPlay negociado ni resolución de salida. No se etiqueta esta ruta como lossless de extremo a extremo sólo por usar Wi-Fi.

### FiiO K7BT y Edifier

El K7BT integra dos DAC AK4493 de la familia documentada por FiiO y amplificación THX AAA 788+. Sus límites publicados son **PCM 24/96 por óptico**, **24/192 por coaxial** y **32/384 por USB**, además de DSD por USB. Su Bluetooth admite, entre otros, AAC, SBC, LDAC y variantes aptX; disponer de esos códecs no significa que el iPhone negocie todos ellos. La ruta Bluetooth del iPhone no se documenta aquí como LDAC. [Parámetros K7](https://www.fiio.com/k7_parameters), [K7BT y conectividad](https://fiio.com/k7).

Para alimentar las Edifier se utiliza la **salida RCA posterior**. El modo LO proporciona salida de línea; PRE permite controlarla como preamplificador. No se comprobó cuál está seleccionado actualmente. FiiO publica una salida de línea de al menos 2 V RMS en sus condiciones. La compatibilidad consiste en entregar señal a una entrada de línea, no en transferir watts a las bocinas.

Las cifras de **2 W balanceados o 1.22 W por 6.35 mm a 32 Ω**, con THD+N menor de 1% en la especificación de potencia máxima, describen las salidas de audífonos. **No son la potencia que reciben las Edifier por RCA.** El K7BT tampoco tiene salida de línea XLR: su conector balanceado de 4.4 mm es de audífonos. [Ficha técnica FiiO](https://www.fiio.com/k7_parameters).

Las R1855DB son bocinas activas: su amplificación está incorporada. Edifier publica **70 W totales**, repartidos como `19 W × 2 + 16 W × 2`, respuesta nominal **60 Hz–20 kHz** y relación señal/ruido de al menos **80 dBA**. Tienen entradas RCA, óptica, coaxial y Bluetooth, procesamiento DSP/DRC y salida para subwoofer. Los 60 Hz no vienen acompañados de una tolerancia en la ficha consultada; no se interpretan como un corte exacto a −3 dB. [Edifier México](https://www.edifier.com/mx/p/bookshelf-speakers/r1855db).

Su entrada Line 1 tiene sensibilidad publicada de 400 ±50 mV y Line 2 de 600 ±50 mV. La sensibilidad es la señal requerida bajo las condiciones del fabricante, **no el máximo absoluto antes de saturar**. La diferencia frente a los aproximadamente 2 V del K7 indica que hay margen de nivel y que la combinación de controles importa; no prueba una sobrecarga permanente.

La cadena AirPort–K7–Edifier separa recepción de red, conversión/control y amplificación acústica. El K7 también ofrece conexión de audífonos y Bluetooth alternativo. No se verificó que entrar por RCA omita cualquier conversión o DSP interno de las Edifier, ni que su salida de subwoofer active un filtro pasaaltos sobre los altavoces principales.

En bocinas, escritorio, distancia a paredes, posición de escucha y reflexiones modifican la respuesta recibida. No hay medición de sala o EQ de trabajo documentada. La EQ del HE1000se no describe ni corrige esta instalación.

### Arya Stealth y AirPods Pro 2

HIFIMAN publica para el **Arya Stealth** 32 Ω, sensibilidad de 94 dB y 430 g. Es otro planar abierto, con respuesta y ajuste propios. No se trasladan automáticamente la EQ ni los cálculos de sensibilidad del HE1000se. Su estado de posesión y ubicación quedan registrados como pendientes de actualización. [Ficha Arya Stealth](https://www.hifiman.com/products/detail/312).

Los **AirPods Pro 2** integran transductores, DAC, amplificación, procesamiento H2, ecualización adaptativa y cancelación activa de ruido. No necesitan ni utilizan el RME/Aune en su ruta inalámbrica. La cancelación reduce ruido ambiental mediante micrófonos y procesamiento; el sellado de las puntas también influye en aislamiento y respuesta grave. Apple publica Bluetooth 5.3 y hasta seis horas de escucha bajo sus condiciones. La variante Lightning o USB-C no está identificada y no se le asigna una clasificación de resistencia al agua específica. [AirPods Pro 2 Lightning](https://support.apple.com/en-gb/111851), [variante USB-C](https://support.apple.com/es-es/111834).

La reproducción Bluetooth convencional desde iPhone no equivale a la distribución ALAC sin pérdidas del servicio. Eso es una limitación de transporte, no una conclusión de inferioridad audible para este usuario. No hay una medición de autonomía o una queja de funcionamiento de sus AirPods registrada. [Apple y audio sin pérdida](https://support.apple.com/en-us/118295).

## 9. Alimentación y respaldo eléctrico

El **CyberPower CP1500PFCLCD** pertenece a una familia de UPS line-interactive con regulación automática de tensión y onda senoidal en batería. El catálogo actual indica 1,500 VA/1,000 W; existen diferencias de revisión y no se leyó la placa de esta unidad, por lo que ese límite de watts no se certifica para el ejemplar poseído. [Ficha del fabricante](https://www.cyberpowersystems.com/product/ups/pfc-sinewave/cp1500pfclcd/).

Los VA expresan potencia aparente y los W potencia real. Para dimensionar un UPS deben respetarse ambos límites y la carga efectiva del conjunto. Los 750 W de la Corsair RM750x son capacidad de la fuente de la PC, no consumo fijo que pueda sumarse como medición. La autonomía depende de carga y estado de batería; no hay minutos de respaldo medidos para esta instalación.

La regulación automática compensa ciertas variaciones de tensión dentro del intervalo especificado; el UPS usa batería cuando corresponde. Ser line-interactive no equivale a regenerar continuamente toda la alimentación mediante doble conversión. Su beneficio documentado es respaldo y gestión de determinadas anomalías eléctricas. No se midió una reducción de ruido o distorsión de audio atribuible al UPS.

El Aune está registrado como versión de **220 V**, utilizada con elevador externo. El elevador adapta tensión; no convierte por sí mismo la electricidad en una fuente de mayor fidelidad. En un transformador ideal `V_s/V_p = N_s/N_p`, relación entre vueltas secundarias y primarias. La tensión real depende de entrada, relación, carga y regulación. Faltan modelo, potencia continua, tensión nominal de entrada/salida y confirmación de si es autotransformador o transformador aislado. No se le asignan 500 VA ni aislamiento galvánico sin esos datos.

A igual potencia, una alimentación de mayor tensión requiere menos corriente en el primario, pero eso no demuestra una mejora en la salida de audio de un aparato diseñado para su tensión correspondiente. La comparación relevante depende de fuentes internas, regulación, ruido y mediciones a la salida. No hay evidencia para afirmar que la versión de 220 V del EVO suene mejor que una de 110/120 V.

La fuente externa del RME está especificada en el manual como 12 V/2 A con entrada universal de red. Los 24 W resultantes son capacidad nominal del adaptador, no consumo medido del DAC. No se levantó un mapa confirmado de qué aparatos están conectados a cada toma del UPS o al elevador. [Manual RME, alimentación](/home/n30/dotfiles/context/MANUAL-RMEadi2dac_e.pdf).

## 10. Críticas, desventajas y límites de la evidencia

No existe en las fuentes revisadas una encuesta representativa o tasa de fallos comparable para todos estos aparatos. Se distinguen limitaciones documentadas, observaciones de reseñistas y experiencias del propietario. No se presentan como “las fallas más frecuentes” por contar mensajes de internet sin conocer cuántas unidades funcionan correctamente.

| Aparato | Crítica o desventaja documentable | Alcance y fuente |
|---|---|---|
| HE1000se | Algunas evaluaciones encuentran agudos enfatizados; el diseño abierto deja entrar ruido y salir música; peso nominal de 440 g | El brillo aparece en más de una evaluación, pero la tolerancia es personal. [Headphones.com](https://headphones.com/blogs/reviews/hifiman-he1000se-review-a-planar-like-nothing-else) y [Unheard Lab](https://unheardlab.com/2024/12/16/review-of-hifiman-he1000se-2023/). No hay tasa de fallos de esta unidad o población |
| Arya Stealth | Brillo/sibilancia y balance de medios discutidos por reseñistas; también es abierto | [Comparación de escucha y mediciones](https://headphones.com/blogs/reviews/hifiman-arya-stealth-vs-arya-v2). Son características percibidas del modelo probado, no un defecto confirmado del ejemplar poseído |
| RME ADI-2 DAC FS | Muchas funciones concentradas en botones, mandos y menús; curva de aprendizaje. Sus cinco bandas paramétricas exigen priorizar correcciones complejas | [Experiencia de The Headphoneer](https://www.headphoneer.com/rme-adi-2-dac-review/) y manual. Bass/Treble amplían las posibilidades, pero no equivalen a un número ilimitado de filtros |
| Aune S17 Pro EVO | Disipación y espacio de sobremesa; algunas operaciones del menú de ajustes requieren el mando frontal, según manual | Las quejas conocidas de calentamiento con cambio automático de polarización y curva de volumen del S17 Pro original no se atribuyen automáticamente al EVO. [Artículo que distingue ambas versiones](https://soundnews.net/reviews/amplifiers/aune-s17-pro-evo-review-a-giant-killer-amp/) y manual específico |
| Eversolo DMP-A6 original | Dependencia de firmware, aplicaciones y servicios externos; DAC y salidas analógicas no se usan en esta conexión óptica | Usuarios reportaron incidencias de acceso/control de servicios como Apple Music en versiones concretas. Son reportes históricos, no un fallo comprobado hoy en esta unidad. [Hilo de servicios de 2023](https://forum.zidoo.tv/index.php?threads/eversolo-app-won%E2%80%99t-open-music-services.96049/), [hilo de firmware de 2025](https://forum.zidoo.tv/index.php?threads/firmware-update-v-1-4-70-75-76.100677/page-5) |
| FiiO K7BT | Ligero retraso de respuesta del volumen observado por un reseñista; ausencia de línea balanceada; óptico limitado a 96 kHz | [Prueba de Headfonia](https://www.headfonia.com/fiio-k7-bt-review/) para experiencia de mando; ficha FiiO para conexiones. La reseña contiene una mención contradictoria a USB de 768 kHz: aquí se conserva el máximo oficial de 384 kHz |
| Edifier R1855DB | Extensión nominal de graves limitada; entradas analógicas no balanceadas; respuesta dependiente de sala y colocación | Son límites de diseño y uso, no una avería. No hay evidencia suficiente para afirmar una frecuencia de fallos ni un bypass analógico completo. [Ficha Edifier](https://www.edifier.com/mx/p/bookshelf-speakers/r1855db) |
| AirPort Express | Plataforma con Wi-Fi 802.11n y Ethernet 100 Mbps en la segunda generación; ruta y funciones ligadas a AirPlay | Especificaciones más antiguas no significan ancho de banda insuficiente para música. El modelo y firmware locales siguen sin confirmar. [Apple](https://support.apple.com/en-la/112421) |
| AirPods Pro 2 | Autonomía finita, dependencia de carga y del ajuste de puntas; Bluetooth convencional no transporta el ALAC del servicio sin pérdidas | Limitaciones documentadas por Apple. No hay queja personal ni deterioro medido registrado |
| CyberPower CP1500PFCLCD | Autonomía y capacidad de carga finitas; batería sujeta a mantenimiento y envejecimiento; no es un UPS de doble conversión | Características de la familia. Sin placa y prueba de carga no se fija autonomía o capacidad exacta de esta revisión |
| PC y ruta óptica | Interrupciones robóticas breves reportadas en varias aplicaciones; varias capas de mezcla, volumen y negociación de frecuencia | Experiencia del propietario y auditoría local. No se atribuyen a la GPU, fuente o interferencia electromagnética sin diagnóstico |
| Cables XLR, USB y Toslink | Fiabilidad condicionada por conectores, construcción y manejo; no hay medición comparativa de estos ejemplares | Sin modelo completo de XLR/USB ni defectos observados, no se inventan quejas específicas o beneficios de materiales |
| Elevador de tensión | Añade un aparato y requiere compatibilidad de tensión y capacidad; características concretas desconocidas | No hay datos suficientes para evaluar regulación, ruido mecánico, pérdidas o aislamiento del ejemplar |

## 11. Estado documental y verificaciones pendientes

Los hechos observados se obtuvieron mediante `wpctl`, `pactl`, `pw-metadata`, `pw-dump`, consultas de versiones y lectura de `/proc/asound`, parámetros HDA y archivos de configuración. La inspección del 12/09 fue de lectura: este informe no cambia la configuración de reproducción. La auditoría del 11/09 conserva el detalle de los cambios y pruebas anteriores.

Para reproducir una fotografía básica del estado, sin modificarlo:

```sh
wpctl status
pactl info
pactl list sinks
pw-metadata -n settings
cat /proc/asound/cards
cat /proc/asound/card0/pcm1p/sub0/hw_params
cat /sys/module/snd_hda_intel/parameters/power_save
cat /sys/module/snd_hda_intel/parameters/power_save_controller
```

La numeración de tarjeta/PCM puede cambiar: el archivo de `hw_params` debe corresponder al dispositivo óptico activo. Estas lecturas identifican configuración y transporte, no miden presión sonora, distorsión analógica o audibilidad.

Quedan sin confirmar: ajustes activos completos y firmware del RME; atenuación digital de margen de EQ; ganancia/polarización del Aune; placa y características del elevador/UPS; ruta y formato de Apple Music en Eversolo; igualdad de volumen y procesamiento entre fuentes; desconexión física del USB en comparación óptica; modo LO/PRE y cableado actual de trabajo; generación del AirPort; estado del Arya; variante de AirPods y referencias completas de cables.

La información anterior permite describir el funcionamiento y la compatibilidad del sistema sin completar esos vacíos con suposiciones. La satisfacción y las preferencias del propietario quedan registradas como experiencia personal; las causas físicas de una diferencia de escucha requieren evidencia adicional a esa preferencia.
