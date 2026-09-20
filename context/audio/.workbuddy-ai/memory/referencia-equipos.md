# Referencia de equipos — proyecto de audio

Fichas estáticas de equipos, movidas aquí para que `MEMORY.md` quepa en el límite de
inyección. No duplicar aquí lo que ya está en `MEMORY.md`.

## HE1000se
35 Ω, 96 dB, 440 g. Caja: 1,5 m (3,5 mm), **3 m XLR 4 pines balanceado**, 3 m (6,35 mm).
Conector por copa **3,5 mm**; 3 m es el techo del catálogo. El cable «Crystalline Copper
Silver» ($249) no es mejora. **No hay adaptador magnético de desconexión rápida para XLR.**
Almohadillas con clips que se doblan hacia dentro, asimétricas; Dekoni dice 9 y que los de 12
no sirven → **contarlas antes de comprar**.

## Aune S17 Pro EVO
Balanceada G-H: 7500 mW @32 Ω · 4654 @55 · 2673 @100 · 918 @300. No balanceada G-H:
2050 mW @32 Ω. Impedancia de salida **1 Ω** (XLR/6,35/4.4, las tres en el panel frontal).
Ganancia G-L / G-H, dos modos de corriente. **No tiene Bluetooth.**

## RME ADI-2 DAC FS (manual local)
1,5 W @32 Ω; +7 dBu Low / +22 dBu Hi Power; 0,1 Ω; THD <−110 dB @32 Ω; SNR 120 dBA;
0 Hz–80 kHz. Salida IEM fija **−3 dBu** (0,55 Vrms), piso **−121 dBu(A)**. Línea RCA hasta
+13 dBu (−5/+1/+7/+13), XLR hasta +19 dBu (+1/+7/+13/+19). Web oficial: **123 dBA**,
distorsión <−120 dB, **THD+N −116 dB**; el manual dice 120 dBA (**discrepancia**, lo repite
dos veces). **Todas las salidas (XLR, RCA, Phones, IEM) salen del mismo DAC: misma señal.**
**Sí tiene** M/S Processing, Phase, Mono y Width (manual §8.7): no es exclusivo del Pro.
PEQ 5 bandas editable en el equipo, loudness dinámico, crossfeed, USB full-duplex que graba
el SPDIF, AutoDark, analizador de 30 bandas. **No tiene Bluetooth.**

## RME ADI-2/4 Pro EX vs DAC FS
**Otra categoría:** 2 canales A/D + 4 canales D/A = interfaz de masterización; el DAC FS es
sólo D/A de escucha.
**Gana:** 2 entradas XLR/TRS (+24 dBu), ADC, **RIAA/MM y MC**, tornillo de tierra, hasta
**−35 dBu**, **4 salidas de línea**, audífonos **balanceados 4.4 mm Pentaconn**, 2,1 W no
bal. / 3,4 W bal. @32 Ω, True Balanced **+25 dBu**, AES+SPDIF+ADAT in/out, USB **6 in/8 out**,
trigger 12 V, DC universal 9,5–15 V.
**Del EX sobre el SE** (comunicado oficial 3-jun-2026): A/D **ESS9823Pro**, D/A
**ESS9039Q2M**, **RIAA en modo línea (0 dB)** para preamps externos y cápsulas MC, −35 dBu,
canales ADAT 3/4 como fuente de audífonos, **SteadyClock EX** (±1 ppm de fábrica, ±50 ppm
ajustable en pasos de 0,1 ppm), USB-C bloqueable, fuente sin fusible, protección DC por canal.
**Ojo:** la subida de potencia de audífonos del comunicado es del **ADI-2 Pro EX**, no del 2/4.
**Contradicción de fuentes:** el comunicado dice ESS9039Q2M para D/A, pero la página oficial
del ADI-2 Pro EX dice **AK5574 (ADC) + AK4493 (DAC)**.
**La conversión D/A no cambia de clase** (120–123 dBA ambos) → diferencia audible marginal.
**Veredicto:** no pertinente sin tocadiscos ni grabación; si aplica, **el SE ya lo hace**.
→ `analisis_rme_dac_fs_vs_adi-2-4_pro_ex.md`.

