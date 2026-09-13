# Auditoría: PC óptica frente a Eversolo

11 de septiembre de 2026 · HE1000se → cadena de reproducción con RME ADI-2 DAC FS y Aune S17 Pro EVO.

**Conclusión:** encontramos diferencias comprobables de configuración anteriores al RME, pero todavía no demostramos la causa de tu preferencia sonora por el Eversolo. Se aplicaron ajustes reversibles para reducir procesamiento adicional y permitir frecuencias de reproducción sin el forzado general a 192 kHz. El ruido robótico intermitente sigue pendiente de diagnóstico concluyente.

## 1. Tus observaciones: referencia de escucha

- El Eversolo te suena más denso y nítido **cuando ambos sistemas funcionan correctamente**.
- La EQ siempre la aplica el RME. No utilizas ya un ecualizador de software.
- En la PC utilizas Tidal con máxima calidad seleccionada y Cider para Apple Music a 256 kbps. No distingues una diferencia entre ellos.
- En el Eversolo utilizas Apple Music mediante la red, con formato efectivo todavía desconocido.
- La PC produce aproximadamente un segundo de audio robótico y luego se recupera. Ocurre en distintas aplicaciones, incluido YouTube y Tidal; sucede menos por óptico que por USB.

Estas son observaciones tuyas, no mediciones realizadas aquí. Son dos problemas distintos: **preferencia estable de sonido** y **fallos breves de reproducción**. No utilizaremos el segundo para explicar automáticamente el primero.

## 2. Datos objetivos de la PC

| Comprobación | Resultado | Qué no demuestra |
|---|---|---|
| Sistema | Garuda Linux; kernel 7.2.3-zen1-2-zen | No describe necesariamente sesiones anteriores. |
| Servidor | PipeWire y pipewire-pulse 1.6.8; WirePlumber 0.5.17 | No identifica el códec de una canción. |
| Salida | ALC1220 Digital, `iec958:0`, estéreo óptico | El RME no estaba conectado por USB; esa ruta no se probó. |
| ALSA inicial | S32_LE, dos canales, 192000 Hz | El contenedor de 32 bits no significa 32 bits útiles por S/PDIF. |
| Códec digital | Anuncia 32000/44100/48000/88200/96000/192000 Hz y 16/20/24 bits | No anuncia 176400 Hz. La capacidad anunciada no es una prueba de recepción íntegra en el RME. |
| Regla global inicial | Forzaba `audio.rate=192000`, `node.force-rate=192000`, `node.force-quantum=2048` a todas las aplicaciones PulseAudio | No convertía una fuente comprimida en una grabación de alta resolución. |
| Zen | Flujos F32LE de 48 kHz; pausados en la lectura inicial | No verifica el formato de una sesión anterior de Tidal. |
| Cider inicial | Flujo activo F32LE de 192 kHz | Es PCM entregado al servidor; no es el bitrate de Apple Music. |
| Volumen óptico | Primera lectura: 47%, −19.67 dB. Antes y después del primer reinicio: 59%, −13.75 dB | No conocemos el nivel equivalente del Eversolo. El volumen cambió durante la sesión, antes de los reinicios; nuestros comandos no lo modificaron. |
| EasyEffects | Ausente de la ruta activa; preferencias en bypass | Tener presets guardados no significa que se estén aplicando. |
| Ahorro HDA | `power_save=0`, `power_save_controller=N` | Ya estaba desactivado; no lo presentamos como arreglo nuevo. |

Comandos utilizados: `wpctl`, `pactl`, `pw-dump`, `pw-metadata`, `pw-top`, `pw-config`, `pacman -Q`, `journalctl`; lectura de `/proc/asound`, parámetros de `snd_hda_intel` y archivos de configuración.

El nodo contenía `alsa.resolution_bits=16`, mientras ALSA usaba S32_LE y el códec anunciaba hasta 24 bits digitales. **No concluimos que estuvieras escuchando a 16 bits ni que los 24 bits estuvieran comprobados.** Hace falta verificar los datos recibidos mediante el Bit Test del RME.

## 3. Cider: EQ apagada no equivale a ausencia de otros efectos

En `/home/n30/.config/sh.cider.genten/spa-config.yml` encontramos:

