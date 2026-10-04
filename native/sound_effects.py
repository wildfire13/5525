"""Independent bounded SE channels. Production catalog is validated, never guessed."""
from collections import deque
import hashlib
import json
import os
from pathlib import Path
import wave
from wave_audio import WaveOutput

ASSETS = Path(__file__).resolve().parent / 'assets' / 'se'
CUES = {'attack', 'hit', 'skill', 'heal', 'confirm', 'cancel', 'victory', 'failure'}
PHYSICAL_SKILLS = {'archer', 'scout', 'stamp', 'retreatSlash', 'knockback', 'splitShot', 'pincer'}


class SoundCatalog:
    """Read the supplied schema-2 SE runtime manifest without rewriting it."""
    def __init__(self, directory=ASSETS):
        self.clips, self.durations, self.error = {}, {}, None
        base = Path(directory).resolve()
        try:
            data = json.loads((base / 'manifest.json').read_text(encoding='utf-8-sig'))
            if data['schema_version'] != 2 or len(data['se'])!=8 or {entry['id'] for entry in data['se']} != CUES:
                raise ValueError('Expected exactly eight SE cues')
            for entry in data['se']:
                cue=entry['id']
                path = (base / entry['filename']).resolve()
                if not path.is_relative_to(base) or path.suffix.lower() != '.wav':
                    raise ValueError('SE path must stay inside its catalog')
                raw=path.read_bytes()
                if len(raw)!=entry['size_bytes'] or hashlib.sha256(raw).hexdigest() != entry['sha256']:
                    raise ValueError('SE checksum mismatch: ' + cue)
                with wave.open(str(path), 'rb') as wav:
                    if (wav.getcomptype() != 'NONE' or wav.getnchannels() not in (1, 2)
                            or wav.getsampwidth() not in (2, 3)
                            or (wav.getframerate(),wav.getnchannels(),wav.getsampwidth()*8,wav.getnframes()) != (entry['sample_rate_hz'],entry['channels'],entry['bits_per_sample'],entry['frames'])
                            or entry['loop'] is not False
                            or abs(wav.getnframes()/wav.getframerate()-entry['duration_seconds']) > .001
                            or not 0 < wav.getnframes() / wav.getframerate() <= 10):
                        raise ValueError('Unsupported SE WAV: ' + cue)
                self.clips[cue] = path
                self.durations[cue]=entry['duration_seconds']
        except (OSError, ValueError, KeyError, TypeError, AttributeError, wave.Error, EOFError) as error:
            self.clips.clear();self.durations.clear();self.error = str(error)


def phase_sound(phase, state):
    kind = phase['phase']
    if kind == 'action':
        if phase.get('kind') == 'attack':return 'attack'
        if phase.get('kind') == 'skill':return 'attack' if phase.get('skill_id') in PHYSICAL_SKILLS else 'skill'
        if phase.get('kind') == 'return':return 'skill'
    if kind == 'hurt' and phase['to'] < phase['from']:return 'hit'
    if kind == 'heal' and phase['to'] > phase['from']:return 'heal'
    if kind == 'settled' and state.get('result'):
        return 'victory' if not state.get('failure') and not any(u['side']=='enemy' and u['hp']>0 for u in state['units']) else 'failure'
    return None


class SoundPlayer:
    def __init__(self, root, catalog=None, backend_factory=None):
        self.root = root
        self.catalog = catalog if catalog is not None else SoundCatalog()
        self.factory = backend_factory if backend_factory is not None else (lambda: WaveOutput(loop=False)) if os.name == 'nt' else None
        self.voices = []
        self.seen, self.order = set(), deque()
        self.muted = self.closed = False
        self.timer = None
        self.serial = 0
        self.error = None
        root.bind('<Destroy>', lambda e: self.close() if e.widget is root else None, add='+')

    def _reap(self):
        retained = []
        for channel, backend in self.voices:
            if backend.playing():retained.append((channel, backend))
            else:backend.stop()
        self.voices = retained

    def play(self, cue, key, channel='gameplay'):
        if self.closed or cue not in CUES:return
        token = (cue, key)
        if token in self.seen:return
        self.seen.add(token);self.order.append(token)
        if len(self.order)>512:self.seen.discard(self.order.popleft())
        if self.muted or not self.factory or cue not in self.catalog.clips:return
        try:
            self._reap()
            limit = 1 if channel == 'ui' else 4
            existing = [item for item in self.voices if item[0] == channel]
            if len(existing) >= limit:
                existing[0][1].stop();self.voices.remove(existing[0])
            backend = self.factory();backend.start(self.catalog.clips[cue])
            self.voices.append((channel, backend))
            if self.timer is None:self.timer = self.root.after(50, self._poll)
        except (OSError, ValueError) as error:
            self.error = str(error)

    def phase(self, phase, state):
        cue = phase_sound(phase, state)
        if cue:
            self.play(cue, (phase['action_id'], phase['phase'], phase['impact_group_id']))
            return 0 if self.muted else int(self.catalog.durations.get(cue,0)*1000)+60
        return 0

    def ui(self, cue):
        self.serial += 1
        self.play(cue, ('ui', self.serial), 'ui')

    def _poll(self):
        self.timer = None
        if self.closed:return
        try:
            self._reap()
            if self.voices:self.timer = self.root.after(50, self._poll)
        except OSError as error:
            self.error = str(error);self.stop()

    def stop(self):
        if self.timer is not None:
            self.root.after_cancel(self.timer);self.timer = None
        for _, backend in self.voices:
            try:backend.stop()
            except OSError as error:self.error = str(error)
        self.voices.clear()

    def set_muted(self, muted):
        self.muted = bool(muted)
        if self.muted:self.stop()

    def close(self):
        self.closed = True;self.stop()

    def control(self, parent):
        import tkinter as tk
        if not hasattr(self, 'mute_var'):self.mute_var = tk.BooleanVar(master=self.root, value=self.muted)
        widget = tk.Checkbutton(parent, text='効果音をミュート', variable=self.mute_var,
            command=lambda:self.set_muted(self.mute_var.get()), bg='#111827', fg='#94a3b8', selectcolor='#1e293b')
        widget.pack(side='left', padx=6)
        return widget
