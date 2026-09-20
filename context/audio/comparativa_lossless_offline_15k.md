# Lossless en Arch Linux + biblioteca offline de 15.000 canciones

**Fecha:** 20-sep-2026
**Pregunta:** además de Spotify y Apple (que nunca han fallado en descarga offline), qué servicios
permiten (a) escuchar sin pérdida en el escritorio con Arch Linux, (b) mantener ~15.000 canciones
descargadas en el teléfono. Datos, curiosidades, quién tiene los mejores algoritmos y en quién
confían los audiófilos.

Convención de esta carpeta: cada dato con **fuente** y **nivel de confianza**. Lo que no se sabe,
se dice. Precios en MXN.

---

## El titular incómodo

**Ningún servicio cumple las tres condiciones a la vez.** Cada uno falla en un sitio distinto:

| | Qobuz | TIDAL | Spotify | Apple Music | Deezer | Amazon Music |
|---|---|---|---|---|---|---|
| **Lossless en Arch** | parcial | **sí** | **sí** | no | parcial | no |
| **15.000 offline** | **sí** | **sí** | **no** | sí | sin dato | sin dato |
| **Offline fiable** | **sí** | **no** | sí | sí | sin dato | sin dato |

Leyenda: **sí** = cumple · **no** = no cumple · **parcial** = sólo por vías indirectas ·
**sin dato** = no pude verificarlo en esta pasada, no lo doy por bueno.

Los tres que al menos pasan el filtro de Linux son **Qobuz, TIDAL y Spotify**. Los otros tres
quedan fuera por motivos duros, no por opinión:

- **Apple Music** — no existe cliente para Linux, y el envoltorio Cider entrega **AAC-LC 256 kbps**
  (medido en tu equipo el 20-sep). Sin pérdida en Linux, punto. En el iPhone sigue siendo la mejor
  opción de offline.
- **Amazon Music Unlimited** — no hay cliente de escritorio para Linux y **el reproductor web está
  limitado a SD**. Sólo hay un instalador no oficial por Wine, que no es una vía bit-perfect.
- **Deezer** — no hay app oficial para Linux (existe un port no oficial, `aunetx/deezer-linux`), y
  **México no aparece con plan HiFi**: `deezer.com/mx/offers` sólo lista Premium (US$11,99) y
  Family (US$19,99). Deezer HiFi es FLAC 16 bits/44,1 kHz y va incluido en Premium «en la mayoría
  de países» según su propia ayuda — **si México es una de las excepciones, no lo pude confirmar.**

---

## 1. El dato que descarta a Spotify para tu caso

**Spotify tiene un tope de 10.000 canciones descargadas por dispositivo**, en hasta 5 dispositivos.
Texto literal de su ayuda oficial en español:

> «Puedes descargar hasta 10 000 canciones en hasta 5 dispositivos distintos.»

Y además, la condición que casi nadie lee:

> «Debes conectarte a Internet al menos una vez cada 30 días para poder seguir escuchando el
> contenido descargado.»

**15.000 canciones no caben.** No es un matiz: es un techo duro. Otros datos del mismo artículo:

- **La versión gratuita sólo puede descargar pódcasts.** Música, nada. (Coincide con lo que ya
  medimos: estás en el plan gratuito a 160 kbps.)
- **No se pueden descargar canciones sueltas**, sólo listas o álbumes completos.
- Si superas 5 dispositivos, Spotify **borra las descargas del dispositivo que usaste menos**.
- Reinstalar la app = volver a descargarlo todo.

*Fuente: `support.spotify.com/es/article/listen-offline/` — medido, texto oficial.*

---

## 2. El problema aritmético de 15.000 canciones sin pérdida

Antes de elegir servicio, hay que ver si el número cabe en un teléfono. Pista media de 4 minutos,
estéreo:

| Calidad | Por pista | 15.000 pistas |
|---|---|---|
| AAC 320 kbps | ~9,6 MB | **~144 GB** |
| FLAC 16/44,1 (calidad CD) | ~27 MB | **~405 GB** |
| FLAC 24/96 | ~75 MB | **~1,1 TB** |
| FLAC 24/192 | ~150 MB | **~2,25 TB** |

Cálculo propio, **estimación**: asume 4 min por pista, estéreo, compresión FLAC del ~55 %. Los
tamaños reales varían según el material.

