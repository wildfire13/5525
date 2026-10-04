"""Explicit real hidden Tk regression for Astra's passive-trial P2; not human QA."""
import copy
import json
from pathlib import Path
from types import SimpleNamespace
from qa_presentation_tk import pump
from app import App, Bridge, tk

report = {'kind': 'real Tk hidden-window passive regression; not human playtest', 'cases': []}
bridge = Bridge()
root = tk.Tk()
root.withdraw()
try:
    for uid in ('guard', 'warrior', 'mage', 'porter'):
        for gear, effect in [('victory-earring-1', 'victoryBreath'), ('lone-ring-1', 'loneWolf')]:
            bridge.call(op='campaign_start')
            saved = bridge.call(op='campaign_save')['data']
            saved['state']['location'] = 'west'
            saved['state']['selected'] = [uid] if uid == 'porter' else [uid, 'porter']
            assert bridge.call(op='campaign_load', data=saved)['ok']
            assert bridge.call(op='campaign', action='trial', args=[uid, gear])['ok']
            window = tk.Toplevel(root)
            window.withdraw()
            try:
                app = App(window, bridge=bridge)
                before = copy.deepcopy(app.data['state'])
                hp, mp = app.actor()['hp'], app.actor()['mp']
                mode = 'guard' if uid == 'porter' else 'attack'
                def select():
                    app.set_mode(mode)
                    if mode == 'attack':
                        app.click_cell(SimpleNamespace(x=5*74+30, y=2*74+30))
                select()
                assert app.pending
                app.cancel()
                assert bridge.call(op='view')['state'] == before
                select()
                app.commit()
                pump(window, lambda: app.presentation.busy)
                window.update_idletasks()
                assert app.data['ok']
                events = app.data.get('skillEvents', [])
                activated = any(e['actorId'] == uid and e['skillId'] == effect for e in events)
                assert activated == (uid != 'porter' or effect == 'victoryBreath')
                if effect == 'victoryBreath':
                    assert app.data['state']['result']
                    hero = next(u for u in app.data['state']['units'] if u['id'] == uid)
                    assert hero['mp'] == mp + 2
                report['cases'].append({'id': uid, 'effect': effect, 'passed': True,
                                        'activated': activated, 'cancel_unchanged': True})
            finally:
                window.destroy()
            assert bridge.call(op='campaign', action='endTrial')['ok']
            assert bridge.call(op='campaign_save')['data'] == saved
    report['passed'] = True
finally:
    root.destroy()
    bridge.close()
    Path(__file__).with_name('qa-passive-trial-tk-report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print(json.dumps(report))
