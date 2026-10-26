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


run('facility_asset_integrity', [sys.executable, str(repo / 'godot/tests/facility_asset_integrity.py')], repo)
run('individual_icons_integrity', [sys.executable, str(repo / 'godot/tests/individual_icons_integrity.py')], repo)

for name in ['facility_art_261021', 'hover_regression', 'hover_lifetime_regression', 'icons_approved_261021', 'feedback_261021', 'inventory_header_261020', 'status_layout_lifecycle', 'status_empty_inventory', 'feedback_261019_3', 'feedback_261019_2', 'feedback_261019_input', 'guild_regression', 'inventory_regression', 'ui_feedback2_20261016', 'ui_feedback2_20261017', 'ui_feedback_20261016', 'shop_rows_regression', 'owned_equipment_regression', 'frontend_smoke', 'ui_preferences_restart', 'brushup_formation_regression', 'brushup_comparison_regression', 'facility_npc_regression', 'research2_descriptions', 'inventory_context_regression', 'window_resize_regression', 'battle_layout_f2', 'inventory_short_window_regression', 'equipment_hover_f4', 'skill_effect_regression', 'ui_p3_drag_regression', 'turn_order_keyboard_regression', 'deployment_start_regression', 'guard_visibility_regression', 'individual_icons_regression', 'audio_options_regression', 'feedback_backdrops_regression', 'loading_screen_check', 'results_regression', 'painted_vfx_regression', 'vfx_expansion_regression', 'facility_feedback2_regression', 'feedback2_guild_regression', 'deployment_drag_regression', 'feedback2_party_strip_regression', 'native_file_dialog', 'feedback3_guild_regression', 'feedback3_speech_regression', 'speech_tail_regression', 'status_footer_stability', 'debug_window_check', 'inn_feedback3_regression', 'quest_board_feedback3']:
    scope = Path(tempfile.mkdtemp(prefix=name + '-', dir=out))
    env = dict(os.environ, NATIVE5525_NODE=node, NATIVE5525_PYTHON=sys.executable, NATIVE5525_AUDIO_OFF='1', INVENTORY_QA_ROOT=str(scope), UIUX_REVIEW_EVIDENCE=str(scope), SKILL_EFFECT_QA_ROOT=str(scope))
    for key, child in [('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        path = scope / child
        path.mkdir()
        env[key] = str(path)
    for phase in ['write', 'read'] if name == 'ui_preferences_restart' else ['']:
        env['UI_PREFERENCES_PHASE'] = phase
        run(name + ('_' + phase if phase else ''), [godot, '--headless', '--audio-driver', 'Dummy', '--path', str(repo / 'godot'), '--script', 'res://tests/' + name + '.gd'], repo, env)
sys.exit(0 if all(r['passed'] for r in results) else 1)
