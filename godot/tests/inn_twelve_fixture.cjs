'use strict';
// Test-only roster extension exercises the existing maximum party size without
// introducing a production character or changing the save schema.
const assert = require('node:assert/strict');
const B = require('../../native/campaign-battle.js');
B.roster.push({...B.roster[0],id:'inn-boundary-12',name:'宿屋境界試験'});
const C = require('../../native/campaign.js');
const s = C.create();
s.gold=500;
assert.equal(C.select(s,B.roster.map(u=>u.id)),true);
for(const uid of s.selected){s.characters[uid].hp=0;s.characters[uid].mp=0;}
const before=C.serialize(s);
assert.equal(C.inn(s),true);
assert.equal(s.gold,470);
const after=C.serialize(s);
const view=C.view(s);
assert.equal(view.roster.length,12);
assert.ok(view.roster.every(u=>u.hp===u.max&&u.mp===u.maxMp));
assert.equal(C.inn(s),false);
assert.equal(C.serialize(s),after);
assert.equal(C.serialize(C.deserialize(after)),after);
assert.notEqual(before,after);
console.log(JSON.stringify({passed:true,members:12,gold:s.gold,fullRecovery:view.roster.every(u=>u.hp===u.max&&u.mp===u.maxMp),repeatFree:true,reloaded:true,fixture:'synthetic test-only twelfth roster member'}));
