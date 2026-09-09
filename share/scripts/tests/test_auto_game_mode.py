"""Pruebas aisladas: nunca modifican la sesión de Hyprland del usuario."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'auto-game-mode.sh'
module = types.ModuleType('auto_game_mode')
exec(compile(SCRIPT.read_text().split("<<'PYTHON'\n", 1)[1].rsplit('\nPYTHON', 1)[0], str(SCRIPT), 'exec'), module.__dict__)


class AutoGameTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def fake_process(self, pid, comm, env):
        path = self.root / str(pid)
        path.mkdir()
        (path / 'comm').write_text(comm)
        (path / 'environ').write_bytes(env)
        (path / 'stat').write_text(f'{pid} ({comm}) S ' + ' '.join(['0'] * 18 + ['1234']))
        return path

    def test_steam_idle_and_unrelated_wine_are_not_games(self):
        self.fake_process(1, 'steam', b'SteamAppId=0\0')
        self.fake_process(2, 'steamwebhelper', b'SteamAppId=123\0')
        self.fake_process(3, 'wine', b'OTHER=1\0')
        self.fake_process(4, 'wineserver', b'SteamAppId=123\0')
        with patch.object(module, 'PROC', self.root):
            self.assertEqual(module.game_reasons([]), [])

    def test_native_proton_nonsteam_and_window_detection(self):
        self.fake_process(1, 'native-game', b'SteamAppId=123\0')
        self.fake_process(2, 'Game.exe', b'SteamGameId=456\0')
        self.fake_process(3, 'shortcut', b'SteamAppId=0\0SteamGameId=9999999999\0')
        with patch.object(module, 'PROC', self.root):
            self.assertEqual(len(module.game_reasons([{'initialClass': 'steam_app_789'}])), 4)

    def test_gamescope_when_environ_is_denied(self):
        process = self.fake_process(1, 'gamescope', b'')
        (process / 'cmdline').write_bytes(b'gamescope\0--\0reaper\0SteamLaunch\0AppId=1643320\0--\0proton\0')
        original = Path.read_bytes
        def read(path):
            if path.name == 'environ':
                raise PermissionError('Yama')
            return original(path)
        with patch.object(module, 'PROC', self.root), patch.object(Path, 'read_bytes', read):
            self.assertEqual(module.game_reasons([]), ['SteamLaunch AppId=1643320 (PID 1)'])

    def test_wallpaper_environ_denied_single_and_multiple_sessions(self):
        self.fake_process(1, 'Hyprland', b'')
        self.fake_process(2, 'mpvpaper', b'')
        original = Path.read_bytes
        def read(path):
            if path.name == 'environ':
                raise PermissionError('Yama')
            return original(path)
        with patch.object(module, 'PROC', self.root), patch.object(Path, 'read_bytes', read), patch.object(module.os, 'kill') as kill:
            manager = module.Manager(self.root)
            manager.pause_wallpapers()
            kill.assert_called_once_with(2, signal.SIGSTOP)
            manager.restore()
            self.fake_process(3, 'Hyprland', b'')
            kill.reset_mock()
            manager.pause_wallpapers()
            kill.assert_not_called()

    def test_restore_values_and_preserve_external_changes(self):
        values = dict(zip(module.OPTIONS, [1, 0, 1]))
        def setter(name, value):
            values[name] = value
            return True
        manager = module.Manager(self.root)
        with patch.object(module, 'option', side_effect=values.get), patch.object(module, 'set_option', side_effect=setter), patch.object(module.Manager, 'pause_wallpapers'), patch.object(module.Manager, 'notify'), patch.object(Path, 'home', return_value=self.root):
            manager.activate()
            self.assertEqual(list(values.values()), [0, 0, 0])
            values[module.OPTIONS[2]] = 1  # Cambio del usuario mientras juega.
            self.assertTrue(module.Manager(self.root).restore())
            self.assertEqual(list(values.values()), [1, 0, 1])
            self.assertFalse(manager.path.exists())

    def test_restore_failure_retains_journal(self):
        manager = module.Manager(self.root)
        manager.state['options'] = {module.OPTIONS[0]: 1}
        manager.save()
        with patch.object(module, 'option', return_value=None):
            self.assertFalse(manager.restore())
        self.assertTrue(manager.path.exists())

    def test_pid_reuse_never_receives_signal(self):
        process = self.fake_process(123, 'mpvpaper', b'')
        manager = module.Manager(self.root)
        manager.state['paused'] = [{'pid': 123, 'start': '999'}]
        with patch.object(module, 'PROC', self.root), patch.object(module.os, 'kill') as kill:
            self.assertTrue(manager.restore())
            kill.assert_not_called()

    def test_real_process_pause_and_recovery(self):
        env = dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE='auto-game-test')
        child = subprocess.Popen(['python3', '-c', 'import ctypes,time; ctypes.CDLL(None).prctl(15,b"mpvpaper",0,0,0); time.sleep(60)'], env=env)
        def cleanup():
            child.kill()
            child.wait()
        self.addCleanup(cleanup)
        import time
        path = Path('/proc') / str(child.pid)
        for _ in range(100):
            if (path / 'comm').read_text().strip() == 'mpvpaper':
                break
            time.sleep(.01)
        with patch.object(module, 'SESSION', 'auto-game-test'), patch.object(module, 'processes', return_value=[path]):
            manager = module.Manager(self.root)
            manager.pause_wallpapers()
            os.waitpid(child.pid, os.WUNTRACED)
            self.assertEqual(module.identity(path)[1], 'T')
            manager.pause_wallpapers()
            self.assertEqual(len(manager.state['paused']), 1)
            self.assertTrue(module.Manager(self.root).restore())
            for _ in range(100):
                if module.identity(path)[1] != 'T':
                    break
                time.sleep(.01)
            self.assertNotEqual(module.identity(path)[1], 'T')

    def test_manual_ml4w_mode_is_preserved(self):
        flag = self.root / '.config/ml4w/settings/gamemode-enabled'
        flag.parent.mkdir(parents=True)
        flag.touch()
        with patch.object(Path, 'home', return_value=self.root), patch.object(module, 'set_option') as setter, patch.object(module.Manager, 'pause_wallpapers'), patch.object(module.Manager, 'notify'):
            manager = module.Manager(self.root)
            manager.activate()
            manager.restore()
            setter.assert_not_called()
        self.assertTrue(flag.exists())


if __name__ == '__main__':
    unittest.main()
