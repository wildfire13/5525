"""Actual engine phases -> actual SE starts, through real Tk confirmation controls."""
import json
from types import SimpleNamespace
from app import App, Bridge, tk
from qa_presentation_tk import pump


def main():
    root=tk.Tk();root.withdraw();bridge=Bridge();report=[]
    try:
        for case in ('heal','victory','failure'):
            if case=='failure':
                data=bridge.call(op='reset',scenario='porter',presentation=True)
            else:
                bridge.call(op='campaign_start');saved=bridge.call(op='campaign_save')['data']
                saved['state']['location']='east' if case=='heal' else 'west'
                bridge.call(op='campaign_load',data=saved)
                data=bridge.call(op='campaign',action='trial',args=['mage','rest-staff'] if case=='heal' else ['guard','victory-earring-1'])
            assert data['ok']
            window=tk.Toplevel(root);window.withdraw();app=App(window,bridge=bridge)
            app.voice.set_muted(True);app.music.set_muted(True)
            starts=[];factory=app.sounds.factory
            def make():
                backend=factory();start=backend.start
                def record(path):starts.append(path.stem);start(path)
                backend.start=record;return backend
            app.sounds.factory=make
            # Cancelling a real preview produces only UI cancel; no combat progresses.
            app.set_mode('guard');before=bridge.call(op='view')['state'];app.cancel()
            assert starts==['cancel'] and bridge.call(op='view')['state']==before
            starts.clear()
            if case=='failure':app.set_mode('guard')
            else:
                mode='skill' if case=='heal' else 'attack';app.set_mode(mode)
                target=app.data['choices'][mode][0]
                unit=next(u for u in app.data['state']['units'] if u['id']==target)
                p=unit['pos'];app.click_cell(SimpleNamespace(x=p%10*74+30,y=p//10*74+30))
            app.confirm.invoke();assert app.presentation.busy
            pump(window,lambda:app.presentation.busy)
            count=len(starts)
            for _ in range(4):app.draw()
            assert len(starts)==count
            if case=='heal':assert starts==['skill','heal'],starts
            elif case=='victory':assert starts==['attack','hit','victory'],starts
            else:assert starts[-1]=='failure' and starts.count('failure')==1 and 'confirm' not in starts,starts
            assert not app.sounds.error
            report.append({'case':case,'actual_se_starts':starts.copy(),'cancel_no_gameplay':True,'redraw_no_repeat':True})
            window.destroy();root.update()
            assert not app.sounds.voices and app.sounds.timer is None
            if case!='failure':assert bridge.call(op='campaign',action='endTrial')['ok']
        print(json.dumps({'passed':True,'cases':report}))
    finally:root.destroy();bridge.close()


if __name__=='__main__':main()
