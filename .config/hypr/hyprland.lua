-- ----------------------------------------------------- 
-- █▄░█ ▒▄▀▀▄ ▒▄▀▀▄ 
-- █░▀█ ░░▒▀▌ ▒█▄▀█ 
-- ▀░░▀ ▒▀▄▄▀ ▒█▄▀█ 
-- eventually source = ~/.config/hypr/conf/n30.lua
-- ----------------------------------------------------- 
-- ==================
-- VARIABLES
-- ==================
local mainMod  = "SUPER"
local files    = "dolphin"
local browser  = "zen-browser"
local whatsapp = "zapzap"
local music    = "cider"
local term     = "kitty"
local editor   = "code"
local soundsDir  = os.getenv("HOME") .. "/dotfiles/share/sounds/"
local scriptsDir = os.getenv("HOME") .. "/dotfiles/share/scripts/"

-- ==================
-- MONITORS
-- ==================
-- Regla comodín + DP-2 (3440x1440@240, 10 bits)
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.monitor({
    output   = "DP-2",
    mode     = "3440x1440@240.09",
    position = "auto",
    scale    = 1,
    bitdepth = 10,
})
-- eDP-2 (portátil): comentado en el .conf original

-- ==================
-- ENV
-- ==================
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_THEME", "Bibata-Modern-Amber")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Amber")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- AMD RDNA 4 (mesa-git). "vulkan-driver" no es una env real.
hl.env("MESA_LOADER_DRIVER_NAME", "radv")

-- ==================
-- CONFIG GENERAL
-- ==================
hl.config({
    input = {
        kb_layout          = "latam",
        follow_mouse       = 1,
        numlock_by_default = true,
        sensitivity        = 0,
        accel_profile      = "flat",
    },

    general = {
        gaps_in            = 0,
        gaps_out           = { 0, 0, 0, 0 },
        border_size        = 2,
        ["col.active_border"]  = "rgba(ffbf00ee)",   -- ámbar
        ["col.inactive_border"] = "rgba(ffff9c00)",  -- ámbar claro
        layout             = "dwindle",
    },

    dwindle = { preserve_split = true },
    master  = { mfact = 0.5 },

    decoration = {
        rounding          = 12,
        active_opacity    = 1.0,
        inactive_opacity  = 0.9,
        shadow = {
            enabled      = true,
            range        = 30,
            render_power = 5,
            offset       = "0 5",       -- también admite { x = 0, y = 5 }
            color        = 0x00000070,
        },
    },

    animations = { enabled = true },

    misc = {
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        vrr                        = 0, -- el OLED parpadea con VRR, tambien en modo 2
        allow_session_lock_restore = true,
        session_lock_xray          = true,
    },

    render = { direct_scanout = false },
})

