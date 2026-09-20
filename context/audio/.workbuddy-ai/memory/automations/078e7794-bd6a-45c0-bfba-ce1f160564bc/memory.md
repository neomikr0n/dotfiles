# Memoria de automatización — Seguimiento precio RME ADI-2 DAC EX

## Objetivo
Detectar cuándo RME publica precio oficial del ADI-2 DAC EX (sucesor del ADI-2 DAC FS)
y cuándo llega a México. Vigilar también el ADI-2/4 Pro EX.

## Historial de ejecuciones

### 2026-09-19 — Sin precio y sin disponibilidad en México
Comprobado: `adi-2-dac-ex.html` y `adi-2-4-pro-ex.html` → 404. `adi-2-pro-ex.html` ya
existe. Listado oficial y rme-shop sólo con ADI-2 Pro EX. Comunicado 2026-06-03 sigue
siendo la única referencia («late Q3 2026; pricing to be announced»). México: ningún
modelo EX en solidelectronics.mx ni MercadoLibre.
Precios de referencia: Pro EX CHF 1699 / €1.992,87; DAC FS MX $27.600 (sin stock);
/4 Pro SE MX $51.100 (sin stock).

### 2026-09-19 (segunda comprobación, 16:00) — sin novedad
Re-comprobación dentro de otra tarea. Sin cambio alguno.

### 2026-09-20 — sin novedad
Resultado: **sigue sin precio oficial y sin disponibilidad en México.**

- `rme-audio.de/converter/adi-2-dac-ex.html` → **sigue 404**.
- `rme-audio.de/converter/adi-2-4-pro-ex.html` → **sigue 404**.
- `rme-audio.de/products.html` y `rme-audio.de/news.html` → sólo ADI-2 Pro EX.
- `rme-shop.com/acatalog/RME_converters.html` → Pro EX €1.992,87; DAC FS €816,75 agotado;
  /4 Pro SE €2.299 agotado. Ningún modelo EX nuevo en catálogo.
- Comunicado 2026-06-03 (musicnetwork.ch) intacto: DAC EX y /4 Pro EX = «late Q3 2026;
  pricing to be announced».
- México: solidelectronics.mx no lista ningún «EX»; DAC FS $27,600 MXN y /4 Pro SE
  $51,100 MXN, ambos **sin existencias**.
- **Novedad menor:** Thomann ya retiró el ADI-2 DAC FS de su catálogo.
- Único precio existente del /4 Pro EX: preventa de revendedor en Reverb (Tidepool Audio,
  Portland OR), **$2,499 USD**, envío estimado 30-sep-2026. **No es precio oficial.**
- Prensa: phileweb y snrec (09-sep-2026) cubren sólo el ADI-2 Pro EX, lanzamiento en
  Japón 2026-10-02.

## Próxima ejecución — pistas a revisar
- Reintentar `rme-audio.de/converter/adi-2-dac-ex.html` (indicador más limpio) y
  `rme-audio.de/converter/adi-2-4-pro-ex.html`.
- `rme-shop.com/acatalog/RME_converters.html` (aparición en «New Products»).
- Comprobar si Thomann reincorpora el DAC FS ya como «EX».
- México: `solidelectronics.mx/catalogsearch/result/?q=ADI-2`; MercadoLibre México
  (bloquea WebFetch, usar búsqueda web).

## Heurística de precio (para cuando aparezcan)
El ADI-2 Pro EX subió de €1.808,95 (Pro FS R BE) a €1.992,87: **+10 %**. Si el DAC EX y el
/4 Pro EX repiten ese salto, quedarían alrededor de **€900** y **€2.530** respectivamente.
Es una extrapolación, no un dato: usarla sólo como expectativa, nunca como precio.

## Nota fuera de alcance (20-sep-2026)
Ese día, dentro de la misma sesión, se hizo trabajo **ajeno a esta automatización**
(remuestreo de PipeWire a calidad 10, verificación del grafo y calidad real de Spotify).
Está registrado en `../2026-09-20.md`, no aquí. **No afecta al seguimiento de precios.**
Aviso para la próxima ejecución: si el usuario ya cambió de opinión sobre el DAC EX, conviene
confirmarlo antes de seguir dando por supuesto que quiere el sucesor.
