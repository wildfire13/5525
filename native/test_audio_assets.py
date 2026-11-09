"""Validate the audio catalogs loaded by the Godot frontend."""
import hashlib
import json
from pathlib import Path
import unittest


ASSETS = Path(__file__).resolve().parent / 'assets'


class AudioAssetTests(unittest.TestCase):
    def manifest(self, folder):
        return json.loads((ASSETS / folder / 'manifest.json').read_text(encoding='utf-8-sig'))

    def check_file(self, folder, relative, entry):
        path = (ASSETS / folder / relative).resolve()
        self.assertTrue(path.is_relative_to(ASSETS / folder))
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry['sha256'], relative)

    def test_voice_cues(self):
        cues = set()
        for character in self.manifest('voices')['characters']:
            for cue, clip in character['prepared'].items():
                cues.add((character['id'], cue))
                self.check_file('voices', clip['path'], clip)
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
        self.assertEqual(cues, expected)

    def test_music_routes(self):
        manifest = self.manifest('music')
        tracks = {track['id']: track for track in manifest['tracks']}
        towns = {'astaris', 'north', 'east', 'west', 'south'}
        self.assertEqual(manifest['routes']['locations'], {town: town for town in towns})
        self.assertEqual(manifest['routes']['battle'], 'battle')
        self.assertEqual(set(tracks), towns | {'battle'})
        for name, track in tracks.items():
            self.assertEqual(Path(track['filename']).name, name + '.wav')
            self.check_file('music', track['filename'], track)

    def test_effect_cues(self):
        effects = {clip['id']: clip for clip in self.manifest('se')['se']}
        self.assertEqual(set(effects), {'attack', 'hit', 'skill', 'heal', 'confirm', 'cancel', 'victory', 'failure'})
        self.assertEqual(effects['victory']['duration_seconds'], 0.95)
        for clip in effects.values():
            self.check_file('se', clip['filename'], clip)