-- ==================
-- ANIMACIONES Y CURVAS
-- ==================
hl.curve("linear",        { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("md3_standard",  { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })
hl.curve("md3_decel",     { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("md3_accel",     { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("overshot",      { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("crazyshot",     { type = "bezier", points = { { 0.1, 1.5 }, { 0.76, 0.92 } } })
hl.curve("hyprnostretch", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("fluent_decel",  { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("easeInOutCirc", { type = "bezier", points = { { 0.85, 0 }, { 0.15, 1 } } })
hl.curve("easeOutCirc",   { type = "bezier", points = { { 0, 0.55 }, { 0.45, 1 } } })
hl.curve("easeOutExpo",   { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

hl.animation({ leaf = "windows",         enabled = true, speed = 3,   bezier = "md3_decel", style = "popin 60%" })
hl.animation({ leaf = "windowsIn",       enabled = true, speed = 3,   bezier = "default" })
hl.animation({ leaf = "windowsOut",      enabled = true, speed = 3,   bezier = "default" })
hl.animation({ leaf = "windowsMove",     enabled = true, speed = 4,   bezier = "default" })
hl.animation({ leaf = "border",          enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "fade",            enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "workspaces",      enabled = true, speed = 2,   bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2,  bezier = "md3_decel", style = "slidevert" })

-- ==================
-- AUTOSTART 
-- ==================
-- Motor de fondo: skwd-paper-v2 (VAAPI -> Vulkan).
-- Se limpia antes de arrancar: un renderizador viejo (mpvpaper, skwd-wall-vk huérfano)
-- queda por encima y tapa al nuevo. El orden de capas manda: bottom > background.

local wallpaperFile = os.getenv("HOME") .. "/dotfiles/share/wallpapers/yellowmatrix-deepseek.mp4"

local function wallpaperStart()
    local cmd = table.concat({
        "skwd-paper-v2 stop DP-2",
        "pkill -TERM -x mpvpaper",
        "pkill -TERM -x gslapper",
        "pkill -TERM -x skwd-wall-vk",
        "sleep 1",
        "skwd-paper-v2 apply DP-2 " .. wallpaperFile
            .. " --kind video --engine default --fill-mode fill --mute true --layer bottom",
    }, "; ")
    hl.exec_cmd(cmd)
end


local function gameModeStart()
    hl.exec_cmd(os.getenv("HOME") .. "/dotfiles/share/scripts/auto-game-mode.sh")
end

-- Las esperas corren en bash, así que sobreviven a un reload de Lua.
local function shellQuote(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end
local function dispatchCommand(command, workspace)
    return "hyprctl dispatch " .. shellQuote(string.format(
        "hl.dsp.exec_cmd(%q, { workspace = %q })", command, workspace))
end
local function delayedCommand(seconds, command)
    hl.exec_cmd("bash -c " .. shellQuote("sleep " .. seconds .. "; " .. command))
end

-- Espera (máx. 15 s) a que udev cree /dev/i2c-8, el bus DDC del DP-2.
-- Sin ella, la lectura de brillo falla y el guard la convierte en no-op silencioso.
-- El bus va fijo porque DMS nombra los monitores como ddc:i2c-<N>.
local function waitForDdcBus()
    return "i=0; while [ $i -lt 150 ] && [ ! -e /dev/i2c-8 ]; do sleep 0.1; i=$((i+1)); done; "
end

-- Brillo del monitor externo al máximo en cada arranque.
-- Escribe solo VCP 0x10, con el máximo que declara el monitor y solo si no está ya ahí.
-- Usa ddcutil: ddccontrol falla con «Open monitor failed» y aun así devuelve 0.
-- --bus 8 evita la autodetección (0,04 s frente a 3,4 s) y no bloquea el bus.
-- Va antes de DMS y una sola vez: no se registra en config.reloaded.
local function brightnessScript()
    -- Devuelve el script; quien lo lanza decide cuándo.
    return table.concat({
        "set -- $(ddcutil --bus 8 getvcp 10 --brief 2>/dev/null)",
        "cur=$4; max=$5",
        'case "$max" in ""|*[!0-9]*) logger -t astra-brillo "lectura DDC invalida (max=[$max]): NO se escribe"; exit 0 ;; esac',
        '[ "$cur" = "$max" ] && { logger -t astra-brillo "ya en el maximo ($max): no se escribe"; exit 0; }',
        'logger -t astra-brillo "escribiendo maximo $max (estaba en $cur)"',
        'ddcutil --bus 8 setvcp 10 "$max"',
    }, "; ")
end

-- Deja en el journal si DMS acabó viendo el monitor: su fallo es invisible.
-- A los 12 s y en segundo plano, para no competir con su sondeo.
local function dmsDdcSelfCheck()
    return table.concat({
        "( sleep 12",
        "if dms ipc call brightness list 2>/dev/null | grep -q '^ddc:'",
        "then logger -t astra-brillo 'DMS OK: ve el monitor por DDC'",
        "else logger -t astra-brillo 'DMS NO ve el monitor: el slider de brillo no funcionara'",
        "fi ) & ",
    }, "; ")
end

-- hyprland.start se reemite al recargar; la marca por instancia evita duplicar apps.
hl.on("hyprland.start", function()
    local runtime = assert(os.getenv("XDG_RUNTIME_DIR"), "Falta XDG_RUNTIME_DIR")
    local instance = assert(os.getenv("HYPRLAND_INSTANCE_SIGNATURE"), "Falta la instancia Hyprland")
    local marker = runtime .. "/hypr/" .. instance .. "/n30-autostart-astra.done"
    local previous = io.open(marker, "r")
    if previous then previous:close(); return end
    local started = assert(io.open(marker, "w"))
    started:write("Astra 2026-09-16\n")
    started:close()

    -- Sesión y entorno (una sola vez)
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user mask xdg-desktop-portal-gnome")
    hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh")
    -- cliphist: una sola instancia y todos los tipos (antes había dos y duplicaba el historial)
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Vigilante de Ctrl para el dictado. Hyprland no activa graphical-session.target,
    -- así que los servicios que cuelgan de él nunca arrancan: se lanzan a mano.
    hl.exec_cmd("systemctl --user start dictado-tecla.service")

    -- Los otros tres del mismo target muerto: aviso de KTimer, agente HID++ de Logitech
    -- y gestos del touchpad. No se arranca el target entero porque dms.service cuelga
    -- de él y habría un segundo DMS.
    hl.exec_cmd("systemctl --user start ktimer-alert.service")
    hl.exec_cmd("systemctl --user start openlogi-agent.service")
    hl.exec_cmd("systemctl --user start libinput-gestures.service")

    -- whisper residente: sin él, cada dictado recarga el modelo (0,79 s frente a 0,16 s).
    -- Si el modelo se corrompe, la unidad falla y dictado.sh cae al binario.
    hl.exec_cmd("systemctl --user start dictado-servidor.service")

    -- DMS va al final y precedido del brillo. Sondea los buses DDC una sola vez y, si
    -- el bus no existe o está ocupado, se queda sin monitor (el slider mueve los LEDs
    -- de la NIC). Orden: esperar el bus, escribir el brillo y solo entonces arrancar DMS.
    hl.exec_cmd(waitForDdcBus()
        .. "timeout 15 sh -c " .. shellQuote(brightnessScript())
        .. "; " .. dmsDdcSelfCheck()
        .. "exec dms run")

    -- El fondo se relanza en cada recarga; wallpaperStart() limpia antes.
    wallpaperStart()
    gameModeStart()

    -- Apps con workspace destino. CIDER y BTop los lanza special-layout.sh dentro del
    -- espacio `special`, que también fija la geometría del mosaico.
    hl.exec_cmd("copyq",  { workspace = "5 silent" })
    -- ksnip no está instalado.
    -- hl.exec_cmd("ksnip", { workspace = "5 silent" })
    hl.exec_cmd("corectrl", { workspace = "5 silent" })
    -- megasync no está instalado.
    -- hl.exec_cmd("megasync", { workspace = "6 silent" })

    -- Apps locales, con retardo en bash para que un reload no cancele nada.
    delayedCommand(3, dispatchCommand(editor, "1 silent"))
    delayedCommand(5, dispatchCommand(files, "3 silent"))

    -- Espera de red con tope de 60 s; sin red se lanza igual.
    -- Steam y ZapZap tienen su propio script con su propia espera.
    local networkStart =
        "timeout 60s bash -c 'until ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; do sleep 1; done'; "
        .. dispatchCommand(browser, "2 silent")
    hl.exec_cmd("bash -c " .. shellQuote(networkStart))

    -- Steam: steam-open.sh espera internet real (HTTPS), no solo ICMP.
    -- El `workspace` del exec no basta (la ventana la crea steamwebhelper); la garantía
    -- es la regla steam-ws1. Solo en hyprland.start, o cada guardado lo relanzaría.
    hl.exec_cmd(scriptsDir .. "steam-open.sh", { workspace = "1 silent" })

    hl.exec_cmd("bash -c \"sleep 10; rclone mount 'koofr:/koofr/Autosync' /home/n30/Autosync/ --vfs-cache-mode full &\"")
    -- El brillo no se lanza aquí: va encadenado antes de DMS (ver arriba).

    -- Scripts varios
    hl.exec_cmd(scriptsDir .. "mangohud-song.sh")
    hl.exec_cmd(scriptsDir .. "genymotion-open.sh")
    hl.exec_cmd("env CHATGPT_PET_WIDTH=320 CHATGPT_PET_HEIGHT=320 " .. scriptsDir .. "chatgpt-open")
    -- OpenPets sin argumentos: --ozone-platform=x11 da «bad option» y con
    -- ELECTRON_RUN_AS_NODE=1 el binario se comporta como Node. La mascota por defecto
    -- está fijada en ~/.config/@open-pets/desktop/openpets-state.json.
    hl.exec_cmd("/opt/OpenPets/openpets")

    -- Diseño del espacio `special` (NvTop+BTop / ZapZap / CIDER): orden y geometría.
    hl.exec_cmd(scriptsDir .. "special-layout.sh")

    -- KTimer: tarea ya configurada (75 s, bucle, una instancia, script de ronda) pero
    -- parada. No tiene CLI, así que se preconfigura ~/.config/ktimerrc.
    -- `State` refleja cómo se cerró la tarea, así que se fuerza State=0 antes de lanzar;
    -- si no, arrancaría contando. `pgrep` evita la segunda instancia (KDBusService usa
    -- Multiple, y el OneInstance del fichero es sobre no solapar el comando).
    
    -- hl.exec_cmd("sed -i 's/^State=.*/State=0/' ~/.config/ktimerrc 2>/dev/null; "
    --    .. "pgrep -x ktimer >/dev/null 2>&1 || ktimer", { workspace = "2 silent" })

    -- DSH en el 1: arranca `dsh web` y abre Chrome; la regla dsh-web-ws1 garantiza el
    -- escritorio cuando la ventana ya existía.
    hl.exec_cmd(scriptsDir .. "dsh-chrome-open.sh", { workspace = "1 silent" })

    -- WorkBuddy AI en el 2, con la regla workbuddy-ws2 como garantía. Se lanza con el
    -- mismo start.sh que su .desktop, que fija el app_id.
    hl.exec_cmd("/opt/workbuddy-international/start.sh", { workspace = "2 silent" })

    hl.dispatch(hl.dsp.focus({ workspace = 2 }))
end)

hl.on("config.reloaded", function()
    wallpaperStart()
    gameModeStart()
end)

-- ==================
-- ZOOM DEL CURSOR
-- ==================
-- Estado nativo en Lua, sin hyprctl + jq por pulsación.
local function zoomBy(factor)
    local v = tonumber(hl.get_config("cursor.zoom_factor")) or 1
    local nv = v * factor
    if nv < 1 then nv = 1 end
    hl.config({ cursor = { zoom_factor = nv } })
end
local function zoomReset()
    hl.config({ cursor = { zoom_factor = 1 } })
end

-- ==================
-- KEYBINDS
-- ==================
-- === wallpaper
hl.bind("SUPER + W", hl.dsp.exec_cmd("skwd-wall-v2"))

-- === Application Launchers ===
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(term))
-- SUPER+Space: emojis en DMS Spotlight (toggleQuery cierra al repetir; `:e` activa
-- el plugin emojiLauncher).
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("dms ipc call spotlight toggleQuery ':e'"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))
-- VRR a demanda: la config lo deja en 0 porque el OLED parpadea con el activo.
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(scriptsDir .. "vrr-toggle.sh"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("dms ipc call notepad toggle"))
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("dms ipc call dankdash wallpaper"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("dms ipc call bar toggle index 0"))
hl.bind(mainMod .. " + CTRL + Return", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))

-- === Cheat sheet ===
hl.bind(mainMod .. " + SHIFT + Slash", hl.dsp.exec_cmd("dms ipc call keybinds toggle hyprland"))

-- === Security ===
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("dms ipc call lock lock"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(scriptsDir .. "screenlock.sh"))  -- n30.conf pisaba el movefocus
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())  -- sin confirmación

-- Ctrl+Alt+Del: decisión explícita -> processlist (antes reboot)
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))

-- === Screenshots ===
hl.bind("Print", hl.dsp.exec_cmd("dms screenshot"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("dms screenshot full"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("dms screenshot window"))
hl.bind("Shift_R", hl.dsp.exec_cmd("dms screenshot region --filename ss_$(date +%Y-%m-%d_%H-%M_%S)_garuda.png")) -- Shift_R ES la tecla, sin modificador
hl.bind("CTRL + Shift_R", hl.dsp.exec_cmd("dms screenshot full"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("pkill -SIGUSR1 scran"))

-- === Audio (RME) ===
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptsDir .. "rme-volume up"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptsDir .. "rme-volume down"), { repeating = true })
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(scriptsDir .. "rme-volume up5"))
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd(scriptsDir .. "rme-volume down5"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scriptsDir .. "rme-volume mute"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("dms ipc call audio micmute"), { locked = true })
hl.bind("Caps_Lock", hl.dsp.exec_cmd(scriptsDir .. "swayosd-on-demand --caps-lock"), { release = true })

-- === Dictado (voz a texto) ===
-- SUPER+D alterna: un toque graba, el siguiente transcribe y pega en la ventana activa.
-- Es toggle y no push-to-talk porque en Wayland se pierde el evento de soltado.
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(scriptsDir .. "dictado/dictado.sh toggle"),
    { description = "Dictado: grabar / transcribir" })

-- === Dictado: repegar la última transcripción ===
-- SUPER+SHIFT+D vuelve a pegar el último texto, útil si salió en la ventana equivocada.
-- El historial (30 entradas) lo lleva dictado.sh en ~/.local/share/dictado/historial.txt.
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd(scriptsDir .. "dictado/dictado.sh repegar"),
    { description = "Dictado: repegar la última transcripción" })

-- === Dictado (hyprwhspr) ===
-- hyprwhspr usa el compositor (use_hypr_bindings), y el bind que instala en
-- bindings.conf nunca se carga: ese fichero no existe en esta config.
hl.bind(mainMod .. " + ALT + D",
    hl.dsp.exec_cmd("/usr/lib/hyprwhspr/config/hyprland/hyprwhspr-tray.sh record"),
    { description = "Dictado hyprwhspr: grabar / transcribir" })

-- === Brightness ===
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment 5 \"\""), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 5 \"\""), { repeating = true, locked = true })

-- === Calculadora ===
-- La tecla emite KEY_CALC (evdev 140) -> XF86Calculator en latam.
-- Kalk no es single-instance: cada pulsación abre una ventana nueva.
hl.bind("XF86Calculator", hl.dsp.exec_cmd("kalk"))

-- === Transporte multimedia (MPRIS) ===
-- El receptor principal no anuncia PREVIOUSSONG; esa tecla llega por el teclado virtual
-- de Solaar, que no desvía nada (no hay doble disparo).
-- Sin `repeating`: cada pulsación lanza un script. Con `locked` funciona bloqueado.
-- Va por media-keys-control.sh porque playerctl sin -p elige «el primero» al azar.
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(scriptsDir .. "media-keys-control.sh play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(scriptsDir .. "media-keys-control.sh play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(scriptsDir .. "media-keys-control.sh next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(scriptsDir .. "media-keys-control.sh previous"),   { locked = true })
hl.bind("XF86AudioStop",  hl.dsp.exec_cmd(scriptsDir .. "media-keys-control.sh stop"),       { locked = true })

-- Monitor externo (ddccontrol + filtro de luz azul), en release.
-- F1 = noche (brillo 10 % + filtro), F2 = día (100 % + sin filtro). Cada tecla fija su
-- estado; antes las dos hacían toggle del mismo filtro.
-- El shader es el .glsl plano de ~/.config/hypr/shaders: el del sistema es una plantilla
-- mustache y falla sin python-chevron.
hl.bind(mainMod .. " + Control_R + F1",
    hl.dsp.exec_cmd("ddccontrol -r 0x10 -w 10 dev:/dev/i2c-8 && " .. scriptsDir .. "swayosd-on-demand --brightness lower && hyprshade on blue-light-filter"),
    { release = true })
hl.bind(mainMod .. " + Control_R + F2",
    hl.dsp.exec_cmd("ddccontrol -r 0x10 -w 100 dev:/dev/i2c-8 && " .. scriptsDir .. "swayosd-on-demand --brightness raise && hyprshade off"),
    { release = true })

-- === Window Management ===
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))          -- antes fullscreen 1
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" })) -- antes fullscreen 0
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
-- Ctrl+Tab dentro del grupo, sin robarle la tecla a las apps.
-- Un bind normal consume la tecla siempre; aquí se intenta el despacho y, si falla
-- (la ventana no está en un grupo), `pass` devuelve el evento real a la ventana activa.
-- `pass` reenvía el evento capturado, no uno sintético, así que Chromium ve el Ctrl real.
-- Alternativa descartada: auto_consuming depende de que el handler Lua traduzca el fallo.
local function pestanaEnGrupo(direccion)
    return function()
        local r
        if direccion == "siguiente" then
            r = hl.dispatch(hl.dsp.group.next())
        else
            r = hl.dispatch(hl.dsp.group.prev())
        end
        if not (r and r.ok) then
            hl.dispatch(hl.dsp.pass({ window = "activewindow" }))
        end
    end
end
hl.bind("CTRL + Tab", pestanaEnGrupo("siguiente"))
hl.bind("CTRL + SHIFT + Tab", pestanaEnGrupo("anterior"))

-- === Focus Navigation ===
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
-- (mainMod+L lo ocupa screenlock.sh)

-- === Window Movement ===
hl.bind(mainMod .. " + SHIFT + CTRL + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + CTRL + down", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + CTRL + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + CTRL + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + CTRL + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

-- === Column Navigation ===
hl.bind(mainMod .. " + Home", hl.dsp.focus({ window = "first" }))
hl.bind(mainMod .. " + End", hl.dsp.focus({ window = "last" }))

-- === Monitor Navigation ===
-- Mueve el FOCO a otro monitor; con uno solo no hace nada.
-- SUPER+CTRL+↑/↓ son de Move to Workspace, y left/right del cambio de escritorio.
hl.bind(mainMod .. " + CTRL + H", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.focus({ monitor = "d" }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.focus({ monitor = "u" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.focus({ monitor = "r" }))

-- === Move to Monitor ===
-- Las de dirección chocaban con Window Movement; solo quedan K/L (arriba/derecha).
-- hl.bind(mainMod .. " + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "l" }))
-- hl.bind(mainMod .. " + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "d" }))
-- hl.bind(mainMod .. " + SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "u" }))
-- hl.bind(mainMod .. " + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "u" }))
hl.bind(mainMod .. " + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "r" }))

-- === Workspace Navigation ===
hl.bind(mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + U", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + I", hl.dsp.focus({ workspace = "e-1" }))
-- left/right con sonido
hl.bind(mainMod .. " + CTRL + left", function()
    hl.dispatch(hl.dsp.focus({ workspace = "e-1" }))
    hl.exec_cmd("play -v 0.1 \"" .. soundsDir .. "gravity/change_workspace.wav\"")
end)
hl.bind(mainMod .. " + CTRL + right", function()
    hl.dispatch(hl.dsp.focus({ workspace = "e+1" }))
    hl.exec_cmd("play -v 0.1 \"" .. soundsDir .. "gravity/change_workspace.wav\"")
end)
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
-- mouse_up es zoom-out; ver sección zoom

-- === Move to Workspace ===
-- Mueve la ventana activa y te lleva con ella (follow por defecto).
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + I", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + mouse_down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mainMod .. " + CTRL + mouse_up", hl.dsp.window.move({ workspace = "e-1" }))

-- === Numbered Workspaces ===
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    hl.bind("ALT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end
hl.bind("ALT + 0", hl.dsp.window.move({ workspace = 10, follow = false }))
hl.bind("ALT + bar", hl.dsp.window.move({ workspace = "special", follow = false }))

-- === Column Management ===
hl.bind(mainMod .. " + bracketleft", hl.dsp.layout("preselect l"))
hl.bind(mainMod .. " + bracketright", hl.dsp.layout("preselect r"))
hl.bind(mainMod .. " + R", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + CTRL + F", function() -- antes: resizeactive exact 100%
    local m = hl.get_active_monitor()
    local w = m and (m.width or m.widthInPixels or m.pixelWidth)
    if w then
        hl.dispatch(hl.dsp.window.resize({ x = w, y = 0, exact = true }))
    end
end)

-- === Sizing ===
-- 100 px por pulsación, con repetición (binde en el .conf).
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })

-- === Mouse: mover/redimensionar ===
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })
hl.bind(mainMod .. " + code:20", hl.dsp.window.resize({ x = -100, y = 0, relative = true }),
    { drag = true, description = "Expand window left" })
hl.bind(mainMod .. " + code:21", hl.dsp.window.resize({ x = 100, y = 0, relative = true }),
    { drag = true, description = "Shrink window left" })

-- === Zoom del cursor ===
hl.bind(mainMod .. " + mouse_up", function() zoomBy(0.9) end)
hl.bind(mainMod .. " + equal", function() zoomBy(1.1) end)
hl.bind(mainMod .. " + minus", function() zoomBy(0.9) end)
hl.bind(mainMod .. " + KP_ADD", function() zoomBy(1.1) end)
hl.bind(mainMod .. " + KP_SUBTRACT", function() zoomBy(0.9) end)
hl.bind(mainMod .. " + SHIFT + mouse_up", zoomReset)
hl.bind(mainMod .. " + SHIFT + mouse_down", zoomReset)
hl.bind(mainMod .. " + SHIFT + minus", zoomReset)
hl.bind(mainMod .. " + SHIFT + KP_SUBTRACT", zoomReset)
hl.bind(mainMod .. " + SHIFT + 0", zoomReset)

-- === ALT+Tab ===
hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)

-- === Pass (Awakened PoE Trade) ===
hl.bind("SHIFT + space", hl.dsp.pass({ window = "class:^(awakened-poe-trade)$" }))
hl.bind("CTRL + ALT + D", hl.dsp.pass({ window = "class:^(awakened-poe-trade)$" }))

-- === Sistema ===
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.dpms({ action = "toggle" }))
hl.bind(mainMod .. " + CTRL + ALT + W", hl.dsp.exec_cmd("skwd-paper-v2 stop"))
hl.bind(mainMod .. " + CTRL + ALT + A", hl.dsp.exec_cmd("pkill -9 -i -f \"ArkAscended|ShooterGame\""))
-- === Espacio especial con la tecla Super sola ===
-- Se escribe explícito (Super como mod + Super_L como tecla), al soltar.
hl.bind(mainMod .. " + SUPER_L", hl.dsp.workspace.toggle_special("special"), { release = true })

-- ==================
-- MACRO: STALKER 2 — guardado rápido (F5) con el botón lateral inferior
-- ==================
-- El botón emite BTN_SIDE (evdev 275). Hyprland sintetiza un F5 real, sin ydotool.
-- No toca el Fn-lock: la tecla Fn nunca llega al SO.
-- Dentro del juego se consume el botón (si no, cambia de munición) y se inyecta F5;
-- fuera se devuelve con `pass` para que siga siendo «Atrás».
-- `mods` es obligatorio en send_shortcut: cadena para stringToModMask, "" = ninguno.
local STALKER_TITLE = "S.T.A.L.K.E.R." -- texto literal, no patrón Lua

-- Bajo gamescope la clase es "gamescope" y el nombre va en el title; sin gamescope,
-- la clase sería steam_app_1643320. Se aceptan ambas.
-- `send_shortcut` resuelve el selector con la API de ventanas: hay que pasarle una CADENA.
local function selectorStalker2(w)
    if not w then return nil end
    if w.class == "gamescope" then
        if tostring(w.title):find(STALKER_TITLE, 1, true) then
            return "class:^(gamescope)$"
        end
        return nil
    end
    if w.class == "steam_app_1643320" then
        return "class:^(steam_app_1643320)$"
    end
    return nil
end

hl.bind("mouse:275", function()
    local w = hl.get_active_window()
    if not w then return end

    local sel = selectorStalker2(w)
    if sel then
        hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "F5", window = sel }))
    else
        -- `pass` exige que el selector resuelva; sin ventana activa lanza
        -- «hl.pass: window not found», de ahí el `if not w then return end`.
        hl.dispatch(hl.dsp.pass({ window = "activewindow" }))
    end
end, {
    -- SIN `non_consuming`: ese flag reenviaba el botón al juego y cambiaba munición.
    description = "STALKER 2: guardado rápido (F5)",
})

-- ==================
-- WINDOW RULES
-- ==================
-- Se evalúan de arriba abajo; gana la última coincidencia.

-- Dimming global de inactivas no flotantes. Excluye zen, y debe ir antes de las reglas
-- de apps: la última coincidencia gana y las específicas pisan esto.
hl.window_rule({
    name = "global-inactive-opacity",
    match = { class = "negative:^(zen)$", float = false, focus = false },
    opacity = "0.9 0.9",
})

-- `override` fija el valor exacto en vez de multiplicarlo por decoration:active/inactive_opacity.
-- Sin él, 0.8 sobre el 0.9 global daría 0.72.
hl.window_rule({ name = "workbuddy-opacity", match = { class = "^(WorkBuddy AI)$" }, opacity = "0.8 override 0.7 override" })

-- La app es Codex pero su clase es "Chatgpt"; float=false la limita a la ventana principal
-- (la mascota comparte clase y va flotante).
-- Steam: solo el cliente; los juegos tienen su propia regla.
hl.window_rule({ name = "codex-opacity", match = { class = "^(Chatgpt)$", float = false }, opacity = "0.8 override 0.7 override" })
hl.window_rule({ name = "steam-opacity", match = { class = "^(steam)$" }, opacity = "0.8 override 0.7 override" })

-- Terminales
hl.window_rule({ name = "wezterm-borderless", match = { class = "^(org\\.wezfurlong\\.wezterm)$" }, tile = true, border_size = 0 })
hl.window_rule({ name = "alacritty-borderless", match = { class = "^(Alacritty)$" }, border_size = 0 })
hl.window_rule({ name = "kitty", match = { class = "^(kitty)$" }, border_size = 0, opacity = "0.85 0.85" })
hl.window_rule({ name = "ghostty", match = { class = "^(com\\.mitchellh\\.ghostty)$" }, border_size = 0, opacity = "0.80" })

-- GNOME
hl.window_rule({ name = "gnome-rounding", match = { class = "^(org\\.gnome\\.)" }, rounding = 12, border_size = 0 })
hl.window_rule({ name = "gnome-control-tile", match = { class = "^(gnome-control-center)$" }, tile = true })
hl.window_rule({ name = "gnome-calculator-float", match = { class = "^(org\\.gnome\\.Calculator)$" },
    float = true, opacity = "0.40 0.20", size = { 700, 380 }, move = { 990, 990 } })
hl.window_rule({ name = "nautilus-float", match = { class = "^(org\\.gnome\\.Nautilus)$" }, float = true })

-- Calculadoras y utilidades
hl.window_rule({ name = "calculator-dim", match = { class = "^Calculator$" }, opacity = "0.6 0.1" })
hl.window_rule({ name = "kalk-opacity", match = { class = "^kalk$" }, opacity = "0.35 0.25" })
hl.window_rule({ name = "kalk-float", match = { class = "^(org\\.kde\\.kalk.*)$" }, float = true, size = { 150, 276 }, move = { 2141, 121 } })
hl.window_rule({ name = "galculator-float", match = { class = "^(galculator)$" }, float = true })
hl.window_rule({ name = "blueman-float", match = { class = "^(blueman-manager)$" }, float = true })
hl.window_rule({ name = "xdg-portal-float", match = { class = "^(xdg-desktop-portal)$" }, float = true })
hl.window_rule({ name = "hyprland-dialog-float", match = { class = "^(hyprland-dialog)$" }, float = true, move = { 2900, 60 } })
hl.window_rule({ name = "kde-dolphin-dim", match = { class = "^(org\\.kde\\.dolphin)$" }, opacity = "0.75 0.75" })
hl.window_rule({ name = "dolphin-conflict-dialog", match = { class = "^(org\\.kde\\.dolphin)$", title = "^(Ya existe como carpeta — Dolphin)$" },
    float = true, move = { 1450, 476 } })
hl.window_rule({ name = "thunar-dim", match = { class = "^Thunar$" }, opacity = "0.70 0.70" })
hl.window_rule({ name = "thunar-rename-dialog", match = { class = "^(Thunar)$", title = "^(Renombrar.*|Bulk Rename.*)$" },
    float = true, center = true, size = { 700, 300 } })

-- Navegadores
-- zen y los juegos de steam quedan opacos: `1.0 override` aquí y la exclusión
-- negative:^(zen)$ de la regla global.
hl.window_rule({ name = "zen-opaque", match = { class = "^(zen)$" }, border_size = 0, opacity = "1.0 override 1.0 override" })
hl.window_rule({ name = "chromium-bar", match = { class = "^Chromium-browser$" }, float = true, pin = true,
    move = { 2159, -8 }, border_size = 0, opacity = "0.95 0.95", rounding = 20, size = { 625, 56 } }) -- rounding 40: fuera del máximo (20)
hl.window_rule({ name = "pip-float", match = { title = "^(Picture-in-Picture)$" },
    float = true, pin = true, move = { 0, 885 }, size = { 982, 553 } })

-- DSH al 1 y WorkBuddy al 2.
-- La clase de DSH en modo app es chrome-127.0.0.1__-Default; si cambia el puerto o el
-- perfil, la regla deja de casar en silencio. El `workspace` del exec no basta cuando la
-- ventana la crea un proceso ya existente; la regla se aplica al crearla.
hl.window_rule({ name = "dsh-web-ws1", match = { class = "^(chrome-127\\.0\\.0\\.1.*-Default)$" }, workspace = "1 silent" })
hl.window_rule({ name = "workbuddy-ws2", match = { class = "^(WorkBuddy AI)$" }, workspace = "2 silent" })

-- El editor al 1. Su clase real es com.microsoft.VSCode (visual-studio-code-bin), no "code".
-- Efecto secundario: cualquier ventana del editor va al 1, también abierta a mano.
hl.window_rule({ name = "editor-ws1", match = { class = "^(com\\.microsoft\\.VSCode)$" }, workspace = "1 silent" })

-- Timer JWA: RETIRADO el 2026-10-03. El timer es ahora una capa de Quickshell
-- (jwa-timer.qml): una capa no tiene clase, así que `class = ...` no puede casarla y la
-- regla quedó inerte. Se conserva comentada por si se vuelve a Chromium.
-- OJO: no hay regla de opacidad para capas. hl.layer_rule no tiene `opacity` (solo
-- no_anim, blur, blur_popups, ignore_alpha, dim_around, xray, animation, order,
-- above_lock, no_screen_share); la opacidad 0.70 vive en el QML.
-- Con Chromium, `override` aquí mataba el color del número (salía gris): usar 0.50 0.40.
--
-- hl.window_rule({
--     name = "jwa-timer",
--     match = { class = "^(chrome-__home_n30_Proyectos_jwa-timer_jwa-timer\\.html-Default)$" },
--     float = true,
--     size = { 120, 120 },
--     move = { 60, 60 },
--     border_size = 0,
--     rounding = 0,
--     no_shadow = true,
--     no_initial_focus = true,
--     opacity = "0.50 0.40",
-- })

-- Mensajería / multimedia
hl.window_rule({ name = "wasistlos", match = { class = "^(wasistlos)$" }, opacity = "0.75 0.65", workspace = "1 silent" })
hl.window_rule({ name = "whatsapp-for-linux", match = { class = "^whatsapp-for-linux$" }, opacity = "0.70 0.50" })
hl.window_rule({ name = "whatsie", match = { class = "^whatsie$" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "whatsapp-nativefier", match = { class = "^whatsapp-nativefier$" }, opacity = "0.85 0.85" })
hl.window_rule({ name = "zapzap", match = { class = "^com\\.rtosta\\.zapzap$" }, opacity = "0.85 0.15" })
hl.window_rule({ name = "discord-dim", match = { class = "^discord$" }, opacity = "0.85 0.85" })
hl.window_rule({ name = "cider-dim", match = { class = "^(cider)$" }, opacity = "0.79 0.75" })

-- Espacio `special`: special-layout.sh decide orden y geometría; estas reglas solo
-- garantizan el destino cuando la ventana la crea un proceso hijo (cider es Electron).
hl.window_rule({ name = "layout-cider-special",  match = { class = "^(cider)$" },                workspace = "special silent" })
hl.window_rule({ name = "layout-zapzap-special", match = { class = "^com\\.rtosta\\.zapzap$" }, workspace = "special silent" })
-- BTop tiene clase propia (btop): se le replican los efectos de kitty.
hl.window_rule({ name = "layout-btop-special",   match = { class = "^(btop)$" },                 workspace = "special silent", border_size = 0, opacity = "0.85 0.85" })
hl.window_rule({ name = "layout-nvtop-special",  match = { class = "^(nvtop-fluid)$" },          workspace = "special silent" })
hl.window_rule({ name = "tidal-dim", match = { class = "^tidal-hifi$" }, opacity = "0.50 0.50" })
hl.window_rule({ name = "spotify-dim", match = { class = "^Spotify$" }, opacity = "0.95 0.85" })

-- Herramientas
hl.window_rule({ name = "easyeffects-dim", match = { class = "^easyeffects$" }, opacity = "0.55 0.55" })
hl.window_rule({ name = "pavucontrol-tile", match = { class = "^(pavucontrol)$" }, tile = true })
hl.window_rule({ name = "pavucontrol-dim", match = { class = "^pavucontrol$" }, opacity = "0.90 0.90" })
hl.window_rule({ name = "nm-connection-tile", match = { class = "^(nm-connection-editor)$" }, tile = true })
hl.window_rule({ name = "ktimer-dim", match = { class = "^org.kde.ktimer$" }, opacity = "0.45 0.13" })
hl.window_rule({ name = "ktimer-pos", match = { class = "^org\\.kde\\.ktimer$" },
    workspace = "2 silent", float = true, move = { -540, -184 } })
hl.window_rule({ name = "konsole-dim", match = { class = "^konsole$" }, opacity = "0.25 0.11" })
hl.window_rule({ name = "qdirstat-dim", match = { class = "^qdirstat$" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "qbittorrent-dim-1", match = { class = "^qBittorrent$" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "qbittorrent-dim-2", match = { class = "^org\\.qbittorrent\\.qBittorrent$" }, opacity = "0.80 0.80" })
hl.window_rule({ name = "megasync-dim", match = { class = "^(nz\\.co\\.mega\\.megasync)$" }, opacity = "0.35 0.35" }) -- fusionada (antes x3)
hl.window_rule({ name = "megasync-x11-dim", match = { class = "^(MEGAsync)$" }, opacity = "0.80 0.70" })
hl.window_rule({ name = "luna-dim", match = { class = "^luna$" }, opacity = "0.80 0.80" })
-- EDITOR: la clase real es com.microsoft.VSCode, no "code". Sin `override` estas cifras
-- multiplican la opacidad global, no la fijan.
hl.window_rule({ name = "editor-dim", match = { class = "^(com\\.microsoft\\.VSCode)$" }, opacity = "0.70 0.70" })
-- hl.window_rule({ name = "code-dim", match = { class = "^code$" }, opacity = "0.90 0.75" }) -- superseded por editor-dim
-- code-translucent: su clase puede ser "code-oss" o "Code"; no verificado con ventana.
hl.window_rule({ name = "code-oss-dim", match = { class = "^(code-oss|Code)$" }, opacity = "0.80 0.70" })
-- ===========================================================================
-- Efecto de entrada de la ventana de Safe Eyes
-- ===========================================================================
-- Solo UNA opción activa: dos reglas con el mismo nombre se aplican las dos en silencio.
-- La curva y la velocidad son globales (leaf windowsIn); el estilo no se valida, uno
-- inexistente no anima.
-- Activa: slide right desde el borde derecho.
hl.window_rule({ name = "safeeyes", match = { class = "^io\\.github\\.slgobinath\\.SafeEyes$" }, float = true, pin = true,
    move = { 1444, -11 }, border_size = 0, opacity = "0.75 override 0.75 override", rounding = 20, size = { 600, 180 },
    animation = "slide right" }) -- rounding 40: fuera del máximo (20)

-- Opción 1: popin + resorte (global: cambia windowsIn). El campo es `dampening`, no `damping`.
-- hl.curve("rebote", { type = "spring", mass = 1, stiffness = 300, dampening = 7 })
-- hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, spring = "rebote", style = "popin 20%" })
-- hl.window_rule({ name = "safeeyes", match = { class = "^io\\.github\\.slgobinath\\.SafeEyes$" }, float = true, pin = true,
--     move = { 1444, -11 }, border_size = 0, opacity = "0.75 override 0.75 override", rounding = 20, size = { 600, 180 },
--     animation = "popin 20%" })

-- Opción 3: popin 30% + dim_around (oscurece el resto mientras está abierta).
-- hl.window_rule({ name = "safeeyes", match = { class = "^io\\.github\\.slgobinath\\.SafeEyes$" }, float = true, pin = true,
--     move = { 1444, -11 }, border_size = 0, opacity = "0.75 override 0.75 override", rounding = 20, size = { 600, 180 },
--     animation = "popin 30%", dim_around = true })

-- Opción 4: gnomed + crazyshot (global: cambia el rebote de todo el escritorio).
-- hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "crazyshot", style = "gnomed" })
-- hl.window_rule({ name = "safeeyes", match = { class = "^io\\.github\\.slgobinath\\.SafeEyes$" }, float = true, pin = true,
--     move = { 1444, -11 }, border_size = 0, opacity = "0.75 override 0.75 override", rounding = 20, size = { 600, 180 },
--     animation = "gnomed" })

-- Opción 5: no_anim + script por socket (el script no existe; sin él equivale a no_anim).
-- hl.window_rule({ name = "safeeyes", match = { class = "^io\\.github\\.slgobinath\\.SafeEyes$" }, float = true, pin = true,
--     move = { 1444, -11 }, border_size = 0, opacity = "0.75 override 0.75 override", rounding = 20, size = { 600, 180 },
--     no_anim = true })
hl.window_rule({ name = "rofi-dim", match = { class = "^([Rr]ofi)$" }, opacity = "0.9 0.6" })
hl.window_rule({ name = "satty", match = { class = "^com\\.gabm\\.satty$" },
    float = true, center = true, pin = true, size = { "70%", "70%" } })
hl.window_rule({ name = "dotfiles-floating", match = { class = "^dotfiles-floating$" }, move = { 2, 738 } })
-- Ventana de promociones de Steam: va por TÍTULO porque su clase no está medida.
hl.window_rule({ name = "special-offers", match = { title = "^(.*Special Offers:.*)$" },
    workspace = "1 silent", move = { 937, 60 } })
hl.window_rule({ name = "float-by-title", match = { title = "(Extensi.*|.*Bitwarden.*|Open File)" }, float = true })
hl.window_rule({ name = "bitwarden-panel", match = { title = "^(.*Bitwarden.*)$" }, size = { 420, 698 }, move = { 2345, 49 } })

-- dynisland (zen y steam_app_2399830 ya están cubiertos arriba)
hl.window_rule({ name = "dynisland-borderless", match = { class = "^(dynisland|dynisland-daemon)$" }, border_size = 0 })
hl.window_rule({ name = "dynisland-position", match = { class = "^dynisland$" }, move = { 3345, 49 } })

-- Genymotion
hl.window_rule({ name = "genymotion-dim", match = { title = "^(Genymotion)$" }, opacity = "0.35 0.35" })
-- Panel GPS a 466x306: solo el mapa, sin cabecera, y un cuarto del botón.
-- La app declara min = max = 520x948 (WM_NORMAL_HINTS), así que min_size/max_size
-- sustituyen esos límites. El botón está clavado en coordenadas de ventana
-- (448..483, 288..323) y no reflowa: el tamaño es una resta, 448+18 x 288+18.
-- y = -202 oculta la cabecera (mide 130 px); lo eligió n30 a mano.
-- Para la ventana entera abajo a la derecha: move = { 2960, 1110 }.
hl.window_rule({ name = "genymotion-gps", match = { title = "^(GPS - Genymotion)$" },
    float = true, size = { 466, 306 }, move = { 887, -202 }, opacity = "0.55 0.05",
    min_size = { 466, 306 }, max_size = { 466, 306 } })

-- Mascota de ChatGPT
hl.window_rule({
    name = "chatgpt-pet",
    match = { class = "^(Chatgpt)$", title = "^(ChatGPT)$", xwayland = true, float = true },
    pin = true,
    size = { 333, 333 },
    min_size = { 320, 320 },
    max_size = { 320, 320 },
    -- x = 3440 - 320 (ancho efectivo por max_size) - 24 de margen
    move = { 3096, 1016 },
    suppress_event = "x11configurerequest",
    no_initial_focus = true,
    border_size = 0,
    rounding = 0,
    no_shadow = true,
    no_blur = true,
    opacity = "0.9 override 0.8 override",
})

-- CoreCtrl
hl.window_rule({
    name = "corectrl",
    match = { class = "^(org\\.corectrl\\.CoreCtrl)$" },
    float = true,
    size = { 710, 910 },
    move = { 2720, 520 },
    workspace = "5 silent",
    opacity = "0.55 0.35",
})

-- Steam al 1. La ventana la crea steamwebhelper, así que el `workspace` del exec no la
-- alcanza; la regla se aplica al crear. `negative:^(notificationtoasts)` deja los avisos
-- donde estés, y `silent` no cambia la vista.
hl.window_rule({
    name  = "steam-ws1",
    match = { class = "^(steam)$", title = "negative:^(notificationtoasts)" },
    workspace = "1 silent",
})

-- Steam
-- Cliente: tile (n30.conf ganaba al float de hyprland.conf)
hl.window_rule({ name = "steam-client-tiled", match = { class = "^(steam)$" }, tile = true })

-- Juegos de steam: opacos con `override` y sin blur.
hl.window_rule({
    name = "steam-games",
    match = { class = "^(steam_app.*)$" },
    float = true,
    fullscreen = true,
    border_size = 0,
    opacity = "1.0 override 1.0 override",
    immediate = true,
    no_blur = true,
    no_shadow = true,
    no_initial_focus = true,
})

-- Ark Survival Ascended
hl.window_rule({
    name = "ark-survival-ascended",
    match = { class = "^(steam_app_2399830)$" },
    immediate = true,
    fullscreen = true,
    stay_focused = true,
    min_size = { 1, 1 },
})

-- Juegos bajo gamescope: la clase es "gamescope" y el nombre va en el title, así que
-- steam-games no los cubría y quedaban sin fullscreen (el puntero alcanzaba las esquinas).
hl.window_rule({
    name = "gamescope-games",
    match = { class = "^(gamescope)$" },
    float = true,
    fullscreen = true,
    border_size = 0,
    opacity = "1.0 override 1.0 override",
    immediate = true,
    no_blur = true,
    no_shadow = true,
    no_initial_focus = true,
})

-- Awakened PoE Trade
hl.window_rule({
    name = "awakened-poe-trade",
    match = { class = "^awakened-poe-trade$" },
    float = true,
    no_blur = true,
    no_shadow = true,
    border_size = 0,
})

-- DMS / quickshell
hl.window_rule({ name = "dms-shell-float", match = { class = "^(org\\.quickshell)$" }, float = true })

-- ==================
-- LAYER RULES
-- ==================
hl.layer_rule({ name = "quickshell-noanim", match = { namespace = "^(quickshell)$" }, no_anim = true })

-- hyprpm
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpm reload");
end);
if hl.plugin.hyprliquid then
    hl.config(
    {
        plugin =
        {
            hyprliquid =
            {
                watch_system_color_scheme = true,
                background_sharing = true
            }
        }
    });

    hl.window_rule(
    {
        name = "kitty",
        match = { class = "kitty" },
        border_size = 0,
        no_blur = true,
        no_shadow = true,
        ["hyprliquid:rounding_lua"] = 64,
        ["hyprliquid:effect"] = "liquid_glass",
        ["hyprliquid:tint_color"] = "rgba(0x1a, 0x1b, 0x26, 0.5)",
        ["hyprliquid:highlight_style"] = 2,
        ["hyprliquid:glass_dispersion"] = true
    });

    hl.window_rule(
    {
        name = "zen-browser",
        match = { class = "zen" },
        ["hyprliquid:effect"] = "acrylic_thin",
        ["hyprliquid:color_scheme"] = "follow_system"
    });

    hl.window_rule(
    {
        name = "vscode",
        match = { class = "code" },
        ["hyprliquid:effect"] = "acrylic",
        ["hyprliquid:color_scheme"] = "dark"
    });

    hl.window_rule(
    {
        name = "dolphin",
        match = { class = "org.kde.dolphin" },
        ["hyprliquid:effect"] = "mica_alt",
        ["hyprliquid:color_scheme"] = "light"
    });

    hl.layer_rule(
    {
        name = "waybar",
        match = { namespace = "waybar" },
        ["hyprliquid:effect"] = "liquid_glass",
        ["hyprliquid:corner_radius"] = 20,
        ["hyprliquid:highlight_style"] = 4,
        ["hyprliquid:vdf_map_mode"] = 1,
        ["hyprliquid:vdf_map_update_policy"] = "onchange"
    });

    hl.layer_rule(
    {
        name = "wlogout",
        match = { namespace = "logout_dialog" },
        blur = true,
        ["hyprliquid:effect"] = "liquid_glass",
        ["hyprliquid:corner_radius"] = 96,
        ["hyprliquid:highlight_style"] = 4,
        ["hyprliquid:vdf_map_mode"] = 2,
        ["hyprliquid:vdf_map_update_policy"] = "once"
    });
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- OpenPets — la mascota
-- ═══════════════════════════════════════════════════════════════════════════════
-- Mascota y Centro de Control comparten clase ("open-pets-desktop"); solo cambia el
-- título: `OpenPets — <nombre>` frente a `OpenPets — Control Center`.
-- El borde amarillo era el borde inactivo global y el "blur", el escritorio de detrás
-- difuminado: la ventana es transparente por diseño.
-- Registrar una regla no aplica todo en caliente: los efectos estáticos (float, tile,
-- move, size, pin, workspace, no_initial_focus...) solo se leen al mapear. Los demás se
-- aplican en caliente. `hyprctl reload` no re-mapea nada.

-- 1. Decoración: por clase, cubre las dos ventanas.
hl.window_rule({
    name = "openpets-sin-decoracion",
    match = { class = "^open-pets-desktop$" },
    border_size = 0,
    rounding = 0,
    no_blur = true,
    no_shadow = true,
    decorate = false
})

-- 2. Solo la mascota: flotante, fijada y sin robar el foco al aparecer.
-- `no_initial_focus`, NO `no_focus`: este último la saca del hit-test (sin eventos de
-- ratón, y el arrastre de la mascota es manual en JS). Se comprueba con
-- `hyprctl getprop <selector> no_focus`.
-- `opacity` con override porque sin él se le aplica el inactive_opacity global (0,9).
-- El override va después de cada cifra: solo cuenta la última leída.
hl.window_rule({
    name = "openpets-mascota",
    match = { class = "^open-pets-desktop$", title = "^OpenPets.*Pet$" },
    float = true,
    pin = true,
    no_initial_focus = true,
    opacity = "1 override 1 override"
})

-- 3. Menú del botón derecho: es una ventana X11 aparte, SIN clase ni título, de 321x436
-- (el panel mide 273x388 y el margen es translúcido). La banda que se veía era ese margen
-- difuminado por el blur global: ruido aleatorio por píxel y más claro que el fondo.
-- `class = "^$"` es el único asidero. no_blur es dinámico, se aplica en caliente.
hl.window_rule({
    name = "openpets-menu-sin-halo",
    match = { class = "^$" },
    no_blur = true,
    no_shadow = true,
    border_size = 0,
    rounding = 0
})
