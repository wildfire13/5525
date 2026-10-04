"""Independent Windows PCM stream; device loops buffers without Tk restarts.

WAVEHDR loop flags: https://learn.microsoft.com/windows/win32/api/mmeapi/ns-mmeapi-wavehdr
Buffers remain alive until reset/unprepare/close succeeds. No Python callback runs
on the audio thread. Each instance owns only its own waveOut handle.
"""
import ctypes as C
import wave


class WaveFormat(C.Structure):
    _pack_ = 2
    _fields_ = [('tag', C.c_uint16), ('channels', C.c_uint16),
                ('rate', C.c_uint32), ('bytes_per_second', C.c_uint32),
                ('align', C.c_uint16), ('bits', C.c_uint16), ('extra', C.c_uint16)]


class WaveHeader(C.Structure):
    _fields_ = [('data', C.c_void_p), ('length', C.c_uint32),
                ('recorded', C.c_uint32), ('user', C.c_size_t),
                ('flags', C.c_uint32), ('loops', C.c_uint32),
                ('next', C.c_void_p), ('reserved', C.c_size_t)]


# Only used on catastrophic driver cleanup failures: never free queued memory.
_retained = []


class WaveOutput:
    hardware_loop = True

    def __init__(self, loop=True, dll=None):
        self.loop = loop
        self.handle = C.c_void_p()
        self.buffer = self.header = None
        self.prepared = False
        self.dll = dll if dll is not None else C.WinDLL('winmm')
        signatures = {
            'waveOutOpen': [C.POINTER(C.c_void_p), C.c_uint32, C.POINTER(WaveFormat), C.c_size_t, C.c_size_t, C.c_uint32],
            'waveOutPrepareHeader': [C.c_void_p, C.POINTER(WaveHeader), C.c_uint32],
            'waveOutWrite': [C.c_void_p, C.POINTER(WaveHeader), C.c_uint32],
            'waveOutUnprepareHeader': [C.c_void_p, C.POINTER(WaveHeader), C.c_uint32],
            'waveOutReset': [C.c_void_p], 'waveOutClose': [C.c_void_p],
        }
        for name, args in signatures.items():
            fn = getattr(self.dll, name)
            fn.argtypes, fn.restype = args, C.c_uint32

    def _call(self, name, *args):
        error = getattr(self.dll, name)(*args)
        if error:
            raise OSError(name + ' error ' + str(error))

    def start(self, path):
        self.stop()
        with wave.open(str(path), 'rb') as wav:
            if wav.getcomptype() != 'NONE':
                raise ValueError('PCM audio required')
            channels, width, rate = wav.getnchannels(), wav.getsampwidth(), wav.getframerate()
            raw = wav.readframes(wav.getnframes())
        if not raw:
            raise ValueError('Empty audio')
        fmt = WaveFormat(1, channels, rate, rate * channels * width, channels * width, width * 8, 0)
        self._call('waveOutOpen', C.byref(self.handle), 0xffffffff, C.byref(fmt), 0, 0, 0)
        try:
            self.buffer = C.create_string_buffer(raw)
            self.header = WaveHeader(data=C.addressof(self.buffer), length=len(raw))
            self._call('waveOutPrepareHeader', self.handle, C.byref(self.header), C.sizeof(self.header))
            self.prepared = True
            if self.loop:
                self.header.flags |= 4 | 8  # WHDR_BEGINLOOP | WHDR_ENDLOOP
                self.header.loops = 0xffffffff
            self._call('waveOutWrite', self.handle, C.byref(self.header), C.sizeof(self.header))
        except Exception:
            self.stop()
            raise

    def playing(self):
        return bool(self.handle.value and self.header is not None and not self.header.flags & 1)

    @property
    def opened(self):
        return bool(self.handle.value)

    def stop(self):
        if not self.handle.value:
            return
        self._call('waveOutReset', self.handle)
        if self.prepared:
            self._call('waveOutUnprepareHeader', self.handle, C.byref(self.header), C.sizeof(self.header))
            self.prepared = False
        self._call('waveOutClose', self.handle)
        self.handle = C.c_void_p()
        self.buffer = self.header = None

    def __del__(self):
        try:
            self.stop()
        except Exception:
            _retained.append((self.handle, self.buffer, self.header))
