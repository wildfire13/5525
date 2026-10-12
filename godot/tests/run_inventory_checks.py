"""Reproducible non-GUI checks; all runtime data is redirected to --evidence.

No desktop input, personal save access, network, installation or distribution.
The caller supplies its own writable evidence directory and Godot executable.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument('--evidence', type=Path, required=True)
parser.add_argument('--godot', type=Path)
parser.add_argument('--node', default=shutil.which('node'))
parser.add_argument('--suite', choices=['all', 'native', 'godot'], default='all')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
out = args.evidence.resolve()
if out == repo or out.is_relative_to(repo):
    parser.error('Use a separate evidence directory outside the source checkout')
if args.suite != 'native' and (not args.godot or not args.godot.is_file()):
    parser.error('--godot must name an existing executable')
if not args.node:
    parser.error('Node.js executable was not found')
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ)
env.update(INVENTORY_QA_ROOT=str(out), UIUX_REVIEW_EVIDENCE=str(out),
           NATIVE5525_NODE=str(args.node), NATIVE5525_PYTHON=sys.executable,
           PYTHONDONTWRITEBYTECODE='1')
env['PATH'] = str(Path(args.node).parent) + os.pathsep + env.get('PATH', '')
for var, name in [('APPDATA', 'appdata'), ('LOCALAPPDATA', 'localappdata'),
                  ('TEMP', 'temp'), ('TMP', 'temp')]:
    directory = out / name
    directory.mkdir(exist_ok=True)
    env[var] = str(directory)
results = []


def run(tag, command, cwd, timeout=120):
    started = time.monotonic()
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
    expired = False
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        expired = True
        # This exact child and descendants belong to this invocation only.
        if os.name == 'nt':
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                           capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
        else:
            process.kill()
        output, _ = process.communicate(timeout=10)
    text = output.decode('utf-8', errors='replace')
    errors = [line for line in text.splitlines() if 'ERROR:' in line or
              line.startswith('FAIL ') or 'leaked' in line.lower() or 'WATCHDOG TIMEOUT' in line]
    result = dict(tag=tag, command=command, exit_code=process.returncode, timed_out=expired,
                  elapsed_seconds=round(time.monotonic()-started, 2), errors=errors,
                  passed=process.returncode == 0 and not expired and not errors)
    results.append(result)
    (out / (tag + '.log')).write_text(text, encoding='utf-8')
    (out / 'results.json').write_text(json.dumps(results, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print(('PASS ' if result['passed'] else 'FAIL ') + tag, flush=True)
    if not result['passed']:
        print('\n'.join(text.splitlines()[-15:]), flush=True)


if args.suite != 'godot':
    for test in sorted((repo / 'native').glob('test_*.cjs')):
        run(test.stem, [str(args.node), str(test)], repo / 'native')
    for name in ['test_campaign_files', 'test_godot_files', 'test_campaign_bridge',
                 'test_equipment_slots_bridge', 'test_equipment_skill_bridge',
                 'test_presentation_bridge', 'test_preview_bridge', 'test_journey_bridge']:
        run(name, [sys.executable, '-X', 'utf8', '-B', '-m', 'unittest', name], repo / 'native')
if args.suite != 'native':
    base = [str(args.godot), '--headless', '--audio-driver', 'Dummy', '--path', str(repo / 'godot')]
    run('parse', base + ['--log-file', str(out / 'parse-engine.log'), '--check-only', '--script', 'res://main.gd'], repo)
    for name in ['inventory_regression', 'shop_plan_regression', 'inventory_battle_hud', 'hover_lifetime_regression',
                 'followup_ui_regression', 'ui_review_fixes', 'uiux_inventory_review',
                 'plan_reconnect_regression', 'reference_disconnect_regression', 'audio_regression']:
        run(name, base + ['--log-file', str(out / (name + '-engine.log')), '--script', 'res://tests/' + name + '.gd'], repo)
print(f"{sum(r['passed'] for r in results)}/{len(results)} commands passed", flush=True)
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
