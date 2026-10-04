"""Optional exact-character WAV cues; no network, fallback voices or audio installs."""
from collections import deque
import hashlib
import json
from pathlib import Path
import wave

try:
    import winsound
except ImportError:
    winsound = None

ASSETS = Path(__file__).resolve().parent / 'assets' / 'voices'
# Session-wide preference survives closing/reopening battle and trial windows.
PREFERENCES = {'muted': False}


class VoiceCatalog:
    def __init__(self, directory=ASSETS):
        self.directory = Path(directory).resolve()
        self.clips = {}
        self.error = None
        try:
            data = json.loads((self.directory / 'manifest.json').read_text(encoding='utf-8-sig'))
            if data['schema_version'] != 1:
                raise ValueError('Unsupported voice manifest version')
            seen = set()
            for character in data['characters']:
                uid = character['id']
                if uid in seen:
                    raise ValueError('Duplicate voice character')
                seen.add(uid)
                for cue, clip in character['prepared'].items():
                    key = (uid, cue)
                    path = (self.directory / clip['path']).resolve()
                    if not path.is_relative_to(self.directory) or path.suffix.lower() != '.wav':
                        raise ValueError('Voice path must be a WAV inside the voice directory')
                    if hashlib.sha256(path.read_bytes()).hexdigest() != clip['sha256']:
                        raise ValueError('Voice SHA-256 mismatch: ' + uid + '/' + cue)
                    with wave.open(str(path), 'rb') as wav:
                        duration = wav.getnframes() / wav.getframerate()
                        if (wav.getcomptype() != 'NONE' or not 0 < duration <= 30
                                or wav.getframerate() != clip['sample_rate']
                                or wav.getnchannels() != clip['channels']
                                or abs(duration - clip['duration_seconds']) > 0.02):
                            raise ValueError('Voice WAV metadata mismatch: ' + uid + '/' + cue)
                    self.clips[key] = (path, duration)
        except (OSError, ValueError, KeyError, TypeError, AttributeError, wave.Error, EOFError) as error:
            self.clips.clear()
            self.error = str(error)

    def lookup(self, event):
        return self.clips.get((event.get('character_id'), event.get('cue')))


class VoicePlayer:
    """One asynchronous Windows channel; Tk timers sequence a bounded action batch."""
    def __init__(self, root, catalog=None, backend=winsound, preferences=None):
        self.root = root
        self.catalog = catalog if catalog is not None else VoiceCatalog()
        self.backend = backend
        self.preferences = PREFERENCES if preferences is None else preferences
        self.queue = deque()
        self.timer = None
        self.playing = False
        self.closed = False
        self.error = None

    @property
    def available(self):
        return self.backend is not None and bool(self.catalog.clips)

    def stop(self):
        self.queue.clear()
        if self.timer is not None:
            self.root.after_cancel(self.timer)
            self.timer = None
        if self.playing:
            try:
                self.backend.PlaySound(None, 0)
            except (OSError, RuntimeError):
                pass
        self.playing = False

    def set_muted(self, muted):
        self.preferences['muted'] = bool(muted)
        if muted:
            self.stop()

    def play_events(self, events):
        # A fresh action replaces an unfinished batch: no overlapping/backlogged speech.
        self.stop()
        if self.closed or self.preferences['muted'] or not self.available:
            return
        seen = set()
        for event in events[:32]:
            key = (event.get('character_id'), event.get('cue'))
            clip = self.catalog.lookup(event)
            if key not in seen and clip is not None:
                self.queue.append(clip)
                seen.add(key)
        self._next()

    def _next(self):
        self.timer = None
        self.playing = False
        if self.closed or self.preferences['muted'] or not self.queue:
            return
        path, duration = self.queue.popleft()
        try:
            self.backend.PlaySound(str(path), self.backend.SND_FILENAME |
                                   self.backend.SND_ASYNC | self.backend.SND_NODEFAULT)
            self.playing = True
            self.timer = self.root.after(int(duration * 1000) + 60, self._next)
        except (OSError, RuntimeError) as error:
            self.error = str(error)
            self.queue.clear()

    def close(self):
        self.stop()
        self.closed = True
