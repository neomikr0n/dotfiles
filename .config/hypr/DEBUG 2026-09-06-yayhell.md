# Perfil técnico y metodología de depuración

## 1. Objetivo de este documento

Este documento resume lo aprendido durante una sesión extensa de depuración en Garuda/Arch Linux con Hyprland, Dank Material Shell (DMS), systemd y Plasma.

Está pensado para reutilizarse en:

* nuevos chats con ChatGPT;
* otros modelos de IA;
* sesiones futuras de diagnóstico;
* recuperación de configuraciones;
* migraciones de Hyprland;
* problemas de systemd, Wayland, DMS, Plasma o componentes relacionados.

La prioridad del usuario es **recuperar primero un estado funcional conocido y entender la causa del fallo antes de modernizar, migrar o modificar componentes**.

---

# 2. Perfil del sistema relevante

## Distribución y escritorio

* Garuda Linux / Arch Linux.
* Wayland.
* Hyprland como compositor principal.
* Plasma Wayland disponible como escritorio alternativo y entorno de rescate.
* SDDM como gestor de inicio de sesión.
* También existe una sesión `Hyprland (uwsm-managed)`, pero durante esta depuración se utilizó la sesión Hyprland normal.

Sesión Hyprland:

```text
/usr/share/wayland-sessions/hyprland.desktop

Exec=/usr/bin/start-hyprland
```

## Shell

* fish.

## Kernel observado

Durante la sesión:

```text
7.2.3-zen1-2-zen
```

## Hyprland

Versión diagnosticada:

```text
Hyprland 0.56.2
```

Stack de librerías coherente:

```text
aquamarine 0.15.0
hyprgraphics 0.5.1
hyprutils 0.14.1
hyprcursor 0.1.13
hyprlang 0.6.8
```

No se detectó una incompatibilidad ABI entre Hyprland y sus librerías.

Esto fue importante porque inicialmente existía la posibilidad de que una actualización del sistema hubiera roto Hyprland, pero la evidencia descartó esa hipótesis.

---

# 3. Organización de la configuración de Hyprland

`~/.config/hypr` no es un directorio normal.

Es un symlink:

```text
~/.config/hypr
→ /home/n30/dotfiles/.config/hypr
```

Por tanto, cualquier modificación hecha por instaladores sobre:

```text
~/.config/hypr/*
```

modifica realmente el repositorio/directorio de dotfiles.

Esto debe tenerse siempre en cuenta antes de:

* borrar archivos;
* restaurar backups;
* ejecutar instaladores;
* ejecutar `dms setup`;
* probar configuraciones generadas;
* usar herramientas que sobrescriban `hyprland.conf` o `hyprland.lua`.

---

# 4. Git debe considerarse una fuente primaria de recuperación

El directorio:

```text
~/dotfiles
```

está gestionado con Git.

Durante esta incidencia, el backup automático proporcionado por DMS no contenía la configuración correcta más reciente.

El `hyprland.conf` correcto pudo recuperarse posteriormente desde Git.

Por ello, en futuras incidencias relacionadas con configuración, **Git debe revisarse antes de restaurar backups antiguos al azar**.

Comandos especialmente útiles:

```bash
git -C ~/dotfiles status --short --branch
```

```bash
git -C ~/dotfiles log \
  --all \
  --follow \
  --date=local \
  --format='%h  %ad  %s' \
  -- .config/hypr/hyprland.conf
```

```bash
git -C ~/dotfiles log \
  -p \
  -5 \
  --date=local \
  -- .config/hypr/hyprland.conf
```

Principio aprendido:

> Cuando la configuración vive dentro de un repositorio Git, el historial de Git es normalmente una fuente de recuperación más fiable que backups creados automáticamente por instaladores.

---

# 5. Incidente principal diagnosticado

## Secuencia temporal

La secuencia fue fundamental:

1. Se realizó una gran actualización del sistema.
2. Se reinició.
3. Hyprland funcionó correctamente.
4. Después se ejecutó:

