"""Exercise the candidate CMD/PowerShell entry without visible windows."""
import ctypes,datetime,hashlib,json,os
from pathlib import Path
import subprocess,sys,shutil,tempfile
ROOT=Path(__file__).resolve().parents[2]
Q=ROOT/'godot/qa'
Q.mkdir(parents=True,exist_ok=True)
env={**os.environ,'GODOT_BIN':sys.argv[1],'PYTHONUTF8':'1','PYTHONIOENCODING':'utf-8','NATIVE5525_AUDIO_OFF':'1'}
MARKERS=['SCRIPT ERROR:','ERROR:','FAIL ','ObjectDB instances leaked','resources still in use']
entries=[]
def run(name,entry,args,environment,expected=0,project=ROOT):
    command=['cmd.exe','/d','/c',str(project/entry),*args]
    p=subprocess.run(command,env=environment,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45)
    combined=p.stdout+p.stderr
    item=dict(name=name,command=command,exitCode=p.returncode,stdout=p.stdout,stderr=p.stderr,passed=p.returncode==expected and not any(m in combined for m in MARKERS))
    entries.append(item)
    return item
# Exercise real discovery in its documented portable layout. Only existing
# executables are copied to a disposable fixture; no sibling-PC layout is assumed.
with tempfile.TemporaryDirectory(prefix='5525 launcher discovery ') as temporary:
    project=Path(temporary)
    for relative in ['Start-5525.cmd','Start-5525-Godot.cmd','godot/launch.ps1',
                     'godot/project.godot','native/bridge.cjs','native/godot_files.py',
                     'native/master-data.cjs','native/master_data.py','native/data/master.sqlite',
                     'native/assets/music/manifest.json','godot/assets/quest_music.json']:
        target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/relative,target)
    runtime=project/'runtime/godot';runtime.mkdir(parents=True)
    executable=Path(sys.argv[1]).resolve()
    shutil.copy2(executable,runtime/executable.name)
    companion=executable.with_name(executable.name.replace('_console.exe','.exe'))
    if companion!=executable and companion.is_file():shutil.copy2(companion,runtime/companion.name)
    auto={k:v for k,v in env.items() if k not in ['GODOT_BIN','NATIVE5525_NODE','NATIVE5525_PYTHON']}
    node=Path(env.get('NATIVE5525_NODE') or shutil.which('node') or 'node')
    auto['PATH']=os.pathsep.join([str(node.parent),str(Path(sys.executable).parent),auto.get('PATH','')])
    item=run('Default entry discovers portable runtime without overrides','Start-5525.cmd',['-Check'],auto,project=project)
    if item['passed']:
        data=json.loads(item['stdout'])
        item['resolved']=data
        item['passed'] &= data['installedNothing'] and all(Path(data[k]['path']).is_file() for k in ['godot','node','python'])
        # Hosted Windows TEMP may use an 8.3 alias while PowerShell returns
        # the long path. Require the same filesystem directory, not spelling.
        item['passed'] &= Path(data['godot']['path']).parent.samefile(runtime)
        item['passed'] &= bool(data['python'].get('sqlite'))
    master=project/'native/data/master.sqlite'
    original=master.read_bytes()
    try:
        master.unlink()
        missing=run('Reject missing master before launch','Start-5525.cmd',['-Check'],auto,1,project=project)
        missing['passed'] &= 'Missing project file: native/data/master.sqlite' in missing['stderr']
        master.write_bytes(b'not a SQLite database')
        invalid=run('Reject corrupt master before launch','Start-5525.cmd',['-Check'],auto,1,project=project)
        invalid['passed'] &= 'Master data could not be read' in invalid['stderr']
        invalid['passed'] &= master.read_bytes()==b'not a SQLite database'
    finally:
        master.write_bytes(original)
explicit=run('Godot entry accepts explicit runtime','Start-5525-Godot.cmd',['-Check'],env)
if explicit['passed']:
    data=json.loads(explicit['stdout']);explicit['resolved']=data
    explicit['passed'] &= bool(data['python'].get('sqlite')) and bool(data['python'].get('pillow'))
for key in ['GODOT_BIN','NATIVE5525_NODE','NATIVE5525_PYTHON']:
    item=run('Reject missing explicit '+key,'Start-5525-Godot.cmd',['-Check'],{**env,key:str(ROOT/'nonexistent-runtime.exe')},1)
    item['passed'] &= 'was not found' in item['stderr']
item=run('Default entry starts and closes actual app','Start-5525.cmd',['-SmokeTest'],env)
if item['passed']:
    lines=[s for s in item['stdout'].splitlines() if s.startswith('{')]
    state=json.loads(lines[-1]) if lines else {}
    item['smoke']=state
    item['passed'] &= state.get('passed',False) and state.get('headless',False)
    if state.get('node_pid'):
        kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.OpenProcess.argtypes=[ctypes.c_uint32,ctypes.c_int,ctypes.c_uint32];kernel.OpenProcess.restype=ctypes.c_void_p
        kernel.GetExitCodeProcess.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_uint32)];kernel.CloseHandle.argtypes=[ctypes.c_void_p]
        handle=kernel.OpenProcess(0x1000,False,int(state['node_pid']))
        alive=False
        if handle:
            code=ctypes.c_uint32()
            try:alive=bool(kernel.GetExitCodeProcess(handle,ctypes.byref(code))) and code.value==259
            finally:kernel.CloseHandle(handle)
        item['node_remaining']=alive;item['passed'] &= not alive
fallback=ROOT/'Start-5525-Python.cmd'
baseline=json.loads((ROOT/'godot/tests/fixtures/python-launcher-baseline.json').read_text(encoding='utf-8'))
# Git may materialize CMD files with LF or CRLF. Compare against historical
# source bytes with only CRLF normalized, never a baseline derived from the candidate.
canonical=fallback.read_bytes().replace(b'\r\n',b'\n')
entries.append(dict(name='Python fallback preserves historical launcher (Git EOL normalized)',passed=hashlib.sha256(canonical).hexdigest()==baseline['sha256_lf']))
report=dict(at=datetime.datetime.now(datetime.timezone.utc).isoformat(),gui=False,subjective_listening=False,steps=entries,passed=all(e['passed'] for e in entries))
(Q/'launcher-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for e in entries:print(('PASS ' if e['passed'] else 'FAIL ')+e['name'])
raise SystemExit(0 if report['passed'] else 1)
