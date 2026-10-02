"""Headless controller/real-bridge regression tests, not native GUI evidence.

Tk widgets and draw() are isolated test doubles. Ordinary public journey actions
reach the porter turn; YES/NO are checked against the real Node battle engine.
Stale/invalid response tests explicitly mock view data, without altering engine
state. Actual window rendering, focus and OS interaction need separate GUI QA.
"""
from copy import deepcopy
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from app import App, Bridge


class Widget:
    """Small Tk surface double that exposes callbacks, not a GUI emulator."""
    def __init__(self, parent=None, **options):
        self.parent, self.options = parent, options
        self.children, self.protocols, self.bindings = [], {}, {}
        self.grabbed = self.destroyed = self.focused = False
        if parent is not None: parent.children.append(self)

    def pack(self, **_): pass
    def title(self, *_): pass
    def transient(self, *_): pass
    def resizable(self, *_): pass
    def configure(self, **options): self.options.update(options)
    def protocol(self, key, callback): self.protocols[key] = callback
    def bind(self, key, callback): self.bindings[key] = callback
    def update_idletasks(self): pass
    def winfo_rootx(self): return 30
    def winfo_rooty(self): return 25
    def winfo_width(self): return 1210
    def winfo_height(self): return 820
    def winfo_reqwidth(self): return 400
    def winfo_reqheight(self): return 200
    def geometry(self, value): self.position = value
    def grab_set(self): self.grabbed = True
    def grab_current(self): return self if self.grabbed else None
    def grab_release(self): self.grabbed = False
    def focus_set(self): self.focused = True
    def destroy(self): self.destroyed = True
    def cget(self, key): return self.options[key]

    def find(self, text):
        if self.options.get('text') == text: return self
        for child in self.children:
            found = child.find(text)
            if found is not None: return found
        return None


