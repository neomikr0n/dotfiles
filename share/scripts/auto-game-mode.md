# AutoGame para Steam y Hyprland

`auto-game-mode.sh` se inicia desde el `exec` que ya existe en `~/.config/hypr/n30.conf`. Usa Bash y Python 3 estándar, además de `hyprctl`; las notificaciones requieren `notify-send`.

## Qué hace

- Consulta cada 5 segundos las ventanas `steam_app_<ID>` y las variables reales `SteamAppId` / `SteamGameId` de los procesos de tu usuario. También reconoce los argumentos `SteamLaunch AppId=…` de Steam/reaper/Gamescope cuando el sistema restringe la lectura del entorno. Reconoce juegos nativos, Proton y accesos añadidos a Steam. Steam abierto y Wine por sí solos no activan el modo. Un lanzador que conserve esas variables puede mantenerlo activo hasta cerrarse.
- Desactiva animaciones, desenfoque y sombras si estaban activados. Respeta el flag de modo manual ML4W si ya existía, sin crearlo ni borrarlo.
- **Fondo de vídeo (skwd-paper-v2).** Lee el estado real con `skwd-paper-v2 status` y lo congela con `skwd-paper-v2 pause`. Ese comando sustituye el renderizador de vídeo `skwd-wall-vk` por `skwd-wall-still`, que muestra el fotograma exacto del momento de la pausa conservando monitor, capa y modo de relleno. Medido el 2026-09-21: 5,8 % de un núcleo reproduciendo → 0,0 % congelado, y el proceso de vídeo desaparece.
- **Sólo reclama la pausa que causó él.** Si el fondo ya estaba pausado (por ejemplo desde el selector), no lo toca y tampoco lo reanuda al salir. Si no hay ningún fondo de skwd aplicado, si `skwd-paper-v2` no responde o si la CLI devuelve error, no hace nada y lo reintenta en el ciclo siguiente.
- **Mientras hay un juego abierto vuelve a comprobar el fondo en cada ciclo.** Una recarga de Hyprland ejecuta `wallpaperStart()`, que reaplica el fondo: eso reinicia el proceso `skwd-paper-v2 serve`, y como la pausa vive en ese proceso, se pierde. Medido el 2026-09-21: el script vuelve a congelarlo 3 segundos después.
- `mpvpaper` y `gslapper`, si aún aparecieran, se siguen pausando con SIGSTOP: se reanudan sólo los procesos registrados, validando PID y tiempo de inicio. Si el entorno del fondo no se puede leer, sólo lo pausa cuando detecta un único compositor del usuario y es Hyprland. No inicia fondos que no existían ni elimina instancias de otros monitores.
- **No se usa SIGSTOP con `skwd-wall-vk`.** skwd ya ofrece pausa propia y una señal no se refleja en `skwd-paper-v2 status`. Medido: la señal sí mantiene el proceso parado de forma indefinida, pero skwd sigue creyendo que reproduce, así que una reaplicación del fondo (recarga de Hyprland) deja dos renderizadores a la vez sobre la misma salida.
- Espera 15 segundos sin detectar juegos antes de restaurar, para tolerar transiciones entre lanzador y juego. Restaurar no recarga Hyprland ni ejecuta nuevamente los comandos `exec`.
- Mantiene DMS, audio, comunicaciones y bloqueo de pantalla disponibles. No vacía cachés ni modifica prioridades, afinidad o perfiles de energía.

## Efectos con la configuración en Lua

Hyprland 0.56 con la configuración en Lua **rechaza `hyprctl keyword`** (`keyword can't work with non-legacy parsers. Use eval.`), y `getoption` devuelve la clave `bool`, no `int`. La versión anterior de este script leía `int` y escribía con `keyword`, así que **no desactivaba nada**: comprobado el 2026-09-21 midiendo los tres valores antes y después.

Ahora se lee `int` o `bool`, y se escribe con `hyprctl eval 'hl.config({…})'`, que sí aplica el cambio. `keyword` se conserva como respaldo para configuraciones clásicas. Verificado en vivo: 1/1/1 → 0/0/0 → 1/1/1.

Los valores de efectos que cambies mientras juegas se conservan si difieren del valor desactivado aplicado por el script. Una recarga manual puede volver a activar efectos durante el juego; el script evita imponerlos continuamente sobre tus cambios.

## Diagnóstico

Desde una terminal de Hyprland:

```sh
~/dotfiles/share/scripts/auto-game-mode.sh --check
~/dotfiles/share/scripts/auto-game-mode.sh --status
cat "$XDG_RUNTIME_DIR/auto-game-mode/daemon.log"
```

`--check` consulta detección, efectos y estado de skwd (`paused`, `assignments`) sin cambiarlos. `--status` comprueba el bloqueo del daemon e indica `Monitor: ACTIVO` o `DETENIDO`, su PID y el estado del modo juego. El archivo `daemon.log` corresponde a la instancia iniciada durante esta actualización; las ejecuciones posteriores escriben en su salida estándar.

El bloqueo real con `flock` impide duplicados, incluso al recargar la configuración. Para detenerlo, envía SIGTERM al PID de la instancia; restaura antes de salir. No uses SIGKILL: si ocurre una caída así, la próxima ejecución recupera el registro. También puedes ejecutar `--restore` cuando no haya otra instancia activa. Si Hyprland no está disponible, conserva las restauraciones pendientes y reanuda el fondo.

Los archivos privados de bloqueo y recuperación están en `$XDG_RUNTIME_DIR/auto-game-mode/` y desaparecen al finalizar la sesión del usuario. No borres el registro mientras haya un fondo pausado.

## Ajustes opcionales

Variables de entorno: `AUTO_GAME_INTERVAL` (1–60, predeterminado 5), `AUTO_GAME_EXIT_DELAY` (0–300, predeterminado 15), `AUTO_GAME_NOTIFY=0` para silenciar notificaciones. Deben establecerse al iniciar una nueva instancia.

## Verificación

```sh
python3 -m unittest discover -s ~/dotfiles/share/scripts/tests -p test_auto_game_mode.py -v
```

19 pruebas: detección de juegos, modo manual ML4W, recuperación, errores de IPC, reutilización de PID, pausa/reanudación de un proceso real aislado, lectura de `bool` e `int`, construcción del literal Lua, preferencia de `eval` con respaldo a `keyword`, y la lógica de propiedad de la pausa de skwd. Ninguna toca la sesión real: la CLI de skwd va simulada.

Medido en vivo el 2026-09-21 con Hyprland 0.56.2: con el fondo de vídeo congelado, `paused` se mantuvo en `true` con el mismo `skwd-wall-still` durante 285 segundos seguidos, `resume` devolvió el vídeo y la caché de fotogramas congelados quedó a cero. No se midieron FPS.

Referencia para las operaciones de configuración en ejecución: [documentación de hyprctl](https://wiki.hypr.land/Configuring/Using-hyprctl/).
