"""Resolve the Godot executable from explicit settings or existing discovery."""
import json
import os
from pathlib import Path
import shutil


def _automatic_candidates(root: Path):
    for name in ("godot", "godot4"):
        found = shutil.which(name)
        if found:
            yield Path(found)

    runtime = root / "runtime" / "godot"
    if runtime.is_dir():
        yield from sorted(runtime.glob("*_console.exe"), key=lambda p: p.name, reverse=True)
        yield from sorted(runtime.glob("godot*"), key=lambda p: p.name, reverse=True)

    for demo_root in (root, root.parent / "5525"):
        if not demo_root.is_dir():
            continue
        for folder in sorted(demo_root.glob("Godot*"), reverse=True):
            if folder.is_dir():
                yield from sorted(folder.glob("*_console.exe"), key=lambda p: p.name, reverse=True)


def resolve_godot(root: Path, explicit: str | None = None, environ=None, validate=None):
    """Return ``(path, source)`` using CLI > GODOT_BIN > local config > discovery.

    An invalid explicit value fails closed. An invalid local config also fails
    closed instead of silently selecting a different engine.
    """
    root = Path(root).resolve()
    environ = os.environ if environ is None else environ
    local_config = root / "godot" / "launcher.local.json"
    configured = explicit if explicit else environ.get("GODOT_BIN")
    source = "--godot" if explicit else "GODOT_BIN" if configured else ""

    if not configured and local_config.exists():
        try:
            data = json.loads(local_config.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            raise ValueError(f"Invalid {local_config}: {error}") from error
        configured = data.get("godot_bin") if isinstance(data, dict) else None
        if not isinstance(configured, str) or not configured.strip():
            raise ValueError(f"{local_config} must contain a non-empty string field 'godot_bin'")
        source = "godot/launcher.local.json"

    if configured:
        path = Path(configured).expanduser()
        if source == "godot/launcher.local.json" and not path.is_absolute():
            path = root / path
        if not path.is_file() or validate is not None and not validate(path):
            raise FileNotFoundError(f"Godot executable from {source} is missing or is not a usable Godot 4.6.x executable: {configured}")
        return path.resolve(), source

    for path in _automatic_candidates(root):
        if path.is_file() and (validate is None or validate(path)):
            return path.resolve(), "automatic discovery"
    raise FileNotFoundError(
        "Godot 4.6.x was not found. Set GODOT_BIN or copy "
        "godot/launcher.local.example.json to godot/launcher.local.json and edit godot_bin."
    )
