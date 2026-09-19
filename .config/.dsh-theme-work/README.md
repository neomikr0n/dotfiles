# .dsh-theme-work — taller del tema negro

Directorio de trabajo (desechable) para oscurecer la interfaz del arnés.
El plugin **vivo** está instalado y en uso en:

    ~/.dsh/plugins/dsh-theme-black          # fuente instalada (autoritativa)
    ~/.dsh/profiles/web/cordis.patch.yml    # lo monta en el perfil web
    ~/.dsh/profiles/web/package.json        # dependencia link: (lo conserva pnpm)

`dsh-theme-black/` aquí es una **copia sincronizada** de esa fuente; editar la
de ~/.dsh es lo que surte efecto.

## Ficheros

| Fichero | Para qué |
|---|---|
| `dsh-theme-black/lib/client.js` | La tabla de tokens del tema (`SURFACE_SCALE`, `EXCEPTIONS`). |
| `check-tokens.mjs` | Comprueba que cada valor `light` es idéntico al de fábrica (modo claro intacto) y que cada `dark` oscurece. `node check-tokens.mjs` |
| `gen-overrides.mjs` | Vuelca la tabla oscura a `overrides.json`. |
| `shot.mjs` | Captura la GUI con Chrome headless vía CDP. Sin argumentos usa la GUI viva (mina la cookie de sesión desde `~/.dsh/.credentials.yaml`); acepta `out.png ancho alto [url] [texto-a-clicar] [stock]`. |
| `fetch-auth.mjs` | Petición autenticada a la GUI: `node fetch-auth.mjs / salida.html`. |
| `dark-tokens.txt` | Volcado de todos los tokens del modo oscuro de fábrica, para consultar. |
| `before.png` / `after-black2.png` | Estado vacío: de fábrica vs. tema negro. |
| `conv-before.png` / `conv-after.png` | Conversación real: de fábrica vs. negro (simulado inline, sin reiniciar). |
| `real-black.png` | Pantalla de sesión nueva con el tema aplicado. |

## Ajustar y revertir

- Intensidad: `SURFACE_SCALE` en `lib/client.js` (el `dark` de `bluish-950` es el
  fondo base). Recarga la pestaña para verlo.
- Revertir del todo: borra el bloque `insert` de `cordis.patch.yml` (hay copia en
  `cordis.patch.yml.bak-theme-black`) y reinicia `dsh web`.
