"""Exercise the candidate CMD/PowerShell entry without visible windows."""
import ctypes,datetime,hashlib,json,os
from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
Q=ROOT/'godot/qa'
env={**os.environ,'GODOT_BIN':sys.argv[1],'PYTHONUTF8':'1','PYTHONIOENCODING':'utf-8'}
MARKERS=['SCRIPT ERROR:','ERROR:','FAIL ','ObjectDB instances leaked','resources still in use']
entries=[]
def run(name,entry,args,environment,expected=0):
    command=['cmd.exe','/d','/c',str(ROOT/entry),*args]
    p=subprocess.run(command,env=environment,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45)
    combined=p.stdout+p.stderr
    item=dict(name=name,command=command,exitCode=p.returncode,stdout=p.stdout,stderr=p.stderr,passed=p.returncode==expected and not any(m in combined for m in MARKERS))
    entries.append(item)
    return item
auto={k:v for k,v in env.items() if k not in ['GODOT_BIN','NATIVE5525_NODE','NATIVE5525_PYTHON']}
item=run('Default entry resolves existing runtimes','Start-5525.cmd',['-Check'],auto)
if item['passed']:
    data=json.loads(item['stdout'])
    item['resolved']=data
    item['passed'] &= data['installedNothing'] and all(Path(data[k]['path']).is_file() for k in ['godot','node','python'])
explicit=run('Godot entry accepts explicit runtime','Start-5525-Godot.cmd',['-Check'],env)
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
baseline=json.loads((Q/'preservation.json').read_text(encoding='utf-8'))
entries.append(dict(name='Python fallback preserves original launcher bytes',passed=hashlib.sha256(fallback.read_bytes()).hexdigest()==baseline['normalLauncherSha256']))
report=dict(at=datetime.datetime.now(datetime.timezone.utc).isoformat(),gui=False,subjective_listening=False,steps=entries,passed=all(e['passed'] for e in entries))
(Q/'launcher-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for e in entries:print(('PASS ' if e['passed'] else 'FAIL ')+e['name'])
raise SystemExit(0 if report['passed'] else 1)
