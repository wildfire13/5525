import unittest

from test_current_fixture import current_campaign
from bridge_test_session import Session


class VoiceBridgeTests(unittest.TestCase):
    def test_real_bridge_response_events_are_not_replayed_by_view(self):
        bridge = Session()
        self.addCleanup(bridge.close)
        bridge.call(op='reset', scenario='victory')
        response = bridge.call(op='act', kind='attack', target='enemy-archer')
        self.assertTrue(response['ok'])
        self.assertEqual(response['voiceEvents'], [{'character_id': 'archer', 'cue': 'attack'}])
        self.assertNotIn('voiceEvents', bridge.call(op='view'))

    def test_campaign_opening_enemy_hit_only_after_begin(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        current_campaign(bridge)
        for action, args in [('select', [['guard', 'porter']]), ('depart', ['east']),
                             ('travel', ['safe']), ('deploy', ['guard', 4])]:
            response = bridge.call(op='campaign', action=action, args=args)
            self.assertTrue(response['ok'])
            self.assertNotIn('voiceEvents', response)
        before = bridge.call(op='view')
        bridge.call(op='record', type='battle.preview.cancelled')
        self.assertEqual(bridge.call(op='view'), before)
        response = bridge.call(op='campaign', action='begin', args=[])
        self.assertTrue(response['ok'])
        self.assertEqual(response['voiceEvents'], [{'character_id': 'guard', 'cue': 'hurt'}])
        self.assertLess(next(u['hp'] for u in response['state']['units'] if u['id'] == 'guard'), 180)
        self.assertNotIn('voiceEvents', bridge.call(op='view'))
        retry = bridge.call(op='campaign', action='begin', args=[])
        self.assertFalse(retry['ok'])
        self.assertEqual(retry['voiceEvents'], [])

    def test_eight_new_active_skills_emit_one_matching_voice_per_action(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        cases = [('guard', 'undertow-sword', 'retreatSlash'), ('mage', 'breaker-hammer', 'knockback'),
                 ('archer', 'twin-bow', 'splitShot'), ('scout', 'partner-dagger', 'pincer'),
                 ('mage', 'rest-staff', 'healingCross'), ('mage', 'battleline-shield', 'defenseLine'),
                 ('mage', 'sharing-tome', 'manaGift'), ('porter', 'return-ring-1', 'returnHome')]
        for uid, gear, skill in cases:
            with self.subTest(skill=skill):
                current_campaign(bridge)
                saved = bridge.call(op='campaign_save')['data']
                saved['state']['location'] = 'north' if skill == 'returnHome' else 'east'
                self.assertTrue(bridge.call(op='campaign_load', data=saved)['ok'])
                data = bridge.call(op='campaign', action='trial', args=[uid, gear])
                self.assertTrue(data['ok'], data.get('error'))
                mode = 'return' if skill == 'returnHome' else 'skill'
                target = data['choices'][mode][0]
                before = bridge.call(op='view')
                preview = bridge.call(op='preview', kind=mode, target=target)
                self.assertTrue(preview['ok'])
                self.assertNotIn('voiceEvents', preview)
                self.assertEqual(bridge.call(op='view'), before)
                result = bridge.call(op='act', kind=mode, target=target)
                self.assertTrue(result['ok'])
                event = {'character_id': uid, 'cue': 'skill:' + skill}
                self.assertEqual(result['voiceEvents'][0], event)
                self.assertEqual(sum(e == event for e in result['voiceEvents']), 1)
                self.assertEqual(sum(e['cue'].startswith('skill:') for e in result['voiceEvents']), 1)
                self.assertTrue(any(e['skillId'] == skill for e in result['skillEvents']))
                self.assertNotIn('voiceEvents', bridge.call(op='view'))
                self.assertTrue(bridge.call(op='campaign', action='endTrial', args=[])['ok'])

    def test_passive_activation_does_not_emit_skill_speech(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        for gear, skill, action in [('victory-earring-1', 'victoryBreath', 'attack'),
                                    ('lone-ring-1', 'loneWolf', 'attack'),
                                    ('pioneer-gloves-1', 'firstStride', 'move')]:
            current_campaign(bridge)
            saved = bridge.call(op='campaign_save')['data']
            saved['state']['location'] = 'north'
            self.assertTrue(bridge.call(op='campaign_load', data=saved)['ok'])
            data = bridge.call(op='campaign', action='trial', args=['mage', gear])
            self.assertTrue(data['ok'])
            result = bridge.call(op='act', kind=action, target=data['choices'][action][0])
            self.assertTrue(result['ok'])
            self.assertTrue(any(e['skillId'] == skill for e in result['skillEvents']))
            self.assertFalse(any(e['cue'].startswith('skill:') for e in result['voiceEvents']))
            self.assertNotIn('voiceEvents', bridge.call(op='view'))
            self.assertTrue(bridge.call(op='campaign', action='endTrial', args=[])['ok'])
