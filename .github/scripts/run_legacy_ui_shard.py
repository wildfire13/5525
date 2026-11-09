"""Run the legacy suite with exhaustive, checked CI groups."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

REPO = Path(__file__).resolve().parents[2]
RUNNER = REPO / 'godot/tests/run_inventory_header_261020.py'
sys.path.insert(0, str(RUNNER.parent))
from legacy_ui_manifest import check_groups

SHARDS = 3


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
    groups = check_groups()
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
