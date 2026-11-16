"""Real bridge protocol tests, no files or user saves."""
from bridge_current_campaign import GUARD, PORTER, SCOUT, fresh_campaign, trial
import copy
import unittest
from bridge_test_session import Session


class PresentationBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge = Session()
        self.addCleanup(self.bridge.close)
        self.data = trial(self.bridge, SCOUT, 'twin-bow')

    def test_phase_state_save_lock_and_stale_ack(self):
        before = copy.deepcopy(self.data['state'])
        data = self.bridge.call(op='act', kind='skill', target=['enemy-guard', 'enemy-archer'], presentation=True)
        token = data['presentation']
        self.assertEqual(token['phase'], 'action')
        self.assertEqual(data['state']['units'], before['units'])
        for request in [dict(op='act', kind='guard'), dict(op='campaign_save'), dict(op='campaign_start'),
                        dict(op='campaign', action='endTrial'), dict(op='campaign_load', data={}), dict(op='export')]:
            self.assertFalse(self.bridge.call(**request)['ok'])
        next_data = self.bridge.call(op='presentation_next', id=token['id'], index=token['index'])
        self.assertEqual(next_data['presentation']['phase'], 'hurt')
        self.assertFalse(self.bridge.call(op='presentation_next', id=token['id'], index=token['index'])['ok'])
        self.assertEqual(self.bridge.call(op='view')['state'], next_data['state'])
        frames = [token]
        while next_data.get('presentation'):
            p = next_data['presentation']; frames.append(p)
            next_data = self.bridge.call(op='presentation_next', id=p['id'], index=p['index'])
        self.assertEqual([p['phase'] for p in frames], ['action', 'hurt', 'hurt', 'settled'])
        self.assertEqual(next_data['state']['actions'], 1)
        self.assertTrue(self.bridge.call(op='campaign', action='endTrial')['ok'])
        self.assertTrue(self.bridge.call(op='campaign_save')['ok'])

    def test_finish_is_idempotent_and_no_voice_replay(self):
        data = self.bridge.call(op='act', kind='attack', target='enemy-guard', presentation=True)
        token = data['presentation']
        done = self.bridge.call(op='presentation_finish', id=token['id'])
        self.assertTrue(done['ok'])
        self.assertEqual(done['state']['actions'], 1)
        self.assertFalse(self.bridge.call(op='presentation_finish', id=token['id'])['ok'])
        self.assertNotIn('voiceEvents', self.bridge.call(op='view'))
        self.assertEqual(self.bridge.call(op='view')['state'], done['state'])

    def test_opening_enemy_turn_and_save_resume_only_after_completion(self):
        bridge = Session(5525);self.addCleanup(bridge.close)
        fresh_campaign(bridge)
        for action,args in [('select',[[GUARD,PORTER]]),('depart',['east']),
                            ('travel',['safe']),('deploy',[GUARD,4])]:
            self.assertTrue(bridge.call(op='campaign',action=action,args=args)['ok'])
        hp=lambda d:next(u['hp'] for u in d['state']['units'] if u['id']==GUARD)
        initial_hp=hp(bridge.call(op='view'))
        data=bridge.call(op='campaign',action='begin',args=[],presentation=True)
        self.assertEqual(hp(data),initial_hp)
        self.assertFalse(bridge.call(op='campaign_save')['ok'])
        seen=[]
        while data.get('presentation'):
            p=data['presentation'];seen.append(p)
            if p['phase']=='action' and not any(frame['phase']=='hurt' for frame in seen):
                self.assertEqual(hp(data),initial_hp)
            data=bridge.call(op='presentation_next',id=p['id'],index=p['index'])
        self.assertLess(hp(data),initial_hp)
        hit=next(p for p in seen if p['phase']=='hurt')
        self.assertTrue(hit['actor_id'].startswith('enemy-'))
        self.assertEqual(hit['unit_id'],GUARD)
        saved=bridge.call(op='campaign_save')['data']
        loaded=bridge.call(op='campaign_load',data=saved)
        self.assertTrue(loaded['ok']);self.assertEqual(loaded['state'],data['state'])


if __name__ == '__main__':
    unittest.main()
