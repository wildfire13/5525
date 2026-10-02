"""Scheduling/geometry regression only: no display or visual Tk QA."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from campaign_app import CampaignApp

class Scheduler:
    def __init__(self): self.jobs = {}; self.sequence = 0
    def after_idle(self, command):
        self.sequence += 1; self.jobs[self.sequence] = command; return self.sequence
    def after_cancel(self, job): del self.jobs[job]
    def flush(self):
        while self.jobs:
            jobs, self.jobs = self.jobs, {}
            for command in jobs.values(): command()

class Canvas:
    def __init__(self, top=1200, viewport=600):
        self.top = top; self.viewport = viewport; self.region=(0, 0, 1100, 3000)
        self.position=(0, 0); self.fractions=[]; self.item_width=None
    def canvasy(self, y): return self.top + y
    def winfo_width(self): return 1100
    def winfo_height(self): return self.viewport
    def coords(self, item, x, y): self.position=(x, y)
    def configure(self, **kw): self.region = kw['scrollregion']
    def xview_moveto(self, fraction): self.x = fraction
    def yview_moveto(self, fraction):
        self.fractions.append(fraction); self.top=fraction*self.region[3]
    def itemconfigure(self, item, **kw): self.item_width=kw['width']

class Panel:
    def __init__(self, height=3000): self.height=height
    def winfo_reqheight(self): return self.height
    def winfo_children(self): return []

class ScrollTests(unittest.TestCase):
    def setUp(self):
        self.app=CampaignApp.__new__(CampaignApp)
        a=self.app;a.root=Scheduler();a.scroll=Canvas();a.panel=Panel();a.panel_id=7
        a._scroll_sync_job=None;a._scroll_reset_pending=False;a._render_key=None
        a.data={'campaign':{'phase':'town','location':'east','selected':[]}}
        a.page='shop';a.notice='';a.foot=Mock();a.status=Mock();a.render_town=Mock()
    def test_short_content_cannot_leave_negative_blank_offset(self):
        a=self.app;a.panel.height=180;a.scroll.top=-218
        a._queue_scroll_sync();a.root.flush()
        self.assertEqual(a.scroll.region,(0,0,1100,600));self.assertEqual(a.scroll.position,(0,0));self.assertEqual(a.scroll.top,0)
    def test_long_to_short_clamps_old_midpage_position(self):
        a=self.app;a.panel.height=218
        a._queue_scroll_sync();a.root.flush();self.assertEqual(a.scroll.top,0)
    def test_same_page_retains_valid_position(self):
        a=self.app;a._queue_scroll_sync();a.root.flush();self.assertEqual(a.scroll.top,1200)
    def test_same_page_shrink_clamps_to_bottom(self):
        a=self.app;a.panel.height=1400;a.scroll.top=1800
        a._queue_scroll_sync();a.root.flush();self.assertEqual(a.scroll.top,800)
    def test_reset_happens_after_new_geometry_and_is_coalesced(self):
        a=self.app;a._queue_scroll_sync();a._queue_scroll_sync(reset=True);a._queue_scroll_sync()
        self.assertEqual(len(a.root.jobs),1);self.assertEqual(a.scroll.top,1200)
        a.panel.height=200;a.root.flush();self.assertEqual(a.scroll.top,0)
    def test_set_page_requests_deferred_reset(self):
        a=self.app;a.render=Mock();a.set_page('board')
        a.render.assert_called_once_with(reset_scroll=True);self.assertEqual(a.scroll.top,1200)
    def test_render_resets_changed_location_page_and_phase(self):
        a=self.app;a._render_key=('town','east','shop');a.render();a.root.flush();self.assertEqual(a.scroll.top,1200)
        a.data['campaign']['location']='south';a.render();a.panel.height=200;a.root.flush();self.assertEqual(a.scroll.top,0)
        a.scroll.top=80;a.page='board';a.render();a.root.flush();self.assertEqual(a.scroll.top,0)
    def test_successful_load_resets_even_if_current_page_same(self):
        a=self.app;a.request=Mock(return_value={'ok':True});a.close_battle=Mock();a.render=Mock()
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'south.json';path.write_text(json.dumps({'state':{}}))
            with patch('campaign_app.filedialog.askopenfilename',return_value=str(path)),patch('campaign_app.messagebox.askyesno',return_value=True):a.load()
        a.render.assert_called_once_with(reset_scroll=True);self.assertEqual(a.page,'board')
    def test_invalid_load_does_not_request_reset(self):
        a=self.app;a.request=Mock(return_value={'ok':False});a.close_battle=Mock();a.render=Mock()
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'bad.json';path.write_text('{}')
            with patch('campaign_app.filedialog.askopenfilename',return_value=str(path)),patch('campaign_app.messagebox.askyesno',return_value=True):a.load()
        a.render.assert_called_once_with(reset_scroll=False);a.close_battle.assert_not_called()
    def test_restart_requests_reset(self):
        a=self.app;a.request=Mock(return_value={'ok':True});a.close_battle=Mock();a.render=Mock()
        with patch('campaign_app.messagebox.askyesno',return_value=True):a.restart()
        a.render.assert_called_once_with(reset_scroll=True)
    def test_resize_schedules_region_update(self):
        a=self.app;a._resize_scroll(type('Event',(),{'width':980})())
        self.assertEqual(a.scroll.item_width,980);self.assertEqual(len(a.root.jobs),1)

if __name__=='__main__':unittest.main(verbosity=2)
