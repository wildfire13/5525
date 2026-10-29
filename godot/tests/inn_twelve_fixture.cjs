'use strict';
// Current production candidates exercise the unchanged maximum party size.
const assert = require('node:assert/strict');
const C = require('../../native/campaign.js');
const s = C.create();
s.gold=500;
assert.equal(C.select(s,C.view(s).roster.slice(0,12).map(u=>u.id)),true);
for(const uid of s.selected){s.characters[uid].hp=0;s.characters[uid].mp=0;}
const before=C.serialize(s);
assert.equal(C.inn(s),true);
assert.equal(s.gold,470);
const after=C.serialize(s);
const view=C.view(s);view.roster=view.roster.filter(u=>s.selected.includes(u.id));
assert.equal(view.roster.length,12);
assert.ok(view.roster.every(u=>u.hp===u.max&&u.mp===u.maxMp));
assert.equal(C.inn(s),false);
assert.equal(C.serialize(s),after);
assert.equal(C.serialize(C.deserialize(after)),after);
assert.notEqual(before,after);
console.log(JSON.stringify({passed:true,members:12,gold:s.gold,fullRecovery:view.roster.every(u=>u.hp===u.max&&u.mp===u.maxMp),repeatFree:true,reloaded:true,fixture:'twelve selected production candidates'}));
