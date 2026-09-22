#!/usr/bin/env bash
# AutoGame para Hyprland/Steam. Python estándar: JSON, /proc y recuperación segura.
# Uso: auto-game-mode.sh [--check | --status | --restore]
# Opcionales: AUTO_GAME_INTERVAL=5 AUTO_GAME_EXIT_DELAY=15 AUTO_GAME_NOTIFY=1
# Fondo de vídeo: skwd-paper-v2 se pausa con su propia CLI, que sustituye el
# renderizador de vídeo por skwd-wall-still con el fotograma congelado (CPU 0,
# imagen exacta). mpvpaper/gslapper, si aún existieran, se pausan con SIGSTOP.
# NO usar SIGSTOP con skwd-wall-vk: skwd no lo refleja en su estado y, si el
# fondo se reaplica (recarga de Hyprland), quedan dos renderizadores a la vez.
# No modifica perfiles de energía, afinidad, audio, DMS ni servicios de seguridad.
exec python3 - "$@" <<'PYTHON'
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import threading
import time

OPTIONS = ('animations:enabled', 'decoration:blur:enabled', 'decoration:shadow:enabled')
SKWD = 'skwd-paper-v2'
# Motores que se pausan por señal. skwd-wall-vk queda fuera a propósito.
WALLPAPERS = {'mpvpaper', 'gslapper'}
# Wallpaper Engine is a desktop utility, not a game.
NON_GAME_APPIDS = {b'431960'}
HELPERS = {'steam', 'steamwebhelper', 'steamservice', 'steam-runtime-l',
           'steam-runtime-s', 'pressure-vessel', 'pv-bwrap', 'bwrap',
           'wineserver', 'services.exe', 'winedevice.exe', 'explorer.exe',
           'rpcss.exe', 'plugplay.exe', 'svchost.exe', 'conhost.exe',
           'crashhandler', 'crashhandler64', 'gameoverlayui'}
PROC = Path('/proc')
UID = os.getuid()
SESSION = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
STOP = threading.Event()


def log(message):
    print(time.strftime('[AutoGame %H:%M:%S] ') + message, flush=True)


def hypr(*args):
    try:
        result = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=3)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def query(*args):
    try:
        return json.loads(hypr('-j', *args) or 'null')
    except ValueError:
        return None


def option(name):
    result = query('getoption', name)
    if not isinstance(result, dict):
        return None
    value = result.get('int')
    if value is None and isinstance(result.get('bool'), bool):
        # Hyprland 0.56 devuelve "bool" en las opciones booleanas, no "int".
        value = int(result['bool'])
    return value


def lua_literal(name, value):
    """Literal Lua anidado para hl.config: decoration:blur:enabled -> 0."""
    text = 'true' if int(value) else 'false'
    for key in reversed(name.split(':')):
        text = '{ ' + key + ' = ' + text + ' }'
    return text


def set_option(name, value):
    # Con la configuración en Lua, `hyprctl keyword` se rechaza ("keyword can't
    # work with non-legacy parsers"); `eval` con hl.config sí aplica el cambio.
    # El keyword se conserva como respaldo para configuraciones clásicas.
    if hypr('eval', 'hl.config(' + lua_literal(name, value) + ')') == 'ok':
        return True
    return hypr('keyword', name, str(value)) == 'ok'


