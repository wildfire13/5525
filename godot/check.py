"""Repeatable headless checks for the isolated Godot frontend (no visible UI)."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
from mock_ui_suites import SUITES, read_results
from qa_reports import evidence_directory, runtime_details
from launcher_config import resolve_godot, runtime_environment
import time
import tempfile

BASE = Path(__file__).resolve().parent
ROOT = BASE.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", help="Godot 4.7 console executable (overrides GODOT_BIN and launcher.local.json)")
parser.add_argument("--full", action="store_true", help="Also rerun the complete native regression suite")
parser.add_argument("--evidence", type=Path)
args = parser.parse_args()
reports = evidence_directory("headless", args.evidence)
def is_godot_47(path: Path) -> bool:
    try:
        result = subprocess.run([str(path), "--version"], capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0 and result.stdout.strip().startswith("4.7.")

try:
    env = runtime_environment(ROOT)
    godot_path, godot_source = resolve_godot(ROOT, explicit=args.godot, validate=is_godot_47)
except (FileNotFoundError, ValueError) as error:
    parser.error(f"{error} Install/use Godot 4.7.x, set GODOT_BIN, or create godot/launcher.local.json from the example.")
args.godot = str(godot_path)
node = env["NATIVE5525_NODE"]
python = env["NATIVE5525_PYTHON"]
env.update(PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
run_parent = None if args.evidence else reports.parents[2] / "runs"
if run_parent:
    run_parent.mkdir(parents=True, exist_ok=True)
scratch = tempfile.TemporaryDirectory(prefix="5525-headless-", dir=run_parent)
evidence = Path(scratch.name)
env.update(GODOT_BIN=args.godot, NATIVE5525_NODE=node, NATIVE5525_AUDIO_OFF="1",
           INVENTORY_QA_ROOT=evidence.as_posix(), UIUX_REVIEW_EVIDENCE=evidence.as_posix())
profile = evidence / "profile"
profile.mkdir()
if os.name == "nt":
    env["APPDATA"] = str(profile)
    env["LOCALAPPDATA"] = str(profile)
else:
    env["XDG_DATA_HOME"] = str(profile)
common = [args.godot, "--headless", "--resolution", "1920x1080", "--audio-driver", "Dummy", "--path", str(BASE)]
steps = [
    ("QA configuration and reporting", [python, "-X", "utf8", "-B", "-m", "unittest", "discover", "-s", "tests", "-p", "*_tests.py"], BASE),
    ("Godot import/parse", common + ["--editor", "--import", "--quit"], BASE),
    ("Godot candidate rules", [node, "test_godot_rules.cjs"], ROOT / "native"),
    ("Atomic save and portrait adapter", [python, "-X", "utf8", "-B", "-m", "unittest", "-v", "test_godot_files"], ROOT / "native"),
]
# Keep bridge, fault and lifecycle coverage alongside the current CI UI suite.
for name, script in [
    ("Pipe bridge", "bridge_smoke.gd"),
    ("Frontend controls", "frontend_smoke.gd"),
    ("Music state machine", "audio_smoke.gd"),
    ("Local map, facility and road battle music", "audio_trial_bgm_regression.gd"),
    ("Audio reconnect and load regression", "audio_regression.gd"),
    ("Portrait hover and HUD lifecycle", "hover_regression.gd"),
    ("Delayed hover responses after board destruction", "hover_lifetime_regression.gd"),
    ("Standalone quest dialogue", "quest_story_regression.gd"),
    ("Approved equipment flavor and detail presentation", "equipment_flavor_regression.gd"),
]:
    steps.append((name, common + ["--script", "res://tests/" + script], BASE))
steps.append(("Fault handling and shutdown", [python, "-X", "utf8", "-B", str(BASE / "tests/audit_checks.py"), args.godot, "--evidence", str(reports)], BASE))
if os.name == "nt":
    steps.append(("Candidate launcher", [python, "-X", "utf8", "-B", str(BASE / "tests/launcher_checks.py"), args.godot, "--evidence", str(reports)], BASE))
ui_runner = str(BASE / "tests/run_mock_ui_regression.py")
steps.append(("Current FHD UI regression", [python, "-X", "utf8", "-B", ui_runner, "--godot", args.godot, "--evidence", str(evidence)], BASE))
if args.full:
    steps.append(("Full native regression", [python, "-X", "utf8", "-B", "check.py", "--evidence", str(reports)], ROOT / "native"))
report = {
    "at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "guiIncluded": False,
    "audioDriver": "Dummy",
    "newQuestWavsIncluded": True,
    "subjectiveListening": False,
    "runtimes": runtime_details(godot=args.godot, python=python, node=node),
    "steps": [],
}
target = reports / "headless-report.json"
for name, command, cwd in steps:
    start = time.monotonic()
    try:
        # The CI runner applies its own per-suite deadline and records each result.
        timeout = None if ui_runner in command or name == "Full native regression" else 180
        step_env = env
        if name in ("Audio reconnect and load regression", "Fault handling and shutdown"):
            step_env = {**env, "NATIVE5525_AUDIO_OFF": "0"}
        result = subprocess.run(command, cwd=cwd, env=step_env, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=timeout)
        combined = result.stdout + result.stderr
        markers = ["SCRIPT ERROR:", "ERROR:", "FAIL ", "ObjectDB instances leaked", "resources still in use"]
        bad_markers = [marker for marker in markers if marker in combined]
        entry = dict(name=name, passed=result.returncode == 0 and not bad_markers,
                     exitCode=result.returncode, markers=bad_markers)
        if not entry["passed"]:
            print(combined, flush=True)
    except subprocess.TimeoutExpired as error:
        for stream in (error.stdout, error.stderr):
            if stream:
                print(stream.decode("utf-8", errors="replace") if isinstance(stream, bytes) else stream, flush=True)
        entry = dict(name=name, passed=False, error="timeout after 180 seconds")
    if ui_runner in command:
        suites, error = read_results(evidence / "results.json", SUITES)
        entry["suites"] = suites
        if error:
            entry.update(passed=False, error=error)
            if len(suites) < len(SUITES):
                entry["firstUnconfirmed"] = SUITES[len(suites)]
        elif any(not suite["passed"] for suite in suites):
            entry["passed"] = False
    entry["seconds"] = round(time.monotonic() - start, 3)
    report["steps"].append(entry)
    report["passed"] = False
    report["complete"] = False
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(("PASS " if entry["passed"] else "FAIL ") + name, flush=True)
report["passed"] = all(step["passed"] for step in report["steps"])
report["complete"] = True
target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
scratch.cleanup()
print(target.name, flush=True)
raise SystemExit(0 if report["passed"] else 1)
