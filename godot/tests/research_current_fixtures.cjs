'use strict';
const C = require('../../native/campaign.js');
const assert = require('node:assert/strict');
const s = C.create();
const owner = 'recruit-guard-human-female';
s.characters[owner].lowerBody = 'kungfu-pants';
assert(C.depart(s, 'east'));
assert(C.travel(s, 'short', () => 0));
assert(C.begin(s));
const b = s.battle, actor = b.units.find(u => u.id === owner);
const positions = [22, 12, 13, 4, 32];
b.units.filter(u => u.side === 'ally').forEach((u, i) => {
  u.pos = positions[i]; u.next = 100;
});
b.units.filter(u => u.side === 'enemy').forEach((u, i) => {
  u.pos = [25, 15, 35][i]; u.next = 2 + i;
});
actor.pos = 24;
actor.next = 1;
actor.selectedSkill = 'legSweep';
b.actor = owner;
assert(C.validate(s).ok, C.validate(s).error);
console.log(JSON.stringify({sweep50: JSON.parse(C.serialize(s))}).replace(/[^\x00-\x7f]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')));
