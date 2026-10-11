"""Audio/controller tests use temporary synthetic WAVs, never substitute game assets."""
import json
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import wave

from app import App, Bridge
from voice import VoiceCatalog, VoicePlayer
from campaign_app import CampaignApp
from journey_app import JourneyApp
from test_journey_bridge import Session


class VoiceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name)
        with wave.open(str(self.path / 'test.wav'), 'wb') as wav:
            wav.setparams((1, 2, 8000, 800, 'NONE', 'not compressed'))
            wav.writeframes(b'\0\0' * 800)
        self.manifest([{'character_id': 'mage', 'cue': 'skill:mage', 'file': 'test.wav'},
                       {'character_id': 'mage', 'cue': 'hurt', 'file': 'test.wav'}])
        self.root = Mock()
        self.backend = Mock(SND_FILENAME=1, SND_ASYNC=2, SND_NODEFAULT=4)
        self.player = VoicePlayer(self.root, VoiceCatalog(self.path), self.backend, {'muted': False})
        self.addCleanup(self.player.close)

    def manifest(self, clips):
        characters = {}
        for clip in clips:
            uid = clip['character_id']
            characters.setdefault(uid, {'id': uid, 'prepared': {}})['prepared'][clip['cue']] = {
                'path': clip['file'], 'text': 'synthetic test only',
                'sha256': hashlib.sha256((self.path / 'test.wav').read_bytes()).hexdigest(),
                'duration_seconds': 0.1, 'sample_rate': 8000, 'channels': 1}
        (self.path / 'manifest.json').write_text(json.dumps({
            'schema_version': 1, 'characters': list(characters.values())}), encoding='utf-8')

    def test_manifest_integrity_and_metadata_mismatch_are_silent(self):
        path = self.path / 'manifest.json'
        original = json.loads(path.read_text(encoding='utf-8'))
        for field, value in [('sha256', '0' * 64), ('duration_seconds', 9),
                             ('sample_rate', 48000), ('channels', 2)]:
            data = json.loads(json.dumps(original))
            data['characters'][0]['prepared']['skill:mage'][field] = value
            path.write_text(json.dumps(data), encoding='utf-8')
            catalog = VoiceCatalog(self.path)
            self.assertFalse(catalog.clips)
            self.assertIsNotNone(catalog.error)

    def test_exact_character_and_skill_no_fallback(self):
        self.player.play_events([{'character_id': 'mage-2', 'cue': 'skill:mage'},
                                 {'character_id': 'mage', 'cue': 'skill:stamp'},
                                 {'character_id': 'enemy-mage', 'cue': 'hurt'}])
        self.backend.PlaySound.assert_not_called()
        self.player.play_events([{'character_id': 'mage', 'cue': 'skill:mage'}])
        self.backend.PlaySound.assert_called_once_with(str(self.path / 'test.wav'), 7)

    def test_serial_async_no_overlap_mute_cancels_queue(self):
        self.player.play_events([{'character_id': 'mage', 'cue': 'skill:mage'},
                                 {'character_id': 'mage', 'cue': 'hurt'}])
        self.assertEqual(self.backend.PlaySound.call_count, 1)
        self.assertEqual(len(self.player.queue), 1)
        self.root.after.assert_called_once()
        self.assertGreaterEqual(self.root.after.call_args.args[0], 100)
        self.player.set_muted(True)
        self.root.after_cancel.assert_called_once()
        self.backend.PlaySound.assert_called_with(None, 0)
        self.assertFalse(self.player.queue)
        self.player.play_events([{'character_id': 'mage', 'cue': 'hurt'}])
        self.assertEqual(self.backend.PlaySound.call_count, 2)

    def test_duplicate_hurt_in_one_response_is_not_repeated(self):
        self.player.play_events([{'character_id': 'mage', 'cue': 'hurt'}] * 3)
        self.backend.PlaySound.assert_called_once()
        self.assertFalse(self.player.queue)

    def test_installed_pack_has_all_137_exact_character_cues(self):
        catalog = VoiceCatalog()
        self.assertIsNone(catalog.error)
        expected = set()
        for uid in ('guard', 'guard-2', 'archer', 'archer-2', 'mage', 'mage-2', 'scout', 'scout-2'):
            expected.update((uid, cue) for cue in ['attack', 'hurt', 'skill:guard', 'skill:archer',
                                                 'skill:mage', 'skill:scout', 'skill:stamp'])
        expected.update(('warrior', cue) for cue in ['attack', 'hurt', 'skill:archer', 'skill:mage', 'skill:stamp'])
        for uid in ('porter', 'porter-2'):
            expected.update((uid, cue) for cue in ['hurt', 'skill:porter'])
        new = ['retreatSlash', 'knockback', 'splitShot', 'pincer', 'healingCross',
               'defenseLine', 'manaGift', 'returnHome']
        for uid in ('guard', 'guard-2', 'archer', 'archer-2', 'mage', 'mage-2', 'scout', 'scout-2'):
            expected.update((uid, 'skill:' + skill) for skill in new)
        expected.update(('warrior', 'skill:' + skill) for skill in new if skill not in ('retreatSlash', 'pincer'))
        expected.update((uid, 'skill:returnHome') for uid in ('porter', 'porter-2'))
        self.assertEqual(set(catalog.clips), expected)
        self.assertEqual(len(catalog.clips), 137)
        for (uid, cue), (path, _) in catalog.clips.items():
            self.assertEqual(path.name, uid + '_' + cue.replace(':', '_') + '_01.wav')

    def test_new_action_interrupts_and_close_cancels(self):
        event = [{'character_id': 'mage', 'cue': 'hurt'}]
        self.player.play_events(event)
        self.player.play_events(event)
        self.assertEqual(self.backend.PlaySound.call_args_list[1].args, (None, 0))
        self.player.close()
        count = self.backend.PlaySound.call_count
        self.player.play_events(event)
        self.assertEqual(self.backend.PlaySound.call_count, count)

    def test_backend_failure_does_not_break_game(self):
        self.backend.PlaySound.side_effect = RuntimeError('no device')
        self.player.play_events([{'character_id': 'mage', 'cue': 'hurt'}])
        self.assertEqual(self.player.error, 'no device')
        self.assertFalse(self.player.queue)

    def test_invalid_missing_or_escaping_assets_are_silent(self):
        for filename in ['missing.wav', '../outside.wav']:
            self.manifest([{'character_id': 'mage', 'cue': 'hurt', 'file': filename}])
            catalog = VoiceCatalog(self.path)
            self.assertFalse(catalog.clips)
            self.assertIsNotNone(catalog.error)

    def test_controller_only_successful_commit_plays_once(self):
        app = App.__new__(App)
        app.voice = Mock()
        app.bridge = Mock()
        app.draw = Mock()
        app.porter_confirmation = None
        event = [{'character_id': 'mage', 'cue': 'skill:mage'}]
        app.bridge.call.return_value = {'ok': True, 'voiceEvents': event}
        app.pending = ('skill', 'mage')
        app.commit()
        app.commit()
        app.voice.play_events.assert_called_once_with(event)
        app.cancel()
        app.voice.play_events.assert_called_once()
        app.bridge.call.return_value = {'ok': False, 'error': 'illegal'}
        app.perform_action('skill', 'mage')
        app.voice.play_events.assert_called_once()

    def test_real_bridge_response_events_are_not_replayed_by_view(self):
        bridge = Bridge()
        self.addCleanup(bridge.close)
        bridge.call(op='reset', scenario='victory')
        response = bridge.call(op='act', kind='attack', target='enemy-archer')
        self.assertTrue(response['ok'])
        self.assertEqual(response['voiceEvents'], [{'character_id': 'archer', 'cue': 'attack'}])
        self.assertNotIn('voiceEvents', bridge.call(op='view'))

    def test_campaign_opening_enemy_hit_only_after_begin(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        bridge.call(op='campaign_start')
        for action, args in [('select', [['guard', 'porter']]), ('depart', ['east']),
                             ('travel', ['safe']), ('deploy', ['guard', 4])]:
            response = bridge.call(op='campaign', action=action, args=args)
            self.assertTrue(response['ok'])
            self.assertNotIn('voiceEvents', response)
        before = bridge.call(op='view')
        bridge.call(op='record', type='battle.preview.cancelled')
        self.assertEqual(bridge.call(op='view'), before)
        response = bridge.call(op='campaign', action='begin', args=[])
        self.assertTrue(response['ok'])
        self.assertEqual(response['voiceEvents'], [{'character_id': 'guard', 'cue': 'hurt'}])
        self.assertLess(next(u['hp'] for u in response['state']['units'] if u['id'] == 'guard'), 180)
        self.assertNotIn('voiceEvents', bridge.call(op='view'))
        retry = bridge.call(op='campaign', action='begin', args=[])
        self.assertFalse(retry['ok'])
        self.assertEqual(retry['voiceEvents'], [])

    def test_begin_controller_transfers_events_once_and_rejects_failed_start(self):
        for cls in (CampaignApp, JourneyApp):
            app = cls.__new__(cls)
            app.open_battle = Mock()
            event = [{'character_id': 'guard', 'cue': 'hurt'}]
            response = {'ok': True, 'voiceEvents': event}
            app.data = response
            app.act = Mock(return_value=response)
            cls.begin(app)
            app.open_battle.assert_called_once_with(initial_voice_events=event)
            self.assertNotIn('voiceEvents', response)
            app.open_battle.reset_mock()
            app.data = {'ok': False, 'voiceEvents': []}
            app.act.return_value = app.data
            cls.begin(app)
            app.open_battle.assert_not_called()

    def test_reopened_battle_does_not_receive_old_opening_events(self):
        app = CampaignApp.__new__(CampaignApp)
        app.battle_window = None
        app.root, app.bridge, app.images = Mock(), Mock(), {}
        with patch('campaign_app.tk.Toplevel'), patch('campaign_app.CampaignBattleApp') as battle:
            app.open_battle()
            self.assertIsNone(battle.call_args.kwargs['initial_voice_events'])

    def test_eight_new_active_skills_emit_one_matching_voice_per_action(self):
        catalog = VoiceCatalog()
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        cases = [('guard', 'undertow-sword', 'retreatSlash'), ('mage', 'breaker-hammer', 'knockback'),
                 ('archer', 'twin-bow', 'splitShot'), ('scout', 'partner-dagger', 'pincer'),
                 ('mage', 'rest-staff', 'healingCross'), ('mage', 'battleline-shield', 'defenseLine'),
                 ('mage', 'sharing-tome', 'manaGift'), ('porter', 'return-ring-1', 'returnHome')]
        for uid, gear, skill in cases:
            with self.subTest(skill=skill):
                bridge.call(op='campaign_start')
                saved = bridge.call(op='campaign_save')['data']
                saved['state']['location'] = 'north' if skill == 'returnHome' else 'east'
                self.assertTrue(bridge.call(op='campaign_load', data=saved)['ok'])
                data = bridge.call(op='campaign', action='trial', args=[uid, gear])
                self.assertTrue(data['ok'], data.get('error'))
                mode = 'return' if skill == 'returnHome' else 'skill'
                target = data['choices'][mode][0]
                before = bridge.call(op='view')
                preview = bridge.call(op='preview', kind=mode, target=target)
                self.assertTrue(preview['ok'])
                self.assertNotIn('voiceEvents', preview)
                self.assertEqual(bridge.call(op='view'), before)
                result = bridge.call(op='act', kind=mode, target=target)
                self.assertTrue(result['ok'])
                event = {'character_id': uid, 'cue': 'skill:' + skill}
                self.assertEqual(result['voiceEvents'][0], event)
                path, _ = catalog.lookup(event)
                self.assertEqual(path.name, uid + '_skill_' + skill + '_01.wav')
                self.assertEqual(sum(e == event for e in result['voiceEvents']), 1)
                self.assertEqual(sum(e['cue'].startswith('skill:') for e in result['voiceEvents']), 1)
                backend = Mock(SND_FILENAME=1, SND_ASYNC=2, SND_NODEFAULT=4)
                player = VoicePlayer(Mock(), catalog, backend, {'muted': False})
                try:
                    player.play_events(result['voiceEvents'])
                    backend.PlaySound.assert_called_once_with(str(path), 7)
                finally:
                    player.close()
                self.assertTrue(any(e['skillId'] == skill for e in result['skillEvents']))
                self.assertNotIn('voiceEvents', bridge.call(op='view'))
                self.assertTrue(bridge.call(op='campaign', action='endTrial', args=[])['ok'])

    def test_passive_activation_does_not_emit_skill_speech(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        for gear, skill, action in [('victory-earring-1', 'victoryBreath', 'attack'),
                                    ('lone-ring-1', 'loneWolf', 'attack'),
                                    ('pioneer-gloves-1', 'firstStride', 'move')]:
            bridge.call(op='campaign_start')
            saved = bridge.call(op='campaign_save')['data']
            saved['state']['location'] = 'north'
            self.assertTrue(bridge.call(op='campaign_load', data=saved)['ok'])
            data = bridge.call(op='campaign', action='trial', args=['mage', gear])
            self.assertTrue(data['ok'])
            result = bridge.call(op='act', kind=action, target=data['choices'][action][0])
            self.assertTrue(result['ok'])
            self.assertTrue(any(e['skillId'] == skill for e in result['skillEvents']))
            self.assertFalse(any(e['cue'].startswith('skill:') for e in result['voiceEvents']))
            self.assertNotIn('voiceEvents', bridge.call(op='view'))
            self.assertTrue(bridge.call(op='campaign', action='endTrial', args=[])['ok'])


if __name__ == '__main__':
    unittest.main()
