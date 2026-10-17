"""Run the real PowerShell launcher in a disposable checkout with cold/warm assets.

Usage: python launcher_import_checks.py --powershell /path/to/pwsh --godot /path/to/godot
On Windows use powershell.exe; the proxy runs the real Godot, recording launch order.
No existing project cache or user save is modified. Evidence stays in --output.
"""
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

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--powershell', required=True)
parser.add_argument('--godot', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
out = Path(args.output).resolve()
out.mkdir(parents=True, exist_ok=False)
project = out / 'project with spaces'
project.mkdir()
archive = out / 'source.tar'
with archive.open('wb') as stream:
    subprocess.run(['git', '-C', str(ROOT), 'archive', 'HEAD'], stdout=stream, check=True)
with tarfile.open(archive) as source:
    source.extractall(project, filter='data')
archive.unlink()
# Include the candidate launcher even when the test is run before committing.
shutil.copy2(ROOT / 'godot/launch.ps1', project / 'godot/launch.ps1')
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
if phase=="game" and "--headless" not in a:a += ["--headless","--quit-after","120"]
sys.exit(subprocess.call([os.environ["IMPORT_TEST_GODOT"],*a]))
''', encoding='utf-8')
if os.name == 'nt':
    executable = out / 'godot proxy.cmd'
    executable.write_text('@echo off\n"' + sys.executable + '" "' + str(proxy) + '" %*\nexit /b %errorlevel%\n')
else:
    executable = out / 'godot proxy'
    import shlex
    executable.write_text('#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' ' + shlex.quote(str(proxy)) + ' "$@"\n')
    executable.chmod(0o755)
env = dict(os.environ, GODOT_BIN=str(executable), NATIVE5525_NODE=shutil.which('node') or '',
           NATIVE5525_PYTHON=sys.executable, IMPORT_TEST_GODOT=str(Path(args.godot).resolve()),
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

def run(name, mode='', smoke=False, check=False, expected=0):
    events = out / (name + '-events.jsonl')
    local = dict(env, IMPORT_TEST_EVENTS=str(events), IMPORT_TEST_MODE=mode)
    command = [args.powershell, '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(project/'godot/launch.ps1')]
    if smoke: command.append('-SmokeTest')
    if check: command.append('-Check')
    p = subprocess.run(command, env=local, capture_output=True, text=True, timeout=150)
    log = p.stdout + p.stderr
    (out/(name+'.log')).write_text(log, encoding='utf-8')
    phases = [json.loads(line)['phase'] for line in events.read_text().splitlines()]
    wanted = ['version'] if check else ['version','import'] + ([] if mode in ('fail','error_zero') else ['game'])
    assert p.returncode == expected, (name, p.returncode, log)
    assert phases == wanted, (name, phases)
    if mode in ('fail','error_zero'):
        assert 'Asset import failed. Log:' in log and 'injected import failure' in log, log
    elif expected == 0:
        assert 'ERROR:' not in log, log
    assert hashlib.sha256(sentinel.read_bytes()).hexdigest() == sentinel_hash
    results.append(dict(name=name, passed=True, exit_code=p.returncode, phases=phases))
    print('PASS', name, flush=True)

def assets(name, equipment_count):
    p = subprocess.run([args.godot,'--headless','--path',str(project/'godot'),'--script','res://import_asset_probe.gd'],
                       env=env, capture_output=True, text=True, timeout=30)
    (out/(name+'-assets.log')).write_text(p.stdout+p.stderr, encoding='utf-8')
    assert p.returncode == 0 and 'ERROR:' not in p.stdout+p.stderr
    report = json.loads(next(line.removeprefix('ASSET_PROBE ') for line in p.stdout.splitlines() if line.startswith('ASSET_PROBE ')))
    assert report['equipment'] == equipment_count and report['existing'] == 52 and not report['failed'], report
    results[-1]['assets'] = report

try:
    run('check-does-not-import', check=True)
    assert not (project/'godot/.godot').exists()
    run('cold-normal-launch')
    assets('cold',42)
    for recipe in (project/'godot/assets/equipment_icons_placeholder/icons64').glob('*.png.import'):
        target = re.search(r'^path="([^"]+)"', recipe.read_text(), re.M).group(1)
        (project/'godot'/target.removeprefix('res://')).unlink()
    run('missing-42-normal-launch')
    assets('missing-42',42)
    run('warm-smoke-launch',smoke=True)
    assets('warm',42)
    # A future addition has no recipe or cache; do not hard-code the current set.
    folder=project/'godot/assets/equipment_icons_placeholder'
    shutil.copy2(folder/'icons64/armor-cloth.png',folder/'icons64/future-item.png')
    mapping=json.loads((folder/'mapping.json').read_text())
    mapping['future-item']='res://assets/equipment_icons_placeholder/icons64/future-item.png'
    (folder/'mapping.json').write_text(json.dumps(mapping))
    run('future-png-normal-launch')
    assets('future-png',43)
    run('import-nonzero-blocks-game',mode='fail',expected=23)
    run('import-error-zero-blocks-game',mode='error_zero',expected=1)
    run('game-exit-code-preserved',mode='game_exit',expected=17)
finally:
    (out/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
