"""Isolated, headless UI checks. Never treat these as OS mouse/visual QA."""
import argparse,json,os,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--evidence',type=Path,required=True)
p.add_argument('--godot',default=shutil.which('godot'))
p.add_argument('--node',default=shutil.which('node'))
a=p.parse_args();repo=Path(__file__).resolve().parents[2];out=a.evidence.resolve()
if out==repo or repo in out.parents:p.error('Evidence must be outside the checkout')
if not a.godot or not a.node:p.error('Existing Godot and Node are required')
out.mkdir(parents=True,exist_ok=True);results=[]
def run(name,script,scope,phase=''):
 folder=out/scope;folder.mkdir(exist_ok=True);env=dict(os.environ)
 env.update(INVENTORY_QA_ROOT=str(folder),UIUX_REVIEW_EVIDENCE=str(folder),NATIVE5525_NODE=a.node,NATIVE5525_PYTHON=sys.executable,UI_PREFERENCES_PHASE=phase)
 for key,sub in [('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_CONFIG_HOME','config'),('APPDATA','appdata'),('LOCALAPPDATA','localappdata'),('TMP','temp'),('TEMP','temp')]:
  path=folder/sub;path.mkdir(exist_ok=True);env[key]=str(path)
 command=[a.godot,'--headless','--audio-driver','Dummy','--path',str(repo/'godot'),'--script','res://tests/'+script+'.gd']
 try:
  proc=subprocess.run(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=100)
  text=proc.stdout.decode(errors='replace');code=proc.returncode
 except subprocess.TimeoutExpired as exc:text=(exc.stdout or b'').decode(errors='replace');code=124
 (out/(name+'.log')).write_text(text,encoding='utf-8')
 errors=[line for line in text.splitlines() if 'ERROR:' in line or line.startswith('FAIL ') or 'leaked' in line.lower()]
 results.append(dict(name=name,exit_code=code,passed=code==0 and not errors,errors=errors,checks=sum(line.startswith('PASS ') for line in text.splitlines())))
 (out/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(results[-1],ensure_ascii=False),flush=True)
for script in ['launcher_smoke','ui_feedback_20261016','ui_input_layout_20261016','ui_inventory_stress_20261016','owned_equipment_regression']:
 run(script,script,script)
run('restart-write','ui_preferences_restart','restart','write')
run('restart-read','ui_preferences_restart','restart','read')
sys.exit(0 if all(r['passed'] for r in results) else 1)
