# ¿El reproductor web de Qobuz (`play.qobuz.com`) hace streaming lossless?

**Fecha:** 20 de septiembre de 2026
**Pregunta:** «https://play.qobuz.com/ ¿hace streaming lossless?»
**Respuesta corta:** **Sí, entrega hasta FLAC 24-bit/192 kHz**, pero **no es un camino bit-perfect**
en este equipo, y **no permite escuchar sin conexión**. Para tu cadena RME es un **reproductor de
escritorio aceptable**, no la vía «de audiófilo».

---

## 1. Qué dice Qobuz de su propio web player

### Lo que Qobuz afirma explícitamente

| Dato | Fuente | Nivel |
|---|---|---|
| «Qobuz also has a **Webplayer** version» | help.qobuz.com §10153, «Qobuz apps» (16-ago-2022) | declarado por Qobuz |
| «Web Player — **Escucha tu música directamente en tu navegador**» | qobuz.com/discover/apps-partners (página oficial de ecosistema) | declarado por Qobuz |
| «Qobuz offers ... whichever quality, **on all our applications**» | try.qobuz.com | declarado por Qobuz |
| «You can purchase these formats from the download store, as well as in our **desktop applications and web player**» (incluye DSD y DXD 24/352,8) | help.qobuz.com §10167 | declarado por Qobuz |
| **No se puede escuchar sin conexión:** «Yes. With a **Studio or Sublime** subscription, you can download tracks, albums and playlists **in the app**» | help.qobuz.com §602448, «How to listen to Qobuz?» (11-mar-2026) | declarado por Qobuz |
| «The application started as a Qobuz client for paying subscribers who wanted to listen **without the audio quality limits of web browsers**» | README de QBZ (el cliente nativo de Linux, retirado el 20-sep-2026) | declarado por el autor de un cliente |

**Lectura importante:** en la documentación de Qobuz **no existe ninguna página que fije la calidad
máxima del web player con una cifra**, ni que diga «el web player se limita a 16/44,1» o «a 24/96».
Sencillamente **no lo documentan**. Y el número que sí aparece —el techo de **24-bit/192 kHz**— está
atribuido al **catálogo y al servicio**, no al reproductor web.

**Corrección de una confusión frecuente** (que yo mismo arrastraba de la charla anterior): el límite
de **24-bit/96 kHz** que Qobuz documenta (§10202) **no es del web player** — es de **Google Cast /
Chromecast**: «*by using Google Cast/Chromecast built-in ... (in 24-bit at 96 kHz in most cases and up
to 24-bit at 192 kHz on some devices)*». Son dos cosas distintas y conviene no mezclarlas.

### Lo que sí documentan, y es más útil para ti

La página **«How do I experience Hi-Res on PC?»** (help.qobuz.com §10202, 16-ago-2022) dice:

> «In order to enjoy Hi-Res quality on PC, it is advisable to use a **sound card external to your
> computer** and set your **Qobuz application** to one of the following playback modes, **WASAPI
> (exclusive) or ASIO**.»

Dos cosas que salen de ahí sin interpretar nada:

1. **El camino Hi-Res en PC, según Qobuz, pasa por la aplicación con WASAPI exclusivo o ASIO.**
   Ninguno de los dos existe en Linux (son APIs de Windows), y el web player no los ofrece porque
   un navegador no puede tomarlos.
2. **Qobuz no tiene aplicación de escritorio para Linux.** Su página de ecosistema solo ofrece
   descargas para **Windows y macOS** («Requires Windows 10 or later, or macOS 11 or later»).
   En Linux las opciones oficiales son **el web player** o **Qobuz Connect**.

---

## 2. ¿Es bit-perfect en tu equipo? No

Aquí no hay que especular: **ya lo medimos en esta máquina** en la sesión del 20-sep.

