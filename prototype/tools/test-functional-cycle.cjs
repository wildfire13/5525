'use strict';
const assert = require('node:assert/strict');
const Battle = require('../src/battle.js');
const Journey = require('../src/journey.js');
const playMirror = require('./playtest-mirror.cjs');
const allies = battle => battle.units.filter(unit => unit.side === 'ally');
const resources = units => units.map(({id, hp, mp, max, maxMp}) => ({id, hp, mp, max, maxMp}));

function runDelivery(job, rest) {
  const journey = Journey.create();
  assert.ok(Journey.accept(journey, job));
  assert.ok(Journey.depart(journey, 'medicine', 'convoy'));
  const actions = [];
  for (let leg = 0; leg < 2; leg++) {
    assert.equal(journey.phase, 'road');
    assert.ok(Journey.travel(journey, 'short'));
    // Fixed documented fixture; combat itself is not mocked or weakened.
    const battle = Battle.create({ally: journey.selected, enemy: ['scout', 'mage', 'archer', 'guard'].slice(0, leg + 3), previous: journey.party, formation: journey.formation, skillStage: journey.level, potions: journey.potions, enemyPotions: leg, deployment: true});
    assert.equal(battle.actor, null);
    assert.equal(battle.actions, 0);
    assert.equal(battle.potions.ally, journey.potions);
    if (leg) assert.deepEqual(resources(allies(battle)), resources(journey.party), 'second battle preserves each individual HP and MP');
    assert.ok(Battle.begin(battle));
    const played = playMirror(Battle, 'front-focus', battle, (kind, target) => {
      assert.ok(Battle.legal(battle, kind, target), `policy attempted illegal ${kind} ${target}`);
      assert.ok(Battle.act(battle, kind, target));
    });
    assert.ok(battle.result, 'battle must finish before the play policy action limit');
    assert.equal(battle.failure, undefined);
    assert.ok(battle.units.filter(unit => unit.side === 'enemy').every(unit => unit.hp <= 0), played.result);
    assert.ok(battle.actions > 0 && battle.actions <= 180);
    actions.push(battle.actions);
    const hours = journey.hours;
    assert.ok(Journey.finishBattle(journey, battle));
    assert.equal(journey.hours, hours + 1, 'combat always costs one hour');
    assert.equal(journey.stage, leg + 1);
    assert.deepEqual(resources(journey.party), resources(allies(battle)));
    assert.equal(journey.potions, battle.potions.ally);
    assert.equal(Journey.finishBattle(journey, battle), false, 'return from battle is single-use');
    assert.equal(journey.hours, hours + 1);
    if (leg === 0) {
      assert.equal(journey.phase, 'camp');
      if (rest) {
        const before = resources(journey.party);
        assert.ok(Journey.rest(journey));
        journey.party.forEach((unit, index) => {
          assert.equal(unit.hp, Math.min(before[index].max, before[index].hp + 60));
          assert.equal(unit.mp, Math.min(before[index].maxMp, before[index].mp + 2));
        });
        const snapshot = JSON.stringify(journey);
        assert.equal(Journey.rest(journey), false);
        assert.equal(JSON.stringify(journey), snapshot, 'second rest changes nothing');
      }
      assert.ok(Journey.onward(journey));
    }
  }
  assert.equal(journey.phase, 'delivery');
  assert.equal(journey.hours, rest ? 8 : 6);
  assert.ok(Journey.deliver(journey));
  const late = job === 'medicine' && rest;
  assert.equal(journey.outcome, late ? 'late' : 'success');
  assert.equal(journey.gold, late ? 117 : job === 'medicine' ? 180 : 150);
  assert.equal(journey.xp, late ? 60 : 100);
  assert.equal(journey.level, late ? 1 : 2);
  const result = JSON.stringify(journey);
  assert.equal(Journey.deliver(journey), false);
  assert.equal(JSON.stringify(journey), result, 'repeated delivery cannot duplicate rewards');
  return {job, rest, outcome: journey.outcome, hours: journey.hours, actions};
}

const records = ['parts', 'medicine'].flatMap(job => [false, true].map(rest => runDelivery(job, rest)));
// Rest must revive a non-porter without granting a second rest or extra MP.
const recovery = Journey.create();
Journey.accept(recovery, 'parts'); Journey.depart(recovery, 'medicine', 'convoy'); Journey.travel(recovery, 'short');
const fixture = Battle.create({ally: recovery.selected, enemy: ['scout']});
fixture.units.find(unit => unit.id === 'scout').hp = 0;
fixture.result = 'test fixture: battle resolved';
assert.ok(Journey.finishBattle(recovery, fixture));
assert.ok(Journey.rest(recovery));
assert.equal(recovery.party.find(unit => unit.id === 'scout').hp, 60);
assert.equal(Journey.rest(recovery), false);
console.log('Functional cycle passed: four real two-battle runs, legal policy actions, resource carryover, single-use transitions, rest/revival and on-time/late rewards.');
console.log(JSON.stringify(records));
