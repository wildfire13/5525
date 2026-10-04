"""Real Tk/Node subprocess restart QA with generated images and isolated saves.

Run explicitly: python native/qa_portraits_tk.py [--screenshots DIRECTORY]
Native file-dialog return values are patched; actual Tk buttons are invoked.
"""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

from campaign_app import CampaignApp, CampaignBattleApp, TrialBattleApp, tk
from portraits import resolve_portrait, SAVE_KEY
from PIL import Image, ImageTk


def children(widget):
    for child in widget.winfo_children():
        yield child
        yield from children(child)


def button(widget, text):
    return next(w for w in children(widget) if isinstance(w, tk.Button) and w.cget('text') == text)


def displayed(canvas, photo):
    return any(canvas.type(item) == 'image' and canvas.itemcget(item, 'image') == str(photo)
               for item in canvas.find_all())


def load(app, path):
    with patch('campaign_app.filedialog.askopenfilename', return_value=str(path)), \
         patch('campaign_app.messagebox.askyesno', return_value=True):
        app.load()


def capture(root, directory, name):
    if directory:
        from PIL import ImageGrab
        root.update()
        path = Path(directory)
        path.mkdir(parents=True, exist_ok=True)
        x, y = root.winfo_rootx(), root.winfo_rooty()
        ImageGrab.grab(bbox=(x,y,x+root.winfo_width(),y+root.winfo_height())).save(path / name)