def skwd_cli(*args, timeout=3):
    """Ejecuta skwd-paper-v2 y devuelve su campo "result", o None si no sirve.

    La CLI resuelve su sesión por XDG_RUNTIME_DIR: con otro valor atendería a
    una sesión vacía y devolvería un "ok" que no hace nada. Por eso se hereda
    el entorno de este script, que ya exige XDG_RUNTIME_DIR.
    """
    binary = shutil.which(SKWD)
    if not binary:
        return None
    try:
        result = subprocess.run([binary, *args], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    try:
        payload = json.loads(result.stdout)
    except ValueError:
        return None
    return payload.get('result') if isinstance(payload, dict) else None


def skwd_state():
    """(pausado, número de fondos) o (None, None) si skwd no responde."""
    result = skwd_cli('status')
    if not isinstance(result, dict):
        return None, None
    paused = result.get('paused')
    assignments = result.get('assignments')
    if not isinstance(paused, bool) or not isinstance(assignments, list):
        return None, None
    return paused, len(assignments)


def processes():
    for path in PROC.iterdir():
        try:
            if path.name.isdecimal() and path.stat().st_uid == UID:
                yield path
        except OSError:
            continue


def identity(path):
    # /proc/PID/stat: comm puede contener espacios o paréntesis.
    fields = (path / 'stat').read_text().rsplit(')', 1)[1].split()
    return fields[19], fields[0]  # starttime (campo 22), estado (campo 3)


def game_reasons(clients):
    found = set()
    for client in clients:
        for key in ('class', 'initialClass'):
            match = re.fullmatch(r'steam_app_([1-9][0-9]*)', client.get(key, '') or '')
            if match and match[1].encode() not in NON_GAME_APPIDS:
                found.add('ventana Steam ' + match[1])
    for path in processes():
        try:
            comm = (path / 'comm').read_text().strip()
            if comm in HELPERS or identity(path)[1] == 'Z':
                continue
            # SteamLaunch/reaper permanece durante el juego, incluso con Gamescope.
            # cmdline suele ser legible aunque Yama proteja /proc/PID/environ.
            try:
                argv = (path / 'cmdline').read_bytes().split(b'\0')
                if b'SteamLaunch' in argv:
                    for argument in argv:
                        if re.fullmatch(rb'AppId=[1-9][0-9]*', argument) and argument.split(b'=', 1)[1] not in NON_GAME_APPIDS:
                            found.add('SteamLaunch ' + argument.decode() + ' (PID ' + path.name + ')')
            except OSError:
                pass
            # Leer variables reales, nunca buscar SteamAppId en el nombre.
            env = dict(item.split(b'=', 1) for item in (path / 'environ').read_bytes().split(b'\0') if b'=' in item)
            appid = env.get(b'SteamAppId', b'0')
            gameid = env.get(b'SteamGameId', b'0')
            if any(value in NON_GAME_APPIDS for value in (appid, gameid)):
                continue
            if any(value.isdigit() and int(value) > 0 for value in (appid, gameid)):
                found.add('proceso Steam ' + path.name + ' (' + comm + ')')
        except (OSError, ValueError, IndexError):
            continue
    return sorted(found)


class Manager:
    def __init__(self, folder):
        self.path = folder / 'state.json'
        self.state = {'session': SESSION, 'options': {}, 'paused': [], 'skwd': False}
        if self.path.exists():
            self.state = json.loads(self.path.read_text())
        # Los diarios escritos antes de usar skwd no traen la clave.
        self.state.setdefault('skwd', False)

    def save(self):
        temporary = self.path.with_suffix('.tmp')
        temporary.write_text(json.dumps(self.state))
        temporary.replace(self.path)

    def pause_wallpapers(self):
        known = {(p['pid'], p['start']) for p in self.state['paused']}
        compositors = []
        for path in processes():
            try:
                name = (path / 'comm').read_text().strip()
                if name in {'Hyprland', 'niri', 'sway', 'kwin_wayland', 'gnome-shell', 'weston', 'labwc', 'wayfire'}:
                    compositors.append(name)
            except OSError:
                pass
        for path in processes():
            try:
                if (path / 'comm').read_text().strip() not in WALLPAPERS:
                    continue
                # No tocar fondos de otra sesión gráfica del mismo usuario.
                try:
                    env = (path / 'environ').read_bytes().split(b'\0')
                    if ('HYPRLAND_INSTANCE_SIGNATURE=' + SESSION).encode() not in env:
                        continue
                except PermissionError:
                    # Con una sola sesión/compositor, los fondos de este UID
                    # se pueden pausar sin necesitar permisos de depuración.
                    if compositors != ['Hyprland']:
                        continue
                start, status = identity(path)
                if status in ('T', 't', 'Z') or (int(path.name), start) in known:
                    continue
                record = {'pid': int(path.name), 'start': start}
                self.state['paused'].append(record)
                self.save()  # Registrar antes de STOP para recuperar tras una caída.
                os.kill(record['pid'], signal.SIGSTOP)
            except (ProcessLookupError, PermissionError, FileNotFoundError):
                continue

    def pause_skwd(self):
        """Congela el fondo de skwd. Sólo reclama la pausa si la causó él."""
        paused, count = skwd_state()
        if paused is None:
            return False  # skwd no responde: no se toca nada
        if not count:
            return False  # sin fondo de skwd aplicado no hay nada que congelar
        if paused:
            # Ya estaba en pausa: si no la pedimos nosotros, no se reclama.
            return bool(self.state['skwd'])
        if skwd_cli('pause') is None:
            return False
        self.state['skwd'] = True
        self.save()  # Registrar antes de seguir, para recuperar tras una caída.
        return True

    def resume_skwd(self):
        """Reanuda sólo la pausa que registró este script."""
        if not self.state['skwd']:
            return True
        paused, _ = skwd_state()
        if paused is False:
            # Otro actor lo reanudó, o la sesión es nueva: no queda nada pendiente.
            self.state['skwd'] = False
            return True
        if paused is None or skwd_cli('resume') is None:
            return False
        self.state['skwd'] = False
        return True

    def activate(self):
        self.state = {'session': SESSION, 'options': {}, 'paused': [], 'skwd': False}
        self.save()
        # Respetar el modo manual ML4W ya activado. No apropiarse de su flag.
        manual = Path.home() / '.config/ml4w/settings/gamemode-enabled'
        if not manual.exists():
            for name in OPTIONS:
                previous = option(name)
                if previous not in (0, 1) or previous == 0:
                    continue
                self.state['options'][name] = previous
                self.save()
                if not set_option(name, 0):
                    log('No se pudo desactivar ' + name)
        self.pause_wallpapers()
        frozen = self.pause_skwd()
        log('Modo juego ON: ' + ('fondo de vídeo congelado, ' if frozen else '') + 'efectos reducidos.')
        self.notify('Modo juego activado')

    def restore(self):
        pending = []
        for record in self.state['paused']:
            try:
                path = PROC / str(record['pid'])
                if path.stat().st_uid == UID and identity(path)[0] == record['start']:
                    os.kill(record['pid'], signal.SIGCONT)
            except (FileNotFoundError, ProcessLookupError):
                pass
            except OSError:
                pending.append(record)
        self.state['paused'] = pending
        remaining = {}
        if self.state['session'] == SESSION:
            for name, previous in self.state['options'].items():
                current = option(name)
                # Conservar cambios externos: restaurar sólo si sigue en 0.
                if current is None or (current == 0 and not set_option(name, previous)):
                    remaining[name] = previous
        self.state['options'] = remaining
        skwd_pending = not self.resume_skwd()
        if remaining or pending or skwd_pending:
            self.save()
            log('Restauración pendiente; se conserva el estado para reintentar.')
            return False
        self.path.unlink(missing_ok=True)
        log('Modo juego OFF: estado anterior restaurado.')
        return True

    @staticmethod
    def notify(message):
        if os.environ.get('AUTO_GAME_NOTIFY', '1') == '1' and shutil.which('notify-send'):
            try:
                subprocess.run(['notify-send', '-a', 'AutoGame', '-t', '2500', message],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
            except (OSError, subprocess.TimeoutExpired):
                pass


def main():
    parser = argparse.ArgumentParser(description='Reduce trabajo de fondo durante juegos de Steam y restaura al salir.')
    for flag in ('check', 'status', 'restore'):
        parser.add_argument('--' + flag, action='store_true')
    args = parser.parse_args()
    if sum((args.check, args.status, args.restore)) > 1:
        parser.error('Usa una sola acción.')
    if not SESSION or not shutil.which('hyprctl'):
        parser.error('Ejecuta desde tu sesión de Hyprland (HYPRLAND_INSTANCE_SIGNATURE requerido).')
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    if not runtime:
        parser.error('XDG_RUNTIME_DIR no está definido.')
    folder = Path(runtime) / 'auto-game-mode'
    if args.check:
        clients = query('clients')
        if not isinstance(clients, list):
            log('No se puede consultar Hyprland.')
            return 1
        paused, count = skwd_state()
        print(json.dumps({'games': game_reasons(clients),
                          'effects': {name: option(name) for name in OPTIONS},
                          'skwd': {'paused': paused, 'assignments': count}}, indent=2))
        return 0
    if args.status:
        path = folder / 'state.json'
        running = False
        pid = ''
        try:
            with (folder / 'lock').open('r') as status_lock:
                try:
                    fcntl.flock(status_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    running = True
                    pid = status_lock.read().strip()
        except FileNotFoundError:
            pass
        print('Monitor: ' + ('ACTIVO' if running else 'DETENIDO') + (' (PID ' + pid + ')' if running and pid else ''))
        print('Modo juego: ' + ('ACTIVO / cambios registrados' if running and path.exists() else 'recuperación pendiente' if path.exists() else 'INACTIVO'))
        if path.exists():
            print(path.read_text())
        return 0
    interval = float(os.environ.get('AUTO_GAME_INTERVAL', '5'))
    delay = float(os.environ.get('AUTO_GAME_EXIT_DELAY', '15'))
    if not (1 <= interval <= 60 and 0 <= delay <= 300):
        parser.error('Intervalo: 1–60 segundos; demora de salida: 0–300 segundos.')
    os.umask(0o077)
    folder.mkdir(mode=0o700, exist_ok=True)
    lock = (folder / 'lock').open('a+')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        log('Ya hay una instancia activa. Para restaurar, detén esa instancia con SIGTERM.')
        return 1 if args.restore else 0
    lock.seek(0)
    lock.truncate()
    lock.write(str(os.getpid()))
    lock.flush()
    manager = Manager(folder)
    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(sig, lambda *_: STOP.set())
    if manager.path.exists() and not manager.restore():
        return 1
    if args.restore:
        return 0
    active = False
    missing_since = None
    failures = 0
    log('Vigilando juegos de Steam cada ' + str(interval) + ' segundos.')
    try:
        while not STOP.is_set():
            clients = query('clients')
            if not isinstance(clients, list):
                failures += 1
                if failures >= 3:
                    log('Hyprland no responde; terminando y restaurando.')
                    return 1
            else:
                failures = 0
                reasons = game_reasons(clients)
                if reasons:
                    missing_since = None
                    if not active:
                        active = True
                        log('; '.join(reasons))
                        manager.activate()
                    else:
                        manager.pause_wallpapers()
                        # Una recarga de Hyprland ejecuta wallpaperStart(), que
                        # reaplica el fondo: eso reinicia `skwd-paper-v2 serve` y
                        # la pausa vive en ese proceso, así que se pierde. Medido
                        # el 2026-09-21: vuelve a congelarse 3 s después.
                        manager.pause_skwd()
                elif active:
                    if missing_since is None:
                        missing_since = time.monotonic()
                    if time.monotonic() - missing_since >= delay:
                        if manager.restore():
                            active = False
                            manager.notify('Escritorio restaurado')
            STOP.wait(interval)
    finally:
        if manager.path.exists():
            manager.restore()
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        log('Error: ' + str(error))
        sys.exit(1)
PYTHON
