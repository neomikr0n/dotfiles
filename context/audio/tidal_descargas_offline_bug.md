# Descargas offline de TIDAL: ¿sigue el bug y hay solución?

**Fecha:** 20-sep-2026
**Pregunta:** con TIDAL Premium, la app de iOS se quedaba colgada descargando una canción y no
descargaba las demás. El mismo error se reprodujo en un Galaxy S21 Ultra. ¿Sigue pasando?
¿Es por tener listas gigantes? ¿Hay solución hoy?

Convención de esta carpeta: cada dato con **fuente** y **nivel de confianza**
(medido / declarado por la fuente / inferencia). Lo que no se sabe, se dice.

---

## Resumen

1. **No hay ningún indicio de que esté arreglado.** La versión actual (2.215.0, 16-sep-2026)
   no menciona descargas en sus notas, y hay reseñas del mismo síntoma en versiones
   recientes. Trabaja con la hipótesis de que **seguirá pasando**.
2. **El tamaño de la biblioteca no es la causa raíz, es el multiplicador.** La causa es que la
   cola de descargas no aísla el fallo de un elemento: si una pista falla, la cola se queda
   ahí. Más elementos = más probabilidad de topar con la pista mala.
3. **Sí hay mitigación hoy, pero es manual y fea:** bajar en lotes pequeños, con la app en
   primer plano, y cuando se atasca, quitar la descarga del elemento culpable y volver a
   añadirla. No hay arreglo definitivo del lado del usuario.
4. **El S21 Ultra no es casualidad:** que se reproduzca igual en Android demuestra que el fallo
   es del cliente de TIDAL, no de iOS. iOS y One UI solo lo empeoran por la gestión de
   procesos en segundo plano.

---

## 1. Estado del bug (medido)

| Dato | Valor | Fuente | Confianza |
|---|---|---|---|
| Versión iOS actual | **2.215.0**, publicada 16-sep-2026 | API de iTunes (`itunes.apple.com/lookup?id=913943275`) | medido |
| Notas de esa versión | «Correcciones de errores y mejoras de rendimiento» — plantilla, **sin mención a descargas** | misma API | medido |
| Calificación tienda MX | 4,70 con 21.492 valoraciones | misma API | medido |
| Ayuda oficial de modo offline en iOS | Última actualización **hace 4 años**; no dice nada de descargas atascadas | `support.tidal.com/hc/en-us/articles/115005843285` | medido |
| Ayuda oficial de solución de problemas | No menciona descargas en ningún punto | `support.tidal.com/hc/en-us/articles/22406092330257` | medido |

**Lectura:** TIDAL no documenta el problema, no lo reconoce y no anuncia ningún arreglo. Sus
notas de versión son genéricas desde hace muchas versiones.

### Reseñas reales (App Store MX / US / GB, versiones 2.199–2.215)

Citas literales, con la versión de la que vienen:

- **2.207.1 (1★, MX)** — «Problemas con las descargas: desde la última actualización ya no es
  posible descargar música nueva que agregues a tu biblioteca».
- **2.205.0 (3★, MX)** — «La descarga en iOS es lenta y torpe, **a veces no descarga canciones
  y directamente las bloquea y de ahí no pasa la descarga**». ← exactamente tu síntoma.
- **2.214.1 (1★, GB)** — «Every now and then, a reinstall is necessary because album downloads
  stop working. **This has been a known issue for a very long time.**»
- **2.205.0 (2★, GB)** — «Downloading Issues: **no new tracks from my collection are being
  added to download queue**». ← la cola deja de aceptar elementos.
- **2.200.0 (2★, GB)** — «App requires you keep app open in order to download items. […] I just
  watch a song say it's being downloaded — only to then see that **it's just been bumped to
  the back of the queue** and so on». ← describe el mecanismo.
- **2.202.1 (1★, GB)** — «awful downloads, keeps breaking and not downloading or **the download
  Que gets stuck**».
