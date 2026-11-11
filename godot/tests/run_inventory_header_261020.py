"""FHD regression suites in isolated profiles; headless checks are not OS GUI playtests."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

from legacy_ui_manifest import ASSET_CHECKS, GODOT_SUITES, suite_checks

p = argparse.ArgumentParser()
p.add_argument('--evidence', required=True, type=Path)
p.add_argument('--only', nargs='*', help='Run only these named checks')
a = p.parse_args()
repo = Path(__file__).resolve().parents[2]
out = a.evidence.resolve()
if out == repo or repo in out.parents:
    p.error('Evidence must be outside the checkout')
node = shutil.which(os.environ.get('NATIVE5525_NODE') or 'node')
godot = shutil.which(os.environ.get('GODOT_BIN') or 'godot')
if not node or not godot:
    p.error('Set NATIVE5525_NODE and GODOT_BIN or put Node and Godot on PATH')
out.mkdir(parents=True, exist_ok=True)
results = []
# Rationale / removals: docs/linux-fhd-tests-20261031.md.
# Main-window FHD is independent from child-dialog and texture dimensions.


def run(name, command, cwd, env=None):
    if a.only and name not in a.only:
        return
    started = time.monotonic()
    try:
        timeout=240 if name=='feedback2_guild_regression' else 210 if name=='guild_regression' else 150
        r = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=timeout)
        text, code = r.stdout + r.stderr, r.returncode
    except subprocess.TimeoutExpired as e:
        def decode(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else value or ''
        text, code = decode(e.stdout) + decode(e.stderr), 124
    (out / (name + '.log')).write_text(text, encoding='utf-8')
    errors = [line for line in text.splitlines() if 'ERROR:' in line or line.startswith('FAIL ') or 'leaked' in line.lower()]
    result = dict(name=name, passed=code == 0 and not errors, exit=code, errors=errors, seconds=round(time.monotonic()-started, 3))
    results.append(result)
    (out / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False), flush=True)


interpreters = {'node': node, 'python': sys.executable}
for name, interpreter, script in ASSET_CHECKS:
    run(name, [interpreters[interpreter], str(repo / script)], repo)

for name in GODOT_SUITES:
    checks = suite_checks(name)
    if a.only and not any(result in a.only for result, _ in checks):
        continue
    scope = Path(tempfile.mkdtemp(prefix=name + '-', dir=out))
    env = dict(os.environ, NATIVE5525_NODE=node, NATIVE5525_PYTHON=sys.executable, NATIVE5525_AUDIO_OFF='1', INVENTORY_QA_ROOT=str(scope), UIUX_REVIEW_EVIDENCE=str(scope), SKILL_EFFECT_QA_ROOT=str(scope))
    for key, child in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        path = scope / child
        path.mkdir()
        env[key] = str(path)
    if os.name == 'nt':
        env['APPDATA'] = str(scope / 'data')
        env['INVENTORY_QA_ROOT'] = scope.as_posix()
    # Resource/configuration/worker checks do not exercise a game viewport.
    screen_suite = name not in {'icons_approved_261021', 'ui_preferences_restart', 'individual_icons_regression', 'debug_store_teardown', 'audio_options_regression'}
    # Wrap screen suites, retaining their lifecycle while checking every frame.
    wrapper = scope / 'fhd-suite.gd'
    wrapper.write_text(
        f'extends "res://tests/{name}.gd"\n'
        'func _initialize():call_deferred("_start_fhd_suite")\n'
        'func _start_fhd_suite():\n'
        ' root.size=Vector2i(1920,1080)\n' +
        (' root.add_child(preload("res://tests/fhd_contract.gd").new())\n' if screen_suite else '') +
        ' super._initialize()\n', encoding='utf-8')
    (scope / 'source-sha256.txt').write_text(hashlib.sha256((repo / 'godot/tests' / (name + '.gd')).read_bytes()).hexdigest() + '\n')
    for result, phase in checks:
        env['UI_PREFERENCES_PHASE'] = phase
        run(result, [godot, '--headless', '--resolution', '1920x1080', '--audio-driver', 'Dummy', '--path', str(repo / 'godot'), '--script', str(wrapper)], repo, env)
sys.exit(0 if all(r['passed'] for r in results) else 1)
