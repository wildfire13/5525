from test_current_fixture import current_campaign
import copy
import unittest
from bridge_test_session import Session

class EquipmentSlotsBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge=Session();self.addCleanup(self.bridge.close)
        current_campaign(self.bridge)
        saved=self.bridge.call(op='campaign_save')['data'];saved['state']['location']='east';saved['state']['gold']=1000
        self.assertTrue(self.bridge.call(op='campaign_load',data=saved)['ok'])

    def test_slot_quote_purchase_and_skill_selection(self):
        preview=self.bridge.call(op='campaign',action='previewGear',args=['mage','breaker-hammer','leftHand'])['previewGear']
        self.assertEqual(preview['slot'],'leftHand');self.assertEqual(preview['oldGearId'],'empty-leftHand')
        self.assertTrue(self.bridge.call(op='campaign',action='buyGear',args=['mage','breaker-hammer','leftHand'])['ok'])
        data=self.bridge.call(op='campaign',action='trial',args=['mage','rest-staff','rightHand'])
        self.assertEqual([x['id'] for x in data['skillset']],['healingCross','knockback'])
        before=data['state']
        selection=self.bridge.call(op='select_skill',skillId='knockback')
        self.assertTrue(selection['ok'])
        self.assertEqual(selection['skillInfo']['cost'],1)
        self.assertEqual(selection['state']['actions'],before['actions'])
        self.assertEqual(selection['state'].get('skillEvents',[]),before.get('skillEvents',[]))
        self.assertEqual([u['mp'] for u in selection['state']['units']],[u['mp'] for u in before['units']])
        bad=self.bridge.call(op='select_skill',skillId='splitShot')
        self.assertFalse(bad['ok'])
        self.assertEqual(bad['state'],selection['state'])
        result=self.bridge.call(op='act',kind='skill',target='enemy-guard');self.assertTrue(result['ok'])
        events=result['skillEvents'];self.assertEqual(events[-1]['skillId'],'knockback')
        self.assertEqual(events[-1]['classification'],'active')

    def test_dual_attack_preview_matches_real_damage_and_range_union(self):
        for gear,slot in [('sword-wood','rightHand'),('staff-wood','leftHand')]:
            self.assertTrue(self.bridge.call(op='campaign',action='buyGear',args=['mage',gear,slot])['ok'])
        for target in ('enemy-guard','enemy-archer'):
            data=self.bridge.call(op='campaign',action='trial',args=['mage','sword-wood','rightHand'])
            self.assertEqual(data['normalAttackReach'],2)
            before=copy.deepcopy(data['state'])
            response=self.bridge.call(op='preview',kind='attack',target=target)
            hit=response['preview']['damagePreview'][0]
            defender=next(u for u in before['units'] if u['id']==target)
            self.assertEqual(hit['damage'],max(0,hit['base']-defender['def']))
            self.assertEqual(self.bridge.call(op='view')['state'],before)
            actual=self.bridge.call(op='act',kind='attack',target=target)
            old=next(u['hp'] for u in before['units'] if u['id']==target)
            now=next(u['hp'] for u in actual['state']['units'] if u['id']==target)
            self.assertEqual(old-now,hit['hpLoss'])
            self.bridge.call(op='campaign',action='endTrial',args=[])

    def test_all_four_new_weapons_in_shop_purchase_and_trial(self):
        cases=[
            ('greatsword-wood',50,1,2,[]),
            ('spear-wood',23,2,1,[]),  # Empty-hand item use is passive.
            ('longspear-wood',34,2,2,[('poleVault','rightHand','longspear-wood',1)]),
            ('javelin-wood',21,1,1,[('spearThrow','rightHand','javelin-wood',1)]),
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

    def test_separate_copy_can_be_bought_into_other_hand(self):
        before=self.bridge.call(op='campaign_save')['data']
        result=self.bridge.call(op='campaign',action='buyGear',args=['guard','sword-wood','leftHand'])
        self.assertTrue(result['ok'])
        after=self.bridge.call(op='campaign_save')['data']
        self.assertEqual(after['state']['characters']['guard']['leftHand'],'sword-wood')
        self.assertEqual(after['state']['characters']['guard']['weapon'],'sword-wood')
        self.assertLess(after['state']['gold'],before['state']['gold'])

if __name__=='__main__':unittest.main()
