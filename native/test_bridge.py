import unittest

from bridge_test_session import Session
from bridge_current_campaign import (
    SCOUT, MAGE, GUARD, PORTER, accepted, campaign, fresh_campaign,
    guard_to_result, journey, reach_actor, trial,
)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.b = Session()
        self.addCleanup(self.b.close)

    def test_invalid_is_unchanged(self):
        trial(self.b, SCOUT, 'bow-wood')
        before = self.b.call(op='view')['state']
        data = self.b.call(op='act', kind='action_move', target=49)
        self.assertFalse(data['ok'])
        self.assertEqual(data['state'], before)

    def test_victory(self):
        trial(self.b, MAGE, 'victory-earring-1', 'north')
        data = accepted(self.b, op='act', kind='action_attack', target='enemy-guard')
        self.assertIn('勝利', data['state']['result'])
        self.assertIsNone(data['state']['actor'])
        self.assertFalse(self.b.call(op='act', kind='action_defend')['ok'])

    def test_defeat(self):
        journey(self.b, [SCOUT], [(SCOUT, 4)])
        data = guard_to_result(self.b, campaign(self.b, 'begin'))
        self.assertIn('敗北', data['state']['result'])
        self.assertTrue(all(u['hp'] == 0 for u in data['state']['units'] if u['side'] == 'ally'))

    def test_porter_failure(self):
        journey(self.b, [GUARD, PORTER], [(GUARD, 40), (PORTER, 4)])
        data = guard_to_result(self.b, campaign(self.b, 'begin'))
        self.assertEqual(data['state']['failure'], 'porter')
        self.assertTrue(any(u['hp'] > 0 and u['side'] == 'ally' for u in data['state']['units']))

    def test_stamp_empty_center_enemy_only(self):
        journey(self.b, deployments=[(MAGE, 14)], stamp=True)
        data = reach_actor(self.b, campaign(self.b, 'begin'), MAGE)
        self.assertEqual(data['stampAreas']['15'], [5, 15, 25])
        before = {u['id']: u for u in data['state']['units']}
        self.assertFalse(any(u['hp'] > 0 and u['pos'] == 15 for u in before.values()))
        data = accepted(self.b, op='act', kind='action_skill', target=15, presentation=True)
        while data['presentation']['phase'] != 'settled':
            token = data['presentation']
            data = accepted(self.b, op='presentation_next', id=token['id'], index=token['index'])
        after = {u['id']: u for u in data['state']['units']}
        self.assertEqual(after[MAGE].get('pendingStamp', {}).get('center'), 15)
        self.assertEqual(after[MAGE]['mp'], before[MAGE]['mp'] - 1)
        for uid in before:
            self.assertEqual(after[uid]['hp'], before[uid]['hp'])
        accepted(self.b, op='presentation_finish', id=data['presentation']['id'])

    def test_equipped_snipe_and_new_campaign(self):
        data = trial(self.b, SCOUT, 'bow-wood')
        actor = next(u for u in data['state']['units'] if u['id'] == SCOUT)
        data = accepted(self.b, op='act', kind='action_skill', target=data['choices']['action_skill'][0])
        self.assertEqual(next(u for u in data['state']['units'] if u['id'] == SCOUT)['mp'], actor['mp'] - 1)
        data = fresh_campaign(self.b)
        self.assertIsNone(data['state'])
        journey(self.b)
        data = campaign(self.b, 'begin')
        self.assertEqual(data['state']['actions'], 0)
        self.assertIsNone(data['state']['result'])


if __name__ == '__main__':
    unittest.main()
