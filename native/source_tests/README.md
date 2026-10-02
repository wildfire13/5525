# Unchanged-source rule assertions against native snapshots

The seven `test-*.cjs` files in this directory were copied from `5525-cloud/5525/prototype/tools/` on 2026-10-02. Only `require('../src/battle.js')`, `require('../src/journey.js')`, and `require('../src/play-log.js')` paths were changed to point one directory up at the native snapshots. All other bytes, including assertions and fixtures, are preserved.

Run `node test_engine_regression.cjs` from the native PoC. To additionally verify source module hashes and exact assertion identity, run:

```sh
node test_engine_regression.cjs --source ../prototype
```

These are the rule-only suites: battle, party, porter, Stamp/Snipe, deployment, journey, and play log. DOM suites importing the browser application/cycle code are deliberately excluded, because those do not test the native frontend. Existing deterministic real-process adapter tests remain in `test_journey_bridge.py`; actual GUI evidence belongs in `COVERAGE.md` and the task's observation record.

Some original suites use clearly constructed rule fixtures. Their presence does not establish native GUI reachability or represent ordinary balance/playthrough evidence. Do not update the copied assertions to hide a divergence; investigate the snapshot/source version and explain any intended change.
