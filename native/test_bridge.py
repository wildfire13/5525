import unittest
from app import Bridge

class BridgeTests(unittest.TestCase):
    def setUp(self): self.b=Bridge()
    def tearDown(self): self.b.close()
    def test_invalid_is_unchanged(self):
        d=self.b.call(op='reset');before=d['state']
        d=self.b.call(op='act',kind='move',target=49)
        self.assertFalse(d['ok']);self.assertEqual(d['state'],before)
    def test_victory(self):
        self.b.call(op='reset',scenario='victory')
        d=self.b.call(op='act',kind='attack',target='enemy-archer')
        self.assertTrue(d['ok']);self.assertIn('勝利',d['state']['result'])
        self.assertIsNone(d['state']['actor'])
        self.assertFalse(self.b.call(op='act',kind='guard')['ok'])
    def test_defeat(self):
        self.b.call(op='reset',scenario='defeat')
        d=self.b.call(op='act',kind='guard')
        self.assertIn('敗北',d['state']['result'])
    def test_porter_failure(self):
        self.b.call(op='reset',scenario='porter')
        d=self.b.call(op='act',kind='guard')
        self.assertEqual(d['state']['failure'],'porter')
        self.assertTrue(any(u['hp']>0 and u['side']=='ally' for u in d['state']['units']))
    def test_stamp_empty_center_enemy_only(self):
        d=self.b.call(op='reset',scenario='stamp')
        self.assertEqual(d['stampAreas']['25'],[15,25,35])
        before={u['id']:u['hp'] for u in d['state']['units']}
        self.assertFalse(any(u['hp']>0 and u['pos']==25 for u in d['state']['units']))
        d=self.b.call(op='act',kind='skill',target=25)
        self.assertTrue(d['ok'])
        after={u['id']:u for u in d['state']['units']}
        self.assertLess(after['enemy-archer']['hp'],before['enemy-archer'])
        self.assertEqual(after['scout']['hp'],before['scout'])
        self.assertEqual(after['enemy-guard']['hp'],before['enemy-guard'])
        self.assertEqual(after['warrior']['mp'],5)
    def test_snipe_and_reset(self):
        d=self.b.call(op='reset');a=next(u for u in d['state']['units'] if u['id']=='archer')
        d=self.b.call(op='act',kind='skill',target='enemy-archer')
        self.assertTrue(d['ok']);self.assertEqual(next(u for u in d['state']['units'] if u['id']=='archer')['mp'],a['mp']-1)
        d=self.b.call(op='reset');self.assertEqual(d['state']['actions'],0);self.assertIsNone(d['state']['result'])

if __name__=='__main__':unittest.main()
