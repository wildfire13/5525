'use strict';
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const {createInterface} = require('node:readline');
const C = require('./campaign.js');
const B = require('./campaign-battle.js');

async function main() {
 const child = spawn(process.execPath, ['--random-seed=5525', require.resolve('./bridge.cjs')]);
 const lines = createInterface({input: child.stdout})[Symbol.asyncIterator]();
 let stderr = '';
 child.stderr.on('data', chunk => { stderr += chunk; });
 const exited = new Promise(resolve => child.on('exit', resolve));
 const call = async request => {
  child.stdin.write(JSON.stringify(request) + '\n');
  const line = await lines.next();
  assert.equal(line.done, false, stderr);
  return JSON.parse(line.value);
 };
 const campaign = async (action, ...args) => {
  const data = await call({op: 'campaign', action, args});
  assert.equal(data.ok, true, data.error);
  return data;
 };
 try {
  const start = await call({op: 'campaign_start'});
  assert.equal(start.ok, true);
  assert.equal(Object.keys(start.campaign.characters).length, 24);
  assert.ok(Object.keys(start.campaign.characters).every(id => id.startsWith('character_')));
  await campaign('depart', 'north', 'convoy');
  await campaign('travel', 'short');
  // This run's real deployment save supplies the same random encounter to both
  // adapters; every subsequent transition is computed independently.
  const saved = await call({op: 'campaign_save'});
  assert.equal(saved.ok, true);
  const direct = C.deserialize(JSON.stringify(saved.data));
  const snapshot = () => JSON.parse(JSON.stringify(direct.battle));
  assert.ok(direct.battle.units.filter(u => u.side === 'ally')
   .every(u => u.id.startsWith('character_') && u.equipment && u.skillSources.length));
  const opening = await call({op: 'campaign', action: 'begin', args: [], presentation: true});
  assert.equal(opening.ok, true);
  assert.ok(C.begin(direct));
  // The fastest current scout opens this encounter, so begin has no enemy
  // action to defer and exposes its settled frame immediately.
  assert.equal(opening.presentation.phase, 'settled');
  assert.deepEqual(opening.state, snapshot());
  const begun = await call({op: 'presentation_finish', id: opening.presentation.id});
  assert.equal(begun.ok, true);
  assert.deepEqual(begun.state, snapshot());
  for (let n = 0; n < 500 && !direct.battle.result; n++) {
   const state = direct.battle;
   const actor = state.units.find(u => u.id === state.actor);
   const {kind, target} = B.chooseAction(state, actor);
   assert.ok(C.act(direct, kind, target), 'test policy must choose a legal campaign action');
   const data = await call({op: 'act', kind, target});
   assert.equal(data.ok, true, data.error);
   assert.deepEqual(data.state, snapshot());
  }
  assert.ok(direct.battle.result, 'battle reaches a terminal outcome');
  const terminal = snapshot();
  assert.equal((await call({op: 'act', kind: 'action_defend'})).ok, false);
  assert.deepEqual((await call({op: 'view'})).state, terminal);
  console.log(`PASS current equipped campaign adapter parity over ${terminal.actions} actions through terminal outcome: ${terminal.result}`);
 } finally {
  child.stdin.end();
  assert.equal(await exited, 0, stderr);
 }
}

main().catch(error => { console.error(error); process.exitCode = 1; });
