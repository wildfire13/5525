"""Headless controller/real Node checks; native modal rendering needs GUI QA."""
from copy import deepcopy
import unittest
from unittest.mock import Mock, patch
from app import Bridge, App
from campaign_app import CampaignBattleApp, CampaignApp, TrialBattleApp
from test_porter_dialog import Widget

class CampaignRetreatTests(unittest.TestCase):
    def setUp(self):
        self.engine = Bridge(); self.addCleanup(self.engine.close)
        self.engine.call(op='campaign_start')
        self.before = self.save()
        for action, args in [('depart', ['north']), ('travel', ['safe']), ('begin', [])]:
            self.assertTrue(self.engine.call(op='campaign', action=action, args=args)['ok'])
        a = self.app = CampaignBattleApp.__new__(CampaignBattleApp)
        a.root, a.bridge = Widget(), Mock(wraps=self.engine)
        a.data = self.engine.call(op='view')
        a.owns_bridge, a.on_close = False, Mock()
        a.retreat_pending = a.retreat_closed = False
        a.porter_dialog = a.porter_confirmation = None
        a.pending, a.preview = ('move', 23), {'preview': True}
        a.draw = Mock()
    def save(self): return self.engine.call(op='campaign_save')['data']['state']
    def retreats(self):
        return [c for c in self.app.bridge.call.call_args_list if c.kwargs.get('action') == 'retreat']
    def test_no_cancel_leave_save_and_preview_unchanged(self):
        for answer in (False, None):
            before = self.save(); preview = deepcopy(self.app.preview)
            with patch('campaign_app.messagebox.askyesno', return_value=answer) as ask: self.app.ask_retreat()
            self.assertEqual(ask.call_args.kwargs['default'], 'no')
            self.assertEqual(self.save(), before)
            self.assertEqual(self.app.preview, preview)
            self.assertEqual(self.app.pending, ('move', 23))
            self.assertFalse(self.app.root.destroyed)
        self.assertEqual(self.retreats(), [])
    def test_yes_restores_and_refreshes_once(self):
        with patch('campaign_app.messagebox.askyesno', return_value=True) as ask:
            self.app.ask_retreat(); self.app.ask_retreat()
        ask.assert_called_once(); self.assertEqual(len(self.retreats()), 1)
        self.assertTrue(self.app.root.destroyed); self.app.on_close.assert_called_once()
        result = self.save(); self.assertEqual(result['result']['outcome'], 'failed')
        for key in ('gold','xp','characters','inventory','hours','sequence','location'):
            self.assertEqual(result[key], self.before[key])
        self.assertIsNone(self.app.pending); self.assertIsNone(self.app.preview)
    def test_modal_reentry_is_ignored(self):
        def answer(*args, **kwargs): self.app.ask_retreat(); return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer) as ask: self.app.ask_retreat()
        ask.assert_called_once(); self.assertEqual(len(self.retreats()), 1)
    def test_closed_window_cannot_later_accept(self):
        before = self.save()
        def answer(*args, **kwargs): self.app.close(); return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer): self.app.ask_retreat()
        self.assertEqual(self.retreats(), []); self.assertEqual(self.save(), before)
    def test_stale_battle_does_not_apply_to_changed_state(self):
        def answer(*args, **kwargs):
            self.assertTrue(self.engine.call(op='act', kind='guard')['ok']); return True
        with patch('campaign_app.messagebox.askyesno', side_effect=answer): self.app.ask_retreat()
        self.assertEqual(self.retreats(), [])
        self.assertEqual(self.engine.call(op='view')['campaign']['phase'], 'battle')
        self.assertTrue(self.app.root.destroyed); self.app.on_close.assert_called_once()
    def test_porter_modal_and_finished_battle_do_not_open_retreat(self):
        with patch('campaign_app.messagebox.askyesno') as ask:
            self.app.porter_confirmation = object(); self.app.ask_retreat()
            self.app.porter_confirmation = None
            self.app.data['state']['result'] = 'finished'; self.app.ask_retreat()
        ask.assert_not_called(); self.assertEqual(self.retreats(), [])
    def test_legacy_and_trial_have_no_retreat(self):
        self.assertFalse(hasattr(App, 'ask_retreat')); self.assertFalse(hasattr(TrialBattleApp, 'ask_retreat'))
        self.engine.call(op='reset'); before = self.engine.call(op='view')
        self.assertFalse(self.engine.call(op='campaign', action='retreat')['ok'])
        self.assertEqual(self.engine.call(op='view'), before)
    def test_campaign_opens_campaign_only_shell(self):
        parent = CampaignApp.__new__(CampaignApp); parent.battle_window = None
        parent.root, parent.bridge, parent.images = Widget(), self.engine, {}
        parent.refresh, parent.act = Mock(), Mock()
        with patch('campaign_app.tk.Toplevel', Widget), patch('campaign_app.CampaignBattleApp') as shell: parent.open_battle()
        shell.assert_called_once(); self.assertIs(shell.call_args.kwargs['on_close'], parent.refresh)

if __name__ == '__main__': unittest.main()
