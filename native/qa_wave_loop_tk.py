"""Real Windows loop crossing and voice coexistence. No capture/hearing claim."""
import ctypes as C
import json
import time
import wave
from app import tk
from music import MusicCatalog, MusicPlayer
from voice import VoicePlayer


def main():
    root=tk.Tk();root.withdraw();music=MusicPlayer(root);voice=VoicePlayer(root)
    errors=[];root.report_callback_exception=lambda *args:errors.append(str(args))
    ticks=[];samples=[];started=time.monotonic()
    path=MusicCatalog().tracks['battle2']
    with wave.open(str(path),'rb') as w:duration=w.getnframes()/w.getframerate()
    music.select('battle2');backend=music.backend
    handle=backend.handle.value;header=backend.header;buffer=backend.buffer
    backend.dll.waveOutGetPosition.argtypes=[C.c_void_p,C.c_void_p,C.c_uint32]
    backend.dll.waveOutGetPosition.restype=C.c_uint32
    def position():
        value=(C.c_uint32*3)(4,0,0)  # TIME_BYTES and MMTIME's 8-byte union
        assert backend.dll.waveOutGetPosition(backend.handle,C.byref(value),C.sizeof(value))==0
        return value[0],value[1]
    def tick():
        now=time.monotonic()-started;ticks.append(now)
        assert backend.playing() and backend.handle.value==handle
        assert backend.header is header and backend.buffer is buffer
        if abs(now-duration)<.25:samples.append((now,*position()))
        if now>duration+1:
            samples.append((now,*position()));root.quit();return
        root.after(20,tick)
    root.after(300,lambda:voice.play_events([{'character_id':'guard','cue':'attack'}]))
    root.after(900,lambda:voice.set_muted(True))
    root.after(20,tick)
    try:
        root.mainloop()
        assert not errors and not music.error and not voice.error
        assert music.timer is None
        assert samples[-1][1]==4 and samples[-1][2]>header.length,(samples[-1],header.length)
        music.set_muted(True);assert not backend.opened
        music.set_muted(False);assert backend.opened and backend.playing()
        music.close();voice.close();assert not backend.opened
        print(json.dumps({'passed':True,'backend':'waveOut single loop buffer','duration_seconds':duration,'ticks':len(ticks),'boundary_samples':samples,'no_tk_loop_restart':True,'voice_coexistence':True,'mute_close_release':True,'errors':errors}))
    finally:music.close();voice.close();root.destroy()


if __name__=='__main__':main()
