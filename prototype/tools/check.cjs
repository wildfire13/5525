#!/usr/bin/env node
'use strict';

// Portable, dependency-free checks. Deliberately excludes opt-in browser scripts.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
if (args.includes('--help')) {
  console.log('Usage: node tools/check.cjs [--json]\nRuns syntax and all tools/test-*.cjs checks; --json emits one machine-readable report.\nWorks from any directory, writes no files, and does not launch a browser.');
  process.exit(0);
}
if (args.some(arg => arg !== '--json')) {
  console.error('Unknown option. Use --help.');
  process.exit(2);
}
const json = args.includes('--json');
const sources = fs.readdirSync(path.join(root, 'src')).filter(name => name.endsWith('.js')).sort();
const tests = fs.readdirSync(__dirname).filter(name => /^test-.*\.cjs$/.test(name)).sort();
const checks = [
  ...sources.map(name => ({name: `syntax: src/${name}`, args: ['--check', path.join(root, 'src', name)]})),
  ...tests.map(name => ({name: `test: tools/${name}`, args: [path.join(__dirname, name)]})),
];
const started = new Date().toISOString();
const results = checks.map(check => {
  const before = process.hrtime.bigint();
  const result = spawnSync(process.execPath, check.args, {cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 4 * 1024 * 1024});
  const passed = result.status === 0 && !result.error;
  const entry = {name: check.name, passed, durationMs: Number(process.hrtime.bigint() - before) / 1e6, exitCode: result.status, stdout: result.stdout || '', stderr: result.stderr || '', ...(result.error ? {error: result.error.message} : {})};
  if (!json) {
    console.log(`${passed ? 'PASS' : 'FAIL'} ${entry.name} (${Math.round(entry.durationMs)} ms)`);
    if (entry.stdout.trim()) console.log(entry.stdout.trim());
    if (entry.stderr.trim()) console.error(entry.stderr.trim());
    if (entry.error) console.error(entry.error);
  }
  return entry;
});
const passed = results.every(result => result.passed);
const report = {schemaVersion: 1, started, node: process.version, passed, checks: results.length, failures: results.filter(result => !result.passed).length, browserQA: 'not-run; DOM wiring checks are simulated and do not verify browser rendering', results};
if (json) console.log(JSON.stringify(report, null, 2));
else console.log(`\n${passed ? 'All checks passed' : 'Checks failed'}: ${results.length - report.failures}/${results.length}. Browser QA not run; DOM checks use a simulation.`);
process.exitCode = passed ? 0 : 1;
