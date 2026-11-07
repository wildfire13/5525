#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js');
function setup(event='wheel',epoch=0){
  const s=C.create();s.worldTime=epoch;s.hours=epoch;s.standaloneEvents.epoch=epoch;
  s.location={wheel:'east',turnip:'north',kiln:'astaris'}[event];
  const q=C.board(s).find(q=>q.eventId===event),porter=C.view(s).roster.find(c=>s.selected.includes(c.id)&&c.job==='porter').id;
  assert(C.accept(s,q.id,porter));return s;
}
function at(s,age,place){s.worldTime=s.standaloneEvents.epoch+age;s.hours=s.worldTime;s.location=place;return s;}
let cases=0;
// All advertised boundaries at every relevant town, both fresh and migrated calendars.
for(const epoch of [0,42])for(const age of [0,9,10,11,17,18,19,23,24,25,35,36,37])for(const town of ['astaris','south','north']){
  const s=at(setup('wheel',epoch),age,town),before=JSON.stringify(s),m=C.recipientMeeting(s);
  const current=age<10?null:age<18?'astaris':age<=36?'south':null;
  assert.equal(m.currentStop,current);assert.equal(m.nextStop?.stop??null,age<10?'astaris':age<18?'south':null);
  assert.equal(m.canWait,town==='astaris'&&age<10||town==='south'&&age<18);
  assert.equal(m.handoffAvailable,current===town);assert.equal(m.finalBoundary,age===36);assert.equal(m.preferredBoundary,age===24);
  assert.equal(m.preferredMet,age<=24);assert.equal(m.finalOpen,age<=36);
  assert.equal(m.waitUntilWorldTime,m.canWait?epoch+(town==='astaris'?10:18):null);
  assert.equal(JSON.stringify(s),before,'meeting projection is pure');
  const qBefore=JSON.stringify(s.activeQuest),v=C.view(s);assert.equal(JSON.stringify(s.activeQuest),qBefore);
  assert.equal(v.scenarioStages.wheel,age<10?'in_transit':age<18?'astaris':age<=24?'south_full':age<=36?'south_late':'departed');
  const round=C.deserialize(C.serialize(s));assert.deepEqual(C.recipientMeeting(round),m);assert(!Object.hasOwn(round.activeQuest,'meeting'));
  cases++;
}
// Wait changes time, not health, inventory, rewards or contract. Snapshot rejects stale callbacks.
for(const [town,age,target] of [['astaris',9,10],['south',0,18],['south',9,18],['south',15,18],['south',17,18]]){
  const s=at(setup('wheel',42),age,town),m=C.recipientMeeting(s),chars=structuredClone(s.characters),gold=s.gold,rp=s.partyRP;
  const bad={...m.waitExpected,worldTime:m.worldTime-1},before=JSON.stringify(s);
  assert.equal(C.waitForEvent(s,bad),false);assert.equal(JSON.stringify(s),before);
  assert(C.waitForEvent(s,m.waitExpected));assert.equal(s.worldTime,42+target);assert.deepEqual(s.characters,chars);assert.equal(s.gold,gold);assert.equal(s.partyRP,rp);assert(s.activeQuest);
  const after=JSON.stringify(s);assert.equal(C.waitForEvent(s,m.waitExpected),false);assert.equal(JSON.stringify(s),after);
  assert.equal(C.recipientMeeting(s).handoffAvailable,true);assert.equal(C.validate(s).ok,true);
}
for(const phase of ['road','camp','battle','arrival','result']){
  const s=at(setup(),9,'astaris');s.phase=phase;const before=JSON.stringify(s);assert.equal(C.waitForEvent(s),false);assert.equal(JSON.stringify(s),before);
}
{
  const s=at(setup(),9,'astaris'),expected=C.recipientMeeting(s).waitExpected;s.location='south';assert.equal(C.waitForEvent(s,expected),false);
  s.location='astaris';s.activeQuest.token++;assert.equal(C.waitForEvent(s,expected),false);
}
// Cargo may be off party: waiting is still possible, delivery/forecast must not promise success.
{
  const s=at(setup(),9,'astaris');s.selected=s.selected.filter(id=>id!==s.activeQuest.cargoOwnerId);
  assert.equal(C.recipientMeeting(s).cargoAboard,false);assert(C.waitForEvent(s));assert.equal(C.recipientMeeting(s).reason,'cargo_missing');assert.equal(C.completeQuest(s),false);
  at(s,9,'east');assert(C.depart(s,'south'));const f=C.forecast(s,'short');assert.equal(f.afterWait.handoffAvailable,false);assert.equal(f.afterWait.reward,0);
}
// Read old calendarless v2 state without modifying source and retain the nonzero epoch.
{
  const old=C.create();old.hours=42;delete old.worldTime;delete old.standaloneEvents;const raw=JSON.stringify(old);
  const s=C.deserialize(JSON.stringify({format:'5525-native-campaign',version:2,cargoRevision:1,state:old}));assert.equal(JSON.stringify(old),raw);
  s.location='east';const offer=C.board(s).find(q=>q.eventId==='wheel');assert.equal(offer.meeting.reason,'not_accepted');assert.equal(C.waitForEvent(s),false);
  assert(C.accept(s,offer.id,C.view(s).roster.find(c=>s.selected.includes(c.id)&&c.job==='porter').id));
  at(s,15,'south');assert.equal(C.recipientMeeting(s).waitUntilWorldTime,60);assert(C.waitForEvent(s));assert.equal(s.worldTime,60);
}
// Forecast evaluates actual arrival, with an independent post-wait result and unchanged contract.
for(const epoch of [0,42])for(const [age,to,predicted,wait] of [[3,'astaris',9,1],[3,'south',9,9],[9,'south',15,3],[12,'astaris',18,0],[18,'south',24,0],[19,'south',25,0],[30,'south',36,0],[31,'south',37,0]]){
  const s=at(setup('wheel',epoch),age,'east');assert(C.depart(s,to));const before=JSON.stringify(s),f=C.forecast(s,'short');assert.equal(JSON.stringify(s),before);
  assert.equal(f.hours,predicted);assert.equal(f.arrivalLocation,to);assert.equal(f.waitHours,wait);assert.equal(!!f.afterWait,wait>0);
  if(wait){assert.equal(f.reward,0);assert.equal(f.afterWait.reward,220);assert.equal(f.afterWait.worldTime,epoch+predicted+wait);assert.equal(f.afterWait.handoffAvailable,true);}
  else assert.equal(f.handoffAvailable,to===(predicted<18?'astaris':predicted<=36?'south':null));
}
for(const event of ['turnip','kiln']){
  const s=setup(event),from=s.location,wrong=event==='turnip'?'east':'north';assert(C.depart(s,wrong));assert.equal(C.forecast(s,'short').handoffAvailable,false);assert.equal(C.forecast(s,'short').reward,0);
  // Synthetic camp state isolates return-destination forecasting from battle RNG.
  s.phase='camp';s.journey.stage=1;s.journey.route='short';const f=C.forecast(s,'turnBack');assert.equal(f.arrivalLocation,from);assert.equal(f.handoffAvailable,false);assert.equal(f.reward,0);
}
// A persisted contract keeps its own money/RP values; projections cannot migrate it.
{
  const s=setup();s.activeQuest.reward=222;s.activeQuest.lateReward=111;s.activeQuest.xp=99;
  at(s,3,'east');assert(C.depart(s,'south'));assert.equal(C.forecast(s,'short').afterWait.reward,222);
  s.phase='town';s.journey=null;at(s,25,'south');assert(C.completeQuest(s));assert.equal(s.result.gold,111);assert.equal(s.result.rp,60);
}
// Missing cargo and terminal/unaccepted status never enable a handoff or time skip.
{
  const s=at(setup(),15,'south');delete s.characters[s.activeQuest.cargoOwnerId].inventory[s.activeQuest.cargoItemId];
  assert(C.waitForEvent(s));assert.equal(C.recipientMeeting(s).reason,'cargo_missing');assert.equal(C.completeQuest(s),false);
  const idle=C.create();idle.location='east';idle.worldTime=25;idle.hours=25;C.view(idle);assert.equal(C.waitForEvent(idle),false);assert.equal(C.recipientMeeting(idle),null);
}
// Every reward contract remains intact, including revisionless EXP contracts and repeat/reload defense.
for(const revision of [undefined,1])for(const [age,gold,outcome] of [[24,220,'success'],[25,110,'late'],[36,110,'late'],[37,0,'failed']]){
  const s=at(setup(),age,'south');if(revision===undefined)delete s.activeQuest.rewardRevision;
  assert(C.completeQuest(s));assert.equal(s.result.gold,gold);assert.equal(s.result.outcome,outcome);
  assert.equal(s.result.xp,revision===undefined&&age<=36?(age===24?100:60):0);assert.equal(s.result.rp||0,revision===1&&age<=36?(age===24?100:60):0);
  const round=C.deserialize(C.serialize(s)),before=JSON.stringify(round);assert.equal(C.completeQuest(round),false);assert.equal(JSON.stringify(round),before);assert.equal(C.waitForEvent(round),false);
}
for(const [event,ages] of [['turnip',[17,18,19]],['kiln',[19,20,21]]])for(const age of ages){
  const s=setup(event);at(s,age,s.activeQuest.to);assert(C.completeQuest(s));assert.equal(s.result.outcome,age<=({turnip:18,kiln:20}[event])?'success':'failed');
}
console.log(`NPC meeting regressions: ${cases} boundary/epoch/location cases plus wait, forecast, save and reward groups passed`);
