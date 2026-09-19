# Auditoría de animaciones — audio_deepseek.html

Banco de pruebas para verificar las animaciones e interactividad de `audio_deepseek.html`
en **Gecko real** (Firefox/Zen). Se usó para localizar y confirmar los arreglos del
17/09/2026. Todo se ejecuta con el Firefox del sistema en modo headless.

## Requisito previo

`node_modules/` no se copia aquí. Si falta, instalar una vez:

```bash
cd .audit && npm init -y && npm install playwright-core
```

> `playwright-core` **no** se usa para lanzar el navegador (ni Firefox ni Zen arrancan
> con `-juggler-pipe` en este entorno: mueren por una aserción DBus). Los scripts usan
> el flag nativo `--headless --screenshot` y el binario `/usr/lib/firefox/firefox`.

## Scripts

| Script | Qué verifica |
|---|---|
| `check.sh <html>` | Extrae y hace `node --check` de cada `<script>` inline. |
| `diag2.js <html> <label> [W] [H]` | Sirve el HTML por HTTP e inyecta un hook que reporta por XHR: errores JS, `console.error`, salud por canvas (`getImageData` → alfa no nulo), bboxes SVG, imágenes rotas, `.reveal` sin revelar, altura del documento. **La comprobación más útil.** |
| `interact.js <html> <label> [W] [H]` | Pulsa los 23 controles (bias, dip, noise, slider, presets EQ, transport, xrun, voltajes, checklist, planar, rail) y compara lecturas antes/después. |
| `lifecycle.js <html> <label> [W] [H]` | Entrar / salir / volver por canvas: debe dibujar en la entrada y en el retorno. |
| `smiltest.js <html> [W] [H]` | Muestrea posiciones de los 21 `animateMotion` en dos instantes y lista los keyframes CSS activos. |
| `secwork.js <html> <label> <idSeccion> [W] [H]` | Captura una sección concreta ocultando los hermanos previos. |
| `herom.js <html> [W] [H]` | Mide geometría y visibilidad de los elementos del hero. |

## Uso típico

```bash
cd .audit && npm install playwright-core   # una sola vez

./check.sh ../audio_deepseek.html
node diag2.js ../audio_deepseek.html check
node interact.js ../audio_deepseek.html check
node lifecycle.js ../audio_deepseek.html check
node smiltest.js ../audio_deepseek.html
node secwork.js ../audio_deepseek.html energia energia
```

Salida de referencia (estado correcto): 0 errores JS, 9/9 canvas dibujando,
`docH ≈ 30405`, 23/23 interacciones OK, 21/21 SMIL en movimiento.

## Notas de entorno

- Requiere `DBUS_SESSION_BUS_ADDRESS=disabled:`, `NO_AT_BRIDGE=1`, `MOZ_HEADLESS=1`,
  `MOZ_DISABLE_CONTENT_SANDBOX=1` y un `--profile <dir>` ya creado (los scripts lo hacen).
- El reporte por XHR **debe** salir de un origen `http://127.0.0.1`; desde `file://`
  está bloqueado y se obtiene `NO_REPORT_RECEIVED`.
- `--screenshot` dispara **en la carga**; los timers posteriores no afectan la captura.
  Por eso `secwork.js` oculta los hermanos previos y repite en varios timestamps.
  Medir el offset y aplicar `margin-top` negativo **no** funciona (mide pre-layout).
- Un canvas en blanco estando lejos de pantalla es **correcto**: el IntersectionObserver
  pausa y limpia. Debe recuperarse al volver a entrar — eso es lo que valida `lifecycle.js`.

## Baseline

`audio_deepseek.baseline.html` es la copia verificada del archivo reparado. Sirve para
comparar (`diff`) si en el futuro se vuelve a romper algo.
