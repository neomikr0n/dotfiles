# AutoGame para Steam y Hyprland

`auto-game-mode.sh` se inicia desde el `exec` que ya existe en `~/.config/hypr/n30.conf`. Usa Bash y Python 3 estándar, además de `hyprctl`; las notificaciones requieren `notify-send`.

- Consulta cada 5 segundos las ventanas `steam_app_<ID>` y las variables reales `SteamAppId` / `SteamGameId` de los procesos de tu usuario. También reconoce los argumentos `SteamLaunch AppId=…` de Steam/reaper/Gamescope cuando el sistema restringe la lectura del entorno. Reconoce juegos nativos, Proton y accesos añadidos a Steam. Steam abierto y Wine por sí solos no activan el modo. Un lanzador que conserve esas variables puede mantenerlo activo hasta cerrarse.
- Desactiva animaciones, desenfoque y sombras si estaban activados. Respeta el flag de modo manual ML4W si ya existía, sin crearlo ni borrarlo.
- Pausa los procesos existentes de `mpvpaper` y `gslapper` de la misma sesión con SIGSTOP; conserva el vídeo, monitor y opciones. Reanuda sólo los procesos registrados, validando PID y tiempo de inicio. Si el entorno del fondo no se puede leer, sólo lo pausa cuando detecta un único compositor del usuario y es Hyprland. No inicia fondos que no existían ni elimina instancias de otros monitores.
- Espera 15 segundos sin detectar juegos antes de restaurar, para tolerar transiciones entre lanzador y juego. Restaurar no recarga Hyprland ni ejecuta nuevamente los comandos `exec`.
- Mantiene DMS, audio, comunicaciones y bloqueo de pantalla disponibles. La pausa reduce trabajo de CPU/GPU; **no libera la RAM/VRAM asignada al fondo**. No vacía cachés ni modifica prioridades, afinidad o perfiles de energía.

Los valores de efectos que cambies mientras juegas se conservan si difieren del valor desactivado aplicado por el script. Una recarga manual puede volver a activar efectos durante el juego; el script evita imponerlos continuamente sobre tus cambios.

## Diagnóstico

Desde una terminal de Hyprland:

```sh
~/dotfiles/share/scripts/auto-game-mode.sh --check
~/dotfiles/share/scripts/auto-game-mode.sh --status
cat "$XDG_RUNTIME_DIR/auto-game-mode/daemon.log"
```

`--check` consulta detección y efectos sin cambiarlos. `--status` comprueba el bloqueo del daemon e indica `Monitor: ACTIVO` o `DETENIDO`, su PID y el estado del modo juego. El archivo `daemon.log` corresponde a la instancia iniciada durante esta actualización; las ejecuciones posteriores escriben en su salida estándar.

El bloqueo real con `flock` impide duplicados, incluso al recargar la configuración. Para detenerlo, envía SIGTERM al PID de la instancia; restaura antes de salir. No uses SIGKILL: si ocurre una caída así, la próxima ejecución recupera el registro. También puedes ejecutar `--restore` cuando no haya otra instancia activa. Si Hyprland no está disponible, conserva las restauraciones pendientes y reanuda el fondo.

Los archivos privados de bloqueo y recuperación están en `$XDG_RUNTIME_DIR/auto-game-mode/` y desaparecen al finalizar la sesión del usuario. No borres el registro mientras haya un fondo pausado.

## Ajustes opcionales

Variables de entorno: `AUTO_GAME_INTERVAL` (1–60, predeterminado 5), `AUTO_GAME_EXIT_DELAY` (0–300, predeterminado 15), `AUTO_GAME_NOTIFY=0` para silenciar notificaciones. Deben establecerse al iniciar una nueva instancia.

## Verificación

```sh
python3 -m unittest discover -s ~/dotfiles/share/scripts/tests -p test_auto_game_mode.py -v
```

Las pruebas cubren detección, modo manual, recuperación, errores de IPC, reutilización de PID y pausa/reanudación de un proceso real aislado. También se comprobó en Hyprland 0.56.2 un ciclo de detección con un proceso de Steam simulado; Además se verificó la detección de STALKER 2 abierto mediante Gamescope, con el fondo en estado T (pausado) y los tres efectos en 0; no se midieron FPS.

Referencia para las operaciones de configuración en ejecución: [documentación de hyprctl](https://wiki.hypr.land/Configuring/Using-hyprctl/).
