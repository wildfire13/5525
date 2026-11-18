"""The shareable report must retain real failures and identify interrupted runs."""
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from mock_ui_suites import read_results


class UIResultsTests(unittest.TestCase):
    def setUp(self):
        temporary = TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / "results.json"
        self.expected = ["first", "second"]
        self.first = dict(name="first", passed=True, exit=0, errors=[])

    def read(self, rows):
        self.path.write_text(json.dumps(rows), encoding="utf-8")
        return read_results(self.path, self.expected)

    def test_valid_failure_survives_without_private_fields(self):
        second = dict(name="second", passed=False, exit=0, errors=["resource-leak"], log="PRIVATE")
        rows, error = self.read([self.first, second])
        self.assertEqual(error, "")
        self.assertEqual(rows[1], {key: second[key] for key in ("name", "passed", "exit", "errors")})

    def test_partial_and_corrupt_results(self):
        self.assertEqual(self.read([self.first]), ([self.first], "incomplete-report"))
        self.path.write_text("[", encoding="utf-8")
        self.assertEqual(read_results(self.path, self.expected), ([], "missing-or-invalid-report"))

    def test_duplicate_misreported_or_unfiltered_results(self):
        for row, error in [(self.first, "unexpected-case"),
                           (dict(name="second", passed=True, exit=1, errors=[]), "invalid-case-result"),
                           (dict(name="second", passed=False, exit=0, errors=["PRIVATE"]), "invalid-case-result")]:
            with self.subTest(error=error):
                self.assertEqual(self.read([self.first, row]), ([self.first], error))


if __name__ == "__main__":
    unittest.main()
