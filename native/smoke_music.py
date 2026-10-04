"""Opt-in Windows/Tk audio smoke: synthetic silence, no installed game assets."""
import json
from pathlib import Path
import tempfile
import time
from types import SimpleNamespace
import wave

from tk_bootstrap import prepare_tk
prepare_tk()
import tkinter as tk
from music import MusicPlayer, WindowsMusic
from voice import VoicePlayer


def main():
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / 'silence.wav'
        with wave.open(str(path), 'wb') as wav:
            wav.setparams((1, 2, 8000, 3200, 'NONE', 'not compressed'))
            wav.writeframes(b'\0\0' * 3200)
        root = tk.Tk()
        root.withdraw()
        backend = WindowsMusic()
        restart = backend.restart
        restarts, ticks, errors = [], [], []
        def record_restart():
            restarts.append(time.monotonic())
            restart()
        backend.restart = record_restart
        music = MusicPlayer(root, SimpleNamespace(tracks={'battle2': path}), backend)
        voice = VoicePlayer(root, SimpleNamespace(clips={1: 1}, lookup=lambda _: (path, .4)),
                            preferences={'muted': False})
        checks = {}
        def safely(callback):
            try:
                callback()
            except Exception as error:
                errors.append(repr(error))
        def play_voice():
            voice.play_events([{'character_id': 'guard', 'cue': 'hurt'}])
            checks['music_during_voice'] = backend.playing()
        def mute_voice():
            voice.set_muted(True)
            checks['music_after_voice_stop'] = backend.playing()
        def tick():
            ticks.append(time.monotonic())
            root.after(20, tick)
        try:
            start = time.monotonic()
            music.select('battle2')
            checks['start_seconds'] = round(time.monotonic() - start, 3)
            root.after(20, tick)
            root.after(50, lambda: safely(play_voice))
            root.after(200, lambda: safely(mute_voice))
            root.after(1150, root.destroy)
            root.mainloop()
        finally:
            voice.close()
            music.close()
        checks.update(loop_starts=len(restarts), ui_ticks=len(ticks), closed=music.closed,
                      device_closed=not backend.opened, errors=errors, synthetic_silence_only=True)
        # Windows timer resolution is not guaranteed to deliver exact 20ms intervals.
        checks['passed'] = bool(checks.get('music_during_voice') and checks.get('music_after_voice_stop')
                                and len(restarts) >= 2 and len(ticks) >= 20
                                and music.closed and not backend.opened and not errors)
        print(json.dumps(checks))
        return 0 if checks['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
