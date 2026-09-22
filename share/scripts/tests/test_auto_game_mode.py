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
        # Aislar de la sesión real: sin esto, activate() llamaría a la CLI de
        # skwd y congelaría el fondo de vídeo del usuario durante las pruebas.
        isolated = patch.object(module, 'skwd_cli', return_value=None)
        isolated.start()
        self.addCleanup(isolated.stop)

    def fake_skwd(self, assignments=1, paused=False):
        """CLI de skwd simulada: nunca toca la sesión real."""
        state = {'paused': paused, 'assignments': assignments, 'calls': []}

        def cli(*args, timeout=3):
            state['calls'].append(args[0])
            if args[0] == 'status':
                return {'paused': state['paused'],
                        'assignments': [{} for _ in range(state['assignments'])]}
            if args[0] == 'pause':
                state['paused'] = True
                return {'paused': True}
            if args[0] == 'resume':
                state['paused'] = False
                return {'paused': False}
            return None

        return state, cli

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

    def test_skwd_pause_is_claimed_and_resumed(self):
        state, cli = self.fake_skwd()
        with patch.object(module, 'skwd_cli', side_effect=cli):
            manager = module.Manager(self.root)
            self.assertTrue(manager.pause_skwd())
            self.assertTrue(manager.state['skwd'])
            self.assertTrue(state['paused'])
            self.assertTrue(manager.restore())
            self.assertFalse(state['paused'])
            self.assertEqual(state['calls'].count('pause'), 1)
            self.assertEqual(state['calls'].count('resume'), 1)
            self.assertFalse(manager.path.exists())

    def test_skwd_pause_already_active_is_not_claimed(self):
        state, cli = self.fake_skwd(paused=True)
        with patch.object(module, 'skwd_cli', side_effect=cli):
            manager = module.Manager(self.root)
            self.assertFalse(manager.pause_skwd())
            self.assertFalse(manager.state['skwd'])
            self.assertTrue(module.Manager(self.root).restore())
            self.assertNotIn('resume', state['calls'])

    def test_skwd_without_assignment_is_not_paused(self):
        state, cli = self.fake_skwd(assignments=0)
        with patch.object(module, 'skwd_cli', side_effect=cli):
            manager = module.Manager(self.root)
            self.assertFalse(manager.pause_skwd())
            self.assertFalse(manager.state['skwd'])
            self.assertNotIn('pause', state['calls'])

    def test_skwd_unreachable_never_claims_nor_resumes(self):
        manager = module.Manager(self.root)
        self.assertFalse(manager.pause_skwd())
        self.assertFalse(manager.state['skwd'])
        self.assertTrue(manager.resume_skwd())

    def test_skwd_resume_failure_retains_journal(self):
        state, cli = self.fake_skwd()
        with patch.object(module, 'skwd_cli', side_effect=cli):
            manager = module.Manager(self.root)
            self.assertTrue(manager.pause_skwd())
            with patch.object(module, 'skwd_cli', return_value=None):
                self.assertFalse(manager.restore())
            self.assertTrue(manager.path.exists())
            self.assertTrue(manager.state['skwd'])
            self.assertTrue(module.Manager(self.root).restore())
            self.assertFalse(state['paused'])

    def test_skwd_is_repaused_when_the_wallpaper_returns(self):
        state, cli = self.fake_skwd()
        with patch.object(module, 'skwd_cli', side_effect=cli):
            manager = module.Manager(self.root)
            self.assertTrue(manager.pause_skwd())
            state['paused'] = False  # Una recarga reaplica el fondo y lo reanuda.
            self.assertTrue(manager.pause_skwd())
            self.assertEqual(state['calls'].count('pause'), 2)
            self.assertTrue(state['paused'])

    def test_skwd_foreign_resume_is_not_overwritten(self):
        state, cli = self.fake_skwd()
        with patch.object(module, 'skwd_cli', side_effect=cli):
            manager = module.Manager(self.root)
            self.assertTrue(manager.pause_skwd())
            state['paused'] = False  # Otro actor lo reanudó durante la partida.
            self.assertTrue(manager.restore())
            self.assertNotIn('resume', state['calls'])
            self.assertFalse(manager.state['skwd'])

    def test_option_reads_bool_and_int_from_hyprland(self):
        modern = {'option': 'animations:enabled', 'bool': True, 'set': True}
        with patch.object(module, 'query', return_value=modern):
            self.assertEqual(module.option('animations:enabled'), 1)
        with patch.object(module, 'query', return_value=dict(modern, bool=False)):
            self.assertEqual(module.option('animations:enabled'), 0)
        with patch.object(module, 'query', return_value={'option': 'x', 'int': 7}):
            self.assertEqual(module.option('x'), 7)
        with patch.object(module, 'query', return_value=None):
            self.assertIsNone(module.option('x'))

    def test_lua_literal_builds_nested_config(self):
        self.assertEqual(module.lua_literal('animations:enabled', 0),
                         '{ animations = { enabled = false } }')
        self.assertEqual(module.lua_literal('decoration:blur:enabled', 1),
                         '{ decoration = { blur = { enabled = true } } }')

    def test_set_option_prefers_eval_and_falls_back_to_keyword(self):
        with patch.object(module, 'hypr', return_value='ok') as call:
            self.assertTrue(module.set_option('animations:enabled', 0))
            self.assertEqual(call.call_count, 1)
            self.assertEqual(call.call_args.args[0], 'eval')
            self.assertEqual(call.call_args.args[1], 'hl.config({ animations = { enabled = false } })')
        with patch.object(module, 'hypr', side_effect=['fail', 'ok']) as call:
            self.assertTrue(module.set_option('animations:enabled', 0))
            self.assertEqual(call.call_count, 2)
            self.assertEqual(call.call_args_list[1].args[0], 'keyword')

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