| Ajuste guardado | Antes | Después |
|---|---|---|
| Ecualizador convencional | Apagado | Apagado |
| Cider Audio | Activado | Desactivado |
| PPE, perfil MAIKIWI | Activado | Desactivado |
| Atmos, preferencia binaural | Activado | Desactivado |
| Crossfade, 5 segundos | Activado | Desactivado |
| Automix | Activado | Desactivado |
| Normalización, objetivo guardado −14 LUFS | Activada | Conservada |
| Volumen de Cider | 1 | Conservado |

El código instalado en `/usr/lib/cider/resources/spa/assets/ws-BYB7BHl2.js` relaciona PPE con un nodo de procesamiento y MAIKIWI con un archivo de respuesta impulsional. Es evidencia de que PPE puede modificar la señal mediante convolución. No capturamos el audio previo al cambio ni el grafo interno en vivo: **no cuantificamos su efecto en la canción concreta**.

Atmos habilitado no prueba que estuvieras reproduciendo una mezcla Atmos. Crossfade y Automix afectan especialmente las transiciones; no explican por sí solos una diferencia sostenida durante toda la canción. Estos ajustes tampoco explican el ruido que aparece en otras aplicaciones.

Se conservó la normalización para no introducir simultáneamente un posible aumento de nivel. Normalizar puede consistir en aplicar una ganancia constante a una pista; no implica necesariamente comprimir su dinámica. Sigue pendiente igualarla con la configuración del Eversolo.

Cider se cerró normalmente mediante MPRIS, se respaldó y editó su configuración y se volvió a abrir. Se comprobaron los ajustes guardados después del arranque. El primer lanzamiento directo de Electron falló; arrancó desde el gestor de sesión, sin desactivar el sandbox de la aplicación.

## 4. Explicaciones de la diferencia sonora: hipótesis, no causas demostradas

### Nivel y procesamiento

La PC atenúa digitalmente la salida y Cider tenía efectos adicionales configurados. Usar la misma EQ en el RME no elimina cambios introducidos antes de ella. La primera comparación útil debe igualar el nivel efectivo, no los porcentajes de volumen.

