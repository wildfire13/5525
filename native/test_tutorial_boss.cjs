'use strict';
const assert = require('node:assert/strict');
const C = require('./campaign.js');
const B = require('./campaign-battle.js');

function secondLeg(solo) {
  const s = C.create({returningPlayer:false});
  for (const job of ['job_warrior', 'job_scout', 'job_mage']) {
    assert.equal(C.createPlayer(s, {job, skipTutorial:true}), false);
  }
  assert(C.createPlayer(s, {race:'human', sex:'female', job:'job_porter', name:'ナギ'}));
  const porter = s.playerProfile.memberId;
  assert.deepEqual(s.selected, [porter]);
  assert.deepEqual(C.view(s).battleSelected, [porter]);
  assert.equal(C.createPlayer(s, {job:'job_porter'}), false);
  if (!solo) assert(C.select(s, [porter, 'character_mirei', 'character_rio', 'character_merina', 'character_shion']));
  assert(C.tutorialAction(s, 'intro_done'));
  assert(C.accept(s, C.board(s).find(q => q.to === 'east').id, porter));
  assert(C.depart(s, 'east'));
  let seed = 1;
  const draw = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);
  assert(C.travel(s, 'safe', draw));
  assert.equal(s.battle.banditChiefId, undefined);
  assert(C.begin(s));
  if (solo) {
    for (const cell of [24, 26, 28, 29]) assert(C.act(s, 'action_move', cell));
    assert.equal(s.battle.resultKind, 'breakthrough');
  } else {
    playWithEscorts(s);
  }
  assert(C.finishBattle(s));
  assert(C.rest(s));
  assert(C.onward(s));
  return s;
}

function playWithEscorts(s) {
  const b = s.battle;
  for (let turn = 0; turn < 200 && !b.result; turn++) {
    const actor = b.units.find(u => u.id === b.actor);
    let {kind, target} = B.chooseAction(b, actor);
    if (actor.job === 'job_porter') {
      const cells = [...B.paths(b, actor, B.moveReach(actor)).keys()]
        .filter(p => p % 10 > actor.pos % 10 && B.legal(b, 'action_move', p));
      cells.sort((a, b) => b % 10 - a % 10);
      kind = cells.length ? 'action_move' : 'action_defend';
      target = cells[0] ?? null;
    } else if (b.banditChiefId && B.legal(b, 'action_attack', b.banditChiefId)) {
      kind = 'action_attack';
      target = b.banditChiefId;
    }
    assert(C.act(s, kind, target));
  }
  assert(b.result);
}

const returning = C.create({returningPlayer:true});
assert(C.createPlayer(returning, {race:'elf', sex:'male', job:'job_scout', skipTutorial:true}));
assert.deepEqual(C.deserialize(C.serialize(returning)).selected, [returning.playerProfile.memberId]);

const solo = secondLeg(true);
for (const route of ['safe', 'short']) {
  const s = C.deserialize(C.serialize(solo));
  assert(C.tutorialAction(s, 'skip'));
  assert(C.travel(s, route, () => 0));
  assert(C.deploy(s, s.playerProfile.memberId, 44));
  const loaded = C.deserialize(C.serialize(s));
  assert(C.begin(loaded));
  const b = loaded.battle;
  for (const cell of [46, 48, 49]) {
    if (b.result) break;
    assert(C.act(loaded, 'action_move', cell));
  }
  assert.equal(b.resultKind, 'defeat');
  assert(b.units.find(u => u.id === b.banditChiefId).hp > 0);
  if (route === 'safe') assert.equal(b.units[0].pos, 49);
  assert(C.finishBattle(loaded));
  assert.equal(loaded.result.outcome, 'failed');
  assert.equal(loaded.result.firstDeath, true);
  assert.equal(C.acknowledge(loaded), false);
  assert.equal(loaded.characters[loaded.playerProfile.memberId].hp, 0);
  assert(C.validate(loaded).ok, C.validate(loaded).error);
}

const party = secondLeg(false);
assert(C.travel(party, 'short', () => 0));
assert(C.deploy(party, party.playerProfile.memberId, 44));
assert(C.begin(party));
playWithEscorts(party);
assert.equal(party.battle.resultKind, 'breakthrough');
assert.equal(party.battle.units.find(u => u.id === party.battle.banditChiefId).hp, 0);
assert(party.battle.units.some(u => u.side === 'enemy' && u.hp > 0));
assert(C.finishBattle(C.deserialize(C.serialize(party))));
