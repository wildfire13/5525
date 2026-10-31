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
# Rationale / removals: docs/linux-fhd-tests-20261031.md.
# Main-window FHD is independent from child-dialog and texture dimensions.


def run(name, command, cwd, env=None):
    if a.only and name not in a.only:
        return
    started = time.monotonic()
    try:
        r = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True, timeout=150)
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


run('facility_asset_integrity', [sys.executable, str(repo / 'godot/tests/facility_asset_integrity.py')], repo)
run('individual_icons_integrity', [sys.executable, str(repo / 'godot/tests/individual_icons_integrity.py')], repo)

for name in ['facility_art_261021', 'hover_regression', 'hover_lifetime_regression', 'icons_approved_261021', 'feedback_261021', 'inventory_header_261020', 'status_layout_lifecycle', 'status_empty_inventory', 'feedback_261019_3', 'feedback_261019_2', 'feedback_261019_input', 'guild_regression', 'inventory_regression', 'ui_feedback2_20261016', 'ui_feedback2_20261017', 'ui_feedback_20261016', 'shop_rows_regression', 'owned_equipment_regression', 'frontend_smoke', 'ui_preferences_restart', 'brushup_formation_regression', 'brushup_comparison_regression', 'facility_npc_regression', 'research2_descriptions', 'text_cleanup_regression', 'battle_selection_regression', 'inventory_context_regression', 'window_resize_regression', 'battle_layout_f2', 'inventory_short_window_regression', 'equipment_hover_f4', 'skill_effect_regression', 'ui_p3_drag_regression', 'turn_order_keyboard_regression', 'deployment_start_regression', 'guard_visibility_regression', 'individual_icons_regression', 'audio_options_regression', 'feedback_backdrops_regression', 'loading_screen_check', 'results_regression', 'painted_vfx_regression', 'vfx_expansion_regression', 'facility_feedback2_regression', 'feedback2_guild_regression', 'deployment_drag_regression', 'feedback2_party_strip_regression', 'native_file_dialog', 'feedback3_guild_regression', 'feedback3_speech_regression', 'speech_tail_regression', 'status_footer_stability', 'debug_window_check', 'debug_log_accuracy', 'debug_store_regression', 'debug_store_teardown', 'inn_feedback3_regression', 'quest_board_feedback3', 'warehouse_regression', 'updateplan_regression']:
    phases = ['write', 'read'] if name == 'ui_preferences_restart' else ['']
    if a.only and not any(name + ('_' + phase if phase else '') in a.only for phase in phases):
        continue
    scope = Path(tempfile.mkdtemp(prefix=name + '-', dir=out))
    env = dict(os.environ, NATIVE5525_NODE=node, NATIVE5525_PYTHON=sys.executable, NATIVE5525_AUDIO_OFF='1', INVENTORY_QA_ROOT=str(scope), UIUX_REVIEW_EVIDENCE=str(scope), SKILL_EFFECT_QA_ROOT=str(scope))
    for key, child in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        path = scope / child
        path.mkdir()
        env[key] = str(path)
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
    for phase in phases:
        env['UI_PREFERENCES_PHASE'] = phase
        run(name + ('_' + phase if phase else ''), [godot, '--headless', '--resolution', '1920x1080', '--audio-driver', 'Dummy', '--path', str(repo / 'godot'), '--script', str(wrapper)], repo, env)
sys.exit(0 if all(r['passed'] for r in results) else 1)
