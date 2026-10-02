#!/usr/bin/env node
'use strict';

// Native-snapshot rule regression runner. No browser/DOM suites, GUI, writes,
// network, dependency installation, or modification of the original checkout.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = __dirname;
const suites = ['battle', 'party', 'porter', 'stamp-snipe', 'deployment', 'journey', 'play-log']
  .map(name => `test-${name}.cjs`);
const hashes = {
  'battle.js': '893b0d35463923806ace15f1a5a48c26dfdb65a306b098ffa9788a773d0f7fe0',
  'journey.js': '3710de59d75110f2e576d0ec00be78a08f7d36ae34f393bc89a7d468bbb7bc8e',
  'play-log.js': 'b7aae87a4a5a23665b050052b9cede24beb4a097277f7a3fc451b2456e2345f0',
};
const args = process.argv.slice(2);
let source = null;
if (args.length === 1 && args[0] === '--help') {
  console.log('Usage: node test_engine_regression.cjs [--source /path/to/5525/prototype]\nChecks three frozen module hashes and seven original rule suites against native snapshots. Optional --source also verifies exact source module identity and that test copies differ only in require paths. No GUI or DOM evidence is claimed.');
  process.exit(0);
}
if (args.length === 2 && args[0] === '--source') source = path.resolve(args[1]);
else if (args.length) {console.error('Invalid arguments. Use --help.');process.exit(2);}
const results = [];
function check(name, fn) {
  try {fn();results.push({name, passed: true});console.log('PASS ' + name);}
  catch (error) {results.push({name, passed: false});console.error('FAIL ' + name + ': ' + error.message);}
}
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const lf = text => text.replaceAll('\r\n', '\n');
const sourceHash = file => crypto.createHash('sha256').update(lf(fs.readFileSync(file, 'utf8'))).digest('hex');
const adaptPaths = text => text.replaceAll("require('../src/battle.js')", "require('../battle.js')")
  .replaceAll("require('../src/journey.js')", "require('../journey.js')")
  .replaceAll("require('../src/play-log.js')", "require('../play-log.js')");
for (const [name, expected] of Object.entries(hashes)) {
  check('frozen hash ' + name, () => {
    const actual = hash(path.join(root, name));
    if (actual !== expected) throw Error(`Expected ${expected}, got ${actual}`);
  });
  if (source) check('source hash parity ' + name, () => {
    if (hash(path.join(root, name)) !== sourceHash(path.join(source, 'src', name)))
      throw Error('Native snapshot differs from supplied source');
  });
}
for (const name of suites) {
  const copied = path.join(root, 'source_tests', name);
  if (source) check('original assertion identity ' + name, () => {
    const expected = adaptPaths(lf(fs.readFileSync(path.join(source, 'tools', name), 'utf8')));
    if (fs.readFileSync(copied, 'utf8') !== expected)
      throw Error('Copied suite differs beyond module require paths');
  });
  check('native rules ' + name, () => {
    const result = spawnSync(process.execPath, [copied], {
      cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024,
    });
    if (result.stdout.trim()) console.log(result.stdout.trim());
    if (result.stderr.trim()) console.error(result.stderr.trim());
    if (result.error || result.status !== 0)
      throw result.error || Error('Exit code ' + result.status);
  });
}
const failed = results.filter(result => !result.passed);
console.log(`\n${results.length - failed.length}/${results.length} checks passed: 7 rule suites, 3 frozen hashes${source ? ', 3 source hashes, 7 original-assertion identity checks' : ''}.`);
console.log('Rules only: no native controls, preview rendering, drag/drop, dialogs, file saving, art, or GUI coverage is implied.');
process.exitCode = failed.length ? 1 : 0;
