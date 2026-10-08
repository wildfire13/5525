"""Headless fault regression, including app-close process ownership checks."""
import ctypes, datetime, json, os
from pathlib import Path
import subprocess, sys, tempfile
BASE=Path(__file__).resolve().parents[1]
EXE=sys.argv[1]
COMMON=[EXE,'--headless','--audio-driver','Dummy','--path',str(BASE)]
MARKERS=['SCRIPT ERROR:','ERROR:','FAIL ','ObjectDB instances leaked','resources still in use']
def alive(pid):
    if sys.platform=='win32':
        kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.OpenProcess.argtypes=[ctypes.c_uint32,ctypes.c_int,ctypes.c_uint32]
        kernel.OpenProcess.restype=ctypes.c_void_p
        kernel.GetExitCodeProcess.argtypes=[ctypes.c_void_p,ctypes.POINTER(ctypes.c_uint32)]
        kernel.CloseHandle.argtypes=[ctypes.c_void_p]
        handle=kernel.OpenProcess(0x1000,False,int(pid))
        if not handle:return False
        code=ctypes.c_uint32()
        try:return bool(kernel.GetExitCodeProcess(handle,ctypes.byref(code))) and code.value==259
        finally:kernel.CloseHandle(handle)
    try:os.kill(int(pid),0);return True
    except ProcessLookupError:return False
def run(name,command):
    result=subprocess.run(command,text=True,encoding='utf-8',errors='replace',capture_output=True,timeout=120)
    bad=[m for m in MARKERS if m in result.stdout+result.stderr]
    return dict(name=name,command=command,exitCode=result.returncode,stdout=result.stdout,stderr=result.stderr,markers=bad,passed=result.returncode==0 and not bad)
report={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'gui':False,'steps':[]}
entry=run('Fault handling',COMMON+['--script','res://tests/audit_faults.gd'])
report['steps'].append(entry)
print(entry['stdout'],end='')
for mode in ['file','ack']:
    with tempfile.TemporaryDirectory(prefix='5525-close-') as directory:
        directory=Path(directory)
        assert directory.resolve().is_relative_to(Path(tempfile.gettempdir()).resolve())
        marker=directory/'marker.json'
        entry=run('Close during '+mode,COMMON+['--script','res://tests/shutdown_case.gd','--',mode,str(marker)])
        if marker.exists():
            state=json.loads(marker.read_text(encoding='utf-8'))
            entry['owned_pids']=[int(state['node']),*state['helpers']]
            entry['remaining_pids']=[pid for pid in entry['owned_pids'] if alive(pid)]
            entry['remaining_temporaries']=[p.name for p in directory.glob('.5525-save-*.tmp')]
            entry['save_created']=Path(str(marker)+'.save.json').exists()
            entry['passed'] &= state['busy'] and not entry['remaining_pids'] and not entry['remaining_temporaries']
            if mode=='file':entry['passed'] &= not entry['save_created']
            else:entry['passed'] &= state['presenting']
        else:entry['passed']=False
        report['steps'].append(entry)
        print(('PASS ' if entry['passed'] else 'FAIL ')+entry['name'])
report['passed']=all(s['passed'] for s in report['steps'])
(BASE/'qa/audit-faults-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if report['passed'] else 1)
