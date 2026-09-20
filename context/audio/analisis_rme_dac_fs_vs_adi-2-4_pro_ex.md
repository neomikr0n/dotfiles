# RME ADI-2 DAC FS frente al ADI-2/4 Pro EX

Análisis profundo, clasificación de las mejoras (marginales o significativas) y
recomendación sobre si tiene sentido considerarlo.

Fecha de comprobación: **20 de septiembre de 2026**.

Convención: cada dato lleva fuente y nivel de confianza. **[verificado]** = página
oficial o manual; **[referencia]** = distribuidor o medio; **[no confirmado]** = no se
pudo comprobar. Cuando dos fuentes discrepan, se dan ambas.

---

## 0. Veredicto corto

**No es pertinente como sustituto directo de tu ADI-2 DAC FS.**

El ADI-2/4 Pro EX no es una versión mejor de tu DAC: es **otro equipo**. Tu DAC es un
convertidor D/A de escucha con dos salidas de audífonos. El 2/4 Pro EX es una
**interfaz de masterización** de 2 canales A/D y 4 canales D/A con entrada de fono,
AES, ADAT y USB multicanal.

La conversión D/A —que es lo que tú escuchas— está **en la misma clase** en ambos
(120–123 dBA). Lo que cambia no es el sonido: es el **bloque de entradas y salidas**.

**La pregunta que decide todo:** ¿tienes un tocadiscos, o quieres grabar o digitalizar
audio analógico?

- **Sí** → el 2/4 Pro es una mejora real y significativa, y además **ya existe** la
  versión SE que hace exactamente eso. No hace falta esperar al EX.
- **No** → quédate con el DAC FS. El cambio sería funcional, no sonoro, por ~4 veces
  el precio.

---

## 1. Qué es cada equipo

| | ADI-2 DAC FS | ADI-2/4 Pro EX |
|---|---|---|
| Conversión | Sólo D/A | **2 canales A/D + 4 canales D/A** |
| Enfoque | Escucha doméstica y HiFi | Masterización y estudio |
| Salidas de línea | 1 estéreo (XLR + RCA) | **4** (2 XLR + 2 TRS) |
| Salidas de audífonos | 2 (Extreme Power 6.35 mm + IEM 3.5 mm) | 2 (Extreme Power 6.35 mm + Pentaconn 4.4 mm **balanceada**) |
| Entradas analógicas | **Ninguna** | 2, combo XLR/TRS servo-balanceadas |
| Entrada de fono | **Ninguna** | **Sí, RIAA** |
| Salidas digitales | **Ninguna** | AES, SPDIF coaxial, SPDIF óptico, ADAT |
| USB | 2 canales (2 in / 2 out) | Estéreo **y multicanal (6 in / 8 out)** |
| DSP | 5 bandas PEQ, bass/treble, loudness, crossfeed, M/S, ancho, fase, mono | Idéntico, más EQ dual L/R |
| Chasis | Medio rack 9.5" | Medio rack 9.5", 1 U, **ventilado** |
| Precio | $27,600 MXN / €816.75 | **Sin precio oficial** |

**[verificado]** La lista de conectividad de la página oficial del ADI-2/4 Pro SE es:
«2 x Phono/Line input · 1 x ADAT I/O · 1 x SPDIF I/O · 1 x AES I/O · RME USB 2.0 ·
1 x Phones or Balanced Pentaconn · 4 x Line Output».

**[verificado]** El manual de tu DAC dice literalmente: «The rear RCA and XLR outputs
and the front outputs Phones and IEM are fed from the same DAC, hence carry the same
signal.» Es decir, **todas las salidas de tu DAC llevan la misma señal**. El 2/4 Pro,
en cambio, tiene caminos independientes: los audífonos balanceados usan los canales
DAC 3/4 y la salida trasera puede emitir otra señal distinta por los canales 1/2.

---

## 2. La conversión D/A: prácticamente la misma

| | Tu ADI-2 DAC FS | ADI-2/4 Pro SE | ADI-2/4 Pro EX |
|---|---|---|---|
| Chip D/A | ESS ES9028Q2M | AKM (no confirmado en la web oficial) | **ESS9039Q2M** |
| SNR | **123 dBA** (web) / **120 dBA** (manual) | «hasta 123 dBA» | «notablemente mejorado», **sin cifras** |
| THD+N | **−116 dB** | no publicado | «notablemente mejorado» |
| Distorsión | **< −120 dB** | no publicado | «notablemente mejorado» |

