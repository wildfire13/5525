"""Real Node bridge + Tk-controller doubles. Not human GUI playtest evidence."""
import copy
from types import SimpleNamespace
import unittest
from unittest.mock import Mock
from app import App
from test_journey_bridge import Session


class EquipmentSkillBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge = Session()
        self.addCleanup(self.bridge.close)
        self.bridge.call(op='campaign_start')

    def town(self, location):
        saved = self.bridge.call(op='campaign_save')['data']
        saved['state']['location'] = location  # Explicit shop fixture, not travel evidence.
        saved['state']['gold'] = 500
        self.assertTrue(self.bridge.call(op='campaign_load', data=saved)['ok'])

    def trial(self, uid, gear, location='east'):
        self.town(location)
        data = self.bridge.call(op='campaign', action='trial', args=[uid, gear])
        self.assertTrue(data['ok'], data.get('error'))
        app = App.__new__(App)
        app.data, app.bridge = data, self.bridge
        app.mode, app.pending, app.preview = 'skill', None, None
        app.preview_kind, app.porter_confirmation = 'attack', None
        app.message, app.buttons, app.draw = '', {'skill': Mock(), 'return': Mock(), 'move': Mock()}, Mock()
        return app

    @staticmethod
    def click(app, pos):
        app.click_cell(SimpleNamespace(x=pos % 10 * 74 + 30, y=pos // 10 * 74 + 30))

    def test_split_two_clicks_preview_cancel_and_one_commit(self):
        app = self.trial('archer', 'twin-bow')
        before = copy.deepcopy(app.data['state'])
        self.assertEqual(app.data['skillInfo']['target'], 'pair')
        self.assertIn(27, app.data['ranges']['skill'])
        self.click(app, 25)
        self.assertEqual(app.pending, ('skill', ['enemy-guard']))
        self.assertIsNone(app.preview)
        self.click(app, 15)
        self.assertEqual(set(app.pending[1]), {'enemy-guard', 'enemy-archer'})
        self.assertEqual(set(app.preview['targets']), {'木人1', '木人2'})
        self.assertEqual(self.bridge.call(op='view')['state'], before)
        app.cancel()
        self.assertIsNone(app.pending)
        self.assertEqual(self.bridge.call(op='view')['state'], before)
        self.click(app, 25)
        self.click(app, 15)
        app.commit()
        self.assertTrue(app.data['ok'])
        self.assertEqual(app.data['state']['actions'], 1)
        events = app.data['skillEvents']
        self.assertEqual(events[-1]['skillId'], 'splitShot')
        self.assertEqual(events[-1]['classification'], 'active')
        self.assertEqual(self.bridge.call(op='view')['skillEvents'], events)

    def test_defense_select_one_or_two_and_show_test_hit(self):
        app = self.trial('mage', 'battleline-shield')
        self.click(app, 14)
        self.assertIn(app.pending[1], app.data['choices']['skill'])
        self.click(app, 34)
        self.assertEqual(len(app.pending[1]), 2)
        self.assertEqual(len(app.preview['targets']), 2)
        app.commit()
        self.assertTrue(app.data['ok'])
        self.assertTrue(any('かばう' in line for line in app.data['state']['log']))

    def test_cross_preview_includes_friends_not_enemy(self):
        app = self.trial('mage', 'rest-staff')
        self.click(app, 24)
        self.assertIn('ガロ', app.preview['targets'])
        self.assertIn('リノ', app.preview['targets'])
        self.assertNotIn('木人1', app.preview['targets'])
        self.assertIn('MP2', app.mode_hint('skill'))
        app.commit()
        self.assertTrue(app.data['ok'])

    def test_return_position_zero_mp_kind_and_no_reuse(self):
        app = self.trial('mage', 'return-ring-1', 'north')
        app.mode = 'return'
        before = copy.deepcopy(app.data['state'])
        self.click(app, 3)
        self.assertEqual(app.preview['destination'], 3)
        self.assertEqual(self.bridge.call(op='view')['state'], before)
        app.commit()
        self.assertTrue(app.data['ok'])
        self.assertEqual(app.data['choices']['return'], [])
        self.assertEqual(app.data['skillEvents'][-1]['skillId'], 'returnHome')
        event_count = len(app.data['skillEvents'])
        denied = self.bridge.call(op='act', kind='return', target=4)
        self.assertFalse(denied['ok'])
        self.assertEqual(len(denied['skillEvents']), event_count)

    def test_first_stride_preview_path_and_distance_not_mutated(self):
        app = self.trial('mage', 'pioneer-gloves-1', 'north')
        app.mode = 'move'
        before = copy.deepcopy(app.data['state'])
        self.assertEqual(app.data['moveReach'], 3)
        self.click(app, 21)
        self.assertEqual(app.preview['path'], [23, 22, 21])
        self.assertEqual(self.bridge.call(op='view')['state'], before)
        app.commit()
        self.assertTrue(app.data['ok'])
        self.assertEqual(app.data['moveReach'], 2)

    def test_retreat_preview_and_mana_description(self):
        app = self.trial('guard', 'undertow-sword')
        self.click(app, 25)
        self.assertEqual(app.preview['destination'], 23)
        self.assertEqual(app.preview['units'][0]['pos'], 23)
        self.assertEqual(self.bridge.call(op='view')['state']['units'][0]['pos'], 24)
        self.bridge.call(op='campaign', action='endTrial')
        app = self.trial('mage', 'sharing-tome')
        self.assertIn('総量は増えない', app.mode_hint('skill'))
        self.click(app, 14)
        app.commit()
        self.assertTrue(app.data['ok'])

    def test_duplicate_passives_and_save_roundtrip_real_process(self):
        self.town('north')
        for gear in ['lone-ring-1', 'lone-ring-2']:
            self.assertTrue(self.bridge.call(op='campaign', action='buyGear', args=['mage', gear])['ok'])
        for action, args in [('depart', ['astaris']), ('travel', ['safe']), ('begin', [])]:
            self.assertTrue(self.bridge.call(op='campaign', action=action, args=args)['ok'])
        before = self.bridge.call(op='view')
        hero = next(u for u in before['state']['units'] if u['id'] == 'mage')
        self.assertEqual(hero['effects'], ['loneWolf'])
        saved = self.bridge.call(op='campaign_save')['data']
        self.bridge.close()
        self.bridge = Session(2)
        self.addCleanup(self.bridge.close)
        loaded = self.bridge.call(op='campaign_load', data=saved)
        self.assertTrue(loaded['ok'])
        self.assertEqual(loaded['state'], before['state'])


if __name__ == '__main__':
    unittest.main()
