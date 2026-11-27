'use strict';
const assert = require('node:assert/strict');
const C = require('./campaign.js');
for (const hire of [true, false]) {
  for (const job of ['job_porter', 'job_scout']) {
    const predecessor = {memberId:'character_yuno', name:'初代', hire};
    let s = C.create({returningPlayer:true, predecessor});
    assert(C.createPlayer(s, {race:'human', sex:'female', job, name:'二代目'}));
    s = C.deserialize(C.serialize(s));
    const hero = s.playerProfile.memberId;
    assert.deepEqual(s.selected, [hero]);
    const former = C.view(s).roster.filter(u => u.name === '初代');
    assert.equal(former.length, hire ? 1 : 0);
    if (hire) {
      assert.notEqual(hero, former[0].id);
      assert(C.select(s, [hero, former[0].id]));
      assert.deepEqual(C.deserialize(C.serialize(s)).selected, [hero, former[0].id]);
    } else if (hero !== predecessor.memberId) {
      assert(!C.select(s, [hero, predecessor.memberId]));
    }
  }
}

// An injured warrior can be carried home by the surviving porter.
const porter = 'character_yuno';
const s = C.create({returningPlayer:true});
assert(C.createPlayer(s, {race:'human', sex:'female', job:'job_warrior', skipTutorial:true}));
const hero = s.playerProfile.memberId;
assert(C.select(s, [hero, porter]));
s.characters[hero].hp = 1;
assert(C.accept(s, C.board(s).find(q => q.to === 'east').id, porter));
assert(C.depart(s, 'east'));
assert(C.travel(s, 'short', () => 0.5));
assert(C.deploy(s, hero, 34));
assert(C.deploy(s, porter, 44));
assert(C.begin(s));
const unit = s.battle.units.find(u => u.id === hero);
for(let turn = 0; unit.hp > 0 && turn < 30; turn++)assert(C.act(s, 'action_defend'));
assert.equal(unit.hp, 0);
assert.equal(C.view(s).playerDeath, false);
assert.equal(C.deserialize(C.serialize(s)).battle.actor, porter);
for(const cell of [46,48,49])assert(C.act(s, 'action_move', cell));
assert(C.finishBattle(s));
assert(C.rest(s));
assert(C.turnBack(s, () => 0.25));
assert(C.deploy(s, porter, 44));
assert(C.begin(s));
for(const cell of [46,48,49])assert(C.act(s, 'action_move', cell));
assert(C.finishBattle(s));
assert(C.arrive(s));
assert.equal(s.location, 'astaris');
assert.equal(s.characters[hero].hp, 0);
assert(C.inn(s));
assert.equal(s.characters[hero].hp, C.stats(s.characters[hero]).max);
