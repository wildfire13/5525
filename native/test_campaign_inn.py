"""Headless inn controller/real Node tests; modal rendering still needs GUI QA."""
from copy import deepcopy
import unittest
from unittest.mock import Mock, patch
from app import Bridge
from campaign_app import CampaignApp
from test_porter_dialog import Widget


class CampaignInnTests(unittest.TestCase):
    def setUp(self):
        self.engine = Bridge()
        self.addCleanup(self.engine.close)
        self.engine.call(op='campaign_start')
        damaged = self.save()
        damaged['state']['characters']['guard']['hp'] = 0
        damaged['state']['characters']['mage']['mp'] = 0
        damaged['state']['characters']['warrior']['hp'] = 1
        self.assertTrue(self.engine.call(op='campaign_load', data=damaged)['ok'])
        a = self.app = CampaignApp.__new__(CampaignApp)
        a.root, a.bridge = Widget(), Mock(wraps=self.engine)
        a.data = self.engine.call(op='view')
        a.inn_pending = a.closed = False
        a.notice, a.page, a.selected = '', 'inn', None
        a.battle_window = a._scroll_sync_job = None
        a.render = Mock()

    def save(self):
        return self.engine.call(op='campaign_save')['data']

    def stays(self):
        return [c for c in self.app.bridge.call.call_args_list if c.kwargs.get('action') == 'inn']

    def test_no_cancel_leave_complete_save_unchanged(self):
        for answer in (False, None):
            before = self.save()
            with patch('campaign_app.messagebox.askyesno', return_value=answer) as ask:
                self.app.stay_inn()
            self.assertEqual(ask.call_args.kwargs['default'], 'no')
            self.assertIn('30G', ask.call_args.args[1])
            self.assertEqual(self.save(), before)
            self.assertFalse(self.app.inn_pending)
        self.assertEqual(self.stays(), [])

    def test_yes_recovers_selected_once_and_save_reload_retains_result(self):
        before = self.save()['state']
        with patch('campaign_app.messagebox.askyesno', return_value=True) as ask:
            self.app.stay_inn()
            self.app.stay_inn()
        ask.assert_called_once()
        self.assertEqual(len(self.stays()), 1)
        after = self.save()
        self.assertEqual(after['state']['gold'], before['gold'] - 30)
        for c in self.app.campaign['roster']:
            if c['id'] in before['selected']:
                self.assertEqual((c['hp'], c['mp']), (c['max'], c['maxMp']))
            else:
                self.assertEqual(after['state']['characters'][c['id']], before['characters'][c['id']])
        self.assertTrue(self.engine.call(op='campaign_load', data=after)['ok'])
        self.assertEqual(self.save(), after)

    def test_modal_reentry_cannot_double_charge(self):
        def answer(*args, **kwargs):
            self.app.stay_inn()
            return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer) as ask:
            self.app.stay_inn()
        ask.assert_called_once()
        self.assertEqual(len(self.stays()), 1)
        self.assertEqual(self.save()['state']['gold'], 150)

    def test_window_closed_during_confirmation_cannot_charge(self):
        before = self.save()
        def answer(*args, **kwargs):
            with patch.object(self.app.bridge, 'close'):
                self.app.close()
            return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer):
            self.app.stay_inn()
        self.assertTrue(self.app.root.destroyed)
        self.assertEqual(self.stays(), [])
        self.assertEqual(self.save(), before)
        self.app.render.assert_not_called()

    def test_stale_loaded_save_cannot_apply_old_confirmation(self):
        replacement = deepcopy(self.save())
        replacement['state']['gold'] = 80
        def answer(*args, **kwargs):
            self.assertTrue(self.engine.call(op='campaign_load', data=replacement)['ok'])
            return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer):
            self.app.stay_inn()
        self.assertEqual(self.stays(), [])
        self.assertEqual(self.save(), replacement)
        self.assertEqual(self.app.campaign['gold'], 80)
        self.assertFalse(self.app.inn_pending)

    def test_unavailable_quotes_do_not_open_confirmation(self):
        original = deepcopy(self.save())
        variants = []
        for location in ('east', 'west', 'south', 'north'):
            s = deepcopy(original); s['state']['location'] = location; variants.append(s)
        s = deepcopy(original); s['state']['gold'] = 29; variants.append(s)
        for saved in variants:
            self.app.data = self.engine.call(op='campaign_load', data=saved)
            self.assertTrue(self.app.data['ok'])
            with patch('campaign_app.messagebox.askyesno') as ask:
                self.app.stay_inn()
            ask.assert_not_called()
            self.assertEqual(self.save(), saved)
        self.assertEqual(self.stays(), [])


if __name__ == '__main__':
    unittest.main()