**Conclusión:** 15.000 canciones sin pérdida **no caben en un teléfono normal**. A calidad CD son
~405 GB — que es exactamente tu «casi medio tera» de Apple Music, lo que encaja con una biblioteca
de ese orden. A alta resolución son más de 2 TB.

O sea: el requisito realista no es «15.000 sin pérdida en el teléfono», sino
**«15.000 en el teléfono, sin pérdida en casa»**. Eso cambia la respuesta, y es lo que hacen los
que se lo toman en serio: calidad máxima en la cadena de escritorio, calidad móvil en el bolsillo.

---

## 3. Qobuz

**Precio México (verificado en su web):** $149/mes, o **$1.498,80 al año con pago único**, que sale
a **$124,90/mes**. Catálogo: «más de 100 millones de pistas». Hi-Res 24 bits en todos los planes.

### Lo bueno

- **No hay tope de pistas offline.** Su ayuda dice que el número de pistas «depende del espacio
  disponible en tu dispositivo». Sin techo de 10.000. → **cumple los 15.000.**
- **La descarga sobrevive al cierre de sesión y a la reinstalación.** Texto literal de su ayuda:
  «On mobile: reinstalling or logging out of the application **will not** delete the downloaded
  music from your app.» Esto es lo contrario de Spotify y de TIDAL, y es exactamente el fallo que
  te hizo dejar TIDAL.
- **No se documenta** la obligación de reconectar cada 30 días que sí tiene Spotify.
- **Es el que mejor paga a los artistas:** **$0,018732 por reproducción** (cifra declarada por
  Qobuz, ejercicio cerrado en marzo de 2024), **4,4 veces la media del mercado**. TIDAL:
  $0,01284–0,0133. Apple: $0,006–0,010. Spotify: $0,003–0,005.

### Lo malo, y es grave

**Qobuz no tiene app oficial para Linux.** Su página de descargas ofrece Windows y macOS, más un
reproductor web. En México el web player funciona, pero **el web player no permite reproducción
offline** (dicho por Qobuz) y pasa por el navegador, que ya medimos que remuestrea internamente:
**no es bit-perfect**.

### El golpe de hoy mismo

El cliente nativo para Linux que resolvía esto era **QBZ** (Rust, bit-perfect, acceso exclusivo al
DAC, gapless, integración con biblioteca local, Qobuz Connect, y hasta reproducción de DSD por DoP).
Su desarrollador es **mexicano**. Hoy, **20-sep-2026**, he comprobado que:

| Comprobación | Resultado |
|---|---|
| `github.com/vicrodh/qbz` | **404** |
| `github.com/vicrodh/qbz/releases` | **404** |
| Paquete AUR `qbz-bin` (consulta a la API del AUR) | **no existe** |
| `snapcraft.io/qbz-player` | **404** |
| Flathub `com.blitzfc.qbz` | «no longer available… no longer maintained or distributed» |
| `qbz.lol` | **200**, pero con un aviso |

El aviso de `qbz.lol`, literal y bilingüe:

> «**QBZ Paused · En pausa.** QBZ is not available right now. The repository, the releases and the
> packages on Flathub, Snap, the AUR and my own apt and rpm repositories have been withdrawn. **I
> don’t know yet whether development continues**, and I don’t have a timeline to share.»

O sea: el repositorio, las versiones y los paquetes en Flathub, Snap, AUR y sus repos propios de
apt y rpm **fueron retirados**, y el desarrollo está en el aire. *Comprobado con peticiones HTTP
directas el 20-sep-2026; no se ha dado una razón pública.*

**Qué queda para Qobuz en Arch:**

1. **El DMP-A6.** Es la respuesta buena y ya la tienes: el Eversolo soporta Qobuz de forma nativa y
   sale en digital hacia el RME. Sale el PC, sale PipeWire, sale el remuestreador. Es la única vía
   bit-perfect de verdad que tienes hoy sin depender de un proyecto de un solo desarrollador.
2. **Roon Server en Linux** (hay paquete en el AUR) con Qobuz integrado. Funciona, cuesta dinero
   aparte, y es robusto.
3. **LMS + Squeezelite** con el plugin de Qobuz. Gratis, más trabajo, menos bonito.
4. **El reproductor web.** Funciona para escuchar, pero no es bit-perfect ni permite offline.

---

## 4. TIDAL

- **Cliente oficial para Linux** con HiRes FLAC hasta 24/192. Es el **único servicio de alta
  resolución con cliente de escritorio oficial para Linux**. En eso gana a todos.