Si compensas fuentes con distintos controles, verifica también Loudness en el RME: su compensación depende del volumen configurado en el DAC. Esto es una variable pendiente; no demuestra que escucharas simplemente más fuerte. [Manual del RME](https://rme-audio.de/downloads/adi2dac_e.pdf).

La atenuación digital no demuestra por sí misma una pérdida audible de detalle. Su importancia depende del formato efectivo, ruido, ganancias posteriores y nivel de escucha; aquí es, ante todo, una diferencia que hay que controlar.

### Misma grabación y formato

Tidal con máxima calidad seleccionada no certifica por sí solo el formato de cada canción ni que se compare el mismo máster que Apple Music. Apple distribuye AAC y ALAC. Una lectura de 192 kHz en el DAC no identifica cuál llegó originalmente por la red. [Apple: audio sin pérdida](https://support.apple.com/en-us/118295).

Que no distingas Cider y Tidal en tu PC reduce el interés práctico de atribuirlo todo a AAC, aunque no es una comparación controlada de códecs.

El DMP-A6 ofrece la app Apple Music y también AirPlay como rutas diferentes. Falta identificar si el teléfono transmite audio o sólo controla una aplicación ejecutada en el Eversolo. No hemos supuesto que esa ruta sea lossless. [Manual original del DMP-A6](https://music.eversolo.com/dmp/instruction/EVERSOLO-DMP-A6-User-Manual-v1.0.pdf).

### Remuestreo

La regla inicial imponía 192 kHz incluso a flujos de menor frecuencia. Eliminar conversiones innecesarias facilita verificar la integridad de la señal. No recupera información perdida ni garantiza mayor nitidez audible. El remuestreador de PipeWire tiene compromisos entre filtrado, carga y latencia. [Propiedades de audio de PipeWire](https://docs.pipewire.org/devel/page_man_pipewire-props_7.html).

### Transporte, reloj y energía

TOSLINK no establece una conexión conductora de masa entre fuente y DAC. En tu conexión óptica, el DAC interno y la etapa analógica del Eversolo no realizan la conversión a analógico. Sus prestaciones no explican directamente esta comparación.

El RME utiliza SteadyClock FS para reducir la influencia del jitter de entrada. Atribuir una diferencia grande a un reloj mejor sin mediciones no está justificado; tampoco se deduce que cualquier implementación digital sea necesariamente equivalente. [Manual RME, SteadyClock](https://rme-audio.de/downloads/adi2dac_e.pdf).

No encontramos evidencia que justifique comprar una fuente lineal, un cable óptico más caro o un acondicionador eléctrico para resolver tu preferencia sonora. Esto no invalida la preferencia; limita las explicaciones que podemos sostener.

### Condiciones de escucha

El ruido de ventiladores con audífonos abiertos, recolocación de las copas, pequeñas diferencias de nivel y memoria auditiva son variables que podemos controlar. No medimos cuál interviene. No se atribuye automáticamente tu experiencia a un sesgo.

## 5. Opiniones publicadas en internet

Estas son experiencias de sus autores, separadas de nuestros datos:

| Fuente | Lo que describe | Límite de aplicación |
|---|---|---|
| [John Grandberg en Darko.Audio](https://darko.audio/2023/08/second-opinion-eversolo-dmp-a6-review/) | Buena presentación espacial y dinámica como transporte; prefiere USB por densidad tonal en su equipo, reconociendo la influencia del DAC usado. Frente a otro transporte, las diferencias fueron difíciles de distinguir consistentemente. | Evalúa salidas digitales, pero con otro DAC. No prueba PC frente a Eversolo en el RME. Su preferencia USB no predice tu experiencia. |
| [What Hi-Fi?: DMP-A6](https://www.whathifi.com/reviews/eversolo-dmp-a6) | Sonido directo, definido y con pegada en sus sistemas de amplificador y bocinas. | No aísla nuestra comparación de transportes alimentando el mismo RME. Sus adjetivos no constituyen una explicación técnica. |

Mi valoración: la prueba de mayor utilidad ahora es comparar la misma señal con niveles y procesamiento controlados. Sirve para investigar una preferencia real sin inventar un mecanismo que la justifique.

## 6. Configuración aplicada

1. **Retirado el forzado universal de 192 kHz y quantum 2048.** Frecuencia predeterminada de 48 kHz; permitidas 44.1/48/88.2/96/192 kHz. El cambio automático requiere que la ruta pueda quedar inactiva. Una aplicación que la mantenga abierta puede impedirlo. [Configuración PipeWire](https://docs.pipewire.org/page_man_pipewire_conf_5.html).
2. **Remuestreo de calidad 10** en clientes nativos y en `pipewire-pulse`, donde se procesan sus clientes. Prioriza filtrado cuando hace falta convertir; no es una escala de calidad percibida. Se eliminó la propiedad singular `channelmix.lock-volume`, distinta de la documentada `channelmix.lock-volumes`, y el comentario erróneo que la relacionaba con el reloj.
3. **Margen de planificación mayor:** quantum predeterminado 1024, mínimo 512 y máximo 2048 a 48 kHz, equivalentes a 21.3/10.7/42.7 ms. Son duraciones de bloque, no latencia total. Es una prueba de estabilidad ante el ruido robótico; puede aumentar la latencia en juegos o monitorización. No se presenta como cambio de tonalidad.
4. **Cider en referencia estéreo** con PPE, Atmos, crossfade y Automix desactivados. Normalización y volumen conservados. La EQ del RME no se tocó.

Archivos editados:

- `/home/n30/dotfiles/.config/pipewire/pipewire.conf.d/99-rme-fix.conf`
- `/home/n30/dotfiles/.config/pipewire/pipewire-pulse.conf.d/force-192k.conf` — conserva el nombre histórico, pero ya no fuerza 192 kHz.
- `/home/n30/dotfiles/.config/pipewire/client.conf.d/resampling.conf`
- `/home/n30/.config/sh.cider.genten/spa-config.yml`

Encontramos reglas antiguas para RME USB ubicadas en la configuración de PipeWire en lugar del monitor de WirePlumber. No las activamos porque USB no era la ruta auditada. Aumentar headroom regula entrega y buffers; no demuestra una mejora del reloj físico. [Configuración ALSA de WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html).

## 7. Pruebas realizadas y límites

Se reprodujeron WAV de silencio estéreo de 24 bits, cuatro segundos por frecuencia, leyendo ALSA `hw_params` durante la reproducción. No se subió el volumen ni se reprodujeron tonos audibles.

| Frecuencia del archivo | Con Cider abierto | Con Cider cerrado |
|---|---:|---:|
| 44.1 kHz | Salida permaneció en 192 kHz | Salida 44.1 kHz |
| 48 kHz | Salida permaneció en 192 kHz | Salida 48 kHz |
| 96 kHz | Salida permaneció en 192 kHz | Salida 96 kHz |
| 192 kHz | Salida 192 kHz | Salida 192 kHz |

Los ocho procesos terminaron sin error. Evidencia: `rate-tests.json` y `rate-tests-cider-open.json`. La prueba se hizo antes de ampliar finalmente los buffers; la política de frecuencias no cambió después.

**Esto verifica negociación y apertura de ALSA, no bit-perfect ni igualdad de las salidas analógicas.** Después de reabrir Cider se observaron Cider y Zen entregando 48 kHz, con salida ALSA a 48 kHz. Es una ruta compartida; puede seguir habiendo remuestreo dentro de la aplicación, mezcla, volumen digital y normalización.

Antes de los cambios apareció `ERR=1` acumulado en el nodo óptico, sin marca temporal que lo vincule a tu ruido. Lecturas cortas posteriores mostraron cero, pero reiniciar también reinicia contadores: no permite comparar fiabilidad a largo plazo. El journal no aportó un fallo de audio concluyente. Un aviso genérico sobre gestión de energía USB al arrancar no prueba la causa de tus errores USB.

La captura final adicional de 30 segundos **no se ejecutó**: la revisión automática la rechazó por límite de uso. No se presenta como una prueba pasada.

El audio robótico puede corresponder a entrega tardía/repetición de bloques, planificación/controlador o recuperación de sincronía. Son hipótesis. Al ocurrir en varias aplicaciones, no se atribuye exclusivamente a Cider. Conservar óptico es razonable por tu experiencia de estabilidad; no demuestra una inferioridad sonora universal de USB.

## 8. Cómo resolver lo que aún no sabemos

### Comparación de sonido normal

1. Usa el mismo archivo estéreo local en ambas fuentes; evita comparar versiones de álbum distintas. Cierra otras aplicaciones de audio.
2. Conserva el mismo RME, entrada óptica, EQ, filtro, referencia de salida y ajuste del Aune. Mantén la PC encendida en ambas condiciones para igualar el ruido ambiental.
3. Iguala el nivel efectivo; los porcentajes de volumen no son equivalentes entre aparatos. Si puedes medir la salida analógica, busca una diferencia no mayor de 0.1 dB. Revisa Loudness y normalización.
4. Compara fragmentos cortos, anotando por separado preferencia e identificación. Otra persona puede alternar fuentes sin decirte cuál suena; fija de antemano el orden aleatorio y el número de pruebas.
5. Si persiste una diferencia repetible, compara primero capturas digitales alineadas y después la salida analógica. Si los datos son idénticos, se acota mucho la explicación por procesamiento de la fuente.

### Integridad de la ruta

El Bit Test oficial del RME detecta patrones recibidos sin modificación. Para probarlo, desactiva DSP anterior al RME y normalización y utiliza ganancia digital de fuente a unidad. S/PDIF permite hasta 24 bits: prueba 16 y 24. La ausencia del mensaje de éxito no identifica la causa del fallo. [Manual RME, Bit Test](https://rme-audio.de/downloads/adi2dac_e.pdf).

**Antes de llevar la PC al 100%, baja el nivel en el Aune/RME:** desde el 59% observado son unos 13.75 dB de aumento. No lo hicimos automáticamente. La prueba de integridad es diagnóstica; no necesitas abandonar tu EQ para escuchar música normalmente.

### Audio robótico

Compara sesiones de al menos una hora, anota la hora exacta de los fallos y correlaciónala con los contadores de PipeWire y el estado de sincronización del RME. La ausencia de incremento en ERR no descarta un problema antes o después del servidor. Puede ser útil capturar los datos ópticos recibidos, pero no se conectó ni configuró una captura durante esta auditoría. No se da el problema por resuelto.

## 9. Reversión

Los respaldos y evidencia están en `/home/n30/dotfiles/share/scripts/audio-audit-2026-09-11/`.

Restaurar PipeWire:

```zsh
python /home/n30/dotfiles/share/scripts/audio-audit-2026-09-11/restore-pipewire.py
```

Reinicia brevemente el audio y rechaza sobreescribir archivos modificados después de la auditoría.

Para restaurar sólo los cinco ajustes de Cider, ciérralo normalmente y ejecuta:

```zsh
python /home/n30/dotfiles/share/scripts/audio-audit-2026-09-11/restore-cider.py
```

Conserva las demás preferencias actuales. No se modificó `audio_rules.md`, no se cambió el volumen por comandos y no se compró equipo.

## 10. Comprobación específica: ¿la interferencia de una PC gamer explica el resultado?

Ampliación solicitada tras la auditoría. Se volvió a comprobar por DMI la placa **ASUS PRIME Z690-A** y por ALSA la salida **ALC1220 Digital**. El [manual de ASUS](https://dlcdnets.asus.com/pub/ASUS/mb/LGA1700/PRIME_Z690-A/E18708_PRIME_Z690-A_UM_WEB.pdf) confirma la salida óptica S/PDIF. Se mantiene la cadena declarada PC → óptico → RME → Aune → HE1000se.

**Veredicto provisional:** una PC puede generar perturbaciones eléctricas y ruido acústico, pero no está demostrado que esas perturbaciones expliquen tu preferencia durante la reproducción normal. La afirmación de que una PC gamer necesariamente entrega audio menos limpio no se sostiene como regla aplicable a esta conexión.

La [documentación de Toshiba sobre TOSLINK](https://media.digikey.com/pdf/data%20sheets/toshiba%20pdfs/fiber-optic%20devices%20toslink.pdf) especifica aislamiento galvánico y que la fibra no capta interferencia electromagnética. Esto describe el enlace óptico: no convierte en inmunes los circuitos eléctricos del transmisor, receptor y amplificador, ni elimina otras conexiones conductoras que pudieran existir entre aparatos.

Una fuente perturbada podría afectar los tiempos del transmisor óptico o producir errores; la interferencia no viaja como corriente de masa por la fibra. RME publicó [mediciones con APx555B del ADI-2 DAC](https://forum.rme-audio.de/viewtopic.php?id=33497): señal de 1 kHz por óptico, jitter modulado a 50 Hz y amplitud creciente hasta 500 ns. En el aparato con firmware 35, el fabricante informa que el THD+N no empeoró en esa prueba. Es evidencia experimental del fabricante bajo condiciones definidas, no una medición de nuestro RME ni de todas las frecuencias y escenarios. No comprobamos el firmware de tu unidad.

| Vía posible | Aplicación a esta cadena | Cómo distinguirla |
|---|---|---|
| Corriente de ruido por el cable de audio | La fibra óptica corta esa vía | Confirmar que no queda otro enlace conductor PC–RME, como USB conectado aunque no esté seleccionado. |
| Jitter del transmisor | Posible en origen; RME dispone de rechazo medido | Medir la salida analógica ante jitter/carga controlados; el Bit Test no mide jitter ni ruido analógico. |
| Radiación o ruido por alimentación común | Físicamente posible; no medido aquí | Eversolo como única fuente, comparar PC encendida/apagada y medir la salida analógica manteniendo fijo lo demás. |
| Ventiladores o coil whine audibles | Pueden llegar por el aire a audífonos abiertos | Mantener PC encendida, igual posición y carga en la comparación de transportes; para separar acústica de electrónica hace falta medición o aislamiento acústico. |
| Audio robótico | Fallo temporal descrito en varias aplicaciones | Correlacionar evento con contadores y sincronización; no demuestra contaminación continua del sonido. |

**Experimento con mayor poder de discriminación:** mantener reproduciendo el Eversolo por óptico, sin cambiar canción, nivel, EQ ni amplificador, y comparar con la PC encendida y apagada. Guardar antes cualquier trabajo. Si la diferencia aparece aun sin usar la PC como fuente, investigar influencia ambiental, alimentación o conexiones restantes. Esa prueba por escucha sola no separa ventiladores de interferencia eléctrica. Si no aparece y sólo cambia el resultado al seleccionar la PC como fuente con ésta encendida en ambas condiciones, la hipótesis de contaminación ambiental permanente pierde fuerza; siguen pendientes señal digital, nivel, procesamiento y transporte.

No se apagó la PC, no se cambió cableado ni se midieron emisiones o salida analógica durante esta comprobación. Falta confirmar si la PC permanece encendida al escuchar el Eversolo y si USB queda físicamente desconectado. No se aplicaron más ajustes de software en esta ampliación.
