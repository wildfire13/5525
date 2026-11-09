"""Direct bridge checks for live battle formation rules (display text retired)."""
import json
from pathlib import Path
from test_current_fixture import current_campaign
import unittest
from bridge_test_session import Session

class CampaignFormationTests(unittest.TestCase):
    def setUp(self):
        self.bridge=Session();self.addCleanup(self.bridge.close)
        current_campaign(self.bridge)
        for action,args in [('depart',['north']),('travel',['safe']),('begin',[])]:
            self.assertTrue(self.bridge.call(op='campaign',action=action,args=args)['ok'])
    def test_live_boost_readonly_until_porter_act(self):
        data=self.bridge.call(op='view')
        for _ in range(10):
            if data['state']['actor']=='porter':break
            data=self.bridge.call(op='act',kind='guard')
        self.assertEqual(data['state']['actor'],'porter')
        data=self.bridge.call(op='act',kind='skill',target='porter')
        self.assertTrue(data['ok']);self.assertTrue(data['boosted']['ally'])
    def test_second_porter_cannot_complete_a_guard_slot_in_live_bridge_view(self):
        bridge=Session();self.addCleanup(bridge.close)
        fixture=Path(__file__).parent/'test_fixtures'/'porter-formation-two-porters.json'
        with fixture.open(encoding='utf-8') as handle:save=json.load(handle)
        data=bridge.call(op='campaign_load',data=save)
        self.assertTrue(data['ok'],data.get('error'))
        self.assertEqual(data['formationSlots']['ally'],[24,13,33])
        self.assertEqual([(u['id'],u['pos']) for u in data['state']['units'] if u['side']=='ally'][:4],
                         [('porter',22),('porter-2',24),('guard',13),('archer',33)])
        self.assertFalse(data['formed']['ally'],'bridge must use live battle formation rules')
        self.assertTrue(bridge.call(op='campaign',action='deploy',args=['porter-2',14])['ok'])
        data=bridge.call(op='campaign',action='deploy',args=['mage',24])
        self.assertTrue(data['ok'])
        self.assertTrue(data['formed']['ally'],'three living non-Porters complete the formation')

if __name__=='__main__':unittest.main()
