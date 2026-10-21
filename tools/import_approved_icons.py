"""Verify approved v56 source and produce runtime recipes; no artwork redrawing."""
import json,hashlib,shutil,subprocess,sys
from pathlib import Path
source=Path(sys.argv[1]);repo=Path(__file__).resolve().parents[1]
m=json.loads((source/'manifest.json').read_text())
for a in m['assets']+[m['approved_fist_image']]:
 p=source/a['path'];assert p.stat().st_size==a['bytes'];assert hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256']
ids=json.loads(subprocess.check_output(['node','-e',"console.log(JSON.stringify({gear:require('./native/campaign.js').gear.map(g=>g.id),skills:Object.keys(require('./native/campaign.js').view(require('./native/campaign.js').create()).skillNames)}))"],cwd=repo))
assert all(e['equipment_id'] in ids['gear'] for e in m['equipment'])
assert all(s['skill_id'] in ids['skills'] for s in m['skills'])
root=repo/'godot/assets/approved_v56';root.mkdir(exist_ok=True)
for a in m['assets']+[m['approved_fist_image']]:
 target=root/a['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/a['path'],target)
def path(p):return 'res://assets/approved_v56/'+p
def recipe(v):
 crops=v['crops'];base=next((c for c in crops if not c['label'].startswith('スキルLv')),None)
 images=v['images'];d={}
 if base:d={'base':path(base['sheet']),'crop':[int(x) for x in base['xywh'].split(',')]}
 else:d={'base':path(next(i for i in images if i.endswith('/skill.png') or ('temporary' not in i and 'style-selected' not in i)))}
 badges=[i for i in images if 'temporary' in i]
 if badges:d['badge']=path(badges[0])
 levels={}
 for c in crops:
  if c['label'].startswith('スキルLv'):levels[c['label'].removeprefix('スキルLv')]={'base':path(c['sheet']),'crop':[int(x) for x in c['xywh'].split(',')]}
 if levels:d['levels']=levels
 return d
r={'equipment':{},'skills':{},'fist':{'base':path(m['approved_fist_image']['path'])}}
for e in m['equipment']:
 if e['name_images']:r['equipment'][e['equipment_id']]=recipe(e['name_visual'])
for s in m['skills']:r['skills'][s['skill_id']]=recipe(s['visual'])
(root/'recipes.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
(root/'source-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
print(f"Verified {len(m['assets'])} assets + fist; {len(m['equipment'])} equipment IDs and {len(m['skills'])} skill IDs match game")