```bash
curl -fsSL https://install.danklinux.com | sh
```

5. Tras instalar Dank/DMS, al seleccionar Hyprland aparecía:

   * pantalla gris;
   * cursor visible;
   * sin escritorio funcional.

6. Plasma seguía funcionando perfectamente.

Esta cronología permitió descartar como causa principal:

* Mesa;
* AMDGPU;
* kernel;
* ABI de Hyprland;
* actualización general de Arch;
* SDDM.

El cambio causal más probable tenía que encontrarse entre los archivos modificados por Dank.

---

# 6. Causa raíz del fallo de Hyprland

El instalador de Dank creó:

```text
~/.config/hypr/hyprland.lua
```

alrededor de las 09:39 del 6 de septiembre de 2026.

Ese archivo contenía una configuración genérica DMS y cargaba:

```lua
require("dms.colors")
require("dms.outputs")
require("dms.layout")
require("dms.cursor")
require("dms.binds")
require("dms.binds-user")
require("dms.windowrules")
```

Además iniciaba:

```lua
systemctl --user start hyprland-session.target
```

El archivo generado por Dank tomó precedencia como configuración principal y dejó de utilizarse efectivamente la configuración Hyprlang anterior.

La configuración Lua desplegada por DMS estaba orientada a un escritorio genérico y no contenía la personalización real del sistema.

La evidencia mostró claramente la existencia de ese nuevo `hyprland.lua` y sus módulos DMS.

Resultado:

```text
Hyprland arrancaba
↓
pero cargaba una configuración distinta
↓
el entorno personalizado no se iniciaba
↓
pantalla gris + cursor
```

Esto fue una distinción crítica:

> La pantalla gris no significaba que Hyprland estuviera muerto. Hyprland estaba funcionando, pero con una configuración distinta/incompleta.

---

# 7. Lección importante sobre Hyprlang y Lua

Durante la depuración se corrigió una interpretación inicial.

En Hyprland 0.55 y 0.56:

* Lua es el nuevo sistema de configuración;
* Hyprlang sigue siendo utilizable;
* no debe tratarse como completamente eliminado;
* la retirada efectiva prevista se encuentra más adelante, alrededor de la transición hacia 0.57.

Por tanto, para este sistema la estrategia correcta fue:

```text
1. Restaurar el entorno funcional en Hyprlang.
2. Verificar que todo funciona.
3. Migrar a Lua posteriormente y de forma controlada.
```

No:

```text
romper el sistema funcional
↓
migrar mientras se depura
↓
introducir dos fuentes de errores simultáneas
```

Principio general:

> Nunca mezclar una recuperación de emergencia con una migración tecnológica si no es necesario.

---

# 8. Configuración incorrecta restaurada inicialmente

DMS había creado backups bajo:

```text
~/.config/hypr/.dms-backups/
```

Entre ellos existía:

```text
hyprland.conf.backup.2025-12-26_17-36-40
```

Ese archivo pertenecía a una antigua configuración de ML4W.

Incluía:

```ini
source = ~/.config/hypr/conf/monitor.conf
source = ~/.config/hypr/conf/cursor.conf
source = ~/.config/hypr/conf/environment.conf
source = ~/.config/hypr/conf/keyboard.conf
...
source = ~/.config/hypr/conf/ml4w.conf
source = ~/.config/hypr/conf/custom.conf
source = ~/.config/hypr/conf/n30.conf
```

Era un entry point viejo de ML4W.

Al restaurarlo, Hyprland arrancó, pero produjo cerca de 300 errores por sintaxis y configuraciones antiguas incompatibles con Hyprland 0.56.

El usuario comentó temporalmente esas líneas para poder arrancar.

Después se concluyó que ese backup **no era la configuración real inmediatamente anterior al incidente**.

Esto es una lección importante:

> Un backup existente no implica que sea el backup correcto.