- Sin tope de pistas offline publicado; **5 dispositivos** máximo, y cada dispositivo descarga lo
  suyo por separado (no hay transferencia).
- **Pero el offline está roto**, y no es opinión: la cola no aísla el fallo, la descarga muere al
  suspenderse la app, y se reproduce igual en iOS y en Android. Todo el detalle, con reseñas y
  fuentes, está en `tidal_descargas_offline_bug.md`, en esta misma carpeta.
- **Curiosidad con peso:** TIDAL abandonó MQA y 360 Reality Audio el **24 de julio de 2024** y
  sustituyó el catálogo por FLAC. Texto de su propia ayuda: «As of July 24, 2024, music in the MQA
  or 360 Reality Audio formats is no longer accessible». MQA Ltd había entrado en administración
  concursal en 2023. Fue el mayor golpe de credibilidad de la década en audio por streaming, y
  explica por qué la comunidad audiófila tardó años en volver a mirar a TIDAL.

---

## 5. Spotify

- **Cliente oficial para Linux** (deb/rpm/Flatpak) y **sin pérdida incluido en el Premium normal**
  desde el 10-sep-2025, FLAC hasta 24 bits/44,1 kHz — o sea, calidad CD, no alta resolución.
- En Arch funciona sin inventos. Es, con diferencia, el que menos te obliga a hacer malabares.
- **Pero el tope de 10.000 canciones descargadas lo descalifica para tu caso.**
- Aplica **normalización de sonoridad a −14 LUFS** en toda la reproducción, y en el plan gratuito
  no se puede descargar música en absoluto.

---

## 6. Quién tiene los mejores algoritmos

Aquí hay un estudio académico real, y **contradice el consenso popular**. El trabajo *The Diversity
of Music Recommender Systems* (ACM, CHIIR 2022) comparó cinco servicios con un método objetivo:

- Construyeron **tres listas de 20 canciones** con diversidad baja, media y alta, y las reprodujeron
  en cada servicio con **cuentas separadas** para evitar contaminación.
- Grabaron **las primeras 30 canciones sugeridas** por cada algoritmo (15 listas × 30 = 450
  recomendaciones).
- Midieron similitud con **factorización matricial entrenada en el Million Playlist Dataset de
  Spotify**, 50 características latentes por pista y similitud coseno. **Menos similitud = más
  diversidad.**

Resultados (similitud media; más bajo es más diverso):

| Servicio | Similitud media | Lectura |
|---|---|---|
| **YouTube Music** | **0,259** | el más diverso; **preserva** la diversidad de lo que le das |
| Apple Music | 0,287 | intermedio |
| Last.fm | 0,310 | intermedio |
| Pandora | 0,361 | intermedio (filtrado por contenido, Music Genome) |
| **Spotify** | **0,479** | **el menos diverso; reduce la diversidad** de lo que le das |

El detalle importante: **Spotify es el único que entrega recomendaciones sistemáticamente menos
diversas que la lista de entrada.** Le das variedad y te devuelve similitud.

**El matiz que hay que decir:** diversidad **no** es calidad. Spotify es el mejor optimizando
**enganche y satisfacción** — Discover Weekly, Release Radar, daylist, AI DJ, Wrapped — y eso
significa precisamente homogeneizar. YouTube Music gana en variedad. Apple tira mucho de
**curaduría humana** (editores, radio) y por eso queda en medio. Pandora usa el Music Genome Project,
que es filtrado por contenido puro.

**Y el detalle irónico del mismo estudio:** cuando miraron las reseñas de usuarios, de 1.000
reseñas analizadas **sólo 27** hablaban del sistema de recomendaciones, y **la percepción de los
usuarios era prácticamente igual en los cinco servicios** pese a las diferencias objetivas. La
gente no distingue.

**Qobuz juega otro deporte.** No compite en algoritmos: su apuesta es **editorial humana** —
Qobuzissime, Panoramas, reseñas semanales y una revista de hi-fi propia. Si lo que te gusta es
descubrir por criterio de una persona y no por máquina, Qobuz es el único de la lista que
deliberadamente renuncia al algoritmo. TIDAL, entre los grandes, es el más flojo en esto.

---

## 7. En quién confían los audiófilos (con datos, no con fama)

**1. Qobuz es la referencia.** No por marketing, por tres cosas verificables:

