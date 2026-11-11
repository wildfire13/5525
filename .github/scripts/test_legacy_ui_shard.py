"""Fail-closed manifest and completion checks for supplemental CI."""
import copy
import unittest
from run_legacy_ui_shard import SHARDS, check_groups, selected_names, verify_results


class ShardTests(unittest.TestCase):
    def setUp(self):
        self.groups = check_groups()

    def test_disjoint_exhaustive_and_paired(self):
        expected = [name for group in self.groups for name in group]
        shards = [selected_names(self.groups, shard) for shard in range(SHARDS)]
        self.assertEqual(len(expected), 67)
        self.assertEqual(sorted(name for shard in shards for name in shard), sorted(expected))
        self.assertEqual(len(set(expected)), len(expected))
        self.assertTrue(all(shards))
        pairs = [shard for shard in shards if 'ui_preferences_restart_write' in shard]
        self.assertEqual(len(pairs), 1)
        start = pairs[0].index('ui_preferences_restart_write')
        self.assertEqual(pairs[0][start:start + 2],
                         ['ui_preferences_restart_write', 'ui_preferences_restart_read'])

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