**[verificado]** Las cifras de tu DAC salen de la página oficial de RME («noise levels
of 123 dBA, distortion less than −120 dB, or THD+N of −116 dB»). **Discrepancia:** el
manual local de tu equipo dice 120 dBA en dos lugares distintos. Doy ambas.

**Clasificación: marginal.** La serie EX promete mejores cifras con el ESS9039Q2M, pero
**RME no ha publicado ni un solo número** del 2/4 Pro EX. Y aunque los publique, la
única prueba relevante que existe sigue siendo el A/B ciego de KaiS en el foro oficial
de RME, con nivel igualado, entre las versiones AKM y ESS del propio ADI-2: **49:51**.
No hay base para afirmar que un cambio de chip de DAC sea audible aquí.

---

## 3. Amplificación de audífonos: más potencia que no necesitas

| | Tu ADI-2 DAC FS **[verificado, manual]** | ADI-2/4 Pro SE **[verificado, web oficial]** |
|---|---|---|
| Potencia | **1.5 W @ 32 Ω** | **2.1 W** no balanceada · **3.4 W** balanceada @ 32 Ω |
| Niveles | Low Power **+7 dBu** (1.73 V) · Hi Power **+22 dBu** (10 V) | True Balanced: **+7 dBu** IEM · **+13 dBu** Low Power · **+25 dBu** High Power |
| Impedancia de salida | 0.1 Ω | no publicada |
| THD | < −110 dB a 32 Ω cerca de plena salida | no publicada |
| SNR | 120 dBA | no publicada |
| Respuesta | 0 Hz a 80 kHz (−0.5 dB a 80 kHz) | no publicada |
| Salida IEM | −3 dBu (0.55 Vrms), piso de ruido **−121 dBu(A)** | modo IEM dedicado |
| Balanceada | **No** | **Sí** (Pentaconn 4.4 mm) |

**Diferencia real: +1.5 dB sin balancear, +3.6 dB balanceada.** Sobre el papel.

**Por qué es irrelevante en tu caso.** Tus HE1000se son de 35 Ω y 96 dB de sensibilidad.
Para alcanzar 120 dB de SPL necesitan unos **250 mW**. Tu DAC entrega **1,500 mW**: seis
veces más, unos 7.8 dB de margen por encima de un nivel que ya es doloroso. Los 3.4 W
del Pro añaden 3.6 dB a un margen que ya no se usa.

Y hay algo más determinante: **tú no escuchas los HE1000se por el RME**, sino por el
Aune S17 Pro EVO. El amplificador de audífonos del RME no es tu camino principal.

**Clasificación: marginal, y además irrelevante para tu cadena.** Lo único que sí
aportaría algo real es la **salida balanceada** — pero el Aune ya te la da.

---

## 4. Lo que sí cambia de verdad: el bloque de E/S

Aquí está toda la diferencia. Y es grande, pero es una diferencia **de estudio**.

| Función | Tu DAC FS | 2/4 Pro EX | ¿Te afecta? |
|---|---|---|---|
| Entradas analógicas | No tiene | 2 ch XLR/TRS, servo-balanceadas, hasta **+24 dBu** | Sólo si grabas |
| ADC | No tiene | Sí, **ESS9823Pro** (según el comunicado) | Sólo si grabas |
| RIAA / fono | No tiene | **Sí**, MM directo; MC con preamp externo | **Sólo si tienes tocadiscos** |
| Tornillo de tierra | No tiene | Sí, para tocadiscos | Sólo con tocadiscos |
| Niveles de entrada | No aplica | Hasta **−35 dBu** → micrófonos dinámicos directos | Sólo si grabas |
| Salidas de línea | 1 estéreo | **4** (2 XLR + 2 TRS), con caminos independientes | Sólo con biamplificación o subwoofer |
| Salida de audífonos balanceada | No | **Sí** (Pentaconn 4.4 mm, True Balanced) | Ya lo cubre el Aune |
| AES/EBU | No | **Entrada y salida** | No |
| ADAT | Sólo entrada óptica, canales 1/2 | Entrada y salida; canales 3/4 como fuente de audífonos | No |
| Salidas digitales | **Ninguna** | AES, SPDIF coax, SPDIF óptico, ADAT | No |
| USB multicanal | No (2 in / 2 out) | **6 in / 8 out** hasta 192 kHz | No |
| Trigger 12 V | No | Sí, para encender etapas de potencia | Marginal |
| Alimentación | Fuente fija 12 V / 2 A | **DC universal 9.5–15 V**, funciona con batería | Marginal |
| Mando | MRC, 32 funciones | MRC, **52 funciones** | Marginal |

