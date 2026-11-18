"""Destinations and shareable runtime details for game QA reports."""
from datetime import datetime
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def evidence_directory(suite, explicit):
    if explicit is None:
        current = ROOT.parent.parent / "QA" / "現行版用"
        if not current.is_dir():
            raise SystemExit("Specify --evidence pointing to a directory outside the checkout.")
        sha = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, text=True).strip()
        stamp = datetime.now().strftime("%y%m%d-%H%M%S-%f")
        target = current / "results" / f"{stamp}-{sha}-{suite}" / "evidence"
    else:
        target = Path(explicit).resolve()
    if target.is_relative_to(ROOT):
        raise SystemExit("--evidence must point outside the game checkout.")
    target.mkdir(parents=True, exist_ok=True)
    return target


def runtime_details(**programs):
    details = {}
    for role, program in programs.items():
        result = subprocess.run([program, "--version"], capture_output=True, text=True, timeout=15, check=True)
        details[role] = {"name": Path(program).name, "version": result.stdout.strip()}
    return details