| Hecho medido en tu PC | Consecuencia para `play.qobuz.com` |
|---|---|
| El grafo de PipeWire **no sigue la fuente**: el RME queda **fijo a 48 kHz** | Un FLAC 16/44,1 o un 24/96 **se remuestrean a 48 kHz** en algún punto |
| Chromium **remuestrea dentro de la app** (medido con Cider: AAC 44,1 kHz entra, **48 000 Hz sale a PipeWire**) | El web player corre sobre el mismo motor (Chromium/Brave/Firefox), así que se comporta igual |
| «Las dos rutas de remuestreo están en calidad 10» | El error de remuestreo queda **bajo el piso de ruido del RME** → **no audible** |

Y por el lado del estándar web, la limitación es estructural, no un defecto de Qobuz. MDN documenta
el parámetro central de Web Audio:

> «The `sampleRate` property ... returns a floating point number representing the sample rate ...
> **used by all nodes in this audio context**. **This limitation means that sample-rate converters
> are not supported.**»

Traducido: **un `AudioContext` de un navegador tiene UNA sola frecuencia de reloj para todo el grafo.**
Si un álbum es 44,1 kHz y el siguiente es 96 kHz, el navegador no puede conmutar el reloj del
dispositivo de salida como sí hace un reproductor con salida exclusiva — **remuestrea**. Es
exactamente el mismo mecanismo que medimos en Cider.

**Cómo verificarlo tú mismo en 30 segundos** (sin creerme a mí): abre el web player en Chromium y
pega esto en la consola de DevTools:

```js
new AudioContext().sampleRate
```

Si devuelve **48000** estando tu tarjeta en 44,1 kHz, tienes la confirmación empírica: el navegador
eligió una única frecuencia interna, no la del archivo.

**Matiz honesto:** cuál es esa frecuencia no es aleatorio. Depende **de tu hardware, tu sistema y tu
navegador**, y el navegador la negocia con el dispositivo al crear el contexto (en Android/Chromium
se ha documentado que se queda en la frecuencia nativa del hardware «incluso si pides otra»). En tu
caso el resultado práctico ya está medido: **48 kHz**.

---

## 3. La alternativa oficial que sí evita el navegador: Qobuz Connect

Qobuz lo presenta como la vía buena, con nombre propio:

> «**Qobuz Connect** — **the recommended solution for optimal quality**. Qobuz Connect allows you to
> control your compatible audio device directly from the Qobuz app, without going through another
> app. **Music is sent directly from Qobuz servers to your device, in Hi-Res up to 24-bit / 192 kHz.**»

Es decir: la nube manda el audio **directamente al aparato**, no pasa por el navegador ni por el
motor de audio del PC → **esquiva el cuello de botella del `AudioContext`**. Es el mismo principio
que ya usas con el Eversolo: el transporte se salta al ordenador.

**Y aquí está la parte interesante para tu casa:** en la lista oficial de marcas integradas
(actualizada el 3-abr-2026) **aparece `Eversolo`**, y en la categoría «Software» aparecen
`Audirvana`, `Volumio` y `BubbleUPnP`.

**Titular:** probablemente ya tienes el mejor camino de Qobuz en casa sin saberlo —
**app de Qobuz (móvil/web) → Qobuz Connect → DMP-A6 → óptico → RME.** Eso da Hi-Res real **y**
bit-perfect, porque lo que sale del Eversolo hacia el RME es la señal tal cual, sin navegador ni
PipeWire en medio. Lo que aporta `play.qobuz.com` es solo el **mando a distancia**.

*(Nota de higiene: que la marca esté en la lista no garantiza que tu unidad concreta lo tenga —
Qobuz avisa de que «compatibility may also vary at the product level». Hay que comprobarlo en los
ajustes del DMP-A6.)*

