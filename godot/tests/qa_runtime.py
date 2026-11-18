"""Use the game configuration for runtimes started by QA runners."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "godot"))
from launcher_config import resolve_godot, runtime_environment


def qa_environment(*, godot=None, needs_godot=True):
    env = runtime_environment(ROOT)
    if needs_godot:
        env["GODOT_BIN"] = str(resolve_godot(ROOT, explicit=godot)[0])
    return env
