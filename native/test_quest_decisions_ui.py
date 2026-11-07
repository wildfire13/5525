"""Tk controller with real Node engine; not real window/pixel QA."""
from copy import deepcopy
import unittest
from unittest.mock import Mock, patch
from app import Bridge
from campaign_app import CampaignApp
from test_porter_dialog import Widget

class QuestDecisionsUITests(unittest.TestCase):
    def setUp(self):
        self.engine = Bridge(); self.addCleanup(self.engine.close)
        self.engine.call(op='campaign_start')
        seed = self.save(); seed['state']['location'] = 'east'
        view = self.engine.call(op='campaign_load', data=seed)['campaign']
        porter = next(c['id'] for c in view['roster'] if c['id'] in view['selected'] and c['job'] == 'porter')
        self.assertTrue(self.engine.call(op='campaign', action='accept', args=['standalone-wheel', porter])['ok'])
        expired = self.save(); expired['state']['location'] = 'north'; expired['state']['hours'] = expired['state']['worldTime'] = 37
        expired['state']['selected'].remove(porter)
        self.assertTrue(self.engine.call(op='campaign_load', data=expired)['ok'])
        a = self.app = CampaignApp.__new__(CampaignApp)
        a.root, a.bridge = Widget(), Mock(wraps=self.engine)
        a.data = self.engine.call(op='view'); a.closed = False
        a.page, a.notice, a.selected = 'board', '', None
        a.render = Mock()
    def save(self): return self.engine.call(op='campaign_save')['data']
    def completions(self): return [c for c in self.app.bridge.call.call_args_list if c.kwargs.get('action') == 'completeQuest']
    def test_cancel_preserves_save(self):
        before = self.save()
        for answer in (False, None):
            with patch('campaign_app.messagebox.askyesno', return_value=answer) as ask: self.app.settle_expired_quest()
            self.assertEqual(ask.call_args.kwargs['default'], 'no')
            self.assertIn('世界の時刻は巻き戻りません', ask.call_args.args[1]); self.assertEqual(self.save(), before)
        self.assertEqual(self.completions(), [])
    def test_confirmation_settles_once_with_reserve_carrier(self):
        with patch('campaign_app.messagebox.askyesno', return_value=True) as ask:
            self.app.settle_expired_quest(); self.app.settle_expired_quest()
        ask.assert_called_once(); self.assertEqual(len(self.completions()), 1)
        s = self.save()['state']; self.assertEqual(s['worldTime'], 37)
        self.assertEqual(s['location'], 'east'); self.assertEqual(s['result']['outcome'], 'failed'); self.assertEqual(s['result']['gold'], 0)
    def test_modal_reentry_cannot_double_settle(self):
        def answer(*args, **kwargs): self.app.settle_expired_quest(); return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer) as ask: self.app.settle_expired_quest()
        ask.assert_called_once(); self.assertEqual(len(self.completions()), 1)
    def test_changed_state_is_not_settled(self):
        replacement = deepcopy(self.save()); replacement['state']['worldTime'] = replacement['state']['hours'] = 38
        def answer(*args, **kwargs): self.engine.call(op='campaign_load', data=replacement); return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer): self.app.settle_expired_quest()
        self.assertEqual(self.completions(), []); self.assertEqual(self.save(), replacement)
    def test_closed_or_navigated_confirmation_is_inert(self):
        for attribute, value in [('closed', True), ('page', 'map')]:
            before = self.save()
            def answer(*args, **kwargs): setattr(self.app, attribute, value); return True
            with patch('campaign_app.messagebox.askyesno', side_effect=answer): self.app.settle_expired_quest()
            self.assertEqual(self.completions(), []); self.assertEqual(self.save(), before)
            self.app.closed = False; self.app.page = 'board'

if __name__ == '__main__': unittest.main()