Hay que comprobar siempre:

* fecha;
* contexto;
* arquitectura;
* shell utilizado;
* `source`;
* historial Git;
* cambios recientes.

---

# 9. Configuración correcta recuperada desde Git

Posteriormente se recuperó desde Git un `hyprland.conf` mucho más reciente y coherente con DMS.

Su arquitectura era mucho más simple:

```ini
monitor = , preferred,auto,auto
```

Configuración principal propia con:

* input;
* decoración;
* animaciones;
* reglas de ventana;
* keybindings DMS;
* navegación;
* workspaces;
* capturas;
* audio;
* brillo;

y finalmente:

```ini
source = ~/.config/hypr/n30.conf
```

Esto confirma que la arquitectura moderna previa al incidente era aproximadamente:

```text
hyprland.conf
    ↓
configuración base / DMS
    ↓
source ~/.config/hypr/n30.conf
    ↓
personalizaciones del usuario
```

No la antigua arquitectura modular de ML4W.

---

# 10. `n30.conf`

`n30.conf` es una parte central de la configuración personalizada.

Contiene, entre otras cosas:

* configuración específica del monitor;
* teclado `latam`;
* variables de entorno;
* ajustes AMD/RADV;
* bindings personalizados;
* aplicaciones de inicio;
* scripts;
* reglas de juegos;
* Steam;
* CoreCtrl;
* Awakened PoE Trade;
* clipboard;
* rclone;
* DMS;
* workspaces;
* automatizaciones de aplicaciones.

En el momento de la incidencia, `n30.conf` tenía una fecha de modificación muy reciente:

```text
2026-09-05 14:49
```

Esto era una señal mucho más fuerte de actualidad que el backup de ML4W de diciembre de 2025.

---

# 11. DMS / Dank Material Shell

Versión observada:

```text
DMS CLI v1.6.0
API v34
```

DMS utiliza:

```text
/usr/bin/dms run --session
```

La unidad de systemd es:

```text
/usr/lib/systemd/user/dms.service
```

Con:

```ini
[Service]
Type=dbus
BusName=org.freedesktop.Notifications
ExecStart=/usr/bin/dms run --session
TimeoutStartSec=90s
```

La unidad está habilitada:

```text
enabled
```

y se integra con:

```text
graphical-session.target
```

---

# 12. Preferencia actual para iniciar DMS

El usuario prefiere que DMS sea gestionado mediante:

```text
systemd --user
```

y no mediante:

```ini
exec-once = dms run
```

o:

```ini
exec-once = bash -c "sleep 3; dms run"
```

Esto tiene varias ventajas:

* un único proceso responsable;
* logs centralizados;
* reinicios;
* supervisión;
* control mediante `systemctl`;
* menor probabilidad de duplicados.

Por ello, el antiguo arranque manual en `n30.conf` quedó comentado:

```ini
#exec-once = bash -c "sleep 3; QSG_RHI_BACKEND=opengl dms run"
```

---

# 13. `hyprland-session.target`

Existe:

```text
~/.config/systemd/user/hyprland-session.target
```

y durante la sesión se comprobó que estaba activo:

```text
Active: active
```

También:

```text
graphical-session.target
```

estaba activo correctamente.

En `n30.conf` quedó:

```ini
exec-once = systemctl --user start hyprland-session.target
```

---

# 14. Ciclo de dependencias systemd descubierto

En una etapa de la depuración existía simultáneamente:

```text
graphical-session.target.wants/dms.service
```

y:

```text
hyprland-session.target.wants/dms.service
```

Esto produjo un ciclo de ordenación.

systemd informó explícitamente:

```text
dms.service: Found ordering cycle
...
Job dms.service/start deleted to break ordering cycle
```

Lección general:

> Si un servicio ya pertenece a `graphical-session.target`, añadirlo simultáneamente como dependencia de otro target que depende de `graphical-session.target` puede crear ciclos.

Antes de hacer `add-wants`, siempre inspeccionar:

