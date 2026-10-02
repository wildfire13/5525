"""Native preview metadata regression through public bridge operations only.

No GUI is driven and no game state is injected. Tests use the existing labeled
Stamp/victory fixtures and ordinary journey selection/deployment/legal actions.
Cancellation checks cover backend immutability plus the diagnostic cancel call;
clearing the frontend's pending action remains a separate native GUI obligation.
"""
import unittest

from test_journey_bridge import Session


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
        self.data = self.bridge.call(op='reset')

    def tearDown(self):
        self.bridge.close()

    def view(self):
        self.data = self.bridge.call(op='view')
        self.assertTrue(self.data['ok'])
        return self.data

    def preview(self, kind, target, preview_kind='attack'):
        before = self.view()
        response = self.bridge.call(op='preview', kind=kind, target=target,
                                    previewKind=preview_kind)
        self.assertTrue(response['ok'], response.get('error'))
        self.assertEqual(self.view(), before, 'Preview must not alter any gameplay/view field')
        return response['preview']

    def journey(self, action, *args):
        self.data = self.bridge.call(op='journey', action=action, args=list(args))
        self.assertTrue(self.data['ok'], (action, self.data.get('error')))
        return self.data

    def prepare_journey(self):
        self.data = self.bridge.call(op='journey_start')
        self.journey('accept', 'parts')
        self.journey('depart', 'medicine', 'convoy')
        self.journey('travel', 'short')

    def reach_actor(self, actor_id):
        for _ in range(20):
            if self.data['state']['actor'] == actor_id:
                return self.data['state']
            self.assertIsNone(self.data['state']['result'], 'Battle ended before requested actor')
            self.data = self.bridge.call(op='act', kind='guard')
            self.assertTrue(self.data['ok'])
        self.fail('Requested actor did not become active within20 legal guards')

    def test_stamp_selected_empty_center_reports_only_affected_enemy(self):
        self.data = self.bridge.call(op='reset', scenario='stamp')
        state = self.data['state']
        self.assertFalse(any(u['hp'] > 0 and u['pos'] == 25 for u in state['units']))
        p = self.preview('skill', 25)
        self.assertEqual(p['cells'], [15, 25, 35])
        self.assertEqual(p['ranges'], [15, 25, 35])
        self.assertEqual(p['targets'], [unit(state, 'enemy-archer')['name']])
        self.assertNotIn(unit(state, 'scout')['name'], p['targets'])
        self.assertNotIn(unit(state, 'enemy-guard')['name'], p['targets'])
        self.assertIsNone(p['destination'])
        self.assertEqual(p['units'], state['units'])

    def test_move_stamp_inspection_reports_reachable_enemy_without_moving_real_unit(self):
        self.data = self.bridge.call(op='reset', scenario='stamp')
        state = self.data['state']
        p = self.preview('move', 14, 'skill')
        self.assertEqual(p['destination'], 14)
        self.assertEqual(p['path'], [14])
        self.assertEqual(unit({'units': p['units']}, 'warrior')['pos'], 14)
        self.assertEqual(unit(self.data['state'], 'warrior')['pos'], 24)
        self.assertEqual(p['targets'], [unit(state, 'enemy-archer')['name']])
        self.assertEqual(p['ranges'], [4, 13, 15, 24])
        self.assertEqual(p['cells'], [])
        attack = self.preview('move', 14, 'attack')
        self.assertEqual(attack['targets'], [unit(state, 'enemy-archer')['name']])
        self.assertEqual(attack['ranges'], normal_attack_cells({'units': attack['units']},
                                                           unit({'units': attack['units']}, 'warrior')))

    def test_scout_ambush_previews_long_landing_and_normal_attack_range(self):
        self.prepare_journey()
        # Supported ordinary deployment clears a four-step straight ambush.
        self.journey('deploy', 'scout', 0)
        self.journey('begin')
        state = self.reach_actor('scout')
        target = unit(state, 'enemy-scout-2')
        self.assertEqual(target['pos'], 5)
        self.assertIn(target['id'], self.data['choices']['skill'])
        p = self.preview('skill', target['id'])
        self.assertEqual(p['destination'], 4)
        self.assertEqual(p['path'], [1, 2, 3, 4])
        future = {'units': p['units']}
        actor = unit(future, 'scout')
        self.assertEqual(actor['pos'], 4)
        self.assertEqual(p['ranges'], normal_attack_cells(future, actor))
        self.assertTrue(all(abs(pos % 10 - 4) + pos // 10 <= 1 for pos in p['ranges']))
        self.assertEqual(p['targets'], [target['name']])
        self.assertEqual(unit(self.data['state'], 'scout')['pos'], 0)
        expected_risks = [u['name'] for u in state['units'] if u['hp'] > 0 and u['side'] == 'enemy'
                          and 4 in u.get('intent', {}).get('cells', [])]
        self.assertEqual(p['risks'], expected_risks)

    def test_porter_swap_reports_real_path_and_both_future_positions(self):
        self.prepare_journey()
        self.journey('begin')
        state = self.reach_actor('porter')
        self.assertEqual(unit(state, 'porter')['pos'], 22)
        self.assertEqual(unit(state, 'guard')['pos'], 24)
        p = self.preview('move', 24, 'skill')
        self.assertEqual(p['swap'], 'guard')
        self.assertEqual(p['destination'], 24)
        self.assertEqual(p['path'], [23, 24])
        future = {'units': p['units']}
        self.assertEqual(unit(future, 'porter')['pos'], 24)
        self.assertEqual(unit(future, 'guard')['pos'], 22)
        self.assertTrue(p['formationBefore'])
        self.assertTrue(p['formationAfter'])
        self.assertEqual(p['targets'], [unit(state, 'porter')['name']])
        self.assertEqual(p['ranges'], [24])
        for uid in ('porter', 'guard'):
            for key in ('hp', 'mp', 'next'):
                self.assertEqual(unit(future, uid)[key], unit(state, uid)[key])

    def test_cancel_record_and_repeated_preview_do_not_consume_or_queue_action(self):
        self.data = self.bridge.call(op='reset', scenario='stamp')
        before = self.view()
        expected = self.preview('skill', 25)
        for _ in range(3):
            self.assertEqual(self.preview('skill', 25), expected)
        cancelled = self.bridge.call(op='record', type='battle.preview.cancelled',
                                     details={'destination': None, 'target': 25})
        self.assertTrue(cancelled['ok'])
        self.assertEqual(self.view(), before)
        # A rejected later preview must not execute the older valid one.
        self.assertFalse(self.bridge.call(op='preview', kind='skill', target=49)['ok'])
        self.assertEqual(self.view(), before)
        self.assertEqual(self.preview('skill', 25), expected)
        after = self.bridge.call(op='act', kind='skill', target=25)
        self.assertTrue(after['ok'])
        self.assertEqual(after['state']['actions'], before['state']['actions'] + 1)
        self.assertEqual(unit(after['state'], 'warrior')['mp'], unit(before['state'], 'warrior')['mp'] - 1)

    def test_invalid_deployment_and_terminal_preview_are_read_only(self):
        before = self.view()
        self.assertFalse(self.bridge.call(op='preview', kind='move', target=49)['ok'])
        self.assertEqual(self.view(), before)
        self.prepare_journey()
        before = self.view()
        self.assertFalse(self.bridge.call(op='preview', kind='move', target=0)['ok'])
        self.assertEqual(self.view(), before)
        self.data = self.bridge.call(op='reset', scenario='victory')
        self.data = self.bridge.call(op='act', kind='attack', target='enemy-archer')
        self.assertIsNotNone(self.data['state']['result'])
        before = self.view()
        self.assertFalse(self.bridge.call(op='preview', kind='guard')['ok'])
        self.assertEqual(self.view(), before)

    def test_move_preview_formation_break_and_cancel_restore(self):
        state = self.data['state']
        self.assertEqual(state['actor'], 'archer')
        p = self.preview('move', 14)
        self.assertTrue(p['formationBefore'])
        self.assertFalse(p['formationAfter'])
        self.assertEqual(unit({'units': p['units']}, 'archer')['pos'], 14)
        self.assertEqual(unit(self.data['state'], 'archer')['pos'], 13)
        self.bridge.call(op='record', type='battle.preview.cancelled')
        self.assertTrue(self.view()['formed']['ally'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