## Topping
**TP30** = Clase T Tripath TA2024 + DAC USB + amp de audífonos, bornes de 5 vías, 12 V/5 A →
**el único que mueve bocinas pasivas** (bocinas 4–8 Ω; nunca salida de bocina a entrada de
línea). **D30** = sólo DAC (USB 32–192, DSD64/128, coaxial, óptica → RCA). **A30** = sólo amp
de audífonos (RCA in, salida de línea RCA, 1551 mW @32 Ω).
**DX9: hay dos.** El **original** (2024, AK4499EQ, $1,299) **no tiene PEQ**; el **DX9
Discrete / DX9D** sí (10 bandas, editable **sólo con Topping Tune en PC**, **sin loudness**;
XLR 5.2 Vrms / RCA 2.5 Vrms, SNR 131 dB, 7080 mW×2 @32 Ω, <0,1 Ω, USB 768/32 y DSD512, BT
LDAC/aptX Adaptive). Confundirlos invalida la comparación. **Cambio lateral, no mejora**;
los `.adieqpr` no se transfieren.

## Eversolo DMP-A8 Gen 2
**Error de categoría como sustituto del RME:** es streamer + DAC + preamplificador y su par
real es el **DMP-A6**. Dos datos duros del manual: **sin salida de audífonos** (sí salida de
subwoofer con crossover 40–500 Hz) y **Bluetooth sólo de entrada** (BT 5.4,
SBC/AAC/aptX/aptX LL/aptX HD/LDAC).
AK4191EQ + AK4499EXEQ, DSD512, PCM 768/32, pantalla 8.6", 8 GB DDR5 + 64 GB eMMC, volumen
analógico por **red R-2R**, preamp balanceado +10 dB, XLR 4.2 V / RCA 2.1 V, THD+N −121 dB,
rango dinámico >132 dB (XLR), HDMI ARC/eARC, Wi-Fi 6, SFP, M.2 NVMe.
Precio **$1,980 USD / €1,980**; **sin precio en México del Gen 2** (JMI lista el Gen 1
descontinuado a $49,500 MXN). No sustituye al RME. → `analisis_rme_vs_eversolo_a8_gen2.md`.

## Auriculares inalámbricos audiófilos

| Modelo | Códecs | ¿LDAC? | Cable |
|---|---|---|---|
| Focal Bathys MG | SBC/AAC/aptX/aptX Adaptive | No | USB-DAC 24/192, jack |
| DALI IO-12 | + aptX HD | No | USB 24/96, jack |
| Sennheiser HDB 630 | aptX Adaptive/HD, AAC, SBC | No | USB-C o jack, 24/96 |
| Mark Levinson No. 5909 | **LDAC**, aptX Adaptive, AAC | **Sí** | USB-C, jack |

La falta de entrada analógica es **sólo** de los AirPods (Max 2 incluidos: AAC/SBC por BT,
sin pérdida salvo USB-C 24/48). México (JMI Audio, 19-sep-2026): DALI IO-12 $35,802 ·
HDB 630 $10,999 **con BTD 700 incluido**. USD: No. 5909 $999 · IO-12 $1,750 ·
HDB 630 $499.95 · BTD 700 $59.95.

## Equipos que NO transmiten Bluetooth (sólo reciben o nada)

| Equipo | Bluetooth | Evidencia |
|---|---|---|
| Eversolo DMP-A6 | Sólo receptor (QCC5125) | Manual local, líneas 116 y 889–894 |
| FiiO K7BT | Sólo receptor (QCC5124) | Ficha FiiO |
| RME ADI-2 DAC FS | No tiene | Manual local |
| Aune S17 Pro EVO | No tiene | Manual local |
| AirPort Express 2.ª gen | No; es receptor AirPlay | Apple |

**El DMP-A6 es la vía más limpia para streaming:** Tidal, Qobuz, Highresaudio, Amazon Music,
Roon Ready, Tidal Connect, DLNA, con **salidas digitales** hacia el RME. Saca al PC y a
PipeWire de la cadena. **No tiene Spotify Connect.**
