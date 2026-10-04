"""Real Tk geometry regression at 1210x820; no screenshot/human review claim."""
import copy
import json
from pathlib import Path
from unittest.mock import Mock, patch
from app import App, Bridge, tk
from campaign_app import CampaignBattleApp, TrialBattleApp


report = {'kind': 'real mapped transparent Tk geometry, default 1210x820', 'cases': []}
root = tk.Tk()
root.withdraw()
bridge = Bridge()
try:
    for kind in ('battle', 'campaign', 'trial'):
        if kind == 'battle':
            bridge.call(op='reset')
        else:
            bridge.call(op='campaign_start')
            if kind == 'trial':
                saved = bridge.call(op='campaign_save')['data']
                saved['state']['location'] = 'east'
                assert bridge.call(op='campaign_load', data=saved)['ok']
                assert bridge.call(op='campaign', action='trial', args=['guard', 'sword-wood'])['ok']
            else:
                for action, args in [('depart', ['east']), ('travel', ['safe']), ('begin', [])]:
                    assert bridge.call(op='campaign', action=action, args=args)['ok']
        window = tk.Toplevel(root)
        window.withdraw()
        window.attributes('-alpha', 0)
        voice = Mock()
        voice.preferences = {'muted': True}
        try:
            with patch('app.VoicePlayer', return_value=voice):
                cls = {'battle': App, 'campaign': CampaignBattleApp, 'trial': TrialBattleApp}[kind]
                kwargs = {'on_return': Mock()} if kind == 'trial' else {}
                app = cls(window, bridge=bridge, music=Mock(), **kwargs)
            window.deiconify()
            window.update()
            assert (window.winfo_width(), window.winfo_height()) == (1210, 820)
            for lines in (1, 3, 6):
                app.queue.config(text='\n'.join(['行動順: 味方 槌戦士（仮） → 敵ヒーラー → 味方 ポーター'] * lines))
                window.update()
                footer = app.confirm.master
                buttons = footer.winfo_children()
                for button in buttons:
                    assert button.winfo_height() >= button.winfo_reqheight(), (kind, lines, button.cget('text'))
                    assert button.winfo_width() >= button.winfo_reqwidth()
                    assert button.winfo_x() >= 0 and button.winfo_x() + button.winfo_width() <= footer.winfo_width()
                assert footer.winfo_y() + footer.winfo_height() <= window.winfo_height()
                report['cases'].append({'mode': kind, 'queue_lines': lines,
                    'confirm_height': app.confirm.winfo_height(), 'return_height': app.return_button.winfo_height(),
                    'return_requested': app.return_button.winfo_reqheight(), 'footer_bottom': footer.winfo_y() + footer.winfo_height()})
            before = copy.deepcopy(app.data['state'])
            app.set_mode('guard')
            cancel = next(w for w in footer.winfo_children() if w.cget('text').startswith('取消'))
            cancel.invoke()
            assert bridge.call(op='view')['state'] == before
            app.set_mode('guard')
            app.confirm.invoke()
            assert app.data['ok'] and app.data['state']['actions'] == before['actions'] + 1
        finally:
            window.destroy()
        if kind == 'trial':
            assert bridge.call(op='campaign', action='endTrial')['ok']
    report['passed'] = True
finally:
    root.destroy()
    bridge.close()
    Path(__file__).with_name('qa-battle-layout-tk-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
print(json.dumps(report, ensure_ascii=False))