**[verificado]** Todo lo de la columna del 2/4 Pro EX sale del comunicado oficial de RME
del 3 de junio de 2026 y de la página oficial del SE.

---

## 5. Las mejoras del EX sobre el SE, una por una

El comunicado oficial lista esto como «What's New» del ADI-2/4 Pro EX:

1. **Convertidor A/D ESS9823Pro** — «conversión analógico-digital completamente
   transparente con niveles optimizados de ruido y distorsión». **[verificado]**
2. **Convertidor D/A ESS9039Q2M** — «mejora notable de SNR, THD y THD+N». **[verificado]**
   Sin cifras publicadas.
3. **RIAA en modo línea (0 dB de ganancia)** — permite usar preamplificadores externos y
   simplifica el uso de cápsulas **MC**. Antes el RIAA sólo existía con la ganancia fija.
4. **Tornillo de tierra separado** para la conexión del tocadiscos.
5. **Niveles de referencia extendidos hasta −35 dBu** — permite conectar **micrófonos
   dinámicos directamente**, sin previo.
6. **Canales ADAT 3/4 seleccionables como fuente de la salida de audífonos.**
7. **SteadyClock EX** — calibración de fábrica a **±1 ppm** de exactitud, ajustable en el
   menú **±50 ppm en pasos de 0.1 ppm**. Permite igualar la frecuencia de muestreo con
   otros equipos sin sincronización externa («Sync without Sync»).
8. **USB-C bloqueable** con cable de 1.8 m.
9. **Protección de fuente activa sin fusible** contra sobretensión e inversión de polaridad.
10. **Protección DC por canal** en las salidas de audífonos.

Además, el comunicado menciona para toda la serie EX una mejora en los conectores y en
los circuitos de protección.

**Nota importante:** el comunicado atribuye al **ADI-2 Pro EX** (el hermano pequeño) un
aumento de la potencia de audífonos en modo balanceado y no balanceado. **Eso no aparece
en la ficha del ADI-2/4 Pro EX.** No des por hecho que el 2/4 Pro EX también la tenga.

**Discrepancia de fuentes, ya conocida:** el comunicado dice ESS9039Q2M para la conversión
D/A, pero la página oficial del ADI-2 Pro EX dice **AK5574 (ADC) + AK4493 (DAC)**. Para el
2/4 Pro EX no hay página oficial, así que **sus chips no están confirmados por una segunda
fuente**. El «ESS9823Pro» del comunicado es además un número de parte que no puedo
verificar en el catálogo de ESS.

---

## 6. Clasificación: marginal o significativo

**Significativo — pero sólo para un uso que no has declarado:**

- Entradas analógicas con ADC.
- Modo RIAA para vinilo, con RIAA en línea para cápsulas MC.
- Salidas digitales (AES, SPDIF, ADAT).
- USB multicanal 6 in / 8 out.
- Cuatro salidas de línea con caminos independientes.
- Niveles profesionales (−35 dBu a +24 dBu).
- SteadyClock EX con calibración de ±1 ppm.

**Marginal:**

- Conversión D/A (misma clase, 120–123 dBA; sin cifras del EX).
- Amplificación de audífonos (+1.5 dB, y ya usas el Aune).
- Chasis ventilado, USB-C bloqueable, protecciones, trigger, alimentación universal,
  mando con más funciones. Todo esto es comodidad o fiabilidad, no sonido.

**Nulo para ti:**

- Todo el bloque de estudio, mientras no grabes ni tengas tocadiscos.

---

## 7. Precio y disponibilidad (20-sep-2026)

