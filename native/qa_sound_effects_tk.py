"""Actual eight WAVs through independent waveOut handles + BGM and character voice."""
import json
from app import tk
from music import MusicPlayer
from voice import VoicePlayer
from sound_effects import SoundPlayer, CUES


def main():
    root=tk.Tk();root.withdraw()
    music=MusicPlayer(root);voice=VoicePlayer(root);sounds=SoundPlayer(root)
    errors=[];ticks=[];played=[]
    root.report_callback_exception=lambda *args:(errors.append(str(args)),root.quit())
    assert not sounds.catalog.error and set(sounds.catalog.clips)==CUES
    music.select('battle2');music_handle=music.backend.handle.value
    queue=iter(sorted(CUES))
    def tick():ticks.append(1);root.after(20,tick)
    def next_sound():
        assert music.backend.handle.value==music_handle and music.backend.playing()
        cue=next(queue,None)
        if cue is None:finish();return
        sounds.play(cue,('audition',cue),'ui' if cue in ('confirm','cancel') else 'gameplay')
        assert sounds.voices[-1][1].playing()
        played.append(cue)
        if cue=='attack':
            voice.play_events([{'character_id':'guard','cue':'attack'}])
            assert voice.playing and sounds.voices[-1][1].playing()
        root.after(1100,next_sound)
    def finish():
        for i in range(6):sounds.play('victory',('limit',i))
        for i in range(3):sounds.ui('cancel')
        assert len(sounds.voices)<=5
        voice.play_events([{'character_id':'mage','cue':'skill:mage'}])
        sounds.set_muted(True)
        assert not sounds.voices and voice.playing and music.backend.playing()
        sounds.set_muted(False);sounds.ui('confirm')
        voice.set_muted(True);assert sounds.voices[-1][1].playing() and music.backend.playing()
        music.set_muted(True);assert sounds.voices[-1][1].playing()
        sounds.close();assert not sounds.voices and sounds.timer is None
        root.quit()
    try:
        root.after(20,tick);root.after(10,next_sound);root.mainloop()
        assert not errors and not sounds.error and not music.error and not voice.error
        assert len(played)==8 and len(ticks)>100
        print(json.dumps({'passed':True,'real_cues':played,'ui_ticks':len(ticks),'independent_mutes':True,'bounded_pool':True,'release':True,'errors':errors}))
    finally:sounds.close();voice.close();music.close();root.destroy()


if __name__=='__main__':main()
