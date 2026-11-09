"""Exercise the Node battle bridge used by Godot."""
from test_current_fixture import current_campaign
import unittest
from bridge_test_session import Session


class EquipmentSkillBridgeTests(unittest.TestCase):
    def setUp(self):
        self.bridge = Session()
        self.addCleanup(self.bridge.close)
        current_campaign(self.bridge)

    def town(self, location):
        saved = self.bridge.call(op='campaign_save')['data']
        saved['state']['location'] = location  # Explicit shop fixture, not travel evidence.
        saved['state']['gold'] = 500
        self.assertTrue(self.bridge.call(op='campaign_load', data=saved)['ok'])

    def trial(self, uid, gear, location='east'):
        self.town(location)
        data = self.bridge.call(op='campaign', action='trial', args=[uid, gear])
        self.assertTrue(data['ok'], data.get('error'))
        return data

    def preview(self, kind, target):
        before = self.bridge.call(op='view')['state']
        reply = self.bridge.call(op='preview', kind=kind, target=target)
        self.assertTrue(reply['ok'], reply.get('error'))
        self.assertEqual(self.bridge.call(op='view')['state'], before)
        return reply['preview']

    def act(self, kind, target):
        reply = self.bridge.call(op='act', kind=kind, target=target)
        self.assertTrue(reply['ok'], reply.get('error'))
        return reply

    def test_split_preview_and_commit(self):
        data = self.trial('archer', 'twin-bow')
        targets = ['enemy-guard', 'enemy-archer']
        self.assertEqual(data['skillInfo']['target'], 'pair')
        self.assertIn(27, data['ranges']['skill'])
        self.assertEqual(set(self.preview('skill', targets)['targets']), {'木人1', '木人2'})
        reply = self.act('skill', targets)
        self.assertEqual(reply['state']['actions'], 1)
        self.assertEqual(reply['skillEvents'][-1]['skillId'], 'splitShot')
        self.assertEqual(reply['skillEvents'][-1]['classification'], 'active')
        self.assertEqual(self.bridge.call(op='view')['skillEvents'],reply['skillEvents'])

    def test_defense_pair(self):
        self.trial('mage', 'battleline-shield')
        targets = ['guard', 'archer']
        self.assertEqual(len(self.preview('skill', targets)['targets']), 2)
        self.assertTrue(any('かばう' in line for line in self.act('skill', targets)['state']['log']))

    def test_cross_preview_includes_friends_not_enemy(self):
        self.trial('mage', 'rest-staff')
        targets = self.preview('skill', 'mage')['targets']
        self.assertIn('ガロ', targets)
        self.assertIn('リノ', targets)
        self.assertNotIn('木人1', targets)
        self.act('skill', 'mage')

    def test_return_position_zero_mp_kind_and_no_reuse(self):
        self.trial('mage', 'return-ring-1', 'north')
        self.assertEqual(self.preview('return', 3)['destination'], 3)
        reply = self.act('return', 3)
        self.assertEqual(reply['choices']['return'], [])
        self.assertEqual(reply['skillEvents'][-1]['skillId'], 'returnHome')
        denied = self.bridge.call(op='act', kind='return', target=4)
        self.assertFalse(denied['ok'])
        self.assertEqual(len(denied['skillEvents']),len(reply['skillEvents']))

    def test_first_stride_preview_path_and_distance_not_mutated(self):
        data = self.trial('mage', 'pioneer-gloves-1', 'north')
        self.assertEqual(data['moveReach'], 3)
        self.assertEqual(self.preview('move', 21)['path'], [23, 22, 21])
        self.assertEqual(self.act('move', 21)['moveReach'], 2)

    def test_retreat_preview(self):
        self.trial('guard', 'undertow-sword')
        preview = self.preview('skill', 'enemy-guard')
        self.assertEqual(preview['destination'], 23)
        self.assertEqual(preview['units'][0]['pos'], 23)

    def test_duplicate_passives_and_save_roundtrip_real_process(self):
        self.town('north')
        for gear in ['lone-ring-1', 'lone-ring-2']:
            self.assertTrue(self.bridge.call(op='campaign', action='buyGear', args=['mage', gear])['ok'])
        # Both rings replace the fixture's capacity accessory. Transfer the
        # retained pouch through normal inventory rules before leaving town.
        bag = self.bridge.call(op='campaign_save')['data']['state']['characters']['mage']['inventory']
        for item, amount in bag.items():
            quote = self.bridge.call(op='campaign', action='inventoryQuote', args=['mage', item, 'transfer', 'porter', amount])['inventoryQuote']
            self.assertTrue(quote['ok'])
            self.assertTrue(self.bridge.call(op='campaign', action='inventoryAction', args=['mage', item, 'transfer', 'porter', amount, None, quote['token']])['ok'])
        for action, args in [('depart', ['astaris']), ('travel', ['safe']), ('begin', [])]:
            self.assertTrue(self.bridge.call(op='campaign', action=action, args=args)['ok'])
        before = self.bridge.call(op='view')
        hero = next(u for u in before['state']['units'] if u['id'] == 'mage')
        self.assertEqual(hero['effects'], ['itemUse', 'loneWolf'])
        self.assertEqual(len([source for source in hero['skillSources'] if source['id']=='loneWolf']), 2)
        saved = self.bridge.call(op='campaign_save')['data']
        self.bridge.close()
        self.bridge = Session(2)
        self.addCleanup(self.bridge.close)
        loaded = self.bridge.call(op='campaign_load', data=saved)
        self.assertTrue(loaded['ok'])
        self.assertEqual(loaded['state'], before['state'])


if __name__ == '__main__':
    unittest.main()