- **Paga 4,4× la media del mercado** a los artistas.
- **No aparece en las guías de normalización de sonoridad** de las grandes plataformas (Spotify
  −14 LUFS, Apple −16, TIDAL −14), lo que encaja con que aplique una referencia bastante más baja
  — hay reportes de **−18 LUFS con R128**, unos 4 dB por debajo de Spotify. Es decir, **toca menos
  la señal**. *Confianza media: la referencia de −18 LUFS viene de un foro técnico que cita una
  afirmación de Qobuz, no de un documento oficial que yo haya podido leer.*
- Nunca tuvo que desdecirse de nada. TIDAL sí: **MQA**.

**2. TIDAL es el pragmático.** Es el único con cliente Linux oficial y alta resolución. Pero arrastra
el expediente de MQA y el offline roto.

**3. Spotify es el que nadie discute y nadie defiende.** Imbatible en catálogo, apps y algoritmo de
enganche; irrelevante para escucha crítica por bitrate y por normalización.

**4. La respuesta real de un audiófilo serio es: archivos propios.** El propio desarrollador de QBZ
lo dijo en el foro de Audiophile Style: usa Qobuz «por la calidad inigualable frente a otras
plataformas y, más recientemente, por razones éticas». Y tú ya tienes la infraestructura: el DMP-A6
con almacenamiento local hacia el RME es la única vía **bit-perfect de verdad** de toda tu cadena,
según lo que medimos ayer.

**5. La señal de confianza más objetiva que existe hoy en tu caso:** en las revistas y foros
serios, el emparejamiento por defecto es **Qobuz para escucha crítica y Spotify para descubrir**.
Nadie propone Spotify para escucha crítica.

---

## 8. Curiosidades

- **Spotify y Apple Music cuestan exactamente lo mismo en México: $139/mes el plan individual.**
  Ambos subieron precios en 2026 y aterrizaron en la misma cifra. (Spotify: $139 individual, $74
  estudiantes, $189 dúo, $239 familiar — enero 2026. Apple: $139 individual, $75 estudiantes, $239
  familiar — julio 2026.)
- **Qobuz cuesta $124,90/mes con pago anual**: unos **$14 más barato que Spotify Individual**, y da
  alta resolución de verdad. Es la anomalía de precio del mercado mexicano.
- **Deezer Free no está disponible en México** — su web lo dice al entrar: «Deezer Free no está
  disponible en tu país». Y no ofrece plan HiFi en México.
- **Apple Music subió precios en México el 18 de julio de 2026 sin avisar por correo**: estudiante
  +$6, individual +$10, familiar +$40. Tercer ajuste en cuatro años.
- **A Qobuz le preguntaron por un cliente Linux en 2023 y respondió «coming soon».** En 2026 sigue
  sin existir. Ese correo es literalmente el motivo por el que nació QBZ — lo contó su autor.
- **El tope de 10.000 canciones de Spotify** existe desde la era del iPod y nunca se quitó, aunque
  Spotify sí eliminó en 2020 el límite de 10.000 elementos en «Tu biblioteca». El de descargas se
  quedó.
- **TIDAL afirma «más de 180 millones de canciones»**, Qobuz «más de 100 millones de pistas»,
  Spotify y Apple rondan los 100 millones. Las cifras son marketing y no son comparables entre sí:
  cuentan cosas distintas.
- **Deezer dice estar en más de 185 países.** Es el más ubicuo y el menos relevante para alta
  fidelidad.

---

## 9. Qué haría yo en tu lugar

El requisito «15.000 sin pérdida en el teléfono» no se sostiene: son ~405 GB a calidad CD. Lo que sí
se sostiene es **separar el problema en dos**, que es lo que ya insinuaste al decir que Apple y
Spotify nunca te fallan:

**Opción A — la más limpia y la más barata (recomendada):**
**Qobuz solo, $124,90/mes con pago anual.** La biblioteca offline del teléfono va en Qobuz (sin tope
de 10.000, y las descargas no se borran al cerrar sesión ni al reinstalar — justo lo que te falló en
TIDAL). En el escritorio, escuchas Qobuz **por el DMP-A6**, no por el PC. Con esto cumples las tres
condiciones por $14 menos al mes que Spotify Individual, con alta resolución de verdad y pagando
4,4× más a los artistas. **La pega:** no tendrás cliente nativo en Arch, y QBZ acaba de morir.

