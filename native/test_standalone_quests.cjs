#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js');
function setup(event,location){
  const s=C.create();s.location=location;
  const q=C.board(s).find(q=>q.eventId===event);assert(q,`${event} offer present at ${location}`);
  const porter=s.selected.find(id=>C.view(s).roster.find(c=>c.id===id).job==='porter');
  assert(C.accept(s,q.id,porter));assert.equal(C.validate(s).ok,true,C.validate(s).error);return s;
}
function stateAt(s,worldTime,location){s.worldTime=worldTime;s.hours=worldTime;s.location=location;}

// Trial calendar: new games post at hour 0; older saves are seeded at load time.
{
  const s=C.create();assert.equal(s.worldTime,0);assert.equal(C.board(s).filter(q=>q.scenario).map(q=>q.eventId).join(','),'kiln');
  s.location='north';assert.equal(C.board(s).find(q=>q.eventId==='turnip').deadline,18);
  s.location='east';assert.equal(C.board(s).find(q=>q.eventId==='wheel').weight,6);
  s.location='north';s.worldTime=19;s.hours=19;assert(!C.board(s).some(q=>q.eventId==='turnip'));
  assert.equal(C.view(s).scenarioAftermath[0].id,'turnip-aftermath');
}
// On-time turnip delivery succeeds independently of the later second-place result.
{
  const s=setup('turnip','north');assert.equal(s.activeQuest.weight,8);stateAt(s,18,'astaris');
  assert(C.completeQuest(s));assert.equal(s.result.outcome,'success');assert.equal(s.result.gold,240);assert(s.result.story.some(line=>line[0]==='weigher'));
  assert.equal(C.validate(s).ok,true,C.validate(s).error);assert.equal(C.view(s).scenarioStages.turnip,'second');
  assert(!C.board(s).some(q=>q.eventId==='turnip'));assert(C.serialize(s));
}
// A late turnip failure restores the pre-accept cargo/gold/party snapshot once.
{
  const s=setup('turnip','north'),gold=s.gold;stateAt(s,19,'astaris');assert(C.completeQuest(s));
  assert.equal(s.result.outcome,'failed');assert.equal(s.gold,gold);assert.equal(s.location,'north');assert.equal(s.standaloneEvents.events.turnip.status,'failed');assert.equal(C.validate(s).ok,true,C.validate(s).error);
}
// Kiln delivery pays once; world schedule continues through closing, firing, cooling and return.
{
  const s=setup('kiln','astaris');assert.equal(s.activeQuest.weight,2);stateAt(s,6,'east');assert(C.completeQuest(s));assert.equal(s.result.gold,150);
  assert(s.result.story.some(line=>line[0]==='master'));stateAt(s,22,'east');assert.equal(C.view(s).scenarioStages.kiln,'cooling');
  stateAt(s,23,'east');assert.equal(C.view(s).scenarioAftermath[0].id,'kiln-return');assert.equal(C.validate(s).ok,true,C.validate(s).error);
}
// Existing map supports East→North/Astaris/South and the stop schedule leaves feasible travel.
{
  const s=setup('wheel','east');assert.equal(s.activeQuest.weight,6);assert.equal(s.activeQuest.to,'astaris');
  stateAt(s,8,'north');s.activeQuest.to='astaris';assert(C.waitForEvent(s));assert.equal(s.worldTime,10);assert.equal(s.activeQuest.to,'astaris');
  stateAt(s,10,'astaris');assert(C.completeQuest(s));assert.equal(s.result.gold,220);assert.equal(s.result.outcome,'success');assert(s.result.story.some(line=>line[0]==='merchant'));
  const late=setup('wheel','east');stateAt(late,25,'south');late.activeQuest.to='south';assert(C.completeQuest(late));assert.equal(late.result.gold,110);assert.equal(late.result.outcome,'late');
  const missed=setup('wheel','east'),originalGold=missed.gold;stateAt(missed,37,'south');missed.activeQuest.to='south';assert(C.completeQuest(missed));assert.equal(missed.result.outcome,'failed');assert.equal(missed.gold,originalGold);assert.equal(missed.location,'east');
}
// A pre-feature v2 save is read without mutation and gets a fresh calendar at its saved time.
{
  const old=C.create();old.hours=42;delete old.worldTime;delete old.standaloneEvents;
  const loaded=C.deserialize(JSON.stringify({format:'5525-native-campaign',version:C.VERSION,cargoRevision:1,state:old}));
  assert.equal(loaded.worldTime,42);assert.equal(loaded.standaloneEvents.epoch,42);assert.equal(C.validate(loaded).ok,true,C.validate(loaded).error);
}
console.log('standalone quest regressions: 6 groups passed');
