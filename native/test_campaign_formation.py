"""Direct bridge checks for live battle formation rules (display text retired)."""
import unittest
from bridge_test_session import Session

class CampaignFormationTests(unittest.TestCase):
    def setUp(self):
        self.bridge=Session();self.addCleanup(self.bridge.close)
    def test_live_boost_readonly_until_porter_act(self):
        self.assertTrue(self.bridge.call(op='campaign_start')['ok'])
        for action,args in [('depart',['north']),('travel',['safe']),('begin',[])]:
            self.assertTrue(self.bridge.call(op='campaign',action=action,args=args)['ok'])
        porter='character_yuno'
        data=self.bridge.call(op='view')
        for _ in range(10):
            if data['state']['actor']==porter:break
            data=self.bridge.call(op='act',kind='action_defend')
        self.assertEqual(data['state']['actor'],porter)
        data=self.bridge.call(op='act',kind='action_skill',target=porter)
        self.assertTrue(data['ok']);self.assertTrue(data['boosted']['ally'])
    def test_second_porter_cannot_complete_a_guard_slot_in_live_bridge_view(self):
        bridge=self.bridge
        ids=['character_teo','character_yuno','character_mirei',
             'character_rio','character_merina']
        self.assertTrue(bridge.call(op='campaign_start')['ok'])
        for action,args in [('select',[ids]),('accept',['sluice-bell',ids[0]]),('depart',['east']),('travel',['short'])]:
            data=bridge.call(op='campaign',action=action,args=args)
            self.assertTrue(data['ok'],data.get('error'))
        self.assertEqual(data['formationSlots']['ally'],[24,13,33])
        self.assertEqual([(u['id'],u['pos']) for u in data['state']['units'] if u['side']=='ally'][:4],
                         list(zip(ids[:4],[22,24,13,33])))
        self.assertFalse(data['formed']['ally'],'bridge must use live battle formation rules')
        self.assertTrue(bridge.call(op='campaign',action='deploy',args=[ids[1],14])['ok'])
        data=bridge.call(op='campaign',action='deploy',args=[ids[4],24])
        self.assertTrue(data['ok'])
        self.assertTrue(data['formed']['ally'],'three living non-Porters complete the formation')

if __name__=='__main__':unittest.main()
