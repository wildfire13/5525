#!/usr/bin/env node
'use strict';

// Historical provenance and current-rule regression. No browser/DOM suites, GUI, writes,
// network, dependency installation, or modification of the original checkout.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const root = __dirname;
const suites = ['battle', 'party', 'porter', 'stamp-snipe', 'deployment', 'journey', 'play-log']
  .map(name => `test-${name}.cjs`);
const provenance = require('./source_tests/provenance.json');
const args = process.argv.slice(2);
let source = null;
if (args.length === 1 && args[0] === '--help') {
  console.log('Usage: node test_engine_regression.cjs [--source /path/to/5525/prototype]\nChecks historical provenance for three modules and seven adapted suites, allowing only the documented b143630 porter correction. Runs seven rule suites and the current porter acceptance contract. Optional --source additionally compares the historical source and assertions. No GUI or DOM evidence is claimed.');
  process.exit(0);
}
if (args.length === 2 && args[0] === '--source') source = path.resolve(args[1]);
else if (args.length) {console.error('Invalid arguments. Use --help.');process.exit(2);}
const results = [];
function check(name, fn) {
  try {fn();results.push({name, passed: true});console.log('PASS ' + name);}
  catch (error) {results.push({name, passed: false});console.error('FAIL ' + name + ': ' + error.message);}
}
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
const lf = text => text.replaceAll('\r\n', '\n');
const read = file => fs.readFileSync(file, 'utf8');
// Reverse exactly the recorded correction in memory; this never changes game files.
// The old digest still covers every other byte. A missing/duplicated correction fails.
function historicalText(file, name) {
  const current = read(file), correction = provenance.corrections[name];
  if (!correction) return current;
  if (current.split(correction.current).length !== 2)
    throw Error('Expected exactly one documented b143630 correction in ' + name);
  return current.replace(correction.current, correction.original);
}
const adaptPaths = text => text.replaceAll("require('../src/battle.js')", "require('../battle.js')")
  .replaceAll("require('../src/journey.js')", "require('../journey.js')")
  .replaceAll("require('../src/play-log.js')", "require('../play-log.js')");
for (const [name, expected] of Object.entries(provenance.modules)) {
  check('historical module provenance ' + name, () => {
    const actual = hash(historicalText(path.join(root, name), name));
    if (actual !== expected) throw Error(`Expected ${expected}, got ${actual}`);
  });
  if (source) check('historical source hash ' + name, () => {
    if (hash(lf(read(path.join(source, 'src', name)))) !== expected)
      throw Error('Supplied source differs from the recorded historical baseline');
  });
}
for (const name of suites) {
  const copied = path.join(root, 'source_tests', name);
  check('historical assertion provenance ' + name, () => {
    if (hash(historicalText(copied, name)) !== provenance.assertions[name])
      throw Error('Copied assertions differ beyond require paths and the documented b143630 correction');
  });
  if (source) check('original assertion identity ' + name, () => {
    const expected = adaptPaths(lf(read(path.join(source, 'tools', name))));
    if (historicalText(copied, name) !== expected)
      throw Error('Historical assertions differ from supplied source');
  });
  runSuite('native rules ' + name, copied);
}
function runSuite(name, file) {
  check(name, () => {
    const result = spawnSync(process.execPath, [file], {
      cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024,
    });
    if (result.stdout.trim()) console.log(result.stdout.trim());
    if (result.stderr.trim()) console.error(result.stderr.trim());
    if (result.error || result.status !== 0)
      throw result.error || Error('Exit code ' + result.status);
  });
}
runSuite('current porter acceptance contract', path.join(root, 'test_porter_acceptance.cjs'));
const failed = results.filter(result => !result.passed);
console.log(`\n${results.length - failed.length}/${results.length} checks passed: 7 rule suites, current porter contract, 3 historical module hashes, 7 historical assertion hashes${source ? ', 3 source hashes, 7 original-assertion identity checks' : ''}.`);
console.log('Rules only: no native controls, preview rendering, drag/drop, dialogs, file saving, art, or GUI coverage is implied.');
process.exitCode = failed.length ? 1 : 0;
