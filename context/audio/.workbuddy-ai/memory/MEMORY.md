# MEMORY.md — Notas duraderas del proyecto de audio

## Convención de trabajo de este proyecto

El informe principal `audio_context.md` sigue un estilo estricto y el propietario lo
espera también en las respuestas:

- Cada dato lleva su fuente y su **nivel de confianza**. Lo medido, lo publicado por el
  fabricante y lo declarado por el propietario se distinguen explícitamente.
- **No se rellena un hueco con una suposición.** Si un dato no aparece, se dice.
- Cuando dos fuentes discrepan, se dan ambas cifras y se señala la discrepancia.
- Se evita atribuir firmas sonoras («cálido», «brillante») a marcas o chips.
- Importes en pesos mexicanos (MXN).

## Hechos de hardware verificados

### PC de casa: sin adaptador Bluetooth (verificado 2026-09-19)

- `/sys/class/bluetooth` no existe; nada relevante en `lsusb` ni `lspci`;
  módulo `btusb` no cargado. **No hay adaptador Bluetooth.**
- Sí está instalada la pila completa: `bluez` 5.87, `bluez-utils`, y **todos** los
  plugins de códec de PipeWire en `/usr/lib/spa-0.2/bluez5/` (aac, ldac, aptx,
  faststream, opus, sbc) más `libfdk-aac` 2.0.3.
- Consecuencia: **bastaría un dongle USB Bluetooth** para tener AAC y LDAC en la PC.
  No hace falta instalar nada más de software.

## Límites de los audífonos Bluetooth de Apple

- **AirPods Max (cualquier generación, incluidos los AirPods Max 2 de 2026):**
  por Bluetooth sólo aceptan **AAC y SBC**. No hay LDAC ni aptX.
- **No tienen entrada analógica.** Su DAC y amplificador son internos, así que un DAC
  externo (RME, Eversolo, K7BT) no puede insertarse en la cadena.
- **Sin pérdida sólo por cable USB-C** (24 bits / 48 kHz). AirPods Max 2: chip H2,
  Bluetooth 5.3, anunciados el 16-mar-2026.

## Códecs Bluetooth en Linux (PC de casa)

- PipeWire soporta de fábrica: **SBC, SBC-XQ, aptX, LDAC y AAC**. Plugins presentes en
  `/usr/lib/spa-0.2/bluez5/`.
- **aptX Adaptive NO está soportado** en Linux (implementación propietaria de Qualcomm).
  Un dongle Bluetooth normal degrada cualquier auricular aptX Adaptive a aptX HD.
- **Solución:** un **dongle transmisor USB** (Sennheiser BTD 700, Creative BT-W6) que
  codifica en hardware y es USB class-compliant. La PC lo ve como una tarjeta de sonido
  USB y las limitaciones de códecs del sistema dejan de importar.
- Consecuencia práctica: los inalámbricos audiófilos de gama alta usan aptX Adaptive y
  **no LDAC**, así que el dongle transmisor es la ruta inalámbrica correcta, no un
  dongle Bluetooth genérico.

## Auriculares inalámbricos audiófilos: entrada analógica

**Corrección a la nota anterior sobre Apple:** la ausencia de entrada analógica es
específica de los AirPods. Los inalámbricos audiófilos (Focal Bathys MG, DALI IO-12,
Sennheiser HDB 630) **sí tienen entrada de 3.5 mm**, así que el RME ADI-2 DAC FS **sí
puede insertarse en la cadena** por analógico. Tampoco es obligatorio: todos tienen modo
USB-DAC interno.

Códecs verificados en fichas oficiales (sep-2026):

| Modelo | Códecs | ¿LDAC? | Cable |
|---|---|---|---|
| Focal Bathys MG | SBC, AAC, aptX, aptX Adaptive | **No** | USB-DAC 24/192, jack |
| DALI IO-12 | SBC, AAC, aptX, aptX HD, aptX Adaptive | **No** | USB 24/96, jack |
| Sennheiser HDB 630 | aptX Adaptive, aptX HD, AAC, SBC | **No** | USB-C o jack, 24/96 |
| Mark Levinson No. 5909 | **LDAC**, aptX Adaptive, AAC | **Sí** | USB-C, jack |

Precios verificados en México (JMI Audio, 19-sep-2026): DALI IO-12 $35,802 MXN;
Sennheiser HDB 630 $10,999 MXN **con dongle BTD 700 incluido**.
Referencia USD: No. 5909 $999 · IO-12 $1,750 · HDB 630 $499.95 · BTD 700 $59.95.

## Equipos Topping y bocinas Sony pasivas (no documentados en audio_context.md)

El propietario tiene tres equipos Topping arrumbados y unas bocinas Sony pasivas
antiguas. Verificado en manuales y fichas oficiales (19-sep-2026):

| Equipo | Qué es | ¿Mueve bocinas pasivas? |
|---|---|---|
| **Topping TP30** | Amplificador clase T Tripath TA2024 + DAC USB + amp de audífonos. **Bornes de bocina de 5 vías.** Fuente 12 V / 5 A | **Sí, es el único** |
| Topping D30 | Sólo DAC: USB (32–192 kHz, DSD64/128), coaxial, óptica → salida RCA | No |
| Topping A30 | Sólo amplificador de audífonos: RCA in, **salida de línea RCA**, 6.35/3.5 mm. 1551 mW a 32 Ω | No (sin bornes) |

