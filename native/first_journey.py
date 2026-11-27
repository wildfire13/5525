"""Profile-wide first-character fate and the save files owned by that journey."""
from contextlib import closing
import hashlib
import json
import re
import sqlite3
from pathlib import Path

ENDED = 'この旅は初代の死亡により終了しました。'


def retire_save(filename, ident, write_save, max_size):
    path = Path(filename)
    if not path.is_file() or path.is_symlink() or path.stat().st_size > max_size:
        return
    raw = path.read_bytes()
    try:
        data = json.loads(raw)
    except (ValueError, UnicodeError):
        return
    if isinstance(data, dict) and data.get('format') == '5525-native-campaign' and data.get('godotCampaignId') == ident:
        write_save(path, {'format':'5525-ended-journey', 'godotCampaignId':ident},
                   overwrite=True, expected_sha256=hashlib.sha256(raw).hexdigest(), resolved_target=filename)


def handle(request, file_operation, write_save, max_size):
    db_path = Path(request['profile_dir']) / 'first-journey.sqlite3'
    action = request['action']
    if not db_path.exists() and action != 'first_start':
        return {} if action == 'first_status' else file_operation(request)
    with closing(sqlite3.connect(db_path, timeout=8)) as db, db:
        db.execute('BEGIN IMMEDIATE')
        db.execute('CREATE TABLE IF NOT EXISTS journey (singleton INTEGER PRIMARY KEY CHECK(singleton=1), id TEXT, member TEXT, name TEXT, phase TEXT)')
        db.execute('CREATE TABLE IF NOT EXISTS saves (path TEXT PRIMARY KEY)')
        db.execute('CREATE TABLE IF NOT EXISTS ended_journeys (id TEXT PRIMARY KEY)')
        if action == 'first_start':
            ident = request['journey_id']
            if not re.fullmatch('[a-f0-9]{32}', ident):
                raise ValueError('進行の識別情報が不正です')
            existing = db.execute('SELECT id,phase FROM journey').fetchone()
            if existing is None:
                db.execute("INSERT INTO journey VALUES (1,?,?,?,'alive')",
                           (ident, request['memberId'], request['name']))
            elif existing[1] in ('hire', 'end') and existing[0] != ident:
                db.execute('INSERT OR IGNORE INTO ended_journeys VALUES (?)', (existing[0],))
                db.execute("UPDATE journey SET id=?, member=?, name=?, phase='alive' WHERE singleton=1",
                           (ident, request['memberId'], request['name']))
        row = db.execute('SELECT id,member,name,phase FROM journey').fetchone()
        if row is None:
            return {} if action == 'first_status' else file_operation(request)
        ident, member, name, phase = row
        ended_ids = {r[0] for r in db.execute('SELECT id FROM ended_journeys').fetchall()}
        if phase != 'alive':
            ended_ids.add(ident)
        if action.startswith('first_'):
            if action not in ('first_start','first_status') and request['journey_id'] != ident:
                raise ValueError('進行の識別情報が不正です')
            db.execute('CREATE TABLE IF NOT EXISTS first_portrait (singleton INTEGER PRIMARY KEY CHECK(singleton=1), entry TEXT NOT NULL)')
            if action == 'first_death' and phase == 'alive':
                phase = 'pending'
                ended_ids.add(ident)
                db.execute('INSERT OR IGNORE INTO ended_journeys VALUES (?)', (ident,))
                if request.get('portrait') is not None:
                    db.execute('INSERT OR REPLACE INTO first_portrait VALUES (1,?)', (json.dumps(request['portrait']),))
                else:
                    db.execute('DELETE FROM first_portrait')
            if action == 'first_choose':
                choice = request.get('hire')
                if type(choice) is not bool or phase not in ('pending', 'hire' if choice else 'end'):
                    raise ValueError('初代の選択を確定できません')
                phase = 'hire' if choice else 'end'
                if not choice:
                    db.execute('DELETE FROM first_portrait')
            if phase != row[3]:
                db.execute('UPDATE journey SET phase=?', (phase,))
            deferred = 0
            if phase in ('hire', 'end'):
                # Commit the choice before updating separately stored save files.
                db.commit()
                db.execute('BEGIN IMMEDIATE')
                for (filename,) in db.execute('SELECT path FROM saves').fetchall():
                    try:
                        for eid in ended_ids:
                            retire_save(filename, eid, write_save, max_size)
                    except (OSError, ValueError):
                        deferred += 1
                    else:
                        db.execute('DELETE FROM saves WHERE path=?', (filename,))
            result = {'id':ident,'memberId':member,'name':name,'phase':phase,'deferred':deferred,'endedIds':sorted(ended_ids)}
            if phase == 'hire':
                portrait = db.execute('SELECT entry FROM first_portrait').fetchone()
                if portrait:
                    result['portrait'] = json.loads(portrait[0])
            return result
        saving = action in ('write','recover_write')
        data = request.get('data') if saving else file_operation(request)
        if isinstance(data, dict):
            save_id = data.get('godotCampaignId')
            if save_id in ended_ids:
                raise ValueError(ENDED)
            if save_id == ident and data.get('format') == '5525-native-campaign':
                path = Path(request['path'])
                filename = str(path.parent.resolve() / path.name)
                db.execute('INSERT OR IGNORE INTO saves VALUES (?)', (filename,))
        return file_operation(request) if saving else data
