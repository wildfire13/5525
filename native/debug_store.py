"""Optional local diagnostics worker. Never reads game masters or save files.

JSON-lines protocol contains only a separately validated, fixed safe vocabulary.
A failed store is disposable diagnostics, not a reason to interrupt gameplay.
"""
import argparse
from contextlib import closing
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import time

VERSION = '89c4990+debug-store-v1'
APPLICATION_ID = 552501
MAX_DB_BYTES = 16 * 1024 * 1024
MAX_PAYLOAD_BYTES = 8 * 1024 * 1024
MAX_SIDECAR_BYTES = 18 * 1024 * 1024
MAX_LINE_BYTES = 1024 * 1024
MAX_SESSIONS = 20
MAX_EVENTS = 10000
MAX_BATCH = 32
TIMEOUT_SECONDS = .05
OPS = set('campaign_start campaign_save campaign_load select_skill select_return_skill preview hover_preview reset journey_start export state session other ui.file_save ui.file_open ui.confirm ui.navigate ui.load_metadata'.split())
OPS |= {'act.' + x for x in 'attack move skill item ether guard return other'.split()}
OPS |= {'godot_io.' + x for x in 'read write write_target recover_write portrait other'.split()}
OPS |= {'campaign.' + x for x in 'select accept depart travel deploy deployment_assign chooseFormation deployment_reset begin retreat finishBattle rest onward arrive acknowledge completeQuest buyGear buyItem inn useItem inventoryAction warehouseAction buyInventory buyPlan sellInventory allocate allocateBatch trial endTrial'.split()}
SKILLS = set('itemUse legSweep grapple poleVault swift retreatSlash knockback splitShot pincer healingCross defenseLine manaGift returnHome victoryBreath loneWolf firstStride guard archer mage scout stamp porter invasion none other'.split())
SLOTS = set('rightHand leftHand head upperBody lowerBody feet accessory1 accessory2'.split()) | {''}
STATE_KEYS = set('locked presenting preview_pending quote_pending busy disconnected loading'.split())
REASONS = set('rejected disconnected failed success cancel start close queue_overflow worker_disabled'.split())
SCHEMA = '''
CREATE TABLE sessions (
 session TEXT PRIMARY KEY, version TEXT NOT NULL, started_ms INTEGER NOT NULL,
 updated_ms INTEGER NOT NULL, clean_closed INTEGER NOT NULL DEFAULT 0 CHECK(clean_closed IN(0,1)),
 last_seq INTEGER NOT NULL DEFAULT 0, last_elapsed INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE events (
 id INTEGER PRIMARY KEY, session TEXT NOT NULL REFERENCES sessions(session) ON DELETE CASCADE,
 seq INTEGER NOT NULL, request_id INTEGER NOT NULL, kind TEXT NOT NULL, op TEXT NOT NULL,
 ok INTEGER, duration_ms INTEGER, data TEXT NOT NULL, elapsed_ms INTEGER NOT NULL, written_ms INTEGER NOT NULL,
 UNIQUE(session,seq)
);
CREATE INDEX events_session ON events(session,id);
'''


def integer(v, low=0, high=2147483647):
    return type(v) is int and low <= v <= high


def object_keys(value, allowed, required=()):
    return isinstance(value, dict) and set(value) <= set(allowed) and set(required) <= set(value)


def grant(value, extra=None):
    required = {'slot', 'grant', 'item_ref', 'skill'}
    allowed = required | ({'actor', extra} if extra else set())
    if not object_keys(value, allowed, allowed): return False
    if value['slot'] not in SLOTS or not integer(value['grant'], 1, 3): return False
    if not isinstance(value['item_ref'], str) or re.fullmatch('[0-9a-f]{64}', value['item_ref']) is None: return False
    if value['skill'] not in SKILLS: return False
    if extra and not integer(value['actor'], 0, 256): return False
    if extra == 'remaining' and not integer(value[extra], 0, 2): return False
    if extra == 'used' and type(value[extra]) is not bool: return False
    return True


def snapshot(value):
    if not object_keys(value, {'actor','order','selected_grant','selected_return_grant','cooldowns','returns'}): return False
    if 'actor' in value and not integer(value['actor'], 0, 256): return False
    if 'order' in value and (not isinstance(value['order'], list) or len(value['order']) > 16 or not all(integer(x, 0, 256) for x in value['order'])): return False
    for key in ('selected_grant','selected_return_grant'):
        if key in value and value[key] is not None and not grant(value[key]): return False
    for key, extra, limit in [('cooldowns','remaining',64),('returns','used',16)]:
        if key in value and (not isinstance(value[key], list) or len(value[key]) > limit or not all(grant(x,extra) for x in value[key])): return False
    return True


