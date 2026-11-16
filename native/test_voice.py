import unittest

from bridge_current_campaign import (
    GUARD, PORTER, SCOUT, HUMAN_MAGE, fresh_campaign, trial,
)
from bridge_test_session import Session


class VoiceBridgeTests(unittest.TestCase):
    def test_real_bridge_response_events_are_not_replayed_by_view(self):
        bridge = Session()
        self.addCleanup(bridge.close)
        trial(bridge, SCOUT, 'victory-earring-1', 'north')
        response = bridge.call(op='act', kind='attack', target='enemy-guard')
        self.assertTrue(response['ok'])
        self.assertEqual(response['voiceEvents'], [{'character_id': SCOUT, 'cue': 'attack'}])
        self.assertNotIn('voiceEvents', bridge.call(op='view'))

    def test_campaign_opening_enemy_hit_only_after_begin(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        fresh_campaign(bridge)
        for action, args in [('select', [[GUARD, PORTER]]), ('depart', ['east']),
                             ('travel', ['safe']), ('deploy', [GUARD, 4])]:
            response = bridge.call(op='campaign', action=action, args=args)
            self.assertTrue(response['ok'])
            self.assertNotIn('voiceEvents', response)
        before = bridge.call(op='view')
        bridge.call(op='record', type='battle.preview.cancelled')
        self.assertEqual(bridge.call(op='view'), before)
        initial_hp = next(u['hp'] for u in before['state']['units'] if u['id'] == GUARD)
        response = bridge.call(op='campaign', action='begin', args=[])
        self.assertTrue(response['ok'])
        self.assertEqual(response['voiceEvents'], [{'character_id': GUARD, 'cue': 'hurt'}])
        self.assertLess(next(u['hp'] for u in response['state']['units'] if u['id'] == GUARD), initial_hp)
        self.assertNotIn('voiceEvents', bridge.call(op='view'))
        retry = bridge.call(op='campaign', action='begin', args=[])
        self.assertFalse(retry['ok'])
        self.assertEqual(retry['voiceEvents'], [])

    def test_eight_new_active_skills_emit_one_matching_voice_per_action(self):
        bridge = Session(5525)
        self.addCleanup(bridge.close)
        cases = [(HUMAN_MAGE, 'undertow-sword', 'retreatSlash'), (HUMAN_MAGE, 'breaker-hammer', 'knockback'),
                 (SCOUT, 'twin-bow', 'splitShot'), (SCOUT, 'partner-dagger', 'pincer'),
                 (HUMAN_MAGE, 'rest-staff', 'healingCross'), (HUMAN_MAGE, 'battleline-shield', 'defenseLine'),
                 (HUMAN_MAGE, 'sharing-tome', 'manaGift'), (PORTER, 'return-ring-1', 'returnHome')]
        for uid, gear, skill in cases:
            with self.subTest(skill=skill):
                data = trial(bridge, uid, gear, 'north' if skill == 'returnHome' else 'east')
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
            data = trial(bridge, HUMAN_MAGE, gear, 'north')
            result = bridge.call(op='act', kind=action, target=data['choices'][action][0])
            self.assertTrue(result['ok'])
            self.assertTrue(any(e['skillId'] == skill for e in result['skillEvents']))
            self.assertFalse(any(e['cue'].startswith('skill:') for e in result['voiceEvents']))
            self.assertNotIn('voiceEvents', bridge.call(op='view'))
            self.assertTrue(bridge.call(op='campaign', action='endTrial', args=[])['ok'])
