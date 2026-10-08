'use strict';
// Synthetic validated saves; no personal files and no writes.
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js');
const assert=require('node:assert/strict');
const s=C.create();
assert(C.depart(s,'north'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
const b=s.battle,g=b.units.find(u=>u.id==='guard'),e=b.units.find(u=>u.side==='enemy');
for(const u of b.units){u.next=1000000;if(u.side==='enemy')u.hp=0;}
g.next=1;b.actor=g.id;g.pos=24;e.pos=25;e.hp=1;
assert(C.validate(s).ok,C.validate(s).error);
const start=JSON.parse(C.serialize(s));
assert(C.act(s,'attack',e.id));assert(s.battle.result);
assert(C.validate(s).ok,C.validate(s).error);
const output=JSON.stringify({start,finished:JSON.parse(C.serialize(s)),enemy:e.id});
console.log(output.replace(/[^\x00-\x7F]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0')));
