import copy
import json
from pathlib import Path
import shutil
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock
from sound_effects import ASSETS, CUES, SoundCatalog, SoundPlayer, phase_sound


class Backend:
    def __init__(self):self.active=False;self.path=None;self.stops=0
    def start(self,path):self.path=path;self.active=True
    def playing(self):return self.active
    def stop(self):self.active=False;self.stops+=1


class SoundEffectsTests(unittest.TestCase):
    def setUp(self):
        self.root=Mock();self.created=[]
        def factory():
            backend=Backend();self.created.append(backend);return backend
        self.player=SoundPlayer(self.root,SoundCatalog(),factory);self.addCleanup(self.player.close)

    def test_installed_original_eight_clips(self):
        self.assertIsNone(self.player.catalog.error)
        self.assertEqual(set(self.player.catalog.clips),CUES)
        self.assertEqual(self.player.catalog.durations['victory'],.95)

    def test_damage_heal_miss_and_physical_vs_cast_mapping(self):
        state={'result':None}
        for skill,cue in [('archer','attack'),('stamp','attack'),('healingCross','skill'),('manaGift','skill')]:
            self.assertEqual(phase_sound({'phase':'action','kind':'skill','skill_id':skill},state),cue)
        self.assertEqual(phase_sound({'phase':'action','kind':'attack'},state),'attack')
        for phase,start,end,cue in [('hurt',10,4,'hit'),('hurt',10,10,None),('heal',4,10,'heal'),('heal',10,10,None)]:
            self.assertEqual(phase_sound({'phase':phase,'from':start,'to':end},state),cue)
        self.assertIsNone(phase_sound({'phase':'settled'},state))

    def test_area_targets_redraw_and_result_are_deduplicated(self):
        frame={'phase':'hurt','from':100,'to':80,'action_id':'1:0:1','impact_group_id':0}
        for _ in range(30):self.player.phase(frame,{'result':None})
        self.assertEqual(len(self.created),1)
        self.player.phase(dict(frame,action_id='1:1:1'),{'result':None})
        self.assertEqual(len(self.created),2)
        result=dict(frame,phase='settled')
        for _ in range(3):self.player.phase(result,{'result':'victory','units':[{'side':'enemy','hp':0}]})
        self.assertEqual([b.path.name for b in self.created],['hit.wav','hit.wav','victory.wav'])
        self.assertEqual(phase_sound(result,{'result':'failure','failure':'porter','units':[]}),'failure')

    def test_bounded_four_gameplay_plus_one_ui_never_touches_other_audio(self):
        for i in range(8):self.player.play('hit',i)
        for _ in range(4):self.player.ui('cancel')
        self.assertEqual(len(self.player.voices),5)
        self.assertEqual(sum(c=='gameplay' for c,_ in self.player.voices),4)
        self.assertEqual(sum(c=='ui' for c,_ in self.player.voices),1)
        self.assertTrue(all(not b.active for b in self.created[:4]))

    def test_muting_stops_existing_and_does_not_replay_old_events(self):
        self.player.play('skill',1);self.player.set_muted(True)
        self.assertFalse(self.created[0].active)
        self.player.play('heal',2);self.player.set_muted(False);self.player.play('heal',2)
        self.assertEqual(len(self.created),1)
        self.player.play('heal',3);self.assertEqual(len(self.created),2)
        self.player.close();self.player.play('attack',4)
        self.assertFalse(any(b.active for b in self.created))

    def test_finished_handles_are_released_and_timer_stops(self):
        self.player.play('confirm',1,'ui');self.created[0].active=False
        self.player._poll()
        self.assertEqual(self.player.voices,[]);self.assertIsNone(self.player.timer)
        self.assertEqual(self.created[0].stops,1)

    def test_manifest_tamper_and_missing_files_fail_silent(self):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory);shutil.copytree(ASSETS,base,dirs_exist_ok=True)
            manifest=json.loads((base/'manifest.json').read_text(encoding='utf-8'))
            for path in ['../outside.wav','se/missing.wav']:
                bad=copy.deepcopy(manifest);bad['se'][0]['filename']=path
                (base/'manifest.json').write_text(json.dumps(bad),encoding='utf-8')
                catalog=SoundCatalog(base);self.assertTrue(catalog.error);self.assertFalse(catalog.clips)

    def test_noncombat_request_confirm_excludes_combat_and_redraw(self):
        from campaign_app import CampaignApp
        app=CampaignApp.__new__(CampaignApp);app.sounds=Mock();app.bridge=Mock();app.foot=Mock()
        app.bridge.call.return_value={'ok':True}
        for action in ['begin','finishBattle','endTrial','trial','forecast','previewGear']:
            app.request(op='campaign',action=action)
        app.request(op='view');app.request(op='campaign_save')
        app.sounds.ui.assert_not_called()
        app.request(op='campaign',action='buyGear');app.sounds.ui.assert_called_once_with('confirm')
        app.bridge.call.return_value={'ok':False,'error':'invalid'}
        app.request(op='campaign',action='buyGear');self.assertEqual(app.sounds.ui.call_args.args,('cancel',))


if __name__=='__main__':unittest.main()
