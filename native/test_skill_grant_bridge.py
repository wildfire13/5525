"""Per-grant bridge contracts; real request process, isolated in-memory campaigns."""
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from test_journey_bridge import Session

BASE = Path(__file__).resolve().parent

class SkillGrantBridgeTests(unittest.TestCase):
    def test_two_heal_buttons_have_independent_selection_and_cooldown(self):
        bridge=Session();self.addCleanup(bridge.close)
        bridge.call(op='campaign_start')
        save=bridge.call(op='campaign_save')['data'];save['state'].update(location='east',gold=9999)
        self.assertTrue(bridge.call(op='campaign_load',data=save)['ok'])
        self.assertTrue(bridge.call(op='campaign',action='buyGear',args=['mage','staff-silver-1','leftHand'])['ok'])
        data=bridge.call(op='campaign',action='trial',args=['mage','staff-wood','rightHand'])
        options=[o for o in data['skillset'] if o['id']=='mage']
        self.assertEqual(len(options),2)
        self.assertEqual(len({o['key'] for o in options}),2)
        self.assertEqual({o['sources'][0]['slot'] for o in options},{'rightHand','leftHand'})
        self.assertEqual({o['sources'][0]['itemName'] for o in options},{'木製の癒し杖','銀製の癒し杖＋1'})
        for option in options:
            selected=bridge.call(op='select_skill',skillId=option['key'])
            self.assertTrue(selected['ok']);self.assertEqual([o['key'] for o in selected['skillset'] if o['selected']],[option['key']])
        used=options[-1];other=options[0]
        before=next(u['mp'] for u in selected['state']['units'] if u['id']=='mage')
        result=bridge.call(op='act',kind='skill',target='guard')
        self.assertTrue(result['ok'])
        self.assertEqual(next(u['mp'] for u in result['state']['units'] if u['id']=='mage'),before-1)
        by_key={o['key']:o for o in result['skillset']}
        self.assertGreater(by_key[used['key']]['cooldown'],0)
        self.assertEqual(by_key[other['key']]['cooldown'],0)
        unchanged=bridge.call(op='view')['state']
        self.assertFalse(bridge.call(op='act',kind='skill',target='archer')['ok'])
        self.assertEqual(bridge.call(op='view')['state'],unchanged)
        available=bridge.call(op='select_skill',skillId=other['key'])
        self.assertTrue(available['ok'])
        self.assertTrue(bridge.call(op='act',kind='skill',target='archer')['ok'])

    def test_return_buttons_remain_independent_once_per_battle(self):
        bridge=Session();self.addCleanup(bridge.close)
        bridge.call(op='campaign_start')
        save=bridge.call(op='campaign_save')['data'];save['state'].update(location='north',gold=9999)
        self.assertTrue(bridge.call(op='campaign_load',data=save)['ok'])
        for gear,slot in [('return-ring-1','accessory1'),('return-ring-2','accessory2')]:
            self.assertTrue(bridge.call(op='campaign',action='buyGear',args=['mage',gear,slot])['ok'])
        data=bridge.call(op='campaign',action='trial',args=['mage','return-ring-1','accessory1'])
        options=data['returnSkillset'];self.assertEqual(len(options),2)
        self.assertEqual(len({o['key'] for o in options}),2)
        selected=bridge.call(op='select_return_skill',skillId=options[0]['key'])
        self.assertTrue(selected['ok'])
        first=bridge.call(op='act',kind='return',target=0)
        self.assertTrue(first['ok'])
        self.assertEqual([o['used'] for o in first['returnSkillset']],[True,False])
        self.assertTrue(bridge.call(op='act',kind='guard')['ok'])
        self.assertEqual([o['used'] for o in bridge.call(op='view')['returnSkillset']],[True,False])
        self.assertTrue(bridge.call(op='select_return_skill',skillId=options[1]['key'])['ok'])
        second=bridge.call(op='act',kind='return',target=1)
        self.assertTrue(second['ok'])
        self.assertTrue(all(o['used'] for o in second['returnSkillset']))
        self.assertTrue(bridge.call(op='select_return_skill',skillId=options[0]['key'])['ok'])
        self.assertFalse(bridge.call(op='act',kind='return',target=2)['ok'])

    def test_broken_master_returns_safe_error_without_process_exit(self):
        for mode in ['missing','corrupt']:
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as folder:
                root=Path(folder)
                for path in BASE.iterdir():
                    if path.suffix in ['.js','.cjs','.py']:
                        shutil.copy2(path,root/path.name)
                (root/'data').mkdir()
                if mode=='corrupt':(root/'data/master.sqlite').write_bytes(b'not sqlite')
                requests=''.join(json.dumps({'op':op})+'\n' for op in ['campaign_start','campaign_load','campaign_save'])
                result=subprocess.run(['node',str(root/'bridge.cjs')],input=requests,text=True,capture_output=True,timeout=20)
                self.assertEqual(result.returncode,0,result.stderr)
                replies=[json.loads(line) for line in result.stdout.splitlines()]
                self.assertEqual(len(replies),3)
                for reply in replies:
                    self.assertFalse(reply['ok']);self.assertIsNone(reply['state'])
                    self.assertIn('セーブデータは変更していません',reply['error'])
                    self.assertNotIn(folder,reply['error']);self.assertNotIn('Traceback',reply['error'])

if __name__=='__main__':unittest.main()