```bash
systemctl --user cat SERVICIO
```

```bash
systemctl --user list-dependencies TARGET
```

```bash
systemctl --user status TARGET
```

---

# 15. Variables systemd/Wayland verificadas

Dentro de Hyprland, el entorno systemd contenía correctamente:

```text
HYPRLAND_INSTANCE_SIGNATURE=...
WAYLAND_DISPLAY=wayland-1
XDG_CURRENT_DESKTOP=Hyprland
```

Por tanto, una vez recuperado Hyprland, el fallo de DMS ya no era causado por falta de:

* `WAYLAND_DISPLAY`;
* `HYPRLAND_INSTANCE_SIGNATURE`;
* `XDG_CURRENT_DESKTOP`.

Esto evitó seguir modificando innecesariamente la exportación de variables.

---

# 16. DMS arrancaba aunque systemd terminara en timeout

Al ejecutar:

```bash
systemctl --user start dms.service
```

systemd terminaba mostrando:

```text
Job for dms.service failed because a timeout was exceeded
```

pero DMS visualmente sí arrancaba.

La unidad se quedaba durante bastante tiempo en:

```text
Active: activating (start)
```

mientras existían procesos:

```text
/usr/bin/dms run --session
qs -p /run/user/1000/danklinux-shell/...
```

Esto llevó a investigar el requisito DBus:

```ini
Type=dbus
BusName=org.freedesktop.Notifications
```

---

# 17. Conflicto pendiente: DMS vs SwayNC

El propietario actual de:

```text
org.freedesktop.Notifications
```

es:

```text
swaync
```

confirmado mediante:

```bash
busctl --user status org.freedesktop.Notifications
```

que devolvió:

```text
Comm=swaync
Exe=/usr/bin/swaync
```

Al mismo tiempo, `dms.service` también declara:

```ini
BusName=org.freedesktop.Notifications
```

Por eso systemd no considera completado correctamente el arranque DBus de DMS.

Además aparecen errores:

```text
Two services allocated for the same bus name org.freedesktop.Notifications
```

para:

* swaync;
* dunst;
* DMS.

Este conflicto quedó **deliberadamente en pausa**.

No modificarlo automáticamente en futuras sesiones salvo que el usuario quiera retomarlo.

---

# 18. DMS y configuración Hyprlang

Al ejecutar DMS con el actual `hyprland.conf`, DMS detectó correctamente que la configuración activa es Hyprlang.

Mostró:

```text
Skipping Hyprland layout Lua write because the active Hyprland config is not Lua
```

y:

```text
hyprland legacy conf configs are read-only;
run dms setup to migrate to Lua before editing window rules
```

Esto no significa que DMS no funcione.

Significa:

```text
DMS puede ejecutarse
pero
DMS no puede administrar/escribir automáticamente determinadas partes
de la configuración Hyprland mientras se use Hyprlang.
```

Esto es aceptable temporalmente.

---

# 19. Migración a Lua: estado actual

La migración:

```text
Hyprlang → Lua
```

está pendiente.

No debe realizarse durante una recuperación de otro problema.

La estrategia acordada es:

```text
1. Estabilizar Hyprland actual.
2. Asegurar que la configuración Git correcta funciona.
3. Corregir problemas pendientes.
4. Crear backup/commit Git.
5. Migrar a Lua.
6. Comparar comportamiento.
7. Mantener rollback sencillo.
```

---

# 20. Plasma como entorno de rescate

Plasma funcionó durante toda la incidencia.

Esto fue extremadamente útil porque permitió:

* editar configuraciones;
* leer logs;
* inspeccionar systemd;
* recuperar archivos;
* trabajar con Git;
* reiniciar Hyprland sin perder un entorno gráfico funcional.

En futuras incidencias de Hyprland:

> Si Plasma funciona, no modificar agresivamente el stack gráfico. Utilizar Plasma como estación de diagnóstico.

---

