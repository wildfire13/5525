"""Check the approved mock UI, rewards and return journey in isolated FHD profiles."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

SUITES = [
    'mock_character_migration', 'character_ab_fixes', 'character_details_parity',
    'mock_shop_migration', 'mock_facility_migration', 'mock_facility_presentation',
    'facility_readability_polish', 'background_ui_polish', 'shop_entry_position',
    'mock_travel_regression', 'mock_journey_integration', 'mock_service_regression',
    'mock_deployment_regression', 'combat_b_ui', 'battle_selection_regression',
    'menu_exit_regression', 'quest_reward_display_regression',
    'standalone_quest_failure_regression', 'quest_modal_regression',
    'npc_meeting_regression', 'town_meeting_layout_regression',
]

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--evidence', required=True, type=Path)
p.add_argument('--only', nargs='+', choices=SUITES)
a = p.parse_args()
repo = Path(__file__).resolve().parents[2]
out = a.evidence.resolve()
if out == repo or repo in out.parents:
    p.error('Evidence must be outside the checkout')
node, godot = shutil.which('node'), shutil.which('godot')
if not node or not godot:
    p.error('Node and Godot must be on PATH')
out.mkdir(parents=True, exist_ok=True)
results = []

for name in a.only or SUITES:
    scope = Path(tempfile.mkdtemp(prefix=name + '-', dir=out))
    env = dict(os.environ, NATIVE5525_NODE=node,
               NATIVE5525_PYTHON=sys.executable,
               NATIVE5525_AUDIO_OFF='1', MENU_EXIT_QA_ROOT=str(scope),
               PYTHONUTF8='1', PYTHONDONTWRITEBYTECODE='1')
    for key, child in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'),
                       ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache'),
                       ('TMPDIR', 'tmp')]:
        path = scope / child
        path.mkdir()
        env[key] = str(path)
    wrapper = scope / 'fhd-suite.gd'
    # The meeting suite deliberately verifies FHD and a smaller viewport.
    contract = '' if name in ('npc_meeting_regression', 'town_meeting_layout_regression') else (
        ' root.add_child(preload("res://tests/fhd_contract.gd").new())\n')
    wrapper.write_text(
        f'extends "res://tests/{name}.gd"\n'
        'func _initialize():call_deferred("_start_fhd_suite")\n'
        'func _start_fhd_suite():\n'
        ' root.size=Vector2i(1920,1080)\n'
        + contract + ' super._initialize()\n', encoding='utf-8')
    command = [godot, '--headless', '--resolution', '1920x1080', '--audio-driver',
               'Dummy', '--path', str(repo / 'godot'), '--script', str(wrapper)]
    started = time.monotonic()
    with (out / (name + '.log')).open('w', encoding='utf-8') as log:
        process = subprocess.Popen(command, cwd=repo, env=env, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=180)
        except subprocess.TimeoutExpired:
            if os.name == 'posix':
                os.killpg(process.pid, signal.SIGKILL)
            else:
                process.kill()
            process.wait()
            code = 124
    text = (out / (name + '.log')).read_text(encoding='utf-8', errors='replace')
    errors = [line for line in text.splitlines()
              if 'ERROR:' in line or line.startswith('FAIL ') or 'leaked' in line.lower()]
    source_sha256 = hashlib.sha256((repo / 'godot/tests' / (name + '.gd')).read_bytes()).hexdigest()
    result = dict(name=name, source_sha256=source_sha256, passed=code == 0 and not errors, exit=code,
                  errors=errors, seconds=round(time.monotonic() - started, 3))
    results.append(result)
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2),
                                      encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False), flush=True)

raise SystemExit(0 if all(result['passed'] for result in results) else 1)
