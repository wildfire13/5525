"""Fail-closed manifest and completion checks for supplemental CI."""
import copy
import unittest
from run_legacy_ui_shard import RUNNER, SHARDS, collect_groups, selected_names, verify_results


class ShardTests(unittest.TestCase):
    def setUp(self):
        self.source = RUNNER.read_text(encoding='utf-8')
        self.groups = collect_groups(self.source)

    def test_disjoint_exhaustive_and_paired(self):
        expected = [name for group in self.groups for name in group]
        shards = [selected_names(self.groups, shard) for shard in range(SHARDS)]
        self.assertEqual(len(expected), 66)
        self.assertEqual(sorted(name for shard in shards for name in shard), sorted(expected))
        self.assertEqual(len(set(expected)), len(expected))
        self.assertTrue(all(shards))
        pairs = [shard for shard in shards if 'ui_preferences_restart_write' in shard]
        self.assertEqual(len(pairs), 1)
        self.assertIn('ui_preferences_restart_read', pairs[0])

    def test_reject_manifest_drift(self):
        for source in [self.source.replace("['write', 'read']", "['read']"),
                       self.source.replace("run('event_voice_assets'", "run('facility_asset_integrity'"),
                       self.source + "\nif True:\n    run('new_check', [], repo)\n"]:
            with self.assertRaises(ValueError):
                collect_groups(source)

    def test_exact_completion_required(self):
        names = ['a', 'b']
        good = [dict(name=name, passed=True, exit=0, errors=[]) for name in names]
        verify_results(good, names)
        for bad in [[], good[:1], good + good[:1], list(reversed(good))]:
            with self.assertRaises(ValueError):
                verify_results(bad, names)
        for field, value in [('passed', False), ('exit', 124), ('errors', ['ERROR: example'])]:
            bad = copy.deepcopy(good)
            bad[0][field] = value
            with self.assertRaises(ValueError):
                verify_results(bad, names)

    def test_reject_invalid_shard(self):
        for shard in [-1, SHARDS]:
            with self.assertRaises(ValueError):
                selected_names(self.groups, shard)


if __name__ == '__main__':
    unittest.main()
