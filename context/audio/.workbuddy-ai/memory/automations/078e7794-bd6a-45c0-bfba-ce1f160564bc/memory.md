# Memoria de automatización — Seguimiento precio RME ADI-2 DAC EX

## Objetivo
Detectar cuándo RME publica precio oficial del ADI-2 DAC EX (sucesor del ADI-2 DAC FS)
y cuándo llega a México. Vigilar también el ADI-2/4 Pro EX.

## Historial de ejecuciones

### 2026-09-19 — Sin precio y sin disponibilidad en México
Resultado: **sin novedad en el ADI-2 DAC EX**.

Comprobado:
- `rme-audio.de/converter/adi-2-dac-ex.html` → sigue 404.
- `rme-audio.de/converter/adi-2-4-pro-ex.html` → sigue 404.
- `rme-audio.de/converter/adi-2-pro-ex.html` → **ya existe** (página oficial publicada).
- Listado oficial `rme-audio.de/products.html` incluye ADI-2 Pro EX, pero no DAC EX ni /4 Pro EX.
- `rme-shop.com/acatalog/RME_converters.html` → sólo ADI-2 Pro EX. Nada de DAC EX.
- Comunicado 2026-06-03 (musicnetwork.ch) sigue siendo la única referencia:
  DAC EX y /4 Pro EX = "late Q3 2026; pricing to be announced". Pro EX = CHF 1699.
- México: solidelectronics.mx y MercadoLibre México no listan ningún modelo EX.

Precios confirmados (no del DAC EX):
- ADI-2 Pro EX: CHF 1699 (comunicado) / €1.992,87 rme-shop / €1.989 Thomann (desde jul-2026)
  / Japón 2026-10-02 precio abierto.
- ADI-2/4 Pro EX: sólo preventa de revendedor Reverb (Tidepool Audio) $2.499 USD, envío est. 29-sep-2026.
- ADI-2 DAC FS en solidelectronics.mx: $27.600 MXN **sin existencias**.
- ADI-2/4 Pro SE en solidelectronics.mx: $51.100 MXN sin existencias.

### 2026-09-19 (segunda comprobación, 16:00) — sin novedad

Re-comprobación dentro de otra tarea. Resultado: **sin cambio alguno**.
- `rme-audio.de/converter/adi-2-dac-ex.html` → sigue **404**.
- Sin precio, sin fecha, sin distribuidor mexicano.

## Próxima ejecución — pistas a revisar
- Reintentar `rme-audio.de/converter/adi-2-dac-ex.html` (es el indicador más limpio).
- Revisar `rme-shop.com/acatalog/RME_converters.html` (aparición en "New Products").
- Buscar "ADI-2 DAC EX" en Thomann, Soundium, Zococity (Europa) — suelen listar antes.
- México: `solidelectronics.mx/catalogsearch/result/?q=ADI-2` (funciona mejor que el buscador normal).
- MercadoLibre México: `listado.mercadolibre.com.mx/rme-adi-2-dac` (bloquea WebFetch, usar búsqueda web).