# 21. Metodología de depuración preferida

## Regla 1 — Reconstruir la cronología

Antes de cambiar nada:

```text
¿Qué funcionaba?
¿Qué se actualizó?
¿Qué comando se ejecutó?
¿Cuándo apareció el fallo?
¿Qué ocurrió entre el último arranque correcto y el primero incorrecto?
```

En esta incidencia fue decisivo:

```text
Hyprland funcionó DESPUÉS de actualizar
pero dejó de funcionar DESPUÉS de instalar Dank
```

Eso redujo muchísimo el espacio de búsqueda.

---

## Regla 2 — Diferenciar correlación de causalidad

No asumir:

```text
"actualicé 500 paquetes"
=
"la actualización rompió Hyprland"
```

si existe evidencia de que Hyprland arrancó después de esa actualización.

---

## Regla 3 — Diagnóstico antes de reparación

Orden preferido:

```text
1. Estado del sistema.
2. Versiones.
3. Logs.
4. Archivos modificados.
5. Backups.
6. Git.
7. Configuración.
8. Dependencias.
9. Hipótesis.
10. Cambio mínimo.
```

---

## Regla 4 — Un cambio cada vez

Evitar hacer simultáneamente:

```text
desinstalar DMS
editar Hyprland
cambiar Mesa
cambiar kernel
borrar configs
modificar systemd
```

porque después no se puede saber qué solucionó o empeoró el problema.

---

## Regla 5 — Preferir comandos de solo lectura primero

Ejemplos:

```bash
systemctl --user status ...
```

```bash
systemctl --user cat ...
```

```bash
journalctl ...
```

```bash
grep ...
```

```bash
find ...
```

```bash
git log ...
```

```bash
git diff ...
```

antes de:

```bash
rm
mv
pacman -R
systemctl disable
systemctl mask
```

---

## Regla 6 — No destruir backups

Antes de modificar una configuración:

```bash
cp -a ...
```

o, mejor todavía cuando existe Git:

```bash
git status
git diff
git commit
```

---

## Regla 7 — No hacer hacks ABI/dependencias sin evidencia

Evitar como primera respuesta:

```bash
pacman -Rdd
```

```bash
--nodeps
```

```bash
--overwrite='*'
```

symlinks manuales de `.so`

borrar bibliotecas

forzar paquetes incompatibles

La sesión anterior mostró que comprobar las versiones reales era suficiente para demostrar que el stack Hyprland era coherente.

---

## Regla 8 — No asumir que un backup es actual

Comparar:

```text
fecha
contenido
arquitectura
shell
historial Git
```

antes de restaurarlo.

---

## Regla 9 — Distinguir "compositor no arranca" de "shell no arranca"

Pantalla gris + cursor puede significar:

```text
Hyprland funciona
pero
bar/shell/wallpaper/autostart/config no funcionan
```

No asumir automáticamente fallo de GPU.

---

## Regla 10 — Priorizar rollback funcional

Si existe un estado conocido:

```text
volver primero a ese estado
```

y modernizar después.

---

# 22. Forma preferida de interacción con una IA durante debug

El usuario prefiere respuestas que:

* expliquen la hipótesis;
* indiquen el nivel de certeza;
* muestren qué evidencia la soporta;
* diferencien claramente hechos e inferencias;
* den pocos comandos por etapa;
* eviten cambios destructivos prematuros;
* esperen los resultados antes de pasar al siguiente cambio;
* expliquen la lógica detrás de cada comando importante;
* corrijan errores propios si el usuario detecta una premisa incorrecta;
* no defiendan una hipótesis después de que la evidencia la descarte;
* aprovechen Git, backups y logs;
* trabajen de forma reversible.

Formato ideal:

```text
HECHO
Lo que sabemos.

HIPÓTESIS
Lo que probablemente ocurre.

PRUEBA
Comando no destructivo.

RESULTADOS POSIBLES
Qué significa cada salida.

CAMBIO
Solo si la prueba confirma la hipótesis.

ROLLBACK
Cómo revertirlo.
```

