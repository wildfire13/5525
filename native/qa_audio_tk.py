"""Opt-in real Windows playback of installed provisional assets, hidden Tk window.

Runs about 31 seconds. Plays each BGM briefly, then battle through a loop with
real voice samples. Does not constitute perceptual approval or human playtesting.
"""
import json
from pathlib import Path
import time
import wave

from tk_bootstrap import prepare_tk
prepare_tk()
import tkinter as tk
from music import MusicCatalog, MusicPlayer, LOCATIONS
from wave_audio import WaveOutput
from voice import VoiceCatalog, VoicePlayer


def main():
    root = tk.Tk()
    root.withdraw()
    catalog, voices, backend = MusicCatalog(), VoiceCatalog(), WaveOutput()
    assert not catalog.error and not voices.error
    player, voice = MusicPlayer(root, catalog, backend), VoicePlayer(root, voices)
    report = {'kind': 'real Windows API + hidden Tk, not human perceptual review',
              'tracks': [], 'errors': [], 'voice_count': len(voices.clips)}
    starts, ticks = [], []
    start = backend.start
    def record_start(path):
        starts.append(time.monotonic())
        start(path)
    backend.start = record_start
    def safe(callback):
        try:
            callback()
        except Exception as error:
            report['errors'].append(repr(error))
            root.destroy()
    def tick():
        ticks.append(time.monotonic())
        root.after(40, tick)
    queue = ['astaris', 'north', 'east', 'west', 'south', 'battle2']
    def next_track():
        key = queue.pop(0)
        data = {'campaign': {'phase': 'town', 'location': key}} if key in LOCATIONS else {'state': {'result': None}}
        player.sync(data)
        count = len(starts)
        player.sync(data)
        report['tracks'].append({'id': key, 'playing': backend.playing(),
                                 'same_scene_did_not_restart': len(starts) == count})
        if queue:
            root.after(1000, lambda: safe(next_track))
        else:
            report['starts_before_loop'] = len(starts)
            with wave.open(str(catalog.tracks['battle2']), 'rb') as wav:
                duration = wav.getnframes() / wav.getframerate()
            voice.play_events([{'character_id': 'mage', 'cue': 'skill:mage'},
                               {'character_id': 'guard', 'cue': 'hurt'}])
            report['voice_started'] = voice.playing and not voice.error
            root.after(800, lambda: safe(check_voice_mute))
            root.after(int(duration * 1000) + 1600, lambda: safe(finish))
    def check_voice_mute():
        voice.set_muted(True)
        report['music_after_voice_mute'] = backend.playing()
    def finish():
        report['natural_loop_without_restart'] = len(starts) == report['starts_before_loop'] and backend.playing()
        player.set_muted(True)
        report['music_mute_closed_device'] = not backend.opened
        player.set_muted(False)
        report['music_unmute_started'] = backend.playing()
        voice.close()
        root.destroy()
    root.after(40, tick)
    root.after(0, lambda: safe(next_track))
    try:
        root.mainloop()
    finally:
        voice.close()
        player.close()
    report.update(ui_ticks=len(ticks), device_closed=not backend.opened, closed=player.closed,
                  playback_starts=len(starts))
    report['passed'] = bool(not report['errors'] and len(report['tracks']) == 6
        and all(t['playing'] and t['same_scene_did_not_restart'] for t in report['tracks'])
        and all(report.get(key) for key in ['voice_started', 'music_after_voice_mute',
            'natural_loop_without_restart', 'music_mute_closed_device', 'music_unmute_started', 'device_closed', 'closed'])
        and len(ticks) > 100)
    Path(__file__).with_name('qa-audio-tk-report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(report))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
