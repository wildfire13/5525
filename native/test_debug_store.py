import copy
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import debug_store as D

SID='a'*32

def event(seq=1,**extra):
    return dict(seq=seq,elapsed_ms=seq*10,request_id=1,kind='request_end',op='campaign.accept',ok=True,duration_ms=12,data={},**extra)

def batch(events=None,session=SID):
    return dict(action='batch',session=session,version=D.VERSION,events=[event()] if events is None else events)

class DebugStoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/'diagnostics'/'debug.sqlite'
        self.stores=[];self.processes=[]
    def tearDown(self):
        for store in self.stores:store.close()
        for p in self.processes:
            if p.poll() is None:p.kill()
            p.communicate(timeout=5)
        self.tmp.cleanup()
    def store(self):
        result=D.Store(self.path);self.stores.append(result);return result
    def worker(self):
        p=subprocess.Popen([sys.executable,'-X','utf8','-B',str(Path(D.__file__)),'--db',str(self.path)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        self.processes.append(p);return p
    def send(self,p,value):
        p.stdin.write(json.dumps(value)+'\n');p.stdin.flush();return json.loads(p.stdout.readline())
    def test_roundtrip_snapshot_and_clean_close(self):
        grant=dict(slot='rightHand',grant=2,item_ref='f'*64,skill='mage')
        value=event();value['data']={'before':{'actor':2,'order':[2,1],'selected_grant':grant,'selected_return_grant':dict(grant,skill='returnHome'),'cooldowns':[dict(grant,actor=2,remaining=1)],'returns':[]},'after':{'actor':1,'selected_grant':None},'busy':False,'reason':'success'}
        s=self.store();self.assertTrue(s.handle(batch([value]))['ok'])
        self.assertEqual(D.read_events(self.path)[0]['data'],value['data'])
        self.assertEqual(D.read_events(self.path)[0]['elapsed_ms'],10)
        self.assertEqual(D.read_sessions(self.path)[0]['clean_closed'],0)
        request=dict(action='close',session=SID,version=D.VERSION)
        self.assertTrue(s.handle(request)['ok']);self.assertTrue(s.handle(request)['ok'])
        self.assertEqual(D.read_sessions(self.path)[0]['clean_closed'],1)
        self.assertEqual(s.handle(batch([event(2)]))['code'],'session_closed')
    def test_idempotence_conflict_and_atomic_batch(self):
        s=self.store();first=s.handle(batch());self.assertEqual(first['accepted'],1)
        self.assertEqual(s.handle(batch())['accepted'],0)
        bad=event();bad['ok']=False
        self.assertEqual(s.handle(batch([bad,event(2)]))['code'],'sequence_conflict')
        self.assertEqual(len(D.read_events(self.path)),1)
        self.assertEqual(s.handle(batch([event(2),event(2)]))['code'],'invalid')
        self.assertEqual(len(D.read_events(self.path)),1)
    def test_elapsed_clock_cannot_move_backwards(self):
        s=self.store();self.assertTrue(s.handle(batch())['ok'])
        value=event(2);value['elapsed_ms']=9
        self.assertEqual(s.handle(batch([value]))['code'],'sequence_conflict')
        self.assertEqual(len(D.read_events(self.path)),1)
    def test_privacy_unknown_fields_rejected_before_open(self):
        secret='PERSON /home/private/token=password'
        inputs=[]
        for key in ['name','path','payload','error','token']:
            r=batch();r['events'][0]['data'][key]=secret;inputs.append(r)
        for key in ['op','kind']:
            r=batch();r['events'][0][key]=secret;inputs.append(r)
        for key in ['session','version']:
            r=batch();r[key]=secret;inputs.append(r)
        r=batch();r['events'][0]['data']={'before':{'actor':secret}};inputs.append(r)
        r=batch();r['events'][0]['data']={'before':{'selected_grant':dict(slot='rightHand',grant=1,item_ref=secret,skill='mage')}};inputs.append(r)
        s=self.store()
        for value in inputs:
            result=s.handle(value);self.assertEqual(result,{'ok':False,'code':'invalid'});self.assertNotIn(secret,json.dumps(result))
        self.assertFalse(self.path.exists())
        self.assertTrue(s.handle(batch())['ok']);s.close();self.assertNotIn(secret.encode(),self.path.read_bytes())
    def test_strict_types_limits(self):
        s=self.store()
        for key,value in [('seq',True),('seq',0),('elapsed_ms',-1),('elapsed_ms',True),('request_id',-1),('duration_ms',600001),('ok',1),('op',[]),('data',{'dropped':-1})]:
            r=batch();r['events'][0][key]=value;self.assertEqual(s.handle(r)['code'],'invalid')
        self.assertEqual(s.handle(batch([event(n) for n in range(1,34)]))['code'],'invalid')
        self.assertFalse(self.path.exists())
    def test_lock_is_bounded_without_internal_retry(self):
        s=self.store();self.assertTrue(s.handle(batch())['ok'])
        with closing(sqlite3.connect(self.path,isolation_level=None)) as lock:
            lock.execute('BEGIN IMMEDIATE');start=time.monotonic();result=s.handle(batch([event(2)]));elapsed=time.monotonic()-start
            self.assertEqual(result['code'],'busy');self.assertLess(elapsed,.25)
            lock.rollback()
        self.assertEqual(s.handle(batch([event(2)]))['accepted'],1)
    def test_corrupt_is_preserved_and_disabled(self):
        self.path.parent.mkdir();original=b'private corrupt diagnostic bytes';self.path.write_bytes(original)
        s=self.store();self.assertEqual(s.handle(batch())['code'],'incompatible');self.assertEqual(self.path.read_bytes(),original)
        self.assertEqual(s.handle(batch([event(2)]))['code'],'incompatible')
    def test_readonly_write_failure_generic(self):
        self.assertTrue(self.store().handle(batch())['ok']);real=sqlite3.connect
        def readonly(*args,**kwargs):return real(self.path.as_uri()+'?mode=ro',uri=True,**kwargs)
        s=self.store()
        with patch('debug_store.sqlite3.connect',side_effect=readonly):result=s.handle(batch(session='b'*32))
        self.assertEqual(result,{'ok':False,'code':'unavailable'});self.assertEqual(len(D.read_events(self.path)),1)
    def test_invalid_parent_and_oversized_files_preserved(self):
        self.path.parent.write_bytes(b'not-directory');s=self.store();self.assertEqual(s.handle(batch())['code'],'unavailable');self.path.parent.unlink()
        self.path.parent.mkdir();self.path.touch()
        with self.path.open('r+b') as f:f.truncate(D.MAX_DB_BYTES+1)
        self.assertEqual(self.store().handle(batch())['code'],'full');self.assertEqual(self.path.stat().st_size,D.MAX_DB_BYTES+1)
    def test_retention_count_sessions_and_size(self):
        for n in range(22):
            s=self.store();self.assertTrue(s.handle(batch(session=f'{n:032x}'))['ok']);s.close()
        self.assertEqual(len(D.read_sessions(self.path)),20);self.assertEqual(len(D.read_events(self.path)),20)
        s=self.store();sid='f'*32
        for start in range(1,10050,32):
            self.assertTrue(s.handle(batch([event(n) for n in range(start,min(start+32,10051))],session=sid))['ok'])
        self.assertEqual(len(D.read_events(self.path)),10000)
        with closing(sqlite3.connect(self.path)) as db:self.assertLessEqual(db.execute('PRAGMA page_count').fetchone()[0]*4096,D.MAX_DB_BYTES)
        self.assertLessEqual(self.path.stat().st_size,D.MAX_DB_BYTES)
    def test_payload_budget_trims_oldest_and_preserves_latest(self):
        grant=dict(slot='rightHand',grant=2,item_ref='f'*64,skill='mage')
        snapshot=dict(actor=1,order=list(range(16)),selected_grant=grant,
            selected_return_grant=dict(grant,skill='returnHome'),
            cooldowns=[dict(grant,actor=n,remaining=1) for n in range(64)],
            returns=[dict(grant,actor=n,used=False) for n in range(16)])
        data=dict(before=snapshot,after=snapshot,reason='success')
        payload_size=len(json.dumps(data,separators=(',',':'),sort_keys=True))
        # Exceed the actual byte budget, while remaining well below count/session caps.
        total=D.MAX_PAYLOAD_BYTES//payload_size+65
        self.assertLess(total,D.MAX_EVENTS)
        s=self.store()
        for start in range(1,total+1,16):
            values=[]
            for seq in range(start,min(start+16,total+1)):
                value=event(seq);value['data']=data;values.append(value)
            result=s.handle(batch(values))
            self.assertTrue(result['ok'],result)
        with closing(sqlite3.connect(self.path)) as db:
            used,count,oldest,newest=db.execute('SELECT sum(length(data)),count(*),min(seq),max(seq) FROM events').fetchone()
            self.assertLessEqual(used,D.MAX_PAYLOAD_BYTES)
            self.assertGreater(used,D.MAX_PAYLOAD_BYTES-payload_size)
            self.assertLess(count,total)
            self.assertGreater(oldest,1)
            self.assertEqual(newest,total)
            self.assertEqual(count,newest-oldest+1)
            self.assertLessEqual(db.execute('PRAGMA page_count').fetchone()[0]*4096,D.MAX_DB_BYTES)
        latest=D.read_events(self.path)[-1]
        self.assertEqual(latest['seq'],total)
        self.assertEqual(latest['data'],data)
        self.assertLessEqual(self.path.stat().st_size,D.MAX_DB_BYTES)
    def test_two_workers_and_unclean_session_are_not_misclassified(self):
        a=self.worker();self.assertTrue(self.send(a,batch())['ok'])
        b=self.worker();self.assertTrue(self.send(b,batch(session='b'*32))['ok'])
        self.assertEqual([s['clean_closed'] for s in D.read_sessions(self.path)],[0,0])
        a.kill();a.wait(timeout=5)
        self.assertTrue(self.send(b,batch([event(2)],session='b'*32))['ok'])
        self.assertTrue(self.send(b,dict(action='close',session='b'*32,version=D.VERSION))['ok'])
        c=self.worker();self.assertTrue(self.send(c,batch(session='c'*32))['ok'])
        self.assertEqual({s['session']:s['clean_closed'] for s in D.read_sessions(self.path)},{SID:0,'b'*32:1,'c'*32:0})
        self.assertEqual(len(D.read_events(self.path)),4)
    def test_jsonl_invalid_input_does_not_echo_and_recovers(self):
        p=self.worker();p.stdin.write('{PRIVATE INVALID\n');p.stdin.flush()
        self.assertEqual(json.loads(p.stdout.readline()),{'ok':False,'code':'invalid'})
        self.assertTrue(self.send(p,batch())['ok'])
    def test_sidecar_highwater_preserves_artifact(self):
        self.path.parent.mkdir();side=Path(str(self.path)+'-journal')
        with side.open('wb') as f:f.truncate(D.MAX_SIDECAR_BYTES+1)
        self.assertEqual(self.store().handle(batch())['code'],'full');self.assertFalse(self.path.exists());self.assertEqual(side.stat().st_size,D.MAX_SIDECAR_BYTES+1)

if __name__=='__main__':unittest.main()
