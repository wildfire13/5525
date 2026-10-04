"""Explicit Windows Tk smoke test. Uses real widgets, not screenshot/human QA.
Run separately: python native/qa_equipment_tk.py. Isolated fixtures, no user saves.
"""
import json
from pathlib import Path
from types import SimpleNamespace
from qa_presentation_tk import pump
from app import App, Bridge, tk

rows = [('archer','twin-bow','east','skill',[25,15]),
        ('mage','battleline-shield','east','skill',[14,34]),
        ('mage','rest-staff','east','skill',[24]),
        ('guard','undertow-sword','east','skill',[25]),
        ('mage','sharing-tome','east','skill',[14]),
        ('mage','return-ring-1','west','return',[3]),
        ('mage','pioneer-gloves-1','west','move',[21])]
report={'kind':'real Tk hidden-window smoke; not human visual/playtest review','cases':[]}
bridge=Bridge()
root=tk.Tk();root.withdraw()
try:
    for uid,gear,location,mode,positions in rows:
        bridge.call(op='campaign_start')
        saved=bridge.call(op='campaign_save')['data'];saved['state']['location']=location
        assert bridge.call(op='campaign_load',data=saved)['ok']
        assert bridge.call(op='campaign',action='trial',args=[uid,gear])['ok']
        window=tk.Toplevel(root);window.withdraw()
        try:
            app=App(window,bridge=bridge)
            app.set_mode(mode)
            for pos in positions:
                app.click_cell(SimpleNamespace(x=pos%10*74+30,y=pos//10*74+30))
                window.update_idletasks()
            assert str(app.confirm.cget('state'))=='normal'
            app.commit();pump(window, lambda: app.presentation.busy);window.update_idletasks()
            assert app.data['ok']
            assert app.data['state']['actions']==1
            report['cases'].append({'gear':gear,'passed':True,'canvasItems':len(app.canvas.find_all())})
        finally:
            window.destroy()
        assert bridge.call(op='campaign',action='endTrial')['ok']
    report['passed']=True
finally:
    root.destroy();bridge.close()
    Path(__file__).with_name('qa-equipment-tk-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