def event_data(value):
    if not object_keys(value, STATE_KEYS | {'before','after','reason','dropped'}): return False
    for key in STATE_KEYS & set(value):
        if type(value[key]) is not bool: return False
    for key in ('before','after'):
        if key in value and not snapshot(value[key]): return False
    if 'reason' in value and value['reason'] not in REASONS: return False
    if 'dropped' in value and not integer(value['dropped'],0,1000000000): return False
    return True


def validated_request(value):
    if not object_keys(value, {'action','session','version','events'}, {'action','session','version'}): raise ValueError()
    if value['action'] not in ('batch','close') or value['version'] != VERSION: raise ValueError()
    if not isinstance(value['session'],str) or re.fullmatch('[0-9a-f]{32}', value['session']) is None: raise ValueError()
    if value['action']=='close':
        if 'events' in value: raise ValueError()
        return []
    events=value.get('events')
    if not isinstance(events,list) or len(events)>MAX_BATCH: raise ValueError()
    rows=[];previous=0
    for event in events:
        if not object_keys(event, {'seq','request_id','kind','op','ok','duration_ms','data','elapsed_ms'}, {'seq','request_id','kind','op','elapsed_ms'}): raise ValueError()
        if not integer(event['seq'],1) or event['seq']<=previous or not integer(event['request_id']): raise ValueError()
        if event['kind'] not in ('request_start','request_end','state','lifecycle') or event['op'] not in OPS: raise ValueError()
        if not integer(event['elapsed_ms'],0,9007199254740991):raise ValueError()
        if 'ok' in event and type(event['ok']) is not bool: raise ValueError()
        if 'duration_ms' in event and not integer(event['duration_ms'],0,600000): raise ValueError()
        data=event.get('data',{})
        if not event_data(data): raise ValueError()
        payload=json.dumps(data,sort_keys=True,separators=(',',':'),allow_nan=False)
        if len(payload)>65536: raise ValueError()
        rows.append((event['seq'],event['request_id'],event['kind'],event['op'],int(event['ok']) if 'ok' in event else None,event.get('duration_ms'),payload,event['elapsed_ms']))
        previous=event['seq']
    return rows


def error_code(exc):
    code=getattr(exc,'sqlite_errorcode',0) & 255
    if code in (sqlite3.SQLITE_BUSY,sqlite3.SQLITE_LOCKED): return 'busy'
    if code==sqlite3.SQLITE_FULL:return 'full'
    if code in (sqlite3.SQLITE_CORRUPT,sqlite3.SQLITE_NOTADB):return 'incompatible'
    return 'unavailable'


