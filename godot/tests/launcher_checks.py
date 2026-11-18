"""Exercise the candidate CMD/PowerShell entry without visible windows."""
import ctypes,datetime,json,os
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
                     'godot/project.godot','godot/windows-shared-env.txt','native/bridge.cjs','native/godot_files.py',
                     'native/master-data.cjs','native/master_data.py','native/data/master.sqlite',
                     'native/assets/music/manifest.json','godot/assets/quest_music.json']:
        target=project/relative;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/relative,target)
    env['AKI_SHARED_ENV_FILE']=str(project/'shared.env')
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
    configured_runtime=project/'local runtime with spaces'/executable.name
    configured_runtime.parent.mkdir(parents=True)
    shutil.copy2(executable,configured_runtime)
    if companion!=executable and companion.is_file():shutil.copy2(companion,configured_runtime.with_name(companion.name))
    local_config=project/'godot/launcher.local.json'
    local_config.write_text(json.dumps({'godot_bin':str(configured_runtime)}),encoding='utf-8')
    configured=run('Per-checkout config selects Godot without environment overrides','Start-5525.cmd',['-Check'],auto,project=project)
    if configured['passed']:
        data=json.loads(configured['stdout']);configured['resolved']=data
        configured['passed'] &= Path(data['godot']['path']).samefile(configured_runtime)
    env_override={**auto,'GODOT_BIN':str(runtime/executable.name)}
    override=run('Existing GODOT_BIN overrides per-checkout config','Start-5525.cmd',['-Check'],env_override,project=project)
    if override['passed']:
        data=json.loads(override['stdout']);override['resolved']=data
        override['passed'] &= Path(data['godot']['path']).samefile(runtime/executable.name)
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
    local_config.write_text(json.dumps({'godot_bin':str(project/'missing Godot.exe')}),encoding='utf-8')
    invalid_config=run('Reject invalid local Godot config without auto fallback','Start-5525.cmd',['-Check'],auto,1,project)
    invalid_config['passed'] &= 'configured Godot path from godot/launcher.local.json' in invalid_config['stderr']
    # Exercise mixed sources with real executables and an unrelated working directory.
    shared=Path(env['AKI_SHARED_ENV_FILE'])
    project_config=project/'.env'
    shared.write_text('GODOT_BIN="local runtime with spaces/' + executable.name + '"', encoding='utf-8-sig')
    project_config.write_text('GODOT_BIN=missing-lower-value\nNATIVE5525_NODE="'+str(node.resolve())+'"',encoding='utf-8')
    mixed={**env,'GODOT_BIN':'missing-process','NATIVE5525_NODE':'missing-process','NATIVE5525_PYTHON':sys.executable}
    checked=run('Shared Godot, project Node, process Python','Start-5525.cmd',['-Check'],mixed,project=project)
    if checked['passed']:
        report=json.loads(checked['stdout'])
        checked['passed'] &= all(Path(report[key]['path']).samefile(path) for key,path in
                                 [('godot',configured_runtime),('node',node),('python',sys.executable)])
    for invalid in ('""','missing-executable','"unterminated','valid\nGODOT_BIN=duplicate'):
        shared.write_text('GODOT_BIN='+invalid,encoding='utf-8')
        failed=run('Reject invalid shared GODOT_BIN: '+repr(invalid),'Start-5525.cmd',['-Check'],mixed,1,project)
        failed['passed'] &= 'GODOT_BIN' in failed['stderr']
    # Direct editor runs use the Godot resolver. Give it an isolated game root.
    probe=project/'resolve_children.gd'
    probe.write_text("""extends SceneTree
func _initialize():
	var args = OS.get_cmdline_user_args()
	var error = preload("res://runtime_paths.gd").apply(args[0])
	var valid = error.contains(args[1]) if args[1] != "ok" else (
		error.is_empty() and OS.get_environment("NATIVE5525_NODE") == args[2]
		and OS.get_environment("NATIVE5525_PYTHON") == args[3])
	quit(0 if valid else 1)
""",encoding='utf-8')
    def direct(name, expected):
        command=[str(executable),'--headless','--path',str(ROOT/'godot'),'--script',str(probe),'--',
                 str(project),expected,node.resolve().as_posix(),Path(sys.executable).resolve().as_posix()]
        result=subprocess.run(command,env=mixed,capture_output=True,timeout=20)
        entries.append(dict(name=name,passed=result.returncode==0))
    project_config.write_text('NATIVE5525_NODE=missing-lower-value',encoding='utf-8')
    shared.write_text('NATIVE5525_NODE="'+str(node.resolve())+'"',encoding='utf-8-sig')
    direct('Direct Godot uses shared Node and process Python', 'ok')
    shared.write_text('NATIVE5525_PYTHON="'+sys.executable+'"',encoding='utf-8')
    project_config.write_text('NATIVE5525_NODE="'+str(node.resolve())+'"',encoding='utf-8')
    direct('Direct Godot uses project Node and shared Python', 'ok')
    shared.write_text('NATIVE5525_NODE=""',encoding='utf-8')
    direct('Direct Godot rejects empty shared Node', 'NATIVE5525_NODE')
    shared.unlink()
    project_config.unlink()
    local_config.unlink()
    for key in ['GODOT_BIN','NATIVE5525_NODE','NATIVE5525_PYTHON']:
        item=run('Reject missing explicit '+key,'Start-5525-Godot.cmd',['-Check'],{**env,key:str(project/'nonexistent-runtime.exe')},1,project)
        item['passed'] &= key in item['stderr'] and 'was not found' in item['stderr']
explicit=run('Godot entry accepts explicit runtime','Start-5525-Godot.cmd',['-Check'],env)
if explicit['passed']:
    data=json.loads(explicit['stdout']);explicit['resolved']=data
    explicit['passed'] &= bool(data['python'].get('sqlite')) and bool(data['python'].get('pillow'))
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
report=dict(at=datetime.datetime.now(datetime.timezone.utc).isoformat(),gui=False,subjective_listening=False,steps=entries,passed=all(e['passed'] for e in entries))
(Q/'launcher-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for e in entries:print(('PASS ' if e['passed'] else 'FAIL ')+e['name'])
raise SystemExit(0 if report['passed'] else 1)
