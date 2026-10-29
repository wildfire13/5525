"""Real Node-process campaign boundaries. These are not GUI tests."""
from test_current_fixture import current_campaign
import copy
import json
import subprocess
import unittest
from test_journey_bridge import Session, BASE
POLICY = """
const B=require('./campaign-battle.js'),fs=require('node:fs'),s=JSON.parse(fs.readFileSync(0,'utf8'));
const a=s.units.find(u=>u.id===s.actor);B.plan(s,a);let {kind,target}=a.intent;
if(a.job==='porter'){kind=B.legal(s,'skill',a.id)?'skill':'guard';target=kind==='skill'?a.id:null;}
console.log(JSON.stringify({kind,target:target??null}));
"""
class CampaignBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge=Session(5525)
        self.data=current_campaign(self.bridge)
        self.assertTrue(self.data['ok'])
    def tearDown(self):self.bridge.close()
    def action(self,action,*args,ok=True):
        self.data=self.bridge.call(op='campaign',action=action,args=list(args))
        self.assertEqual(self.data['ok'],ok,(action,self.data.get('error')))
        return self.data
    def save(self):
        r=self.bridge.call(op='campaign_save');self.assertTrue(r['ok'],r);return r['data']
    def fight(self):
        self.action('begin')
        for _ in range(250):
            if self.data['state']['result']:break
            r=subprocess.run(['node','-e',POLICY],cwd=BASE,input=json.dumps(self.data['state']),text=True,capture_output=True,check=True)
            self.data=self.bridge.call(op='act',**json.loads(r.stdout));self.assertTrue(self.data['ok'],self.data.get('error'))
        self.assertTrue(self.data['state']['result']);self.action('finishBattle')
    def journey(self,destination,quest=True,owner='porter'):
        if quest:
            self.action('accept',next(q['id'] for q in self.data['campaign']['board'] if q['to']==destination),owner)
            accepted=self.save()['state']['activeQuest']
            self.assertEqual(accepted['cargoOwnerId'],owner)
            self.assertEqual(self.data['campaign']['characters'][owner]['inventory'][accepted['cargoItemId']],1)
        self.action('depart',destination,'convoy')
        for leg in range(2):
            self.action('travel','safe');self.fight()
            self.assertNotEqual((self.data['campaign']['result'] or {}).get('outcome'),'failed')
            if leg==0:self.action('rest');self.action('onward')
        before_arrival=self.save()['state']
        self.action('arrive')
        if quest:
            arrived=self.save()['state']
            self.assertEqual(arrived['phase'],'town');self.assertIsNone(arrived['result'])
            self.assertEqual(arrived['gold'],before_arrival['gold'])
            self.assertEqual(arrived['characters'],before_arrival['characters'])
            self.assertEqual(arrived['activeQuest']['cargoOwnerId'],owner)
            self.assertEqual(arrived['characters'][owner]['inventory'][accepted['cargoItemId']],1)
            pending=self.save();self.action('acknowledge',ok=False);self.assertEqual(self.save(),pending)
            self.action('completeQuest')
            self.assertNotIn(accepted['cargoItemId'],self.data['campaign']['characters'][owner]['inventory'])
            completed=self.save();self.action('completeQuest',ok=False);self.assertEqual(self.save(),completed)
        r=copy.deepcopy(self.data['campaign']['result']);self.action('acknowledge');return r
    def test_accept_requires_explicit_selected_porter(self):
        qid=self.data['campaign']['board'][0]['id'];before=self.save()
        for args in [(qid,),(qid,'guard'),(qid,'porter-2')]:
            self.action('accept',*args,ok=False);self.assertEqual(self.save(),before)
        self.action('select',['guard','porter','porter-2'])
        self.action('accept',qid,'porter-2')
        quest=self.data['campaign']['activeQuest']
        self.assertEqual(quest['cargoOwnerId'],'porter-2')
        self.assertEqual(self.data['campaign']['characters']['porter-2']['inventory'][quest['cargoItemId']],1)
        self.assertNotIn(quest['cargoItemId'],self.data['campaign']['characters']['porter']['inventory'])
        self.assertEqual(self.data['campaign']['phase'],'town')
    def test_reject_and_roundtrip_atomic(self):
        saved=self.save();self.action('buyItem','potion',1,ok=False);self.action('depart','nowhere',ok=False)
        self.assertEqual(self.save(),saved)
        corrupt=copy.deepcopy(saved);corrupt['state']['gold']=-1
        self.assertFalse(self.bridge.call(op='campaign_load',data=corrupt)['ok']);self.assertEqual(self.save(),saved)
        self.data=self.bridge.call(op='campaign_load',data=saved);self.assertTrue(self.data['ok']);self.assertEqual(self.save(),saved)
        log=self.bridge.call(op='export')['data'];self.assertEqual(log['mode'],'campaign');self.assertEqual(log['campaign']['location'],'astaris')
    def test_repeat_trial_inventory_purchase_and_questless(self):
        first=self.journey('east');self.assertGreater(first['gold'],0);snapshot=self.save()
        self.action('trial','mage','hammer-wood');self.assertIsNotNone(self.data['trial']);self.assertEqual(self.data['state']['actor'],'mage')
        self.data=self.bridge.call(op='act',kind='skill',target=25);self.assertTrue(self.data['ok']);self.assertEqual(self.data['state']['units'][0]['equippedSkill'],'stamp')
        self.action('accept','invalid',ok=False);self.action('endTrial');self.assertEqual(self.save(),snapshot)
        self.action('buyGear','mage','hammer-iron-1',ok=False);self.assertEqual(self.save(),snapshot)
        self.action('buyGear','mage','hammer-wood');self.assertEqual(self.data['campaign']['characters']['mage']['weapon'],'hammer-wood')
        self.assertEqual(self.data['campaign']['characters']['mage']['inventory']['staff-wood'],1)
        bought=self.save();self.action('buyGear','mage','hammer-wood',ok=False);self.assertEqual(self.save(),bought)
        self.action('inventoryQuote','mage','staff-wood','equip',None,1,'rightHand')
        quote=self.data['inventoryQuote'];self.assertTrue(quote['ok'])
        gold=self.data['campaign']['gold']
        self.action('inventoryAction','mage','staff-wood','equip',None,1,'rightHand',quote['token'])
        self.assertEqual(self.data['campaign']['gold'],gold)
        self.assertEqual(self.data['campaign']['characters']['mage']['inventory']['hammer-wood'],1)
        second=self.journey('astaris');self.assertGreater(second['gold'],0)
        self.assertEqual(self.data['campaign']['completed'],2)
        before=self.save()['state'];selected=before['selected']
        third=self.journey('north',quest=False);self.assertEqual((third['gold'],third['xp'],third['outcome']),(0,0,'travel'))
        after=self.save()['state']
        self.assertEqual(after['xp'],before['xp']);self.assertEqual(after['level'],before['level'])
        for uid,person in before['characters'].items():
            self.assertEqual(after['characters'][uid]['xp'],person['xp']+(40 if uid in selected else 0),uid)
        self.assertEqual(after['gold'],before['gold']+16);self.assertEqual(after['completed'],2)
        saved=self.save();self.action('arrive',ok=False);self.assertEqual(self.save(),saved);self.assertTrue(self.data['campaign']['shop']);self.assertTrue(all(g['slot'] in ['accessory1','accessory2'] for g in self.data['campaign']['shop']))
    def test_malformed_battle_save_does_not_replace_live_state(self):
        generator = r"""
const C=require('./campaign.js'); let seed=0;
const rng=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
for(let i=0;i<100;i++){const s=C.create();C.depart(s,'north');C.travel(s,'short',rng);C.begin(s);
if(s.battle.units.some(u=>u.side==='enemy'&&u.job==='scout'&&u.intent.kind==='skill')){console.log(C.serialize(s));break;}}
"""
        result=subprocess.run(['node','-e',generator],cwd=BASE,text=True,capture_output=True,check=True)
        valid=json.loads(result.stdout); live=self.save()
        for field in ('path','destination'):
            bad=copy.deepcopy(valid)
            scout=next(u for u in bad['state']['battle']['units'] if u['side']=='enemy' and u['job']=='scout' and u['intent']['kind']=='skill')
            del scout['intent'][field]
            self.assertFalse(self.bridge.call(op='campaign_load',data=bad)['ok'])
            self.assertEqual(self.save(),live)
        for field in ('name','image','icon'):
            bad=copy.deepcopy(valid);del bad['state']['battle']['units'][0][field]
            self.assertFalse(self.bridge.call(op='campaign_load',data=bad)['ok'])
            self.assertEqual(self.save(),live)
        self.data=self.bridge.call(op='campaign_load',data=valid);self.assertTrue(self.data['ok'])
        for _ in range(3):
            self.data=self.bridge.call(op='act',kind='guard',target=None);self.assertTrue(self.data['ok'])
    def test_restart_mid_journey(self):
        self.action('depart','north');self.action('travel','safe');saved=self.save()
        self.bridge.close();self.bridge=Session(22);self.data=self.bridge.call(op='campaign_load',data=saved)
        self.assertTrue(self.data['ok'],self.data);self.assertEqual(self.save(),saved)
        self.action('deployment_reset');self.fight();self.assertEqual(self.data['campaign']['phase'],'camp')
if __name__=='__main__':unittest.main()
