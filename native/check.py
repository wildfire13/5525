"""Run the native prototype's non-GUI verification suite."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys

BASE=Path(__file__).resolve().parent
steps=[
 ('Python syntax',[sys.executable,'-m','compileall','-q','app.py','journey_app.py','tiny_poc.py']),
 ('Python rules/adapter/preview tests',[sys.executable,'-m','unittest','-v']),
 ('Standalone 30-action parity',['node','test_parity.cjs']),
 ('Reachable QA boundary fixtures',['node','test_qa_fixtures.cjs']),
 ('Original rule suites and frozen hashes',['node','test_engine_regression.cjs']),
]
source=BASE.parent/'prototype'
if source.exists():steps.append(('Live source and assertion parity',['node','test_engine_regression.cjs','--source',str(source)]))
report={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'guiIncluded':False,'steps':[]}
for name,command in steps:
    try:
        r=subprocess.run(command,cwd=BASE,text=True,encoding='utf-8',capture_output=True,timeout=120,env={**os.environ,"PYTHONIOENCODING":"utf-8","PYTHONUTF8":"1"})
        report['steps'].append({'name':name,'passed':r.returncode==0,'exitCode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
    except subprocess.TimeoutExpired:
        report['steps'].append({'name':name,'passed':False,'error':'timeout after 120 seconds'})
    print(('PASS' if report['steps'][-1]['passed'] else 'FAIL')+': '+name)
report['passed']=all(s['passed'] for s in report['steps'])
(BASE/'qa-check-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if report['passed'] else 1)
