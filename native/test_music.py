"""BGM state/controller tests; real audio smoke is documented separately."""
import json
import hashlib
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
import wave
from unittest.mock import Mock, patch

from music import LOCATIONS, MusicCatalog, MusicPlayer, WindowsMusic, scene_track
from voice import VoicePlayer
from campaign_app import CampaignApp
from test_journey_bridge import Session


class MusicTests(unittest.TestCase):
    def setUp(self):
        self.root, self.backend = Mock(), Mock()
        self.catalog = SimpleNamespace(tracks={key: Path(key + '.wav') for key in LOCATIONS | {'battle2'}})
        self.player = MusicPlayer(self.root, self.catalog, self.backend)
        self.addCleanup(self.player.close)

    def test_five_towns_arrival_and_unspecified_silence(self):
        for location in LOCATIONS:
            for phase in ('town', 'result', 'prepare'):
                self.assertEqual(scene_track({'campaign': {'phase': phase, 'location': location}}), location)
        for phase in ('road', 'camp', 'deployment'):
            self.assertIsNone(scene_track({'campaign': {'phase': phase, 'location': 'astaris'}}))
        self.assertEqual(scene_track({'campaign': {'phase': 'arrival', 'location': 'astaris'},
                                      'journey': {'destination': 'north'}}), 'north')

    def test_battle_trial_end_and_return(self):
        data = {'campaign': {'phase': 'battle', 'location': 'astaris'}, 'state': {'result': None}}
        self.player.sync(data)
        self.assertEqual(self.player.current, 'battle2')
        data['state']['result'] = 'victory'
        self.player.sync(data)
        self.assertIsNone(self.player.current)
        data['campaign'] = {'phase': 'result', 'location': 'astaris'}
        self.player.sync(data)
        self.assertEqual(self.player.current, 'astaris')
        data = {'campaign': {'phase': 'town', 'location': 'east'}, 'trial': {'active': True}, 'state': {}}
        self.assertEqual(scene_track(data), 'battle2')
        data['trial'] = None
        self.assertEqual(scene_track(data), 'east')

    def test_same_scene_redraw_does_not_restart(self):
        for _ in range(12):
            self.player.sync({'campaign': {'phase': 'town', 'location': 'astaris'}})
        self.backend.start.assert_called_once_with(Path('astaris.wav'))
        self.root.after.assert_called_once()

    def test_loop_restarts_only_after_audio_ends(self):
        self.player.select('east')
        self.backend.playing.return_value = True
        self.player._poll()
        self.backend.restart.assert_not_called()
        self.backend.playing.return_value = False
        self.player._poll()
        self.backend.restart.assert_called_once()

    def test_mute_stop_and_unmute_current_scene_without_backlog(self):
        self.player.select('east')
        self.player.set_muted(True)
        self.assertIsNone(self.player.current)
        self.player.select('battle2')
        self.backend.start.assert_called_once()
        self.player.set_muted(False)
        self.backend.start.assert_called_with(Path('battle2.wav'))
        count = self.backend.start.call_count
        self.player.set_muted(False)
        self.assertEqual(self.backend.start.call_count, count)

    def test_close_and_destroy_cancel_loop(self):
        self.player.select('west')
        handler = self.root.bind.call_args.args[1]
        handler(SimpleNamespace(widget=object()))
        self.assertFalse(self.player.closed)
        handler(SimpleNamespace(widget=self.root))
        self.assertTrue(self.player.closed)
        self.root.after_cancel.assert_called_once()
        count = self.backend.start.call_count
        self.player.select('east')
        self.player._poll()
        self.assertEqual(self.backend.start.call_count, count)

    def test_missing_asset_and_device_failure_do_not_break_game_or_retry_redraw(self):
        self.player.select('unassigned')
        self.backend.start.assert_not_called()
        self.backend.start.side_effect = OSError('device unavailable')
        self.player.select('south')
        self.assertIsNone(self.player.current)
        self.assertIsNotNone(self.player.error)
        self.player.select('south')
        self.backend.start.assert_called_once()

    def test_voice_and_music_mute_stop_are_independent(self):
        voice_backend = Mock(SND_FILENAME=1, SND_ASYNC=2, SND_NODEFAULT=4)
        voice_catalog = Mock(clips={('guard', 'hurt'): ('hurt.wav', 0.2)})
        voice_catalog.lookup.return_value = ('hurt.wav', 0.2)
        voice = VoicePlayer(self.root, voice_catalog, voice_backend, {'muted': False})
        self.addCleanup(voice.close)
        self.player.select('battle2')
        count = self.backend.stop.call_count
        voice.play_events([{'character_id': 'guard', 'cue': 'hurt'}])
        voice.set_muted(True)
        self.assertEqual(self.backend.stop.call_count, count)
        calls = voice_backend.PlaySound.call_count
        self.player.set_muted(True)
        self.assertEqual(voice_backend.PlaySound.call_count, calls)

    def test_catalog_paths_and_missing_files(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            with wave.open(str(base / 'track.wav'), 'wb') as wav:
                wav.setparams((2, 3, 48000, 480, 'NONE', 'not compressed'))
                wav.writeframes(b'\0' * 480 * 6)
            raw = (base / 'track.wav').read_bytes()
            manifest = base / 'manifest.json'
            for path, valid in [('track.wav', True), ('../outside.wav', False), ('missing.wav', False)]:
                track = {'id': 'shared', 'filename': path, 'size_bytes': len(raw),
                         'sha256': hashlib.sha256(raw).hexdigest(), 'sample_rate_hz': 48000,
                         'channels': 2, 'bits_per_sample': 24, 'frames': 480,
                         'loop_start_frame': 0, 'loop_end_frame_exclusive': 480}
                manifest.write_text(json.dumps({'schema_version': 1, 'tracks': [track],
                    'playback': {'loop_entire_file': True},
                    'routes': {'locations': {key: 'shared' for key in LOCATIONS}, 'battle': 'shared'}}))
                catalog = MusicCatalog(base)
                self.assertEqual(bool(catalog.tracks), valid)

    def test_installed_six_loops_and_battle_pattern_two_route(self):
        catalog = MusicCatalog()
        self.assertIsNone(catalog.error)
        self.assertEqual(set(catalog.tracks), LOCATIONS | {'battle2'})
        self.assertEqual(catalog.tracks['battle2'].name, 'battle.wav')
        for key in LOCATIONS:
            self.assertEqual(catalog.tracks[key].name, key + '.wav')

    def test_windows_commands_use_separate_alias_and_never_wait(self):
        backend = WindowsMusic.__new__(WindowsMusic)
        backend.alias, backend.opened, backend.command = 'test_music', False, Mock()
        backend.start(Path('test.wav'))
        backend.restart()
        backend.stop()
        commands = [call.args[0] for call in backend.command.call_args_list]
        self.assertEqual(commands, ['open "test.wav" alias test_music',
                                   'play test_music from 0', 'play test_music from 0', 'close test_music'])

    def test_campaign_battle_shares_music_without_taking_ownership(self):
        app = CampaignApp.__new__(CampaignApp)
        app.root, app.bridge, app.images, app.music = Mock(), Mock(), {}, self.player
        app.battle_window = None
        with patch('campaign_app.tk.Toplevel'), patch('campaign_app.CampaignBattleApp') as battle:
            app.open_battle()
            self.assertIs(battle.call_args.kwargs['music'], self.player)

    def test_real_save_load_routes_without_restarting_same_location_or_altering_save(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        self.player.sync(bridge.call(op='campaign_start'))
        saved = bridge.call(op='campaign_save')['data']
        self.player.sync(bridge.call(op='campaign_load', data=saved))
        self.backend.start.assert_called_once_with(Path('astaris.wav'))
        self.assertEqual(bridge.call(op='campaign_save')['data'], saved)
        saved['state']['location'] = 'north'  # Explicit location fixture, not travel evidence.
        self.player.sync(bridge.call(op='campaign_load', data=saved))
        self.assertEqual(self.player.current, 'north')
        self.backend.start.assert_called_with(Path('north.wav'))
        rejected = bridge.call(op='campaign_load', data={})
        self.assertFalse(rejected['ok'])
        self.assertEqual(self.player.current, 'north')


if __name__ == '__main__':
    unittest.main()