Cadena correcta para las Sony: fuente → TP30 → bocinas. Advertencias: el TP30 necesita su
fuente original de 12 V / 5 A; bocinas de 4 a 8 Ω; nunca conectar las salidas de bocina a
una entrada de línea.

## Topping DX9 frente al RME ADI-2 DAC FS (evaluado 19-sep-2026)

**Ojo: hay dos DX9 distintos.** El **DX9 original** (2024, AK4499EQ, $1,299) **no tiene
PEQ**. Sólo el **DX9 Discrete / DX9D** ($1,299) trae PEQ de 10 bandas y crossfeed por
convolución. Confundirlos invalida cualquier comparación.

Datos del DX9 Discrete (manual oficial `dl.topping.audio/um/DX9_Discrete.pdf`):

- Línea: XLR 5.2 Vrms / RCA 2.5 Vrms. SNR 131 dB (XLR). Modo PRE (con volumen) o DAC.
- Auriculares: 4-pin XLR + 4.4 mm + 6.35 mm, 7080 mW ×2 @32 Ω, salida <0.1 Ω.
- Entradas: USB, 2× óptica, 2× coaxial, AES, IIS, Bluetooth (LDAC, aptX Adaptive).
- USB 768/32 y DSD512 nativo. PSU interna. Trigger 12 V. 2750 g.
- **PEQ: se edita sólo con Topping Tune en PC**; el equipo guarda 5 perfiles y los usa
  sin conexión. **No tiene loudness** (verificado: no aparece en el manual).

Datos del RME (manual local `MANUAL-RMEadi2dac_e.pdf`): Extreme Power **1.5 W @ 32 Ω**;
niveles conmutables **-5/+1/+7/+13 dBu**; **PEQ de 5 bandas editable en el equipo**;
**loudness dinámico**; crossfeed; salida IEM a -3 dBu; **interfaz USB full-duplex** que
graba el SPDIF.

**Conclusión registrada:** el DX9 Discrete es un cambio lateral, no una mejora. Gana en
PEQ de 10 bandas, potencia, Bluetooth y entradas; pierde loudness, edición del PEQ sin PC
y la función de interfaz USB. Los presets `.adieqpr` del propietario no se transfieren.

## Eversolo DMP-A8 Gen 2 frente al RME (evaluado 19-sep-2026)

**Es un error de categoría plantearlo como sustituto del RME.** El A8 Gen 2 es
streamer + DAC + preamplificador; el RME es DAC + amplificador de audífonos. El
solapamiento real del A8 Gen 2 es con el **DMP-A6**, no con el RME.

Dos datos duros, verificados en el manual oficial:

- **No tiene salida de audífonos.** La lista completa de E/S no incluye 6.35, 4.4
  ni 3.5 mm. Sí tiene salida de subwoofer con crossover 40–500 Hz.
- **El Bluetooth es sólo de entrada.** El manual lo etiqueta «Bluetooth Audio
  Input» (BT 5.4, SBC/AAC/aptX/aptX LL/aptX HD/LDAC). **No puede enviar audio a
  audífonos Bluetooth.**

Arquitectura: AK4191EQ + AK4499EXEQ, DSD512 y PCM 768/32, pantalla de 8.6",
8 GB DDR5 + 64 GB eMMC, volumen analógico por **red R-2R**, preamp balanceado con
+10 dB, entradas analógicas XLR/RCA, salidas XLR 4.2 V / RCA 2.1 V, THD+N
−121 dB, rango dinámico >132 dB (XLR), HDMI ARC/eARC, Wi-Fi 6, SFP, M.2 NVMe.

Precio: **$1,980 USD** (Audio Solutions) · **€1,980** (deCineOn, «Disponible»).
**No se encontró precio en México del Gen 2.** JMI Audio lista el A8 de **primera
generación** a **$49,500 MXN** (se distingue por la pantalla de 6.0", 4 GB DDR4 y
XMOS XU316). El A8 de primera generación está descontinuado.

**Veredicto:** no vale la pena como sustituto del RME (cambio lateral de ~$34,000
MXN que quita el PEQ en el equipo y la salida de audífonos). Como sustituto del
DMP-A6 tiene sentido sólo si se arma un sistema de bocinas. Entregable:
`analisis_rme_vs_eversolo_a8_gen2.md`.

## Equipos del inventario que NO transmiten Bluetooth

Verificado en manuales locales o fichas oficiales:

| Equipo | Bluetooth | Evidencia |
|---|---|---|
| Eversolo DMP-A6 | **Sólo receptor** (QCC5125) | Manual local, líneas 116 y 889–894 |
| FiiO K7BT | **Sólo receptor** (QCC5124) | Ficha FiiO |
| RME ADI-2 DAC FS | No tiene Bluetooth | Manual local |
| Aune S17 Pro EVO | No tiene Bluetooth | Manual local |
| AirPort Express 2.ª gen | No; es receptor AirPlay | Apple |

Ninguno sirve para enviar audio a unos auriculares Bluetooth.
