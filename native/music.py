"""Optional provisional BGM, independent of the WinSound character-voice channel."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import uuid
import wave
from wave_audio import WaveOutput

ASSETS = Path(__file__).resolve().parent / 'assets' / 'music'
LOCATIONS = {'astaris', 'north', 'east', 'west', 'south'}


def scene_track(data):
    """Unassigned road/camp/deployment screens are silent; arrival uses destination."""
    state = data.get('state') or {}
    campaign = data.get('campaign')
    if data.get('trial'):
        return campaign.get('location') if state.get('result') and campaign else 'battle2'
    if campaign:
        phase = campaign.get('phase')
        if phase == 'battle':
            return None if state.get('result') else 'battle2'
        location = (data.get('journey') or {}).get('destination') if phase == 'arrival' else campaign.get('location')
        if phase in {'town', 'result', 'prepare', 'arrival'} and location in LOCATIONS:
            return location
        return None
    return 'battle2' if state and not state.get('deploying') and not state.get('result') else None


class MusicCatalog:
    def __init__(self, directory=ASSETS):
        self.tracks, self.error = {}, None
        base = Path(directory).resolve()
        try:
            data = json.loads((base / 'manifest.json').read_text(encoding='utf-8-sig'))
            if data['schema_version'] != 1:
                raise ValueError('Unsupported BGM manifest')
            if data['playback']['loop_entire_file'] is not True:
                raise ValueError('Only verified whole-file BGM loops are supported')
            indexed = {}
            for item in data['tracks']:
                key = item['id']
                path = (base / item['filename']).resolve()
                if (key in indexed or not path.is_relative_to(base)
                        or path.suffix.lower() != '.wav' or not path.is_file()):
                    raise ValueError('Invalid BGM track: ' + str(key))
                raw = path.read_bytes()
                if len(raw) != item['size_bytes'] or hashlib.sha256(raw).hexdigest() != item['sha256']:
                    raise ValueError('BGM integrity mismatch: ' + key)
                with wave.open(str(path), 'rb') as wav:
                    if (wav.getcomptype() != 'NONE' or wav.getnframes() != item['frames']
                            or wav.getframerate() != item['sample_rate_hz']
                            or wav.getnchannels() != item['channels']
                            or wav.getsampwidth() * 8 != item['bits_per_sample']
                            or item['loop_start_frame'] != 0
                            or item['loop_end_frame_exclusive'] != wav.getnframes()
                            or wav.getnframes() <= 0):
                        raise ValueError('BGM format/loop mismatch: ' + key)
                indexed[key] = path
            routes = data['routes']
            if set(routes['locations']) != LOCATIONS:
                raise ValueError('Expected all five BGM location routes')
            self.tracks = {location: indexed[track] for location, track in routes['locations'].items()}
            self.tracks['battle2'] = indexed[routes['battle']]
        except (OSError, ValueError, TypeError, KeyError, AttributeError, wave.Error, EOFError) as error:
            self.tracks.clear()
            self.error = str(error)


class WindowsMusic:
    """MCI owns its own device alias; never uses/stops WinSound's voice channel."""
    def __init__(self):
        self.alias = 'bgm5525_' + uuid.uuid4().hex
        self.opened = False
        self.dll = ctypes.WinDLL('winmm')
        self.dll.mciSendStringW.argtypes = [ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint, ctypes.c_void_p]
        self.dll.mciSendStringW.restype = ctypes.c_uint

    def command(self, command):
        result = ctypes.create_unicode_buffer(256)
        error = self.dll.mciSendStringW(command, result, len(result), None)
        if error:
            raise OSError('BGM device error ' + str(error))
        return result.value

    def start(self, path):
        self.stop()
        if '"' in str(path):
            raise ValueError('Invalid audio path')
        self.command(f'open "{path}" alias {self.alias}')
        self.opened = True
        try:
            self.restart()
        except OSError:
            self.stop()
            raise

    def restart(self):
        self.command(f'play {self.alias} from 0')  # No wait: audio does not block Tk.

    def playing(self):
        return self.command(f'status {self.alias} mode') == 'playing'

    def stop(self):
        if self.opened:
            self.command(f'close {self.alias}')
            self.opened = False


def default_backend():
    if os.name == 'nt':
        try:
            return WaveOutput()
        except OSError:
            pass
    return None


class MusicPlayer:
    def __init__(self, root, catalog=None, backend=None):
        self.root = root
        self.catalog = catalog if catalog is not None else MusicCatalog()
        self.backend = backend if backend is not None else default_backend()
        self.requested = self.current = None
        self.muted = False
        self.closed = False
        self.timer = None
        self.error = None
        root.bind('<Destroy>', lambda event: self.close() if event.widget is root else None, add='+')

    def sync(self, data):
        self.select(scene_track(data))

    def select(self, key):
        if self.closed or key == self.requested:
            return
        self.requested = key
        self._apply()

    def stop(self):
        if self.timer is not None:
            self.root.after_cancel(self.timer)
            self.timer = None
        if self.backend:
            try:
                self.backend.stop()
            except OSError as error:
                self.error = str(error)
        self.current = None

    def _apply(self):
        self.stop()
        path = self.catalog.tracks.get(self.requested)
        if self.closed or self.muted or not path or not self.backend:
            return
        try:
            self.backend.start(path)
            self.current = self.requested
            if getattr(self.backend, 'hardware_loop', False) is not True:
                self.timer = self.root.after(100, self._poll)
        except (OSError, ValueError) as error:
            self.error = str(error)
            self.stop()

    def _poll(self):
        self.timer = None
        if self.closed or self.muted or self.current is None:
            return
        try:
            if not self.backend.playing():
                self.backend.restart()
            if getattr(self.backend, 'hardware_loop', False) is not True:
                self.timer = self.root.after(100, self._poll)
        except OSError as error:
            self.error = str(error)
            self.stop()

    def set_muted(self, muted):
        if self.muted != bool(muted):
            self.muted = bool(muted)
            self._apply()

    def close(self):
        self.closed = True
        self.stop()

    def control(self, parent):
        import tkinter as tk
        if not hasattr(self, 'mute_var'):
            self.mute_var = tk.BooleanVar(master=self.root, value=self.muted)
        control = tk.Checkbutton(parent, text='BGMをミュート', variable=self.mute_var,
                                 command=lambda: self.set_muted(self.mute_var.get()),
                                 bg='#111827', fg='#94a3b8', selectcolor='#1e293b')
        control.pack(side='left', padx=6)
        return control
