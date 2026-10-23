import copy
import unittest
from unittest.mock import Mock
from test_journey_bridge import Session
from app import App

class EquipmentSlotsBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge=Session();self.addCleanup(self.bridge.close)
        self.bridge.call(op='campaign_start')
        saved=self.bridge.call(op='campaign_save')['data'];saved['state']['location']='east';saved['state']['gold']=1000
        self.assertTrue(self.bridge.call(op='campaign_load',data=saved)['ok'])

    def test_slot_quote_purchase_and_skill_selection_controller(self):
        preview=self.bridge.call(op='campaign',action='previewGear',args=['mage','breaker-hammer','leftHand'])['previewGear']
        self.assertEqual(preview['slot'],'leftHand');self.assertEqual(preview['oldGearId'],'empty-leftHand')
        self.assertTrue(self.bridge.call(op='campaign',action='buyGear',args=['mage','breaker-hammer','leftHand'])['ok'])
        data=self.bridge.call(op='campaign',action='trial',args=['mage','rest-staff','rightHand'])
        self.assertEqual([x['id'] for x in data['skillset']],['healingCross','knockback'])
        app=App.__new__(App);app.bridge=self.bridge;app.data=data;app.pending=None;app.porter_confirmation=None;app.draw=Mock();app.preview=None
        before=copy.deepcopy(data['state']);app.select_skill('knockback')
        self.assertTrue(app.data['ok']);self.assertEqual(app.active_skill(),'knockback');self.assertEqual(app.data['skillInfo']['cost'],1)
        self.assertEqual(app.data['state']['actions'],before['actions']);self.assertEqual(app.data['state'].get('skillEvents',[]),before.get('skillEvents',[]))
        self.assertEqual([u['mp'] for u in app.data['state']['units']],[u['mp'] for u in before['units']])
        after=copy.deepcopy(app.data['state']);bad=self.bridge.call(op='select_skill',skillId='splitShot');self.assertFalse(bad['ok']);self.assertEqual(bad['state'],after)
        result=self.bridge.call(op='act',kind='skill',target='enemy-guard');self.assertTrue(result['ok'])
        events=result['skillEvents'];self.assertEqual(events[-1]['skillId'],'knockback')
        self.assertEqual(events[-1]['classification'],'active')

    def test_dual_attack_preview_matches_real_damage_and_range_union(self):
        for gear,slot in [('sword-wood','rightHand'),('staff-wood','leftHand')]:
            self.assertTrue(self.bridge.call(op='campaign',action='buyGear',args=['mage',gear,slot])['ok'])
        for target,expected in [('enemy-guard',40),('enemy-archer',14)]:
            data=self.bridge.call(op='campaign',action='trial',args=['mage','sword-wood','rightHand'])
            self.assertEqual(data['normalAttackReach'],2)
            before=copy.deepcopy(data['state'])
            response=self.bridge.call(op='preview',kind='attack',target=target)
            hit=response['preview']['damagePreview'][0]
            self.assertEqual(hit['damage'],expected)
            self.assertEqual(self.bridge.call(op='view')['state'],before)
            actual=self.bridge.call(op='act',kind='attack',target=target)
            old=next(u['hp'] for u in before['units'] if u['id']==target)
            now=next(u['hp'] for u in actual['state']['units'] if u['id']==target)
            self.assertEqual(old-now,hit['hpLoss'])
            self.bridge.call(op='campaign',action='endTrial',args=[])

    def test_all_four_new_weapons_in_shop_purchase_and_trial(self):
        cases=[
            ('greatsword-wood',50,1,2,[]),
            ('spear-wood',23,2,1,[('itemUse','leftHand','empty-leftHand',1)]),
            ('longspear-wood',34,2,2,[('poleVault','rightHand','longspear-wood',1)]),
            ('javelin-wood',21,3,1,[('itemUse','leftHand','empty-leftHand',1)]),
        ]
        for gear,damage,reach,hands,skills in cases:
            snapshot=self.bridge.call(op='campaign_save')['data']
            data=self.bridge.call(op='campaign',action='trial',args=['mage',gear,'rightHand'])
            self.assertTrue(data['ok'],gear);self.assertEqual(data['normalAttackReach'],reach)
            self.assertEqual([skill['id'] for skill in data['skillset']],[skill[0] for skill in skills],gear)
            self.assertEqual([(skill['id'],source['slot'],source['itemId'],source['level'])
                              for skill in data['skillset'] for source in skill['sources']],skills,gear)
            preview=self.bridge.call(op='preview',kind='attack',target='enemy-guard')['preview']
            self.assertEqual(preview['damagePreview'][0]['base'],damage)
            self.assertTrue(self.bridge.call(op='act',kind='attack',target='enemy-guard')['ok'])
            self.bridge.call(op='campaign',action='endTrial',args=[])
            self.assertEqual(self.bridge.call(op='campaign_save')['data'],snapshot)
            result=self.bridge.call(op='campaign',action='buyGear',args=['mage',gear,'rightHand'])
            self.assertTrue(result['ok'],gear)
            actor=next(c for c in result['campaign']['roster'] if c['id']=='mage')
            left=next(e for e in actor['equipmentSlots'] if e['slot']=='leftHand')
            self.assertEqual(left['occupiedBy'],'rightHand' if hands==2 else None)
            saved=self.bridge.call(op='campaign_save')['data']
            self.assertTrue(self.bridge.call(op='campaign_load',data=saved)['ok'])

    def test_exact_item_cannot_be_bought_into_two_slots(self):
        before=self.bridge.call(op='campaign_save')['data']
        result=self.bridge.call(op='campaign',action='buyGear',args=['guard','sword-wood','leftHand'])
        self.assertFalse(result['ok']);self.assertEqual(self.bridge.call(op='campaign_save')['data'],before)

if __name__=='__main__':unittest.main()