| Modelo | Precio | Disponibilidad |
|---|---|---|
| **ADI-2/4 Pro EX** | **Sin precio oficial.** | Página oficial **404**. No aparece en `rme-shop.com` ni en `rme-audio.de/products.html`. |
| ADI-2/4 Pro EX (preventa de revendedor) | **$2,499 USD** | Tidepool Audio (Portland, OR) en Reverb. Envío estimado **30-sep-2026**. No es precio de RME. |
| ADI-2/4 Pro SE | **$51,100 MXN** · **€2,299** | **Sin existencias** en ambas tiendas. |
| ADI-2 DAC FS | **$27,600 MXN** · **€816.75** | **Sin existencias** en ambas tiendas. |
| ADI-2 Pro EX | €1,992.87 | Disponible. Es el único EX con página y precio oficiales. |

**Dato de contexto:** `rme-audio.de/products.html` ya **no lista** ni el ADI-2 DAC FS ni
el ADI-2/4 Pro SE. De la serie EX sólo aparece el ADI-2 Pro EX. Los dos modelos anteriores
están siendo retirados del catálogo.

**Proyección mía, no un dato:** el ADI-2 Pro EX subió de €1,808.95 (FS R BE) a €1,992.87,
un +10 %. Si el 2/4 Pro EX repitiera ese salto sobre los €2,299 del SE, quedaría alrededor
de **€2,530** ≈ $2,970 USD ≈ **$51,000 MXN antes de importación**. Repito: es una
extrapolación, no un precio publicado.

**Nota sobre el precio europeo:** tu DAC cuesta €816.75 en Europa, unos $15,300 MXN al tipo
de cambio actual, frente a los $27,600 MXN de la tienda mexicana. Casi el doble. Es un
dato a tener en cuenta en cualquier compra RME desde México.

---

## 8. Recomendación

**No lo consideres como sustituto de tu DAC.** Sería pagar cuatro veces más por un bloque
de entradas y salidas que no usas, mientras la parte que sí escuchas —la conversión D/A—
se queda en la misma clase. Tu cadena actual (HE1000se + Aune S17 Pro EVO + ADI-2 DAC FS)
ya está en el punto donde el convertidor no es el cuello de botella.

**Considéralo sólo si se cumple alguna de estas tres condiciones:**

1. **Tienes o vas a tener un tocadiscos.** Entonces el RIAA del 2/4 Pro convierte el equipo
   en un digitalizador de vinilo de primer nivel, y ahí sí hay una diferencia real.
2. **Grabas o mides.** El ADC, los niveles profesionales y el USB multicanal son de otra
   categoría.
3. **Necesitas salida de audífonos balanceada** con mucha potencia. Pero tu Aune ya la da,
   así que esta condición no aplica en tu caso.

**Si se cumple la condición 1 o 2, no esperes al EX.** El **ADI-2/4 Pro SE ya hace todo
eso**: tiene RIAA, ADC, AES, ADAT y USB multicanal. Las mejoras del EX (chips ESS, RIAA en
línea para MC, tornillo de tierra, −35 dBu, SteadyClock EX) son **refinamientos**, no
capacidades nuevas. Y el SE tiene precio conocido; el EX no.

**Si no se cumple ninguna, la respuesta es no.** El dinero rinde más en audífonos, en
acústica o en un sistema de bocinas que en cambiar un convertidor por otro de la misma
clase.

---

## Anexo: datos que no se pudieron verificar

- **Precio oficial del ADI-2/4 Pro EX: no existe.** Página oficial 404, sin listar en la
  tienda oficial ni en el catálogo de productos. El único precio es una preventa de
  revendedor.
- **Chips del ADI-2/4 Pro EX: una sola fuente.** El comunicado dice ESS9823Pro (ADC) y
  ESS9039Q2M (DAC). No hay página oficial que lo confirme, y contradice lo que RME publica
  del ADI-2 Pro EX (AK5574 + AK4493).
- **«ESS9823Pro» no lo pude verificar** en el catálogo de ESS. Podría ser un número de
  parte nuevo o un error del comunicado.
- **Cifras del ESS9039Q2M en el 2/4 Pro EX: no publicadas.** «Notablemente mejorado» sin
  números.
- **Impedancia de salida, THD y SNR de audífonos del 2/4 Pro: no publicados** en la página
  oficial del SE.
- **Niveles de referencia analógicos del SE (+4/+13/+19/+24 dBu y +24 dBu de entrada
  máxima):** provienen de una ficha de distribuidor, no de la página oficial. **[referencia]**
- **Fecha de disponibilidad del 2/4 Pro EX en México: desconocida.** Ningún distribuidor
  mexicano lo lista. El comunicado sólo dice «late Q3 2026; pricing to be announced».
