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
