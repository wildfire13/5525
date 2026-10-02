'use strict';
const assert = require('node:assert/strict');
const B = require('./battle.js');
const J = require('./journey.js');
const {makeJourneyFixture} = require('./qa-fixtures.cjs');

const originalRandom = Math.random;
for (const name of ['ontime_delivery', 'failed_result']) {
  const first = makeJourneyFixture(name);
  const second = makeJourneyFixture(name);
  assert.deepEqual(first, second, name + ' generation must be deterministic');
  assert.equal(Math.random, originalRandom, 'fixture must not replace global random');
  assert.equal(first.metadata.name, name);
  assert.equal(first.metadata.testOnly, true);
  assert.match(first.metadata.label, /^QA固定局面/);
  assert.match(first.metadata.method, /^TEST ONLY:/);
  assert.ok(first.metadata.actions.every(count => count > 0 && count <= 250));
  assert.equal(first.state.actor, null);
  assert.ok(first.state.result);
  assert.equal(B.act(first.state, 'guard'), false, 'terminal battle rejects further actions');
  assert.deepEqual(first.journey.party, first.state.units.filter(unit => unit.side === 'ally'));
  assert.equal(first.journey.potions, first.state.potions.ally);
  assert.equal(first.journey.gold, 0);
  assert.equal(first.journey.xp, 0);
  assert.equal(first.journey.kit, 'medicine');
  assert.equal(first.journey.formation, 'convoy');

  // Returned fixtures must be independent objects across calls.
  first.metadata.actions.push(999);
  assert.notDeepEqual(first.metadata.actions, second.metadata.actions);
  assert.deepEqual(makeJourneyFixture(name), second);
}

const delivery = makeJourneyFixture('ontime_delivery');
assert.equal(delivery.journey.phase, 'delivery');
assert.equal(delivery.journey.job.id, 'parts');
assert.deepEqual(delivery.journey.selected, J.create().selected);
assert.equal(delivery.journey.stage, 2);
assert.equal(delivery.journey.hours, 6);
assert.equal(delivery.journey.rested, false);
assert.equal(delivery.journey.outcome, null);
assert.equal(delivery.metadata.actions.length, 2);
assert.ok(delivery.state.units.filter(unit => unit.side === 'enemy').every(unit => unit.hp <= 0));
assert.equal(delivery.state.failure, undefined);
assert.ok(J.deliver(delivery.journey));
assert.equal(delivery.journey.phase, 'result');
assert.equal(delivery.journey.outcome, 'success');
assert.equal(delivery.journey.gold, 150);
assert.equal(delivery.journey.xp, 100);
assert.equal(delivery.journey.level, 2);
const awarded = JSON.stringify(delivery.journey);
assert.equal(J.deliver(delivery.journey), false);
assert.equal(JSON.stringify(delivery.journey), awarded, 'cannot deliver the fixture twice');

const failed = makeJourneyFixture('failed_result');
assert.deepEqual(failed.journey.selected, ['porter']);
assert.equal(failed.journey.phase, 'result');
assert.equal(failed.journey.outcome, 'failed');
assert.equal(failed.journey.stage, 0);
assert.equal(failed.journey.hours, 3);
assert.equal(failed.state.failure, 'porter');
assert.equal(failed.state.units.find(unit => unit.id === 'porter').hp, 0);
assert.ok(failed.state.log.some(line => /防御/.test(line)), 'actual ally guards occurred');
assert.ok(failed.state.log.some(line => /ダメージ/.test(line)), 'actual enemy damage occurred');
assert.match(failed.journey.failureReason, /戦闘不能/);
assert.equal(failed.metadata.actions.length, 1);
assert.equal(J.deliver(failed.journey), false);
assert.equal(J.finishBattle(failed.journey, failed.state), false);
assert.throws(() => makeJourneyFixture('unknown'), RangeError);
assert.throws(() => makeJourneyFixture(null), RangeError);
console.log('PASS test-only public-rule fixtures: deterministic independent generation, unchanged global RNG, two real victories before on-time delivery, full rewards once, actual one-porter death and failed result.');
console.log(JSON.stringify({ontime: delivery.metadata, failure: failed.metadata}, null, 2));
