"""Read-only formation label checks against actual bridge state (not GUI)."""
from test_current_fixture import current_campaign
import unittest
from copy import deepcopy
from app import App, Bridge
from campaign_app import campaign_formation_info, TrialBattleApp, CampaignBattleApp

class CampaignFormationTests(unittest.TestCase):
    def setUp(self):
        self.bridge=Bridge();self.addCleanup(self.bridge.close)
        current_campaign(self.bridge)
        for action,args in [('depart',['north']),('travel',['safe']),('begin',[])]:
            self.assertTrue(self.bridge.call(op='campaign',action=action,args=args)['ok'])
        # R04: retained Python label regression resumes an already-started legacy battle.
        saved=self.bridge.call(op='campaign_save')['data']
        saved['state']['battle']['formationVersion']=1
        self.assertTrue(self.bridge.call(op='campaign_load',data=saved)['ok'])
    def test_live_normal_boost_and_broken_formation_are_readonly(self):
        data=self.bridge.call(op='view');before=deepcopy(data)
        text='\n'.join(campaign_formation_info(data))
        self.assertIn('味方: 3/3 ON 攻撃×1.5 / 被ダメ×0.75',text)
        self.assertIn('強化ON: 攻撃×1.75 / 被ダメ×0.65',text)
        self.assertIn('金枠3マス',text);self.assertEqual(data,before)
        for _ in range(10):
            if data['state']['actor']=='porter':break
            data=self.bridge.call(op='act',kind='guard')
        self.assertEqual(data['state']['actor'],'porter')
        data=self.bridge.call(op='act',kind='skill',target='porter')
        self.assertTrue(data['ok']);self.assertTrue(data['boosted']['ally'])
        text='\n'.join(campaign_formation_info(data))
        self.assertIn('味方: 3/3 強化ON 攻撃×1.75 / 被ダメ×0.65',text)
        # Isolated display boundary: a downed occupant is not counted; a stale
        # boosted flag never claims a factor when the engine says formation OFF.
        display=deepcopy(data)
        for u in display['state']['units']:
            if u['side']=='ally' and u['pos']==24:u['hp']=0
        display['formed']['ally']=False
        self.assertIn('味方: 2/3 OFF 攻撃×1 / 被ダメ×1','\n'.join(campaign_formation_info(display)))
    def test_enemy_factors_are_side_specific(self):
        data=self.bridge.call(op='view');data['formed']={'ally':False,'enemy':True}
        data['boosted']={'ally':False,'enemy':True}
        text='\n'.join(campaign_formation_info(data))
        self.assertIn('強化ON 攻撃×1.75 / 被ダメ×0.65',text)
        self.assertIn('味方: 3/3 OFF 攻撃×1 / 被ダメ×1',text)
    def test_trial_base_comparison_is_conditional(self):
        data=self.bridge.call(op='view');data['trial']={'isolated':True}
        text='\n'.join(campaign_formation_info(data))
        self.assertIn('陣形OFF同士なら基礎ATK比較',text)
        self.assertIn('味方: 3/3 ON',text)
        for shell in (TrialBattleApp, CampaignBattleApp):
            app=shell.__new__(shell);app.data=data
            self.assertEqual(app.formation_info(),campaign_formation_info(data))
    def test_legacy_display_is_unchanged(self):
        a=App.__new__(App);a.data={'formed':{'ally':True,'enemy':False},'boosted':{}}
        self.assertEqual(a.formation_info(),['陣形: 味方ON / 敵OFF'])

if __name__=='__main__':unittest.main()
