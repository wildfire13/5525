"""Run the real PowerShell launcher in a disposable checkout with cold/warm assets.

Usage: python launcher_import_checks.py --powershell /path/to/pwsh --godot /path/to/godot
On Windows use powershell.exe; the proxy runs the real Godot, recording launch order.
No existing project cache or user save is modified. Evidence stays in --output.
"""
from contextlib import contextmanager
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

from qa_runtime import qa_environment

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--powershell', required=True)
parser.add_argument('--godot', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
settings = qa_environment(needs_godot=False)
out = Path(args.output).resolve()
out.mkdir(parents=True, exist_ok=False)
project = out / '日本語 project with spaces'
project.mkdir()
archive = out / 'source.tar'
with archive.open('wb') as stream:
    subprocess.run(['git', '-C', str(ROOT), 'archive', 'HEAD'], stdout=stream, check=True)
with tarfile.open(archive) as source:
    source.extractall(project, filter='data')
archive.unlink()
# Include the candidate launcher even when the test is run before committing.
for filename in ('launch.ps1', 'windows-shared-env.txt', 'engine_bridge.gd', 'runtime_paths.gd'):
    shutil.copy2(ROOT / 'godot' / filename, project / 'godot' / filename)
# Only the disposable game's normal entry gains a graceful auto-close timer.
main = project / 'godot/main.gd'
main_text = main.read_text(encoding='utf-8')
assert 'func _ready():' in main_text
main.write_text(main_text.replace('func _ready():',
    'func _ready():\n\tget_tree().create_timer(10.0).timeout.connect(close_game)', 1), encoding='utf-8')
probe = project / 'godot/import_asset_probe.gd'
probe.write_text('''extends SceneTree
func _initialize():
 var icons=load("res://ui_icons.gd").new()
 var report={"equipment":0,"existing":0,"failed":[]}
 for id in icons.equipment_paths:
  if icons.texture("equipment:"+id)==null:report.failed.append(id)
  else:report.equipment+=1
 for file in DirAccess.get_files_at("res://assets/ui_icons/icons64"):
  if file.ends_with(".png"):
   if icons.texture(file.trim_suffix(".png"))==null:report.failed.append(file)
   else:report.existing+=1
 print("ASSET_PROBE "+JSON.stringify(report))
 quit(0 if report.failed.is_empty() else 1)
''', encoding='utf-8')
proxy = out / 'godot proxy.py'
proxy.write_text('''import json,os,subprocess,sys
from pathlib import Path
a=sys.argv[1:]
phase="version" if "--version" in a else ("import" if "--import" in a else "game")
with open(os.environ["IMPORT_TEST_EVENTS"],"a") as f:f.write(json.dumps({"phase":phase,"args":a})+"\\n")
mode=os.environ.get("IMPORT_TEST_MODE","")
if phase=="import" and mode in ("fail","error_zero"):
 print("ERROR: injected import failure",file=sys.stderr)
 sys.exit(23 if mode=="fail" else 0)
if phase=="game" and mode=="game_exit":sys.exit(17)
if phase=="game" and "--headless" not in a:a += ["--headless"]
sys.exit(subprocess.call([os.environ["IMPORT_TEST_GODOT"],*a]))
''', encoding='utf-8')
if os.name == 'nt':
    executable = out / 'godot proxy.cmd'
    executable.write_text('@echo off\n"%IMPORT_TEST_PYTHON%" "%~dp0godot proxy.py" %*\nexit /b %errorlevel%\n', encoding='ascii')
else:
    executable = out / 'godot proxy'
    import shlex
    executable.write_text('#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' ' + shlex.quote(str(proxy)) + ' "$@"\n')
    executable.chmod(0o755)
shared = out / 'shared.env'
env = dict(settings, AKI_SHARED_ENV_FILE=str(shared), GODOT_BIN=str(executable), IMPORT_TEST_GODOT=str(Path(args.godot).resolve()), IMPORT_TEST_PYTHON=settings["NATIVE5525_PYTHON"],
           XDG_DATA_HOME=str(out/'user/data'), XDG_CONFIG_HOME=str(out/'user/config'),
           XDG_CACHE_HOME=str(out/'user/cache'), APPDATA=str(out/'user/roaming'),
           LOCALAPPDATA=str(out/'user/local'), PYTHONDONTWRITEBYTECODE='1')
for key in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'APPDATA', 'LOCALAPPDATA'):
    Path(env[key]).mkdir(parents=True, exist_ok=True)
# Kept outside the project to detect accidental manipulation of user saves.
sentinel = Path(env['APPDATA'] if os.name == 'nt' else env['XDG_DATA_HOME']) / '5525-godot-prototype/untouched-save.json'
sentinel.parent.mkdir(parents=True, exist_ok=True)
sentinel.write_text('{"sentinel":"preserve"}')
sentinel_hash = hashlib.sha256(sentinel.read_bytes()).hexdigest()
results = []
@contextmanager
def case(name):
    result = {"name": name, "passed": False}
    results.append(result)
    try:
        yield result
    except Exception as error:
        result["error"] = type(error).__name__
        raise
    else:
        result["passed"] = True
        print("PASS", name, flush=True)

configuration = {key: env.pop(key) for key in ('GODOT_BIN', 'NATIVE5525_NODE', 'NATIVE5525_PYTHON')}
def write_config(values):
    def relative(value):
        try:
            return os.path.relpath(value, project)
        except ValueError:  # Executables on another Windows drive stay absolute.
            return value
    (project / '.env').write_text(
        '\n'.join(f'{key}="{relative(value)}"' for key, value in values.items()),
        encoding='utf-8-sig')
write_config(configuration)

def run(name, mode='', smoke=False, check=False, expected=0, verify_assets=False):
    with case(name) as result:
        events = out / (name + '-events.jsonl')
        local = dict(env, IMPORT_TEST_EVENTS=str(events), IMPORT_TEST_MODE=mode)
        command = [args.powershell, '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(project/'godot/launch.ps1')]
        if smoke: command.append('-SmokeTest')
        if check: command.append('-Check')
        p = subprocess.run(command, env=local, capture_output=True, text=True, errors='replace', timeout=150)
        log = p.stdout + p.stderr
        (out/(name+'.log')).write_text(log, encoding='utf-8')
        assert p.returncode == expected, (name, p.returncode, log)
        phases = [json.loads(line)['phase'] for line in events.read_text().splitlines()]
        wanted = ['version'] if check else ['version','import'] + ([] if mode in ('fail','error_zero') else ['game'])
        assert phases == wanted, (name, phases)
        if mode in ('fail','error_zero'):
            assert 'Asset import failed. Log:' in log and 'injected import failure' in log, log
        elif expected == 0:
            assert 'ERROR:' not in log, log
        assert hashlib.sha256(sentinel.read_bytes()).hexdigest() == sentinel_hash
        result.update(exit_code=p.returncode, phases=phases)
        if name == 'check-does-not-import':
            assert not (project/'godot/.godot').exists()
        if verify_assets:
            result['stage'] = 'assets'
            result['assets'] = assets(name)

def assets(name):
    p = subprocess.run([args.godot,'--headless','--path',str(project/'godot'),'--script','res://import_asset_probe.gd'],
                       env=env, capture_output=True, text=True, timeout=30)
    (out/(name+'-assets.log')).write_text(p.stdout+p.stderr, encoding='utf-8')
    assert p.returncode == 0 and 'ERROR:' not in p.stdout+p.stderr
    report = json.loads(next(line.removeprefix('ASSET_PROBE ') for line in p.stdout.splitlines() if line.startswith('ASSET_PROBE ')))
    equipment = json.loads((project/'godot/assets/equipment_icons_placeholder/mapping.json').read_text())
    ui_icons = list((project/'godot/assets/ui_icons/icons64').glob('*.png'))
    assert equipment and ui_icons and not report['failed'], report
    assert (report['equipment'], report['existing']) == (len(equipment), len(ui_icons)), report
    return report

try:
    for key in configuration:
        with case('missing-' + key):
            write_config({**configuration, key: str(project / 'missing executable')})
            p = subprocess.run([args.powershell, '-NoProfile', '-ExecutionPolicy', 'Bypass',
                                '-File', str(project/'godot/launch.ps1'), '-Check'],
                               env=env, capture_output=True, timeout=60)
            assert p.returncode != 0, key

    write_config(configuration)
    env['GODOT_BIN'] = str(project / 'missing process executable')
    run('project-dotenv-overrides-process', check=True)
    shared.write_text('GODOT_BIN="' + executable.name + '"', encoding='utf-8-sig')
    write_config({**configuration, 'GODOT_BIN': str(project / 'missing project executable')})
    run('shared-dotenv-overrides-project-and-process', check=True)
    env.pop('GODOT_BIN')
    shared.unlink()
    write_config(configuration)
    run('check-does-not-import', check=True)
    run('cold-normal-launch', verify_assets=True)
    for recipe in (project/'godot/assets/equipment_icons_placeholder/icons64').glob('*.png.import'):
        target = re.search(r'^path="([^"]+)"', recipe.read_text(), re.M).group(1)
        (project/'godot'/target.removeprefix('res://')).unlink()
    run('missing-cache-normal-launch', verify_assets=True)
    run('warm-smoke-launch', smoke=True, verify_assets=True)
    # A future addition has no recipe or cache; do not hard-code the current set.
    folder=project/'godot/assets/equipment_icons_placeholder'
    shutil.copy2(folder/'icons64/armor-cloth.png',folder/'icons64/future-item.png')
    mapping=json.loads((folder/'mapping.json').read_text())
    mapping['future-item']='res://assets/equipment_icons_placeholder/icons64/future-item.png'
    (folder/'mapping.json').write_text(json.dumps(mapping))
    icons = project/'godot/assets/ui_icons/icons64'
    shutil.copy2(next(icons.glob('*.png')), icons/'future-ui-icon.png')
    run('future-png-normal-launch', verify_assets=True)
    run('import-nonzero-blocks-game',mode='fail',expected=23)
    run('import-error-zero-blocks-game',mode='error_zero',expected=1)
    run('game-exit-code-preserved',mode='game_exit',expected=17)
finally:
    (out/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