**Opción B — la de máxima comodidad en Linux:**
**Apple Music ($139) para offline en el iPhone + Spotify Premium ($139) para el escritorio.**
$278/mes. El iPhone ya sabes que no falla, y en Arch tienes cliente oficial con sin pérdida. La pega:
Spotify es calidad CD, no alta resolución, y no puede pasar de 10.000 descargas — así que el iPhone
se queda con las 15.000 y Spotify con lo que quieras tener a mano.

**Opción C — si quieres alta resolución nativa en Arch y puedes vivir con lo que sabemos:**
**Qobuz ($149) para el teléfono + TIDAL para el escritorio.** Pero pagar TIDAL teniendo su offline
roto, cuando el offline es justo lo que te importa, no lo recomiendo.

**Lo que no recomiendo:** pagar Qobuz esperando que QBZ vuelva. El aviso dice explícitamente que no
hay fecha ni certeza de continuación. Cuenta con el DMP-A6 y con el reproductor web, y si algún día
vuelve QBZ, mejor.

---

## 10. Lo que no pude verificar

- **Si Qobuz permite comprar y descargar música en México.** El desarrollador de QBZ, que es
  mexicano, escribió en el foro que «Purchases is not possible in Mexico» y que tuvo que usar una
  cuenta de Estados Unidos para probarlo. Pero la web mexicana de Qobuz se anuncia como «streaming
  y tienda de descargas Hi-Res». **Las dos fuentes discrepan y no lo pude resolver.** Si te
  interesa comprar música (que es la vía bit-perfect definitiva), hay que comprobarlo entrando a la
  tienda con tu cuenta.
- **El estado real de Deezer HiFi en México.** Su ayuda dice que HiFi va incluido en Premium «en la
  mayoría de países», con excepciones. La página mexicana no menciona HiFi. No confirmado.
- **Los límites de descarga offline de Deezer y de Amazon Music.** No encontré cifras oficiales.
- **El motivo de la retirada de QBZ.** No hay explicación pública. Que coincida en el tiempo con
  una app que se conecta a la API de Qobuz invita a pensar en presión legal, pero **es especulación
  y no la doy por buena**.
- **El estudio de algoritmos es de 2022.** Es la comparación objetiva más seria que existe, pero
  tiene cuatro años y los sistemas han cambiado. Lo uso porque el método es sólido, no porque sea
  actual.

---

## Fuentes

- `support.spotify.com/es/article/listen-offline/` — tope de 10.000 canciones, 5 dispositivos, reconexión cada 30 días.
- `www.qobuz.com/mx-es/discover` y `/discover/apps-partners` — precios México, catálogo, ausencia de app Linux.
- `help.qobuz.com/en/articles/10133` (actualizado 5-dic-2025) — offline, y que cerrar sesión o reinstalar no borra las descargas.
- `help.qobuz.com/en/articles/10143` — sin tope de pistas, sólo limitado por almacenamiento.
- `www.deezer.com/mx/offers` y `support.deezer.com/hc/en-gb/articles/115004588345` — planes México y naturaleza de HiFi (FLAC 16/44,1).
- `tunesmake.com/amazon-music/amazon-music-to-linux.html` y `nramkumar.org` — Amazon sin cliente Linux, web limitado a SD.
- `audiophilestyle.com/forums/topic/72029` — hilo de QBZ: capacidades, versiones 2.0/2.0.1/2.0.2, palabras del desarrollador, y el aviso de retirada.
- `qbz.lol` — aviso «QBZ Paused / En pausa» (comprobado 20-sep-2026).
- Consultas HTTP directas a GitHub, AUR (API RPC v5), Snapcraft y Flathub — estado de los paquetes de QBZ.
- `dl.acm.org/doi/fullHtml/10.1145/3490100.3516474` — *The Diversity of Music Recommender Systems*, ACM CHIIR 2022.
- `resources.onestowatch.com/ethical-spotify-alternatives-2026-payouts/` y `chartlex.com` — pagos por reproducción.
- `support.tidal.com/hc/en-us/articles/25876825185425` — fin de MQA y 360 Reality Audio el 24-jul-2024.
- `criticallisteninglab.com/en/learn/loudness` — objetivos de normalización por plataforma (Qobuz ausente).
- `cadenapolitica.com` (18-jul-2026) y `sdpnoticias.com` (8-ene-2026) — precios Apple Music y Spotify en México.