class Store:
    def __init__(self,path):
        self.path=Path(path);self.db=None;self.disabled=None;self.session=None;self.registered=False
    def close(self):
        if self.db is not None:self.db.close();self.db=None
    def _open(self):
        if self.db is not None:return
        for suffix,limit in [('',MAX_DB_BYTES),('-journal',MAX_SIDECAR_BYTES),('-wal',MAX_SIDECAR_BYTES),('-shm',MAX_SIDECAR_BYTES)]:
            path=Path(str(self.path)+suffix)
            if path.exists() and path.stat().st_size>limit:raise StoreError('full')
        self.path.parent.mkdir(parents=True,exist_ok=True)
        self.db=sqlite3.connect(self.path,timeout=TIMEOUT_SECONDS,isolation_level=None)
        self.db.execute('PRAGMA busy_timeout=50')
        self.db.execute('PRAGMA foreign_keys=ON')
        app=self.db.execute('PRAGMA application_id').fetchone()[0]
        tables=self.db.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        if app!=APPLICATION_ID and tables:raise StoreError('incompatible')
        if self.db.execute('PRAGMA page_size').fetchone()[0]!=4096:raise StoreError('incompatible')
        mode=self.db.execute('PRAGMA journal_mode=DELETE').fetchone()[0]
        if mode!='delete':raise StoreError('incompatible')
        self.db.execute('PRAGMA synchronous=FULL')
        self.db.execute('PRAGMA max_page_count=4096')
        self.db.execute('PRAGMA journal_size_limit=0')
        if not tables:
            self.db.execute('BEGIN IMMEDIATE')
            try:
                # Another launcher may have initialized while we waited for the lock.
                if not self.db.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall():
                    for statement in SCHEMA.split(';'):
                        if statement.strip():self.db.execute(statement)
                    self.db.execute('PRAGMA application_id='+str(APPLICATION_ID))
                    self.db.execute('PRAGMA user_version=1')
                self.db.commit()
            except Exception:self.db.rollback();raise
        if self.db.execute('PRAGMA application_id').fetchone()[0]!=APPLICATION_ID or self.db.execute('PRAGMA user_version').fetchone()[0]!=1:raise StoreError('incompatible')
        if self.db.execute('PRAGMA quick_check').fetchall()!=[('ok',)]:raise StoreError('incompatible')
    def _prune(self):
        self.db.execute('DELETE FROM sessions WHERE session NOT IN (SELECT session FROM sessions ORDER BY started_ms DESC,rowid DESC LIMIT ?)',(MAX_SESSIONS,))
        self.db.execute('DELETE FROM events WHERE id NOT IN (SELECT id FROM events ORDER BY id DESC LIMIT ?)',(MAX_EVENTS,))
        # Count serialized bytes, not just row count, so bulky safe snapshots do
        # not force the artifact over its page limit before count-based pruning.
        used=0;cutoff=None
        for rowid,size in self.db.execute('SELECT id,length(data) FROM events ORDER BY id DESC'):
            used+=size
            if used>MAX_PAYLOAD_BYTES:cutoff=rowid;break
        if cutoff is not None:self.db.execute('DELETE FROM events WHERE id<=?',(cutoff,))
    def handle(self,request):
        try:rows=validated_request(request)
        except (ValueError,TypeError,KeyError):return {'ok':False,'code':'invalid'}
        if self.disabled:return {'ok':False,'code':self.disabled}
        session=request['session']
        if self.session is not None and self.session!=session:return {'ok':False,'code':'invalid'}
        self.session=session
        try:
            self._open();self.db.execute('BEGIN IMMEDIATE')
            current=self.db.execute('SELECT last_seq,clean_closed,last_elapsed FROM sessions WHERE session=?',(session,)).fetchone()
            if current is None and self.registered:raise StoreError('session_evicted')
            now=time.time_ns()//1000000
            if current is None:
                if request['action']=='close':raise StoreError('session_missing')
                self.db.execute('INSERT INTO sessions VALUES(?,?,?,?,0,0,0)',(session,VERSION,now,now));current=(0,0,0)
            last_seq,closed,last_elapsed=current
            if request['action']=='close':
                self.db.execute('UPDATE sessions SET clean_closed=1,updated_ms=? WHERE session=?',(now,session));self.db.commit();self.registered=True
                return {'ok':True,'code':'ok','accepted':0,'last_seq':last_seq}
            if closed:raise StoreError('session_closed')
            accepted=0
            for row in rows:
                seq=row[0]
                if seq<=last_seq:
                    old=self.db.execute('SELECT seq,request_id,kind,op,ok,duration_ms,data,elapsed_ms FROM events WHERE session=? AND seq=?',(session,seq)).fetchone()
                    if old!=row:raise StoreError('sequence_conflict')
                    continue
                if row[-1]<last_elapsed:raise StoreError('sequence_conflict')
                self.db.execute('INSERT INTO events(session,seq,request_id,kind,op,ok,duration_ms,data,elapsed_ms,written_ms) VALUES(?,?,?,?,?,?,?,?,?,?)',(session,*row,now))
                last_seq=seq;last_elapsed=row[-1];accepted+=1
            self.db.execute('UPDATE sessions SET last_seq=?,last_elapsed=?,updated_ms=? WHERE session=?',(last_seq,last_elapsed,now,session))
            self._prune();self.db.commit();self.registered=True
            return {'ok':True,'code':'ok','accepted':accepted,'last_seq':last_seq}
        except (sqlite3.Error,OSError,StoreError) as exc:
            if self.db is not None:
                try:self.db.rollback()
                except sqlite3.Error:pass
            code=exc.code if isinstance(exc,StoreError) else error_code(exc)
            if code=='busy':self.close()  # Retry, if requested by caller, starts fully configured.
            if code not in ('busy','sequence_conflict','session_closed','session_missing'):
                self.disabled=code;self.close()
            return {'ok':False,'code':code}


class StoreError(Exception):
    def __init__(self,code):self.code=code


def _read(path,sql,args=()):
    with closing(sqlite3.connect(Path(path).resolve().as_uri()+'?mode=ro',uri=True,timeout=TIMEOUT_SECONDS)) as db:
        db.row_factory=sqlite3.Row
        return [dict(row) for row in db.execute(sql,args)]

def read_sessions(path):
    """clean_closed=0 means not cleanly closed, not proof of a crashed process."""
    return _read(path,'SELECT * FROM sessions ORDER BY started_ms,rowid')

def read_events(path,session=None):
    rows=_read(path,'SELECT * FROM events'+(' WHERE session=?' if session else '')+' ORDER BY id',(session,) if session else ())
    for row in rows:row['data']=json.loads(row['data'])
    return rows


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--db',required=True);args=parser.parse_args()
    store=Store(args.db)
    try:
        while True:
            line=sys.stdin.buffer.readline(MAX_LINE_BYTES+1)
            if not line:break
            if len(line)>MAX_LINE_BYTES:
                # Bound memory; never parse/store an oversized line or echo it.
                while line and not line.endswith(b'\n'):line=sys.stdin.buffer.readline(MAX_LINE_BYTES+1)
                reply={'ok':False,'code':'invalid'}
            else:
                try:reply=store.handle(json.loads(line))
                except (ValueError,UnicodeError,RecursionError):reply={'ok':False,'code':'invalid'}
            print(json.dumps(reply,separators=(',',':')),flush=True)
    finally:store.close()

if __name__=='__main__':main()
