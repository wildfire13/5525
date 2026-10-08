"""Godot-only file adapter: atomic creation or explicitly confirmed replacement."""
import base64, hashlib, json, os, re, sys, tempfile
from pathlib import Path
from portraits import read_raster, normalize_raster, MAX_PNG_BYTES
MAX_SAVE = 12 * 1024 * 1024

def prepare_portraits(meta, allowed):
    if meta is None: return {'version': 1, 'characters': {}}
    if not isinstance(meta, dict) or meta.get('version') != 1 or not isinstance(meta.get('characters'), dict):
        raise ValueError('保存画像の形式が不正です')
    if not set(meta['characters']).issubset(set(allowed)): raise ValueError('保存画像のキャラIDが不正です')
    for entry in meta['characters'].values():
        if not isinstance(entry, dict) or not isinstance(entry.get('png'), str) or len(entry['png']) > 4*((MAX_PNG_BYTES+2)//3):
            raise ValueError('保存画像のサイズが不正です')
        raw = base64.b64decode(entry['png'], validate=True)
        if hashlib.sha256(raw).hexdigest() != entry.get('sha256'): raise ValueError('保存画像が破損しています')
        normalize_raster(raw, stored=True)
    return meta

def encoded_save(data):
    raw = (json.dumps(data, ensure_ascii=False, indent=2)+chr(10)).encode('utf-8')
    if len(raw) > MAX_SAVE: raise ValueError('保存サイズ超過')
    return raw

def operation_temp(path, operation):
    if not isinstance(operation, str) or not re.fullmatch(r'[0-9a-f]{32}', operation):
        raise ValueError('保存要求の識別子が不正です')
    return path.parent / ('.5525-save-' + operation + '.tmp')

def publish_new(temp, path):
    if os.name == 'nt':
        # Windows rename fails when destination exists, including a competing
        # creator, without requiring filesystem hard-link support.
        os.rename(temp, path)
    else:
        os.link(temp, path)  # POSIX rename overwrites: never use it here.

def write_target(path):
    path = Path(path)
    if path.suffix.lower() != '.json': raise ValueError('JSONファイル名を指定してください')
    if not path.exists(): return {'exists': False}
    if not path.is_file(): raise ValueError('保存先に通常ファイルを指定してください')
    if path.stat().st_size > MAX_SAVE: raise ValueError('既存ファイルが大きすぎます')
    return {'exists': True, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

def publish_replace(temp, path, expected_sha256):
    current = write_target(path)
    if not current['exists'] or current['sha256'] != expected_sha256:
        raise ValueError('確認後に保存先の内容が変わりました。保存先を選び直してください。')
    os.replace(temp, path)  # Complete, flushed sibling file becomes visible atomically.

def write_save(path, data, operation=None, overwrite=False, expected_sha256=None):
    path = Path(path)
    if path.suffix.lower() != '.json': raise ValueError('JSONファイル名を指定してください')
    if type(overwrite) is not bool: raise ValueError('上書き確認が不正です')
    if overwrite and (not isinstance(expected_sha256, str) or not re.fullmatch(r'[0-9a-f]{64}', expected_sha256)):
        raise ValueError('上書きには保存先の確認が必要です')
    raw = encoded_save(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = None
    try:
        if operation is not None:
            candidate = operation_temp(path, operation)
            f = candidate.open('xb')
            temp = candidate
        else:
            f = tempfile.NamedTemporaryFile('wb', dir=path.parent, delete=False)
            temp = Path(f.name)
        with f:
            f.write(raw); f.flush(); os.fsync(f.fileno())
        if overwrite: publish_replace(temp, path, expected_sha256)
        else: publish_new(temp, path)
    finally:
        if temp is not None: temp.unlink(missing_ok=True)

def write_new(path, data, operation=None):
    # Low-level creation remains exclusive; UI-confirmed saves use write_save.
    return write_save(path, data, operation)

def recover_write(path, data, operation):
    path = Path(path)
    temp = operation_temp(path, operation)
    expected = encoded_save(data)
    # Only after this helper PID terminated. Never delete the target.
    temp.unlink(missing_ok=True)
    if path.exists():
        if path.stat().st_size == len(expected) and path.read_bytes() == expected:
            return {'path':str(path), 'outcome':'saved', 'recovered':True}
        return {'path':str(path), 'outcome':'not_saved', 'reason':'保存先には別の内容が残っています。今回の保存完了は確認できません。'}
    return {'path':str(path), 'outcome':'not_saved', 'reason':'保存されていません。別名または別の場所へ保存できます。'}

def run(r):
    if r['action']=='portrait':
        raw=read_raster(r['path'])
        return {'sha256':hashlib.sha256(raw).hexdigest(),'png':base64.b64encode(raw).decode('ascii')}
    if r['action']=='read':
        path=Path(r['path'])
        if path.stat().st_size>MAX_SAVE: raise ValueError('保存サイズ超過')
        data=json.loads(path.read_text(encoding='utf-8-sig'))
        if not isinstance(data,dict): raise ValueError('保存形式が不正です')
        data['nativePortraits']=prepare_portraits(data.get('nativePortraits'),r.get('allowed',[]))
        return data
    if r['action']=='write_target': return write_target(r['path'])
    if r['action']=='write':
        write_save(r['path'],r['data'],r.get('operation'),r.get('overwrite',False),r.get('expected_sha256'));return {'path':r['path'], 'outcome':'saved'}
    if r['action']=='recover_write':return recover_write(r['path'],r['data'],r['operation'])
    raise ValueError('Unknown file operation')
if __name__=='__main__':
    try: print(json.dumps({'ok':True,'data':run(json.loads(sys.stdin.readline()))},ensure_ascii=False))
    except (OSError,ValueError,KeyError,TypeError) as e: print(json.dumps({'ok':False,'error':str(e)},ensure_ascii=False))
