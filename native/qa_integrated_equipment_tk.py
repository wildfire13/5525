"""Integrated r3 gear + real Tk presentation/portraits/save/audio routing fixtures."""
import copy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
from unittest.mock import patch
from PIL import Image
from app import App, tk
from campaign_app import CampaignApp
from portraits import SAVE_KEY
from qa_presentation_tk import pump


def main():
    root=tk.Tk();root.withdraw();app=CampaignApp(root)
    app.music.set_muted(True);app.sounds.set_muted(True)
    rows=[]
    with tempfile.TemporaryDirectory() as directory:
        base=Path(directory);app.images.directory=base/'copies'
        image_path=base/'mage.png';Image.new('RGBA',(80,40),(20,150,230,190)).save(image_path)
        app.images.assign('mage',image_path)
        try:
            saved=app.request(op='campaign_save')['data'];saved['state']['location']='east';saved['state']['gold']=5000
            assert app.request(op='campaign_load',data=saved)['ok']
            app.page='shop';app.shop_uid='mage';app.render();root.update_idletasks()
            assert str(app.shop_portrait.cget('image'))==str(app.images.portrait('mage'))
            assert len(next(u for u in app.roster() if u['id']=='mage')['equipmentSlots'])==8
            def buy(gear,slot):
                assert app.request(op='campaign',action='buyGear',args=['mage',gear,slot])['ok'],(gear,slot)
            def action(gear,kind,target,skill=None,expected=None):
                before_save=app.request(op='campaign_save')['data']
                data=app.request(op='campaign',action='trial',args=['mage',gear,'rightHand']);assert data['ok']
                window=tk.Toplevel(root);window.withdraw()
                battle=App(window,bridge=app.bridge,images=app.images,music=app.music,sounds=app.sounds)
                battle.voice.set_muted(True);frames=[];draw=battle.draw
                def record():
                    draw()
                    p=battle.data.get('presentation')
                    if p:frames.append(copy.deepcopy((p,battle.data['state'])))
                    portrait=battle.canvas.find_withtag('portrait:mage')[0]
                    assert battle.canvas.itemcget(portrait,'image')==str(app.images.portrait('mage'))
                battle.draw=record
                if skill:
                    name=next(s['name'] for s in battle.data['skillset'] if s['id']==skill)
                    button=next(w for w in battle.skill_selector.winfo_children() if w.cget('text')==name)
                    before=copy.deepcopy(battle.data['state']);button.invoke()
                    assert battle.active_skill()==skill and battle.data['state']['actions']==before['actions']
                battle.set_mode(kind)
                unit=next(u for u in battle.data['state']['units'] if u['id']==target);old_hp=unit['hp'];pos=unit['pos']
                battle.click_cell(SimpleNamespace(x=pos%10*74+30,y=pos//10*74+30))
                hit=battle.preview['damagePreview'][0]
                if expected is not None:assert hit['hpLoss']==expected,(gear,hit)
                battle.confirm.invoke();assert battle.presentation.busy
                token=battle.data['presentation'];state0=app.bridge.call(op='view')['state']
                battle.select_skill('healingCross')
                assert app.bridge.call(op='view')['state']==state0
                assert not app.bridge.call(op='select_skill',skillId='healingCross')['ok']
                assert all(str(w.cget('state'))=='disabled' for w in battle.skill_selector.winfo_children())
                pump(window,lambda:battle.presentation.busy)
                assert not app.bridge.call(op='presentation_next',id=token['id'],index=token['index'])['ok']
                now=next(u['hp'] for u in battle.data['state']['units'] if u['id']==target)
                assert old_hp-now==hit['hpLoss']
                assert frames[0][0]['phase']=='action'
                assert next(u['hp'] for u in frames[0][1]['units'] if u['id']==target)==old_hp
                hurt=next(p for p,_ in frames if p['phase']=='hurt');assert hurt['actor_id']=='mage' and hurt['unit_id']==target
                cue=frames[0][0]['voiceEvents'][0]
                assert cue=={'character_id':'mage','cue':'skill:'+skill if skill else 'attack'}
                clip=battle.voice.catalog.lookup(cue);assert clip and clip[0].name==('mage_skill_'+skill+'_01.wav' if skill else 'mage_attack_01.wav')
                rows.append({'gear':gear,'skill':skill,'hp_loss':hit['hpLoss'],'voice':clip[0].name,'weapon_parts':len(hit['weapons'])})
                window.destroy();root.update();assert app.request(op='campaign',action='endTrial',args=[])['ok']
                assert app.request(op='campaign_save')['data']==before_save
            buy('sword-wood','rightHand');buy('staff-wood','leftHand')
            action('sword-wood','attack','enemy-guard',expected=40)
            action('sword-wood','attack','enemy-archer',expected=14)
            buy('breaker-hammer','leftHand')
            action('rest-staff','skill','enemy-guard',skill='knockback')
            buy('empty-leftHand','leftHand')
            for gear,damage in [('greatsword-wood',50),('spear-wood',23),('longspear-wood',34),('javelin-wood',21)]:
                action(gear,'attack','enemy-guard',expected=damage)
                buy(gear,'rightHand')
                result=app.request(op='campaign_save')['data'];assert app.request(op='campaign_load',data=result)['ok']
            # Actual Python load path: embedded portrait + a51 legacy battle migrates together.
            legacy=json.loads((Path(__file__).parent/'test_fixtures/campaign-a51a773-battle.json').read_text(encoding='utf-8'))
            legacy[SAVE_KEY]=app.images.snapshot();source=base/'old-save.json';source.write_text(json.dumps(legacy),encoding='utf-8')
            old_bytes=source.read_bytes()
            with patch('campaign_app.filedialog.askopenfilename',return_value=str(source)),patch('campaign_app.messagebox.askyesno',return_value=True):app.load()
            assert source.read_bytes()==old_bytes
            assert app.images.portrait('mage') is not None
            current=app.request(op='campaign_save')['data']
            assert current['state']['characters']['guard']['equipmentRevision']==2
            assert app.request(op='campaign_load',data=current)['ok']
            assert app.request(op='campaign_save')['data']==current
            print(json.dumps({'passed':True,'cases':rows,'shop_portrait':True,'eight_slots':True,'legacy_portrait_save_migrated':True,'old_file_unchanged':True}))
        finally:app.close()


if __name__=='__main__':main()
