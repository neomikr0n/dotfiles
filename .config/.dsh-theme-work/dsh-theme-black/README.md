# dsh-theme-black

Paleta negro puro para la interfaz web de DeepSeek Harness. No es un tema nuevo
en el selector de Ajustes: es una **capa de overrides de tokens** que se apila
sobre el tema oscuro activo, así que Ajustes › Apariencia sigue con
claro / oscuro / sistema y el resultado se ve en «oscuro».

## Qué toca

- La escala estática `--dsw-static-neutral-bluish-700…950`, de la que el modo
  oscuro deriva casi todas sus superficies. Bajarla oscurece de una vez fondo,
  sidebar, capas, menús, inputs, toasts, tooltips y el CSS de los plugins que la
  usa directamente.
- Un puñado de tokens que no salen de esa escala: etiqueta atenuada, selección
  múltiple, código en línea y los degradados del bloque «pensando».

El modo claro no cambia: cada override lleva su valor `light` original, que es
lo que exige la API (`overrideTokens` pide siempre el par `{ light, dark }`).

## Ajustar la intensidad

Todo vive en `lib/client.js`:

- `SURFACE_SCALE` — la escala. El valor `dark` más alto (950) es el fondo base;
  subirlo acerca la interfaz a su gris actual, bajarlo la acerca al negro.
- `EXCEPTIONS` — los tokens que no siguen la escala.

Tras editar, recarga la pestaña (Cmd/Ctrl+R); el plugin se sirve en cada arranque
del servidor, no hace falta reiniciar `dsh web`.

## Revertir

Quita el bloque `insert` de `~/.dsh/profiles/web/cordis.patch.yml` y recarga.
