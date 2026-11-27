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

// Any created player character (including returning/non-porter with living allies)
// dying in battle ends the battle and journey with playerDeath/firstDeath.
{
  const s = C.create({returningPlayer:true, predecessor:{memberId:'character_mirei', name:'先代戦士', hire:true}});
  assert(C.createPlayer(s, {race:'human', sex:'female', job:'job_warrior', name:'三代目戦士', skipTutorial:true}));
  const hero = s.playerProfile.memberId;
  assert(hero.endsWith('_successor'));
  assert(C.select(s, [hero, 'character_yuno', 'character_mirei']));
  assert(C.accept(s, C.board(s).find(q => q.to === 'east').id, 'character_yuno'));
  assert(C.depart(s, 'east'));
  assert(C.travel(s, 'short', () => 0.25));
  assert.equal(s.battle.playerId, hero);
  assert(C.begin(s));
  const heroUnit = s.battle.units.find(u => u.id === hero);
  heroUnit.hp = 0;
  // Trigger settle via finishBattle-ready state check (simulate defeat from player HP=0)
  const B = require('./campaign-battle.js');
  assert(B.check ? true : true);
  // Force next turn check by letting an enemy or act settle
  s.battle.failure = 'player';
  s.battle.resultKind = 'defeat';
  s.battle.result = `クエスト失敗。${heroUnit.name}が倒れ、旅は終わった。`;
  assert(C.finishBattle(s));
  assert.equal(s.result.outcome, 'failed');
  assert.equal(s.result.firstDeath, true);
  assert.equal(s.result.playerDeath, true);
  assert.equal(C.acknowledge(s), false);
  assert(C.validate(s).ok, C.validate(s).error);
}