---

# 23. Cosas que una IA NO debería hacer automáticamente

No recomendar de entrada:

```text
reinstalar Hyprland
reinstalar Garuda
borrar ~/.config/hypr
borrar dotfiles
eliminar DMS
cambiar de kernel
borrar cachés sin motivo
cambiar Mesa
cambiar drivers
desinstalar paquetes
```

sin demostrar primero que el fallo está relacionado.

Tampoco debería:

* inventar opciones CLI;
* asumir que una configuración antigua ya no funciona;
* confundir "deprecated" con "removed";
* restaurar automáticamente el backup más reciente sin revisar su contenido;
* asumir que un servicio `inactive` nunca llegó a ejecutarse;
* ignorar que `Type=dbus` puede depender de adquirir un BusName.

---

# 24. Estado actual resumido

Actualmente:

```text
Garuda / Arch                  FUNCIONAL
Hyprland 0.56.2                FUNCIONAL
Stack Hyprland                 COHERENTE
AMD / Wayland                  FUNCIONAL
Plasma                         FUNCIONAL
hyprland.conf desde Git        RESTAURADO
n30.conf                       ACTIVO / PERSONALIZADO
hyprland.lua generado por DMS  APARTADO
DMS                            FUNCIONA
DMS vía systemd                FUNCIONA parcialmente,
                               pero puede terminar en timeout
                               por conflicto DBus
SwayNC                         ACTIVO
org.freedesktop.Notifications  propiedad de SwayNC
Migración a Lua                PENDIENTE
Conflicto notificaciones       EN PAUSA
```

---

# 25. Prompt corto para pegar en otro modelo de IA

Estoy depurando Garuda/Arch Linux con Hyprland 0.56.x, Wayland, fish y Dank Material Shell (DMS). Mi `~/.config/hypr` es un symlink a `~/dotfiles/.config/hypr`, que está bajo Git.

Quiero un enfoque conservador y forense:

1. primero reconstruye la cronología;
2. revisa versiones, logs, Git y archivos modificados;
3. usa comandos de solo lectura antes de modificar;
4. distingue hechos de hipótesis;
5. no hagas cambios destructivos ni reinstalaciones sin evidencia;
6. haz un solo cambio por vez;
7. mantén siempre rollback;
8. si existe una configuración funcional anterior, restáurala antes de migrar o modernizar.

Incidente previo relevante: el instalador de Dank creó `~/.config/hypr/hyprland.lua`, que tomó precedencia sobre mi configuración Hyprlang y provocó una pantalla gris con cursor. Hyprland en sí estaba funcionando. Recuperé desde Git mi `hyprland.conf` correcto y ahora carga `source = ~/.config/hypr/n30.conf`.

DMS está gestionado mediante `systemd --user`. Existe un conflicto pendiente porque `dms.service` usa `Type=dbus` con `BusName=org.freedesktop.Notifications`, pero actualmente SwayNC posee ese nombre DBus. Ese conflicto está en pausa.

Por ahora quiero mantener Hyprlang funcional y migrar a Lua después, de forma controlada.

Antes de sugerir cualquier cambio importante, explícame:

* qué evidencia lo justifica;
* qué esperamos observar;
* cómo revertirlo.

---

# 26. Prompt ultracorto

Garuda/Arch + Hyprland + Wayland + DMS. `~/.config/hypr` → `~/dotfiles/.config/hypr`, bajo Git. Depura de forma forense: cronología → logs → versiones → Git → hipótesis → prueba no destructiva → cambio mínimo → rollback. No reinstales ni borres configs sin evidencia. Mi configuración activa es Hyprlang con `hyprland.conf` + `source ~/.config/hypr/n30.conf`; migración a Lua pendiente. DMS usa systemd. Conflicto SwayNC/DMS por `org.freedesktop.Notifications` pendiente.
