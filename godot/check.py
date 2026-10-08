"""Repeatable headless checks for the isolated Godot frontend (no visible UI)."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", default=os.environ.get("GODOT_BIN"), help="Godot 4.6 console executable")
parser.add_argument("--full", action="store_true", help="Also rerun the complete native regression suite")
args = parser.parse_args()
if not args.godot or not Path(args.godot).is_file():
    parser.error("--godot or GODOT_BIN must identify an installed executable")
node = os.environ.get("NATIVE5525_NODE", "node")
env = {**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8", "NATIVE5525_PYTHON": sys.executable}
common = [args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(BASE)]
steps = [
    ("Godot import/parse", common + ["--editor", "--import", "--quit"], BASE),
    ("Godot candidate rules", [node, "test_godot_rules.cjs"], ROOT / "native"),
    ("No-clobber save and portrait adapter", [sys.executable, "-X", "utf8", "-B", "-m", "unittest", "-v", "test_godot_files"], ROOT / "native"),
]
for name, script in [("Pipe bridge", "bridge_smoke.gd"), ("Frontend controls", "frontend_smoke.gd"), ("UI parity", "ui_parity_smoke.gd"), ("Music state machine", "audio_smoke.gd")]:
    steps.append((name, common + ["--script", "res://tests/" + script], BASE))
steps.append(("Fault handling and shutdown", [sys.executable, "-X", "utf8", "-B", str(BASE / "tests/audit_checks.py"), args.godot], BASE))
steps.append(("Audio reconnect and load regression", common + ["--script", "res://tests/audio_regression.gd"], BASE))
steps.append(("Candidate launcher", [sys.executable, "-X", "utf8", "-B", str(BASE / "tests/launcher_checks.py"), args.godot], BASE))
if args.full:
    steps.append(("Full native regression", [sys.executable, "-X", "utf8", "-B", "check.py"], ROOT / "native"))
report = {
    "at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "guiIncluded": False,
    "audioDriver": "Dummy",
    "newQuestWavsIncluded": True,
    "subjectiveListening": False,
    "steps": [],
}
for name, command, cwd in steps:
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=cwd, env=env, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=180)
        combined = result.stdout + result.stderr
        markers = ["SCRIPT ERROR:", "ERROR:", "FAIL ", "ObjectDB instances leaked", "resources still in use"]
        bad_markers = [marker for marker in markers if marker in combined]
        entry = dict(name=name, command=command, passed=result.returncode == 0 and not bad_markers,
                     exitCode=result.returncode, markers=bad_markers, stdout=result.stdout, stderr=result.stderr)
    except subprocess.TimeoutExpired as exc:
        def decoded(value):
            return value.decode("utf-8", errors="replace") if isinstance(value, bytes) else (value or "")
        entry = dict(name=name, command=command, passed=False, error="timeout after 180 seconds",
                     stdout=decoded(exc.stdout), stderr=decoded(exc.stderr))
    entry["seconds"] = round(time.monotonic() - start, 3)
    report["steps"].append(entry)
    print(("PASS " if entry["passed"] else "FAIL ") + name, flush=True)
report["passed"] = all(step["passed"] for step in report["steps"])
target = BASE / "qa" / "headless-report.json"
target.parent.mkdir(exist_ok=True)
target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(target, flush=True)
raise SystemExit(0 if report["passed"] else 1)