**Sobre `qbzd`** (el fork «receptor» de QBZ, que convierte cualquier Linux en un aparato Qobuz
Connect): el proyecto existe y usa PipeWire/ALSA/PulseAudio, pero **no publica ninguna afirmación de
bit-perfect** — solo un arreglo de changelog para que la app muestre «192 kHz» en vez de «44,1 kHz»
por defecto. No lo tomo como solución fiable.

---

## 4. Lo que NO pude verificar

- **La cifra exacta de calidad máxima del web player.** Qobuz no la publica en ninguna página de su
  centro de ayuda. La única cifra que aparece en los resultados (24/192) proviene de blogs sobre
  **Qobuz Connect**, no del web player, y no la uso. **No la invento.**
- **Si el web player recorta Hi-Res en la práctica.** Hay dos blogs que dicen cosas opuestas: uno
  afirma «up to 24-bit/192 kHz quality (based on your subscription)» y otro que «you might not always
  hit the absolute ceiling of 24-bit/192 kHz **due to how browsers handle audio**». El segundo es
  coherente con lo que medimos, pero **es un blog, no Qobuz**: es indicio, no prueba.
- **Si algún día Qobuz saca cliente Linux.** Su lista de aplicaciones no lo menciona y la única vía
  nativa histórica (QBZ) fue retirada el mismo 20-sep-2026.
- **El array de dispositivos de tu Chromecast.** Si tuvieras un Chromecast Audio, Google documenta
  que soporta «**FLAC (up to 96kHz/24-bit)**» — o sea que por ahí también se recorta el Hi-Res a 96
  kHz. No sé si tienes alguno.

---

## 5. Conclusión práctica

| Pregunta | Respuesta |
|---|---|
| ¿`play.qobuz.com` hace streaming lossless? | **Sí.** Entrega FLAC (16/44,1 y, según catálogo/plan, Hi-Res 24-bit) — no es un reproductor con pérdida |
| ¿Hasta dónde? | **No documentado por Qobuz para el web player.** El techo del servicio es 24-bit/192 kHz |
| ¿Es bit-perfect en tu equipo? | **No.** El navegador usa una única frecuencia interna (`AudioContext`) y tu grafo ya está fijo a 48 kHz |
| ¿Se oye la diferencia? | **Muy improbable.** El remuestreo está a calidad 10, por debajo del piso de ruido del RME |
| ¿Sirve para la biblioteca offline? | **No.** Qobuz: las descargas van «in the app», y el web player no las soporta |
| ¿Cuál es la vía buena entonces? | **Qobuz Connect → DMP-A6 → RME**, o el web player como simple mando/fallback |

**En una frase:** el web player de Qobuz **sí es lossless**, pero es la vía *conveniente*, no la
*buena*. Para tu equipo, el mando está en `play.qobuz.com` y el audio debería salir por donde ya
sabes — el Eversolo.

---

## Fuentes

- Qobuz Help Center §10153 «Qobuz apps» — https://help.qobuz.com/en/articles/10153-qobuz-apps
- Qobuz Help Center §602448 «How to listen to Qobuz?» — https://help.qobuz.com/en/articles/602448-how-to-listen-to-qobuz
- Qobuz Help Center §10167 «What are the different audio formats available for download?»
- Qobuz Help Center §10202 «How do I experience Hi-Res on PC?» — https://help.qobuz.com/en/articles/10202-how-do-i-experience-hi-res-on-pc
- Qobuz Help Center §314578 «List of brands integrated into Qobuz Connect» (3-abr-2026)
- Qobuz — «Nuestro ecosistema» / «Our ecosystem» — https://www.qobuz.com/mx-es/discover/apps-partners
- Qobuz — página de calidad de audio — https://www.qobuz.com/store-router/audio-quality
- MDN — `BaseAudioContext.sampleRate` — https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/sampleRate
- Google Cast — «Supported Media for Google Cast» — https://developers.google.com/cast/docs/media
- README de QBZ — https://github.com/NorinB/qbz-backup
- Foro/fork `qbzd` — https://github.com/yet-another-quentin/qbzd
