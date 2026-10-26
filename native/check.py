"""Run the native prototype's non-GUI verification suite."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys

BASE=Path(__file__).resolve().parent
steps=[
 ('Python syntax',[sys.executable,'-m','compileall','-q','app.py','journey_app.py','tiny_poc.py','tk_bootstrap.py','campaign_app.py','voice.py','music.py']),
 ('Python rules/adapter/preview tests',[sys.executable,'-m','unittest','-v']),
 ('Campaign battle extension',['node','test_campaign_battle.cjs']),
 ('Equipment-level ambush and DEF contract',['node','test_equipment_ambush_def.cjs']),
 ('Individual growth and inert legacy team fields',['node','test_team_growth.cjs']),
 ('Eleven equipment proposals',['node','test_equipment_skills.cjs']),
 ('Eight equipment slots',['node','test_equipment_slots.cjs']),
 ('Dual normal attacks',['node','test_dual_attack.cjs']),
 ('Dual skill attacks',['node','test_dual_skills.cjs']),
 ('Support skill reach',['node','test_support_reach.cjs']),
 ('October 11 feedback rules',['node','test_ui_feedback_rules.cjs']),
 ('Old save equipment migration',['node','test_equipment_migration.cjs']),
 ('Two-handed occupancy',['node','test_two_handed.cjs']),
 ('New weapon variants',['node','test_weapon_variations.cjs']),
 ('Sequential battle presentation',['node','test_battle_presentation.cjs']),
 ('Expanded presentation metadata parity',['node','test_vfx_expansion_presentation.cjs']),
 ('Character voice event routing',['node','test_voice_events.cjs']),
 ('Campaign long-battle log retention',['node','test_campaign_log.cjs']),
 ('Separate travelling and deployment rosters',['node','test_deployment_roster.cjs']),
 ('Campaign replay loop',['node','test_campaign.cjs']),
 ('Guild composition and personal ownership',['node','test_guild_contract.cjs']),
 ('Quest cargo ownership and reserve carrier',['node','test_quest_cargo.cjs']),
 ('Standalone 30-action parity',['node','test_parity.cjs']),
 ('Reachable QA boundary fixtures',['node','test_qa_fixtures.cjs']),
 ('Historical provenance and current porter contract',['node','test_engine_regression.cjs']),
]
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