class PorterDialogControllerTests(unittest.TestCase):
    def setUp(self):
        self.engine = Bridge()
        self.addCleanup(self.engine.close)
        self.engine.call(op='journey_start')
        for action, args in [('accept', ['parts']), ('depart', ['medicine', 'convoy']),
                             ('travel', ['short']), ('begin', [])]:
            self.assertTrue(self.engine.call(op='journey', action=action, args=args)['ok'])
        data = self.engine.call(op='view')
        for _ in range(20):
            if data['state']['actor'] == 'porter': break
            data = self.engine.call(op='act', kind='guard')
            self.assertTrue(data['ok'])
        self.assertEqual(data['state']['actor'], 'porter')
        self.assertEqual(data['choices']['skill'], ['porter'])
        self.app = App.__new__(App)
        self.app.root = Widget()
        self.app.bridge = Mock(wraps=self.engine)
        self.app.owns_bridge = False
        self.app.on_close = None
        self.app.data = data
        self.app.mode, self.app.pending = 'move', None
        self.app.preview, self.app.preview_kind = None, 'attack'
        self.app.porter_dialog, self.app.porter_confirmation = None, None
        self.app.message = ''
        self.app.draw = Mock()
        self.app.buttons = {name: Widget(text=name) for name in
                            ('attack', 'skill', 'move', 'guard', 'item')}
        for name in ('Toplevel', 'Label', 'Frame', 'Button'):
            p = patch('app.tk.' + name, Widget)
            p.start()
            self.addCleanup(p.stop)

    def acts(self):
        return [call.kwargs for call in self.app.bridge.call.call_args_list
                if call.kwargs.get('op') == 'act']

    def open_dialog(self):
        self.app.set_mode('skill')
        dialog = self.app.porter_dialog
        self.assertIsNotNone(dialog)
        self.assertTrue(dialog.grabbed)
        self.assertIsNotNone(dialog.find('陣形強化を実行しますか？'))
        self.assertTrue(dialog.find('NO').focused)
        self.assertIsNone(self.app.pending)
        return dialog

    def test_click_immediately_opens_question_without_target_or_state_change(self):
        before = self.engine.call(op='view')
        self.open_dialog()
        self.assertEqual(self.app.mode, 'move')
        self.assertEqual(self.engine.call(op='view'), before)
        self.assertEqual(self.acts(), [])

    def test_yes_directly_acts_on_self_once_even_with_double_callback(self):
        before = self.engine.call(op='view')
        dialog = self.open_dialog()
        yes = dialog.find('YES').options['command']
        yes()
        yes()  # A queued callback from the destroyed window must be harmless.
        self.assertTrue(dialog.destroyed)
        self.assertFalse(dialog.grabbed)
        self.assertIsNone(self.app.porter_confirmation)
        self.assertIsNone(self.app.pending)
        self.assertIsNone(self.app.preview)
        self.assertEqual(self.acts(), [{'op': 'act', 'kind': 'skill', 'target': 'porter'}])
        after = self.engine.call(op='view')
        self.assertEqual(after['state']['actions'], before['state']['actions'] + 1)
        before_porter = next(u for u in before['state']['units'] if u['id'] == 'porter')
        after_porter = next(u for u in after['state']['units'] if u['id'] == 'porter')
        self.assertEqual(after_porter['mp'], before_porter['mp'] - 1)
        self.assertTrue(after['boosted']['ally'])

    def test_no_close_escape_and_root_cancel_leave_gameplay_unchanged(self):
        for dismiss in ('NO', 'close', 'Escape', 'root_cancel'):
            with self.subTest(dismiss=dismiss):
                before = self.engine.call(op='view')
                dialog = self.open_dialog()
                if dismiss == 'NO': dialog.find('NO').options['command']()
                elif dismiss == 'close': dialog.protocols['WM_DELETE_WINDOW']()
                elif dismiss == 'Escape':
                    self.assertEqual(dialog.bindings['<Escape>'](None), 'break')
                else: self.app.cancel()
                self.assertTrue(dialog.destroyed)
                self.assertFalse(dialog.grabbed)
                self.assertIsNone(self.app.porter_confirmation)
                self.assertIsNone(self.app.pending)
                self.assertEqual(self.app.mode, 'move')
                self.assertEqual(self.engine.call(op='view'), before)
        self.assertEqual(self.acts(), [])

    def test_modal_blocks_repeat_open_and_underlying_board_commands(self):
        dialog = self.open_dialog()
        token = self.app.porter_confirmation
        calls = self.app.bridge.call.call_count
        self.app.set_mode('skill')
        self.app.ask_porter_boost()
        self.app.set_mode('guard')
        self.app.click_cell(SimpleNamespace(x=160, y=160))
        self.app.commit()
        self.app.inspect_preview('skill')
        self.app.reset()
        self.assertIs(self.app.porter_dialog, dialog)
        self.assertIs(self.app.porter_confirmation, token)
        self.assertEqual(self.app.bridge.call.call_count, calls)

    def test_existing_move_preview_is_not_replaced_by_boost_dialog(self):
        self.app.set_mode('move')
        target = self.app.data['choices']['move'][0]
        self.app.click_cell(SimpleNamespace(x=(target % 10) * 74 + 30,
                                            y=(target // 10) * 74 + 30))
        self.assertEqual(self.app.pending, ('move', target))
        before = (self.app.mode, self.app.pending, deepcopy(self.app.preview), self.app.message)
        calls = self.app.bridge.call.call_count
        self.app.set_mode('skill')
        self.app.ask_porter_boost()
        self.assertIsNone(self.app.porter_dialog)
        self.assertEqual((self.app.mode, self.app.pending, self.app.preview, self.app.message), before)
        self.assertEqual(self.app.bridge.call.call_count, calls)

    def test_unavailable_porter_cannot_open_dialog(self):
        original = deepcopy(self.app.data)
        for reason in ('mp', 'formation', 'choices', 'finished'):
            with self.subTest(reason=reason):
                self.app.data = deepcopy(original)
                if reason == 'mp': self.app.actor()['mp'] = 0
                elif reason == 'formation': self.app.data['formed']['ally'] = False
                elif reason == 'choices': self.app.data['choices']['skill'] = []
                else: self.app.data['state']['result'] = 'Finished'
                self.app.set_mode('skill')
                self.assertIsNone(self.app.porter_dialog)
                self.assertIsNone(self.app.pending)
        self.assertEqual(self.acts(), [])

    def test_yes_revalidates_mp_formation_actor_and_turn_before_acting(self):
        original = deepcopy(self.app.data)
        for reason in ('mp', 'formation', 'choices', 'actor', 'turn', 'finished'):
            with self.subTest(reason=reason):
                self.app.data = deepcopy(original)
                dialog = self.open_dialog()
                stale = deepcopy(original)
                if reason == 'mp':
                    next(u for u in stale['state']['units'] if u['id'] == 'porter')['mp'] = 0
                elif reason == 'formation': stale['formed']['ally'] = False
                elif reason == 'choices': stale['choices']['skill'] = []
                elif reason == 'actor': stale['state']['actor'] = 'scout'
                elif reason == 'turn': stale['state']['actions'] += 1
                else: stale['state']['result'] = 'Finished'
                # This is an isolated stale-response/controller boundary test.
                with patch.object(self.app.bridge, 'call', return_value=stale) as call:
                    dialog.find('YES').options['command']()
                    call.assert_called_once_with(op='view')
                self.assertIsNone(self.app.porter_confirmation)
                self.assertIsNone(self.app.pending)
        self.assertEqual(self.acts(), [])
        self.assertEqual(self.engine.call(op='view'), original)

    def test_old_callback_cannot_accept_a_new_confirmation(self):
        old = self.open_dialog()
        old_yes = old.find('YES').options['command']
        old.find('NO').options['command']()
        current = self.open_dialog()
        old_yes()
        self.assertIs(self.app.porter_dialog, current)
        self.assertEqual(self.acts(), [])
        current.find('YES').options['command']()
        self.assertEqual(len(self.acts()), 1)

    def test_window_close_dismisses_confirmation_without_action(self):
        before = self.engine.call(op='view')
        dialog = self.open_dialog()
        self.app.close()
        dialog.find('YES').options['command']()
        self.assertTrue(dialog.destroyed)
        self.assertTrue(self.app.root.destroyed)
        self.assertEqual(self.acts(), [])
        self.assertEqual(self.engine.call(op='view'), before)

    def test_other_skill_keeps_board_preview_cancel_and_commit_flow(self):
        self.app.data = self.engine.call(op='reset')
        before = deepcopy(self.app.data)
        for commit in (False, True):
            self.app.set_mode('skill')
            self.assertIsNone(self.app.porter_dialog)
            self.assertIsNone(self.app.pending)
            target = self.app.data['choices']['skill'][0]
            unit = next(u for u in self.app.data['state']['units'] if u['id'] == target)
            self.app.click_cell(SimpleNamespace(x=(unit['pos'] % 10) * 74 + 30,
                                                y=(unit['pos'] // 10) * 74 + 30))
            self.assertEqual(self.app.pending, ('skill', target))
            self.assertEqual(self.engine.call(op='view'), before)
            if commit: self.app.commit()
            else: self.app.cancel()
        self.assertEqual(self.acts(), [{'op': 'act', 'kind': 'skill', 'target': target}])

    def test_equipped_skill_overrides_nonporter_job_but_never_porter(self):
        actor = self.app.actor()
        actor['weapon'], actor['equippedSkill'] = 'hammer', 'stamp'
        self.assertEqual(self.app.active_skill(), 'porter')
        self.assertIn('陣形強化', self.app.mode_hint('skill'))
        actor['job'], actor['equippedSkill'] = 'scout', 'archer'
        self.assertEqual(self.app.active_skill(), 'archer')
        self.assertIn('スナイプ', self.app.mode_hint('skill'))
        actor['equippedSkill'] = None
        self.assertEqual(self.app.active_skill(), 'stamp')
        actor['weapon'] = None
        self.assertEqual(self.app.active_skill(), 'scout')

    def test_equipped_stamp_uses_cell_target_instead_of_unit_target(self):
        actor = self.app.actor()
        actor['job'], actor['weapon'], actor['equippedSkill'] = 'guard', None, 'stamp'
        self.app.mode = 'skill'
        self.app.data['choices']['skill'] = [25]
        self.app.inspect_preview = Mock()
        self.app.click_cell(SimpleNamespace(x=5 * 74 + 30, y=2 * 74 + 30))
        self.assertEqual(self.app.pending, ('skill', 25))
        self.app.inspect_preview.assert_called_once_with()


if __name__ == '__main__':
    unittest.main(verbosity=2)