- **2.215.0 (3★, US)** — «Biggest issues that **haven't been resolved in the last decade** are
  consistent playback errors and getting music to actually download».

**Advertencia sobre esta muestra:** quien escribe reseña suele ser quien tiene el problema.
Esto **no mide la prevalencia**, solo demuestra que el síntoma **persiste** hasta versiones
de septiembre de 2026. No es prueba de que te vaya a pasar a ti; sí es prueba de que no está
cerrado.

---

## 2. Por qué pasa (mecanismo)

### a) La cola no aísla el fallo

Un vendedor de conversores de TIDAL (Ondesoft — **interés comercial**, tómese con reserva)
describe el comportamiento así:

> «Sometimes the download gets stuck on one song and **unless you remove the album it won't
> continue**.»

Y su recomendación explícita: **«Don't queue the entire library to download. If you queue the
entire library to download, Tidal may get stuck.»**

Eso es un fallo de diseño de la cola: **sin timeout por elemento y sin reintento individual**.
Un elemento que no termina bloquea a todos los que vienen detrás. Confianza: **declarado por
tercero**, no por TIDAL. Coincide con las reseñas de usuarios, que es lo que le da peso.

### b) Del lado de TIDAL hay pistas que sí fallan — y está documentado

El *changelog* de `tidekeeper`, un cliente de descarga de TIDAL independiente y activo,
documenta en 2026 los estados que su código tuvo que manejar para no atascarse:

| Estado que devuelve TIDAL | Entrada del changelog | Fecha |
|---|---|---|
| «asset not ready» | «OpenAPI manifest requests again stop after six 'asset not ready' retries instead of up to **64**» | 2-sep-2026 |
| HTTP 404 permanente | «Permanent download errors such as HTTP 404 **fail immediately** instead of retrying for tens of seconds» | 16-ago-2026 |
| HTTP 429 (límite de peticiones) | «Reduced HTTP 429 rate-limit errors by **pacing** playback manifest requests» | 30-jul-2026 |
| `CLIENT_NOT_ENTITLED` | «no longer retries DOWNLOAD→PLAYBACK after permanent `CLIENT_NOT_ENTITLED` blocks» | 5-ago-2026 |

**Fuente:** `github.com/OpenNerdz/tidekeeper/blob/main/CHANGELOG.md`. Confianza: **declarado por
un tercero técnico**, verificable, pero describe el comportamiento de la API de TIDAL visto
desde fuera, no la app oficial. La inferencia — que la app oficial se topa con los mismos
estados — es razonable pero **no está confirmada por TIDAL**.

**Consecuencia:** en una biblioteca grande la probabilidad de que *al menos un* elemento esté
en estado «not ready», retirado del catálogo (404) o sin licencia para descarga tiende a 1.
Y con la cola que no aísla, ese único elemento tumba la operación completa.

### c) La descarga vive dentro de la app, no en el sistema

Apple documenta que las descargas en segundo plano con `URLSession` **siguen ejecutándose
aunque la app esté suspendida** (`developer.apple.com/documentation/foundation/downloading-files-in-the-background`).

Todas las reseñas que hablan del tema coinciden en lo contrario para TIDAL: **«the app needs
to be open on it»**, «requires you keep app open in order to download items». Es decir, TIDAL
está descargando en el proceso de la app, y cuando iOS la suspende (bloqueo de pantalla, cambio
de app, pantalla apagada) **la descarga muere**.

La documentación de Apple es un hecho. Que TIDAL **no** use sesiones en segundo plano es una
**inferencia fuerte** a partir de los informes de usuarios, no una confirmación de TIDAL.

### d) Por eso también falla en el S21 Ultra

Android mata apps en segundo plano igual o peor (optimización de batería de One UI, ahorro de
datos). Que reproduzcas el mismo error en un Samsung descarta la hipótesis «es un bug de iOS» y
apunta al cliente: **el mismo gestor de descargas, con los mismos dos defectos**.

---

## 3. Por qué Apple Music nunca te dio ese problema

