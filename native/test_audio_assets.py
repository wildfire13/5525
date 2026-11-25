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
        characters = self.manifest('event-voices')['characters']
        expected = {
            f'recruit-{job}-{race}-{sex}'
            for job in ('guard', 'scout', 'mage', 'porter')
            for race in ('human', 'elf', 'dwarf')
            for sex in ('male', 'female')
        }
        self.assertEqual(set(characters), expected)
        for uid, clips in characters.items():
            self.assertEqual(set(clips), {
                'attack', 'battle_win', 'damage', 'incapacitated', 'quest_clear',
            })
            _, job, race, sex = uid.split('-')
            for clip in clips.values():
                self.assertEqual(clip['source_character'],
                                 f'{race}-{sex}-{"warrior" if job == "guard" else job}')
                self.assertEqual(Path(clip['file']).name, clip['file'])
                self.check_file('event-voices', clip['file'], clip)

    def test_music_routes(self):
        manifest = self.manifest('music')
        tracks = {track['id']: track for track in manifest['tracks']}
        towns = {'north', 'east', 'west', 'south'}
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
