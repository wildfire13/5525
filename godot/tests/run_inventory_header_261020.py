"""Persistent inventory header checks using fresh, isolated profiles; no desktop GUI claim."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

p = argparse.ArgumentParser()
p.add_argument('--evidence', required=True, type=Path)
p.add_argument('--only', nargs='*', help='Run only these named checks')
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


def run(name, command, cwd, env=None):
    if a.only and name not in a.only:
        return
    try:
        r = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=150)
        text, code = r.stdout + r.stderr, r.returncode
    except subprocess.TimeoutExpired as e:
        def decode(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else value or ''
        text, code = decode(e.stdout) + decode(e.stderr), 124
    (out / (name + '.log')).write_text(text, encoding='utf-8')
    errors = [line for line in text.splitlines() if 'ERROR:' in line or line.startswith('FAIL ') or 'leaked' in line.lower()]
    result = dict(name=name, passed=code == 0 and not errors, exit=code, errors=errors)
    results.append(result)
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False), flush=True)


for name in ['icons_approved_261021', 'feedback_261021', 'inventory_header_261020', 'status_layout_lifecycle', 'status_empty_inventory', 'feedback_261019_3', 'feedback_261019_2', 'feedback_261019_input', 'guild_regression', 'inventory_regression', 'ui_feedback2_20261016', 'ui_feedback2_20261017', 'ui_feedback_20261016', 'shop_rows_regression', 'owned_equipment_regression', 'frontend_smoke', 'ui_preferences_restart']:
    scope = Path(tempfile.mkdtemp(prefix=name + '-', dir=out))
    env = dict(os.environ, NATIVE5525_NODE=node, NATIVE5525_PYTHON=sys.executable, INVENTORY_QA_ROOT=str(scope), UIUX_REVIEW_EVIDENCE=str(scope))
    for key, child in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        path = scope / child
        path.mkdir()
        env[key] = str(path)
    for phase in ['write', 'read'] if name == 'ui_preferences_restart' else ['']:
        env['UI_PREFERENCES_PHASE'] = phase
        run(name + ('_' + phase if phase else ''), [godot, '--headless', '--audio-driver', 'Dummy', '--path', str(repo / 'godot'), '--script', 'res://tests/' + name + '.gd'], repo, env)
sys.exit(0 if all(r['passed'] for r in results) else 1)
