"""Repeatable headless checks for the isolated Godot frontend (no visible UI)."""
import argparse
import datetime
import json
import os
from pathlib import Path
import sys
import subprocess
from launcher_config import resolve_godot
import time
import tempfile

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", help="Godot 4.6 console executable (overrides GODOT_BIN and launcher.local.json)")
parser.add_argument("--full", action="store_true", help="Also rerun the complete native regression suite")
args = parser.parse_args()
def is_godot_46(path: Path) -> bool:
    try:
        # The CI runner applies its own per-suite deadline and records each result.
        timeout = None if ui_runner in command else 180
        result = subprocess.run([str(path), "--version"], capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0 and result.stdout.strip().startswith("4.6.")

try:
    godot_path, godot_source = resolve_godot(ROOT, explicit=args.godot, validate=is_godot_46)
except (FileNotFoundError, ValueError) as error:
    parser.error(f"{error} Install/use Godot 4.6.x, set GODOT_BIN, or create godot/launcher.local.json from the example.")
args.godot = str(godot_path)
node = os.environ.get("NATIVE5525_NODE", "node")
env = {**os.environ, "PYTHONUTF8": "1", "PYTHONIOENCODING": "utf-8", "NATIVE5525_PYTHON": sys.executable}
evidence = Path(tempfile.mkdtemp(prefix="5525-headless-"))
env.update(GODOT_BIN=args.godot, NATIVE5525_NODE=node, NATIVE5525_AUDIO_OFF="1")
profile = evidence / "profile"
profile.mkdir()
env["APPDATA" if os.name == "nt" else "XDG_DATA_HOME"] = str(profile)
common = [args.godot, "--headless", "--resolution", "1920x1080", "--audio-driver", "Dummy", "--path", str(BASE)]
steps = [
    ("Godot path configuration", [sys.executable, "-X", "utf8", "-B", str(BASE / "tests/launcher_config_tests.py")], BASE),
    ("Godot import/parse", common + ["--editor", "--import", "--quit"], BASE),
    ("Godot candidate rules", [node, "test_godot_rules.cjs"], ROOT / "native"),
    ("Atomic save and portrait adapter", [sys.executable, "-X", "utf8", "-B", "-m", "unittest", "-v", "test_godot_files"], ROOT / "native"),
]
# Keep bridge, fault and lifecycle coverage alongside the current CI UI suite.
for name, script in [
    ("Pipe bridge", "bridge_smoke.gd"),
    ("Frontend controls", "frontend_smoke.gd"),
    ("Music state machine", "audio_smoke.gd"),
    ("Audio reconnect and load regression", "audio_regression.gd"),
    ("Portrait hover and HUD lifecycle", "hover_regression.gd"),
    ("Delayed hover responses after board destruction", "hover_lifetime_regression.gd"),
    ("Standalone quest dialogue", "quest_story_regression.gd"),
    ("Approved equipment flavor and detail presentation", "equipment_flavor_regression.gd"),
]:
    steps.append((name, common + ["--script", "res://tests/" + script], BASE))
steps.append(("Fault handling and shutdown", [sys.executable, "-X", "utf8", "-B", str(BASE / "tests/audit_checks.py"), args.godot], BASE))
if os.name == "nt":
    steps.append(("Candidate launcher", [sys.executable, "-X", "utf8", "-B", str(BASE / "tests/launcher_checks.py"), args.godot], BASE))
ui_runner = str(BASE / "tests/run_mock_ui_regression.py")
steps.append(("Current FHD UI regression", [sys.executable, "-X", "utf8", "-B", ui_runner, "--evidence", str(evidence)], BASE))
if args.full:
    steps.append(("Full native regression", [sys.executable, "-X", "utf8", "-B", "check.py"], ROOT / "native"))
report = {
    "at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "guiIncluded": False,
    "audioDriver": "Dummy",
    "newQuestWavsIncluded": True,
    "subjectiveListening": False,
    "uiEvidence": str(evidence),
    "steps": [],
}
target = BASE / "qa" / "headless-report.json"
target.parent.mkdir(exist_ok=True)
for name, command, cwd in steps:
    start = time.monotonic()
    try:
        # The CI runner applies its own per-suite deadline and records each result.
        timeout = None if ui_runner in command else 180
        result = subprocess.run(command, cwd=cwd, env=env, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=timeout)
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
    report["passed"] = False
    report["complete"] = False
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(("PASS " if entry["passed"] else "FAIL ") + name, flush=True)
report["passed"] = all(step["passed"] for step in report["steps"])
report["complete"] = True
target = BASE / "qa" / "headless-report.json"
target.parent.mkdir(exist_ok=True)
target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(target, flush=True)
raise SystemExit(0 if report["passed"] else 1)