def phase(folder, stage, screenshots):
    root = tk.Tk()
    app = CampaignApp(root)
    app.images.directory = folder / ('store-' + stage)
    app.music.set_muted(True)
    errors = []
    root.report_callback_exception = lambda *error: errors.append(str(error))
    save = folder / 'save.json'
    try:
        if stage == 'create':
            initial = app.bridge.call(op='campaign_save')['data']
            (folder / 'old.json').write_text(json.dumps(initial), encoding='utf-8')
            source = folder / 'face.png'
            Image.new('RGBA', (180, 90), (255, 70, 30, 120)).save(source)
            app.edit_portraits()
            dialog = next(w for w in root.winfo_children() if isinstance(w, tk.Toplevel))
            assign = button(dialog, '画像ファイルを選ぶ')
            # First roster member is guard; select via actual widget default.
            with patch('campaign_app.filedialog.askopenfilename', return_value=str(source)):
                assign.invoke()
            assert app.images.portrait('guard') is not None
            original = app.images.snapshot()
            with patch('campaign_app.filedialog.askopenfilename', return_value=''):
                assign.invoke()
            assert app.images.snapshot() == original
            corrupt = folder / 'corrupt.png'
            corrupt.write_bytes(b'broken')
            with patch('campaign_app.filedialog.askopenfilename', return_value=str(corrupt)):
                assign.invoke()
            assert app.images.snapshot() == original
            capture(dialog, screenshots, 'portrait-editor.png')
            button(dialog, '解除して元画像へ').invoke()
            assert app.images.portrait('guard') is None
            with patch('campaign_app.filedialog.askopenfilename', return_value=str(source)):
                assign.invoke()
            button(dialog, '閉じる').invoke()
            # Same basename and job, different character ID.
            second = folder / 'other' / 'face.png'
            second.parent.mkdir()
            Image.new('RGBA', (90,180), (20,220,80,255)).save(second)
            app.images.assign('guard-2', second)
            with patch('campaign_app.filedialog.asksaveasfilename', return_value=str(save)):
                app.save()
            expected = json.loads(save.read_text(encoding='utf-8'))
            assert len(expected[SAVE_KEY]['characters']) == 2
            assert app.bridge.call(op='campaign_save')['data'] == initial
            # Cancellation does not touch the last successful save.
            before = save.read_bytes()
            with patch('campaign_app.filedialog.asksaveasfilename', return_value=''):
                app.save()
            assert save.read_bytes() == before
            # Remove both sources and normalized copies before the NEW process.
            source.unlink()
            second.unlink()
            for copied in app.images.directory.glob('*.png'):
                copied.unlink()
        else:
            load(app, save)
            assert set(app.images.pngs) == {'guard', 'guard-2'}, app.notice
            photo = app.images.portrait('guard')
            assert (photo.width(), photo.height()) == (48,24)
            assert ImageTk.getimage(photo).getpixel((20,10))[3] == 120
            assert len(list(app.images.directory.glob('*.png'))) == 2
            guard = next(m for m in app.roster() if m['id'] == 'guard')
            assert resolve_portrait(app.images, guard) is photo
            baseline = app.bridge.call(op='campaign_save')['data']
            snapshot = app.images.snapshot()
            for bad_type in ('image', 'game'):
                bad = json.loads(save.read_text(encoding='utf-8'))
                if bad_type == 'image':
                    bad[SAVE_KEY]['characters']['guard']['sha256'] = 'bad'
                else:
                    bad['state']['gold'] = -1
                path = folder / (bad_type + '-bad.json')
                path.write_text(json.dumps(bad), encoding='utf-8')
                load(app, path)
                assert app.images.snapshot() == snapshot
                assert app.bridge.call(op='campaign_save')['data'] == baseline
            # Shop portrait really sits above the character name selector.
            state = copy.deepcopy(baseline)
            state['state']['location'] = 'east'
            app.data = app.bridge.call(op='campaign_load', data=state)
            app.set_page('shop')
            root.update()
            assert app.shop_portrait.cget('image') == str(photo)
            selector = app.shop_portrait.master
            menu = next(w for w in selector.winfo_children() if isinstance(w, tk.OptionMenu))
            assert app.shop_portrait.winfo_rooty() + app.shop_portrait.winfo_height() <= menu.winfo_rooty()
            capture(root, screenshots, 'portrait-shop.png')
            app.select_shop_member('mage')
            assert app.shop_portrait.cget('image') == str(resolve_portrait(app.images, next(m for m in app.roster() if m['id']=='mage')))
            # Shop trial shares ID and image, despite replacement equipment.
            assert app.bridge.call(op='campaign', action='trial', args=['guard','sword-iron-1'])['ok']
            window = tk.Toplevel(root)
            trial = TrialBattleApp(window, app.bridge, lambda: None, images=app.images, music=app.music)
            root.update()
            assert displayed(trial.canvas, photo)
            window.destroy()
            assert app.bridge.call(op='campaign', action='endTrial')['ok']
            # Real deployment and battle retain exactly the same PhotoImage.
            app.data = app.bridge.call(op='campaign_load', data=baseline)
            app.act('depart', 'north')
            app.act('travel', 'safe')
            root.update()
            assert displayed(app.deploy_canvas, photo)
            capture(root, screenshots, 'portrait-deployment.png')
            assert app.bridge.call(op='campaign', action='begin', args=[])['ok']
            window = tk.Toplevel(root)
            battle = CampaignBattleApp(window, bridge=app.bridge, images=app.images, music=app.music)
            root.update()
            assert displayed(battle.canvas, photo)
            capture(window, screenshots, 'portrait-battle.png')
            window.destroy()
            # Old version-one save restores default graphics; new game also clears.
            load(app, folder / 'old.json')
            assert not app.images.pngs
            assert resolve_portrait(app.images, guard) is app.images[guard['image']]
            load(app, save)
            with patch('campaign_app.messagebox.askyesno', return_value=True):
                app.restart()
            assert not app.images.pngs
        root.update()
        assert not errors, errors
    finally:
        app.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--phase', choices=['create','reload'])
    parser.add_argument('--folder')
    parser.add_argument('--screenshots')
    args = parser.parse_args()
    if args.phase:
        phase(Path(args.folder), args.phase, args.screenshots)
        print('PASS ' + args.phase)
    else:
        report = {'kind':'real Tk widgets + Node; separate processes; generated fixtures', 'phases':[]}
        with tempfile.TemporaryDirectory(prefix='5525-portraits-') as temporary:
            for stage in ('create','reload'):
                command = [sys.executable, __file__, '--phase', stage, '--folder', temporary]
                if args.screenshots:
                    command += ['--screenshots', args.screenshots]
                result = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', timeout=60)
                report['phases'].append({'stage':stage, 'passed':result.returncode==0,
                                         'stdout':result.stdout, 'stderr':result.stderr})
                if result.returncode:
                    break
        report['passed'] = len(report['phases']) == 2 and all(p['passed'] for p in report['phases'])
        Path(__file__).with_name('qa-portraits-tk-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(report,ensure_ascii=False))
        raise SystemExit(0 if report['passed'] else 1)
