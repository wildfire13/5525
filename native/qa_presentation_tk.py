"""Real Tk widget/timer checks; explicit isolated fixtures, no user save writes."""
import json
import time
import tempfile
from pathlib import Path
from PIL import Image
from portraits import PortraitImages
from types import SimpleNamespace
from app import App, Bridge, tk


def pump(root, predicate, timeout=20):
    deadline = time.monotonic() + timeout
    owner = root._root();errors = [];handler = owner.report_callback_exception
    owner.report_callback_exception = lambda *args: errors.append(str(args))
    try:
        while predicate():
            root.update()
            assert not errors, errors
            if time.monotonic() > deadline:
                raise AssertionError('Tk phase timeout')
            time.sleep(.005)
    finally:
        owner.report_callback_exception = handler


def main():
    root = tk.Tk(); root.withdraw()
    directory=tempfile.TemporaryDirectory()
    image_path=Path(directory.name)/"assigned.png"
    Image.new("RGBA",(80,40),(40,170,80,200)).save(image_path)
    images=PortraitImages(root,Path(directory.name)/"copies")
    images.assign("archer",image_path)
    bridge = Bridge(); errors = []; ticks = []; frames = []; moves = []
    root.report_callback_exception = lambda *args: errors.append(str(args))
    try:
        bridge.call(op='campaign_start')
        saved = bridge.call(op='campaign_save')['data'];saved['state']['location'] = 'east'
        bridge.call(op='campaign_load', data=saved)
        bridge.call(op='campaign', action='trial', args=['archer', 'twin-bow'])
        window = tk.Toplevel(root);window.attributes('-alpha', 0)
        app = App(window, bridge=bridge, images=images);app.music.set_muted(True);app.voice.set_muted(True)
        se_started=[]
        factory=app.sounds.factory
        def se_factory():
            backend=factory();start=backend.start
            def record_start(path):
                se_started.append(path.name);start(path)
            backend.start=record_start
            return backend
        app.sounds.factory=se_factory
        draw = app.draw
        def record_draw():
            draw()
            item=app.canvas.find_withtag('portrait:archer')[0]
            assert app.canvas.itemcget(item,'image')==str(images.portrait('archer'))
            p = app.data.get('presentation')
            if p:
                frames.append((p['phase'], p['actor_id'], p['unit_id'], {u['id']:u['hp'] for u in app.data['state']['units']}))
        app.draw = record_draw
        move = app.canvas.move
        def record_move(tag, x, y):
            if x or y:moves.append((app.data['presentation']['phase'], tag, x, y))
            return move(tag, x, y)
        app.canvas.move = record_move
        def tick():
            ticks.append(time.monotonic())
            if window.winfo_exists():root.after(20, tick)
        tick()
        app.set_mode('skill')
        for p in [25,15]:app.click_cell(SimpleNamespace(x=p%10*74+30,y=p//10*74+30))
        app.confirm.invoke()
        assert app.presentation.busy
        # A redraw mid-shake must keep the custom portrait and not accumulate offset.
        window.after(65,draw)
        window.after(125,draw)
        phase0 = bridge.call(op='view')['state']
        for _ in range(4):app.commit();app.cancel();app.reset();app.set_mode('guard')
        assert bridge.call(op='view')['state'] == phase0
        assert str(app.confirm.cget('state')) == 'disabled'
        assert not bridge.call(op='campaign_save')['ok']
        pump(root, lambda: app.presentation.busy)
        assert [f[0] for f in frames] == ['action','hurt','hurt','settled'], frames
        assert frames[0][3]['enemy-guard'] > frames[1][3]['enemy-guard']
        assert frames[1][3]['enemy-archer'] > frames[2][3]['enemy-archer']
        assert {tag for phase,tag,_,_ in moves if phase=='action'} == {'portrait:archer'}
        assert {tag for phase,tag,_,_ in moves if phase=='hurt'} == {'portrait:enemy-guard','portrait:enemy-archer'}
        assert app.data['state']['actions'] == 1
        assert se_started==['attack.wav','hit.wav'],se_started
        unit0=app.data['state']['units'][0]
        assert app.canvas.coords('portrait:'+unit0['id'])==[unit0['pos']%10*74+37,unit0['pos']//10*74+31]
        # Exact threshold and healing back across it, on board and details.
        unit=app.data['state']['units'][0];unit['max']=100
        for hp, colour, weight in [(25,'#f8fafc','normal'),(24,'#ef4444','bold'),(26,'#f8fafc','normal')]:
            unit['hp']=hp;app.draw()
            item=app.canvas.find_withtag('hp:'+unit['id'])[0]
            assert app.canvas.itemcget(item,'fill') == colour
            assert weight in app.canvas.itemcget(item,'font')
            assert bool(app.info.tag_ranges('low_hp')) == (hp==24)
        app.data=bridge.call(op='view')
        app.perform_action('attack','enemy-guard')
        assert app.presentation.busy
        window.destroy();root.update()
        final=bridge.call(op='view')
        assert not final.get('presentation') and final['state']['actions']==2
        assert not errors, errors
        assert len(ticks)>30
        print(json.dumps({'passed':True,'phases':[f[:3] for f in frames[:4]],'ticks':len(ticks),'shake_samples':len(moves),'hp_boundary':True,'close_settled_once':True,'assigned_portrait_preserved_during_shake':True,'actual_phase_se':se_started[:2],'callback_errors':errors}))
    finally:
        root.destroy();bridge.close();directory.cleanup()


if __name__=='__main__':main()
