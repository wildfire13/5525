"""Native preview metadata regression through public bridge operations only.

No GUI is driven. Battles use fresh campaigns, current equipped characters,
ordinary deployment and legal actions, with no historical battle fixtures.
Cancellation checks cover backend immutability plus the diagnostic cancel call;
Godot covers clearing its pending action in UI tests.
"""
import unittest

from bridge_test_session import Session
from bridge_current_campaign import (
    MAGE, GUARD, SCOUT, AMBUSH, PORTER, fresh_campaign, journey, trial,
)


def unit(state, uid):
    return next(u for u in state['units'] if u['id'] == uid)


def normal_attack_cells(state, actor):
    """Independent Manhattan/affiliation computation for a normal reach view."""
    cells = []
    for pos in range(50):
        occupant = next((u for u in state['units'] if u['hp'] > 0 and u['pos'] == pos), None)
        side = occupant['side'] if occupant else 'enemy'
        distance = abs(pos % 10 - actor['pos'] % 10) + abs(pos // 10 - actor['pos'] // 10)
        if side != actor['side'] and distance <= actor['reach']:
            cells.append(pos)
    return cells


class PreviewBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge = Session()
        self.data = fresh_campaign(self.bridge)

    def tearDown(self):
        self.bridge.close()

    def view(self):
        self.data = self.bridge.call(op='view')
        self.assertTrue(self.data['ok'])
        return self.data

    def preview(self, kind, target, preview_kind='action_attack'):
        before = self.view()
        response = self.bridge.call(op='preview', kind=kind, target=target,
                                    previewKind=preview_kind)
        self.assertTrue(response['ok'], response.get('error'))
        self.assertEqual(self.view(), before, 'Preview must not alter any gameplay/view field')
        return response['preview']

    def journey(self, action, *args):
        self.data = self.bridge.call(op='campaign', action=action, args=list(args))
        self.assertTrue(self.data['ok'], (action, self.data.get('error')))
        return self.data

    def prepare_journey(self):
        self.data = journey(self.bridge)

    def prepare_stamp(self):
        self.data = journey(self.bridge, deployments=[(MAGE, 14)], stamp=True)
        self.journey('begin')
        return self.reach_actor(MAGE)

    def reach_actor(self, actor_id):
        for _ in range(20):
            if self.data['state']['actor'] == actor_id:
                return self.data['state']
            self.assertIsNone(self.data['state']['result'], 'Battle ended before requested actor')
            self.data = self.bridge.call(op='act', kind='action_defend')
            self.assertTrue(self.data['ok'])
        self.fail('Requested actor did not become active within 20 legal guards')

    def test_stamp_selected_empty_center_reports_only_affected_enemy(self):
        state = self.prepare_stamp()
        self.assertFalse(any(u['hp'] > 0 and u['pos'] == 15 for u in state['units']))
        p = self.preview('action_skill', 15)
        self.assertEqual(p['cells'], [5, 15, 25])
        self.assertEqual(p['ranges'], [5, 15, 25])
        affected = [u['name'] for u in state['units']
                    if u['hp'] > 0 and u['side'] == 'enemy' and u['pos'] in p['cells']]
        self.assertTrue(affected)
        self.assertEqual(p['targets'], affected)
        for u in state['units']:
            if u['side'] == 'ally' or u['pos'] not in p['cells']:
                self.assertNotIn(u['name'], p['targets'])
        self.assertIsNone(p['destination'])
        self.assertEqual(p['units'], state['units'])

    def test_move_stamp_inspection_reports_reachable_enemy_without_moving_real_unit(self):
        self.data = journey(self.bridge, deployments=[(GUARD, 40), (MAGE, 24), (SCOUT, 35)], stamp=True)
        self.journey('begin')
        state = self.reach_actor(MAGE)
        selected = self.preview('action_skill', 25)
        self.assertIn(35, selected['cells'])
        self.assertEqual(unit(state, SCOUT)['pos'], 35)
        self.assertNotIn(unit(state, SCOUT)['name'], selected['targets'])
        self.assertTrue(selected['targets'])
        p = self.preview('action_move', 14, 'action_skill')
        self.assertEqual(p['destination'], 14)
        self.assertEqual(p['path'], [14])
        self.assertEqual(unit({'units': p['units']}, MAGE)['pos'], 14)
        self.assertEqual(unit(self.data['state'], MAGE)['pos'], 24)
        self.assertEqual(p['targets'], [u['name'] for u in state['units']
                                      if u['side'] == 'enemy' and u['hp'] > 0 and u['pos'] in (5, 15, 25)])
        self.assertTrue(p['targets'])
        self.assertEqual(p['ranges'], [15])
        self.assertEqual(p['cells'], [])
        attack = self.preview('action_move', 15, 'action_attack')
        self.assertEqual(attack['targets'], [u['name'] for u in state['units']
                                           if u['side'] == 'enemy' and u['hp'] > 0 and u['pos'] in (5, 25, 14, 16)])
        self.assertTrue(attack['targets'])
        self.assertEqual(attack['ranges'], normal_attack_cells({'units': attack['units']},
                                                           unit({'units': attack['units']}, MAGE)))

    def test_scout_ambush_previews_long_landing_and_normal_attack_range(self):
        self.prepare_journey()
        # Supported ordinary deployment clears a four-step straight ambush.
        self.journey('deploy', AMBUSH, 0)
        self.journey('begin')
        state = self.reach_actor(AMBUSH)
        # Node/V8 versions can give the seeded enemy a different duplicate suffix.
        # This case tests the ally scout's four-step landing, not an incidental enemy ID.
        targets = [u for u in state['units'] if u['side'] == 'enemy' and u['hp'] > 0 and u['pos'] == 5]
        self.assertEqual(len(targets), 1, 'Preview fixture needs one live enemy at position 5')
        target = targets[0]
        self.assertEqual(target['pos'], 5)
        self.assertIn(target['id'], self.data['choices']['action_skill'])
        p = self.preview('action_skill', target['id'])
        self.assertEqual(p['destination'], 4)
        self.assertEqual(p['path'], [1, 2, 3, 4])
        future = {'units': p['units']}
        actor = unit(future, AMBUSH)
        self.assertEqual(actor['pos'], 4)
        self.assertEqual(p['ranges'], normal_attack_cells(future, actor))
        self.assertTrue(all(abs(pos % 10 - 4) + pos // 10 <= 1 for pos in p['ranges']))
        self.assertIn(target['name'], p['targets'])
        self.assertEqual(set(p['targets']), {u['name'] for u in state['units'] if u['hp']>0 and u['side']=='enemy'
                         and abs(u['pos']%10-4)+u['pos']//10<=1})
        self.assertEqual(unit(self.data['state'], AMBUSH)['pos'], 0)
        self.assertEqual(p['risks'], [], 'immediate enemies have no saved target-cell forecast')

    def test_porter_swap_reports_real_path_and_both_future_positions(self):
        self.prepare_journey()
        self.journey('begin')
        state = self.reach_actor(PORTER)
        self.assertEqual(unit(state, PORTER)['pos'], 22)
        self.assertEqual(unit(state, GUARD)['pos'], 24)
        p = self.preview('action_move', 24, 'action_skill')
        self.assertEqual(p['swap'], GUARD)
        self.assertEqual(p['destination'], 24)
        self.assertEqual(p['path'], [23, 24])
        future = {'units': p['units']}
        self.assertEqual(unit(future, PORTER)['pos'], 24)
        self.assertEqual(unit(future, GUARD)['pos'], 22)
        self.assertTrue(p['formationBefore'])
        self.assertFalse(p['formationAfter'])
        for uid in (PORTER, GUARD):
            for key in ('hp', 'mp', 'next'):
                self.assertEqual(unit(future, uid)[key], unit(state, uid)[key])

    def test_cancel_record_and_repeated_preview_do_not_consume_or_queue_action(self):
        self.prepare_stamp()
        before = self.view()
        expected = self.preview('action_skill', 15)
        for _ in range(3):
            self.assertEqual(self.preview('action_skill', 15), expected)
        cancelled = self.bridge.call(op='record', type='battle.preview.cancelled',
                                      details={'destination': None, 'target': 15})
        self.assertTrue(cancelled['ok'])
        self.assertEqual(self.view(), before)
        # A rejected later preview must not execute the older valid one.
        self.assertFalse(self.bridge.call(op='preview', kind='action_skill', target=49)['ok'])
        self.assertEqual(self.view(), before)
        self.assertEqual(self.preview('action_skill', 15), expected)
        after = self.bridge.call(op='act', kind='action_skill', target=15)
        self.assertTrue(after['ok'])
        self.assertEqual(after['state']['actions'], before['state']['actions'] + 1)
        self.assertEqual(unit(after['state'], MAGE)['mp'], unit(before['state'], MAGE)['mp'] - 1)

    def test_invalid_deployment_and_terminal_preview_are_read_only(self):
        before = self.view()
        self.assertFalse(self.bridge.call(op='preview', kind='action_move', target=49)['ok'])
        self.assertEqual(self.view(), before)
        self.prepare_journey()
        before = self.view()
        self.assertFalse(self.bridge.call(op='preview', kind='action_move', target=0)['ok'])
        self.assertEqual(self.view(), before)
        self.data = trial(self.bridge, MAGE, 'victory-earring-1', 'north')
        self.data = self.bridge.call(op='act', kind='action_attack', target='enemy-guard')
        self.assertIsNotNone(self.data['state']['result'])
        before = self.view()
        self.assertFalse(self.bridge.call(op='preview', kind='action_defend')['ok'])
        self.assertEqual(self.view(), before)

    def test_move_preview_formation_break_and_cancel_restore(self):
        self.prepare_journey()
        self.journey('begin')
        state = self.reach_actor(PORTER)
        self.assertEqual(state['actor'], PORTER)
        p = self.preview('action_move', 23)
        self.assertTrue(p['formationBefore'])
        self.assertFalse(p['formationAfter'])
        self.assertEqual(unit({'units': p['units']}, PORTER)['pos'], 23)
        self.assertEqual(p['formationSlots']['ally'], [25, 14, 34])
        self.assertEqual(self.view()['formationSlots']['ally'], [24, 13, 33])
        self.assertEqual(unit(self.data['state'], PORTER)['pos'], 22)
        self.bridge.call(op='record', type='battle.preview.cancelled')
        self.assertTrue(self.view()['formed']['ally'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