Diferencia estructural, no de suerte:

| | TIDAL | Apple Music |
|---|---|---|
| Quién ejecuta la descarga | El proceso de la app | Servicio de transferencia del sistema |
| App suspendida o cerrada | La descarga se para | La descarga continúa |
| Un elemento que falla | Bloquea la cola | Se reintenta por separado |
| Biblioteca offline | Lista plana, sin búsqueda ni filtros | Biblioteca gestionada con reconciliación |

Las tres primeras filas están respaldadas por la documentación de Apple y por los informes de
usuarios. La cuarta es **observación de reseñas**, no una comparación medida por mí.

Hay un cuarto problema de TIDAL que agrava todo y aparece repetido en reseñas: **la app te
saca la sesión cuando no hay internet** («Signing out — would have been five if I could listen
to offline without it signing me out»). Como el contenido offline está cifrado y atado a la
sesión, quedarte sin cobertura en un avión puede dejarte **con los archivos en disco y sin
poder abrirlos**. Una reseña de GB lo describe con precisión: 45 GB de datos de descarga
presentes en el analizador de almacenamiento, pero «they just aren't detected».

---

## 4. El dato de los 0,5 TB: ¿es la causa?

**No.** Es el multiplicador. Pero conviene saber qué implica ese número, porque **el mismo
0,5 TB son 3.300 pistas o 52.000 pistas según la calidad de descarga**:

| Calidad de descarga | Tamaño por pista (4 min) | Pistas que caben en 500 GB |
|---|---|---|
| Max — FLAC 24/192 | ~150 MB | ~3.300 |
| Max — FLAC 24/96 | ~75 MB | ~6.700 |
| Max — FLAC 16/44,1 | ~26 MB | ~19.000 |
| High — AAC 320 kbps | ~9,6 MB | ~52.000 |

Cálculo propio, **estimación**: asume pista media de 4 minutos, estéreo, y compresión FLAC del
~55 %. Los tamaños de FLAC varían según el material. TIDAL confirma que Max llega a 24 bits /
192 kHz (`support.tidal.com/hc/en-us/articles/17412130162961`); el resto son cifras habituales
del formato, no publicadas por TIDAL.

**Cómo leer la tabla:**

- Si estás descargando en **Max**, 0,5 TB son apenas ~3.300 pistas. **Eso no es una biblioteca
  gigante**, así que el tamaño queda descartado como causa.
- Si estás en **High (AAC 320)**, 0,5 TB son ~52.000 pistas. Ahí sí es grande — pero el
  problema seguiría siendo la cola que no aísla, no el tamaño en sí.

En ambos casos la conclusión es la misma: **el tamaño agrava la exposición y alarga la
recuperación, pero no es el origen.**

---

## 5. Qué hacer hoy

### Lo que sí funciona

1. **Bajar en lotes pequeños.** Unos pocos álbumes o listas a la vez, y esperar a que termine
   cada lote antes de empezar el siguiente. **Nunca** encolar la biblioteca entera de una vez.
2. **Mantener la app en primer plano durante la descarga**, pantalla encendida y sin
   autobloqueo, cargando y con Wi-Fi bueno. Es la única ventana en la que la descarga avanza.
3. **Cuando se atasca: identificar el culpable y quitarlo.** En `My Collection > Downloads`,
   localizar el elemento que lleva rato en «descargando», quitar su descarga y volver a
   añadirla. La cola se descongela y sigue con el resto. Es el *workaround* documentado.
4. **Si la cola deja de aceptar elementos nuevos** (síntoma distinto: nada entra en la cola),
   el estado de la app está corrupto y el único reinicio conocido es cerrar sesión y volver a
   entrar, o reinstalar. **Coste:** volver a descargar lo que tengas.
5. **Bajar la calidad de descarga si descargas al teléfono.** En
   `Settings > Downloads > Audio`, elegir **High** en vez de **Max** corta el tamaño ~4× y, sobre
   todo, **acorta la ventana en primer plano**, que es donde falla. Ojo: según TIDAL, «your
   choice will only apply to future downloads» — para cambiar lo ya descargado hay que borrarlo
   y volver a bajarlo.
