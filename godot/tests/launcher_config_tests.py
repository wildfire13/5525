"""Unit tests for shared launcher Godot-path precedence and fallback."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from launcher_config import resolve_godot


class LauncherConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "godot").mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def executable(self, path):
        path = self.root / path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("synthetic executable", encoding="utf-8")
        return path

    def config(self, value):
        path = self.root / "godot" / "launcher.local.json"
        path.write_text(json.dumps({"godot_bin": value}), encoding="utf-8")
        return path

    def test_cli_overrides_environment_and_local_file(self):
        cli = self.executable("cli/godot")
        self.executable("env/godot")
        self.executable("config/godot")
        self.config("config/godot")
        actual, source = resolve_godot(self.root, str(cli), {"GODOT_BIN": str(self.root / "env/godot")})
        self.assertEqual(actual, cli.resolve())
        self.assertEqual(source, "--godot")

    def test_environment_overrides_local_file(self):
        env = self.executable("env/godot")
        self.executable("config/godot")
        self.config("config/godot")
        actual, source = resolve_godot(self.root, environ={"GODOT_BIN": str(env)})
        self.assertEqual(actual, env.resolve())
        self.assertEqual(source, "GODOT_BIN")

    def test_local_config_resolves_relative_to_checkout(self):
        expected = self.executable("runtime/日本語 パス/Godot_console.exe")
        self.config("runtime/日本語 パス/Godot_console.exe")
        actual, source = resolve_godot(self.root, environ={})
        self.assertEqual(actual, expected.resolve())
        self.assertEqual(source, "godot/launcher.local.json")

    def test_invalid_environment_fails_closed_even_with_valid_local_file(self):
        self.executable("config/godot")
        self.config("config/godot")
        with self.assertRaisesRegex(FileNotFoundError, "GODOT_BIN"):
            resolve_godot(self.root, environ={"GODOT_BIN": str(self.root / "missing")})

    def test_invalid_local_config_fails_closed_instead_of_discovering(self):
        self.executable("runtime/godot")
        self.config("missing/godot")
        with patch("launcher_config.shutil.which", return_value=str(self.root / "runtime/godot")):
            with self.assertRaisesRegex(FileNotFoundError, "launcher.local.json"):
                resolve_godot(self.root, environ={})

    def test_malformed_local_config_has_actionable_error(self):
        (self.root / "godot" / "launcher.local.json").write_text("{", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Invalid .*launcher.local.json"):
            resolve_godot(self.root, environ={})

    def test_path_discovery_keeps_its_existing_priority(self):
        expected = self.executable("path/godot")
        with patch("launcher_config.shutil.which", side_effect=[str(expected), None]):
            actual, source = resolve_godot(self.root, environ={})
        self.assertEqual(actual, expected.resolve())
        self.assertEqual(source, "automatic discovery")

    def test_runtime_folder_is_discovered_after_path(self):
        expected = self.executable("runtime/godot/Godot_v4.6_console.exe")
        with patch("launcher_config.shutil.which", return_value=None):
            actual, source = resolve_godot(self.root, environ={})
        self.assertEqual(actual, expected.resolve())
        self.assertEqual(source, "automatic discovery")

    def test_auto_discovery_skips_unusable_candidate(self):
        bad = self.executable("path/godot")
        expected = self.executable("runtime/godot/Godot_console.exe")
        with patch("launcher_config.shutil.which", side_effect=[str(bad), None]):
            actual, _ = resolve_godot(self.root, environ={}, validate=lambda path: path != bad)
        self.assertEqual(actual, expected.resolve())

    def test_invalid_explicit_file_does_not_fall_back(self):
        path_candidate = self.executable("path/godot")
        with patch("launcher_config.shutil.which", return_value=str(path_candidate)):
            with self.assertRaisesRegex(FileNotFoundError, "--godot"):
                resolve_godot(self.root, explicit=str(self.root / "missing"), environ={})


if __name__ == "__main__":
    unittest.main(verbosity=2)
