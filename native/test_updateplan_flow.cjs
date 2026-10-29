'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
// Current production start, legal commands only. Deterministic route draw and
// an engine-policy bot are not an OS/manual playthrough.
let s=C.create(),actions=0;
const porter=s.selected.find(id=>C.view(s).roster.find(c=>c.id===id).job==='porter');
assert(C.accept(s,C.board(s).find(q=>q.to==='east').id,porter));assert(C.depart(s,'east'));
for(let leg=0;leg<2;leg++){
 assert(C.travel(s,'safe',()=>.2));assert(C.begin(s));
 while(!s.battle.result&&actions<400){
  const copy=structuredClone(s.battle),actor=copy.units.find(u=>u.id===copy.actor);B.plan(copy,actor);
  const {kind,target}=actor.intent;assert(C.act(s,kind,target));actions++;
  assert(C.validate(s).ok,C.validate(s).error);const serialized=C.serialize(s);s=C.deserialize(serialized);assert.equal(C.serialize(s),serialized);
 }
 assert(s.battle.result);assert(!s.battle.failure);assert(C.finishBattle(s));
 if(s.phase==='camp'){assert(C.rest(s));assert(C.onward(s));}
}
assert.equal(s.phase,'arrival');assert(C.arrive(s));assert(C.completeQuest(s));assert.equal(s.completed,1);assert.equal(s.activeQuest,null);
assert(C.validate(s).ok);assert.deepEqual(C.deserialize(C.serialize(s)),s);
console.log(`PASS new-roster quest/two victories/delivery, ${actions} actions with exact save/load each action`);