6. **iOS:** Low Power Mode apagado, Background App Refresh activado para TIDAL, batería por
   encima del 20 %, y espacio libre de sobra (si el almacenamiento se llena a mitad, la
   descarga falla).
7. **Samsung S21 Ultra:** batería de TIDAL en **Unrestricted** (no «Optimized») y ahorro de
   datos desactivado para la app.
8. **Reportarlo con datos:** `support.tidal.com`, indicando la pista concreta que se atasca.
   Varias reseñas reportan que soporte ha respondido que **de momento no tienen solución** —
   pero sin reportes no hay presión para arreglarlo.

### Lo que no funciona

- Esperar. La cola no se desatasca sola.
- Confiar en que el indicador «descargado» signifique algo. Hay reseñas que describen
  descargas marcadas como completas y que en realidad no lo están.
- Reinstalar como rutina. Funciona como reinicio, pero a 0,5 TB de biblioteca es un coste
  enorme cada vez.
- Esperar un arreglo. No hay ninguno anunciado ni en las notas de la versión del 16-sep-2026.

### La recomendación honesta

Si necesitas offline **fiable** para viajar, TIDAL hoy no es la herramienta. Ya tienes la
solución en casa: **Apple Music para offline** (es la app que gestiona la descarga a nivel de
sistema y es la que nunca te falló) y **TIDAL para escuchar en calidad en la cadena de
escritorio**. El coste es mantener dos suscripciones, y eso es una decisión tuya, no técnica.

Alternativa a considerar si quieres una sola app con calidad alta y offline decente: Qobuz.
No lo he verificado para este caso, así que **no lo doy por bueno** sin comprobarlo.

---

## 6. Lo que no pude verificar

- **Si el bug está arreglado o no en la 2.215.0.** No tengo tu dispositivo. Lo único que
  puedo afirmar es que las notas de versión no lo mencionan y que hay reseñas recientes con el
  mismo síntoma. **Tu prueba manda**: si lo reproduces en la versión actual, sigue vivo.
- **Un artículo que afirmaba que TIDAL arregló las descargas en segundo plano en junio de
  2026.** Lo encontré en un blog de contenido automatizado, el enlace daba 404 y no aparece
  respaldado por ninguna nota de versión oficial. **Lo descarto como evidencia.**
- **Límite de pistas descargables por cuenta.** TIDAL no publica ninguno. Lo único documentado
  es el límite de **5 dispositivos** con contenido offline simultáneo
  (`support.tidal.com/hc/en-us/articles/201623252`), y que cada dispositivo descarga lo suyo
  por separado — no hay transferencia entre dispositivos.

---

## Fuentes

- App Store / API de iTunes, ficha de TIDAL (id 913943275), tiendas MX/US/GB — versión 2.215.0, 16-sep-2026.
- `support.tidal.com/hc/en-us/articles/360003650917` — Change sound quality level (`Settings > Downloads > Audio`).
- `support.tidal.com/hc/en-us/articles/17412130162961` — HiRes FLAC (hasta 24 bits / 192 kHz).
- `support.tidal.com/hc/en-us/articles/201623252` — límite de 5 dispositivos offline.
- `support.tidal.com/hc/en-us/articles/115005843285` — Offline Mode with the iOS App (sin actualizar desde 2022).
- `developer.apple.com/documentation/foundation/downloading-files-in-the-background` — descargas en segundo plano.
- `github.com/OpenNerdz/tidekeeper/blob/main/CHANGELOG.md` — estados de la API de TIDAL (cliente de terceros).
- `ondesoft.com/tidal-music/fix-tidal-offline-mode-not-working.html` — «stuck on one song» (vendedor de conversores, interés comercial).
- `viwizard.com/tidal-music-tips/fix-tidal-download-paused.html` — «keep the app in the foreground» (mismo sesgo).
