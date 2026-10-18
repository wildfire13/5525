"""261019 focused rules/UI regression. Headless checks do not replace GUI acceptance."""
import argparse,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);a=p.parse_args()
repo=Path(__file__).resolve().parents[2];out=a.evidence.resolve()
if out==repo or repo in out.parents:p.error('Use an evidence directory outside the checkout')
node=shutil.which('node');godot=shutil.which('godot')
if not node or not godot:p.error('Node and Godot must be installed')
out.mkdir(parents=True,exist_ok=True);results=[]
def run(name,cmd,env=None):
 try:
  r=subprocess.run(cmd,cwd=repo,env=env,capture_output=True,text=True,timeout=110);text=r.stdout+r.stderr;code=r.returncode
 except subprocess.TimeoutExpired as e:text=(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout,bytes) else str(e.stdout);code=124
 (out/(name+'.log')).write_text(text,encoding='utf-8')
 errors=[line for line in text.splitlines() if 'ERROR:' in line or line.startswith('FAIL ') or 'leaked' in line.lower()]
 result=dict(name=name,passed=code==0 and not errors,exit=code,pass_lines=sum(line.startswith('PASS ') for line in text.splitlines()),errors=errors);results.append(result)
 (out/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=False),flush=True)
for name in ['feedback_261019','inventory_battle','equipment_migration','equipment_slots','two_handed','empty_equipment','weapon_variations','equipment_skills','equipment_ambush_def','support_reach','dual_attack','dual_skills','quest_cargo','cargo_return','cargo_migration','cargo_marker_boundary','ui_feedback_rules','battle_presentation','shop_transactions','reserve_policy']:
 run('native_'+name,[node,'native/test_'+name+'.cjs'])
for name in ['feedback_261019','feedback_261019_skills','frontend_smoke','additional_feedback','turn_order_i02','ui_feedback2_20261017','quest_cargo_regression','deployment_layout_20261017','owned_equipment_regression','ui_preferences_restart']:
 scope=Path(tempfile.mkdtemp(prefix=name+'-',dir=out))
 phases=['write','read'] if name=='ui_preferences_restart' else ['']
 for phase in phases:
  env=dict(os.environ,NATIVE5525_NODE=node,NATIVE5525_PYTHON=sys.executable,INVENTORY_QA_ROOT=str(scope),UI_PREFERENCES_PHASE=phase)
  for key,child in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
   path=scope/child;path.mkdir(exist_ok=True);env[key]=str(path)
  run('godot_'+name+('_'+phase if phase else ''),[godot,'--headless','--audio-driver','Dummy','--path',str(repo/'godot'),'--script','res://tests/'+name+'.gd'],env)
sys.exit(0 if all(r['passed'] for r in results) else 1)
