"""Supplement the unchanged legacy runner with exhaustive, checked CI groups."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
RUNNER = REPO / 'godot/tests/run_inventory_header_261020.py'
SHARDS = 3


def collect_groups(source):
    """Recognize this runner's manifest, never execute it to discover tests."""
    tree = ast.parse(source)
    groups = []
    suite_loops = 0
    recognized_calls = set()
    for statement in tree.body:
        if isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Call):
            call = statement.value
            if isinstance(call.func, ast.Name) and call.func.id == 'run':
                name = ast.literal_eval(call.args[0])
                if not isinstance(name, str) or not name:
                    raise ValueError('Invalid direct check name')
                groups.append([name])
                recognized_calls.add(id(call))
        if isinstance(statement, ast.For):
            if not isinstance(statement.target, ast.Name) or statement.target.id != 'name':
                raise ValueError('Unrecognized top-level runner loop')
            suites = ast.literal_eval(statement.iter)
            if not isinstance(suites, list) or not all(isinstance(n, str) and n for n in suites):
                raise ValueError('Unrecognized suite manifest')
            phase_nodes = [node.value for node in statement.body
                           if isinstance(node, ast.Assign) and any(
                               isinstance(target, ast.Name) and target.id == 'phases'
                               for target in node.targets)]
            expected = ast.parse("['write', 'read'] if name == 'ui_preferences_restart' else ['']", mode='eval').body
            if len(phase_nodes) != 1 or ast.dump(phase_nodes[0]) != ast.dump(expected):
                raise ValueError('Restart phase structure changed; review partitioning')
            calls = [node for node in ast.walk(statement) if isinstance(node, ast.Call)
                     and isinstance(node.func, ast.Name) and node.func.id == 'run']
            expected_name = ast.parse("name + ('_' + phase if phase else '')", mode='eval').body
            if len(calls) != 1 or ast.dump(calls[0].args[0]) != ast.dump(expected_name):
                raise ValueError('Unrecognized suite invocation')
            recognized_calls.add(id(calls[0]))
            groups.extend([[name + '_write', name + '_read'] if name == 'ui_preferences_restart' else [name]
                           for name in suites])
            suite_loops += 1
    all_calls = {id(node) for node in ast.walk(tree) if isinstance(node, ast.Call)
                 and isinstance(node.func, ast.Name) and node.func.id == 'run'}
    if all_calls != recognized_calls:
        raise ValueError('Unrecognized check invocation outside the manifest')
    names = [name for group in groups for name in group]
    if suite_loops != 1 or len(groups) <= SHARDS or len(set(names)) != len(names):
        raise ValueError('Incomplete or duplicate legacy manifest')
    return groups


def selected_names(groups, shard):
    if shard not in range(SHARDS):
        raise ValueError('Invalid shard number')
    return [name for group in groups[shard::SHARDS] for name in group]


def verify_results(results, names):
    if [result.get('name') for result in results] != names:
        raise ValueError('Result names do not exactly match the assigned checks')
    if not results or any(result.get('passed') is not True or result.get('exit') != 0 or result.get('errors') != []
                          for result in results):
        raise ValueError('One or more assigned checks failed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shard', type=int, required=True, choices=range(SHARDS))
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--list-only', action='store_true')
    args = parser.parse_args()
    groups = collect_groups(RUNNER.read_text(encoding='utf-8'))
    names = selected_names(groups, args.shard)
    out = args.evidence.resolve()
    if out == REPO or REPO in out.parents:
        parser.error('Evidence must be outside the checkout')
    manifest = dict(shard=args.shard, shards=SHARDS, selected=names,
                    total_checks=sum(map(len, groups)),
                    commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip(),
                    runner_sha256=hashlib.sha256(RUNNER.read_bytes()).hexdigest())
    if args.list_only:
        print(json.dumps(manifest, ensure_ascii=False))
        return 0
    # Refuse stale results rather than accidentally accepting another invocation.
    out.mkdir(parents=True, exist_ok=False)
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(manifest), flush=True)
    code = subprocess.run([sys.executable, str(RUNNER), '--evidence', str(out), '--only', *names], cwd=REPO).returncode
    if code:
        return code
    verify_results(json.loads((out / 'results.json').read_text(encoding='utf-8')), names)
    print(f'PASS: all {len(names)} assigned checks completed, shard {args.shard + 1}/{SHARDS}', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
