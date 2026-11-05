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
// The wheel quest tracks its current scheduled stop in both directions and text.
{
  const s=setup('wheel','east');assert.equal(s.activeQuest.weight,6);assert.equal(s.activeQuest.to,'astaris');
  stateAt(s,8,'north');assert.equal(C.waitForEvent(s),false);
  stateAt(s,8,'astaris');assert(C.waitForEvent(s));assert.equal(s.worldTime,10);assert.equal(s.activeQuest.to,'astaris');
  assert.equal(C.view(s).activeQuest.text,'替えの車輪をアスタリスまで届けてください。');assert.equal(C.view(s).activeQuest.merchantAtStop,true);
  stateAt(s,10,'astaris');assert(C.completeQuest(s));assert.equal(s.result.gold,220);assert.equal(s.result.outcome,'success');assert(s.result.story.some(line=>line[0]==='merchant'));
  for(const [age,place,gold,outcome] of [[17,'astaris',220,'success'],[18,'south',220,'success'],[24,'south',220,'success'],[25,'south',110,'late'],[35,'south',110,'late'],[36,'south',110,'late'],[37,'south',0,'failed']]){
    const q=setup('wheel','east'),before=q.gold;stateAt(q,age,place);
    const displayed=C.view(q).activeQuest;
    assert.equal(displayed.to,place,`destination at +${age}h`);
    if(age<=36)assert.equal(displayed.text,`替えの車輪を${place==='astaris'?'アスタリス':'サウス'}まで届けてください。`,`text at +${age}h`);
    else assert.match(displayed.text,/出発しました/);
    const encoded=C.serialize(q),reloaded=C.deserialize(encoded);assert.equal(C.view(reloaded).activeQuest.to,place,`saved destination at +${age}h`);
    assert(C.completeQuest(q),`complete at +${age}h`);assert.equal(q.result.gold,gold);assert.equal(q.result.outcome,outcome);
    if(age===37){assert.equal(q.gold,before);assert.equal(q.location,'east');assert.equal(q.result.restored,true);}
    else {assert.equal(q.gold,before+gold);assert.equal(C.completeQuest(q),false);}
  }
  const missed=setup('wheel','east');stateAt(missed,9,'astaris');assert.equal(C.completeQuest(missed),false);
}
// Forecasts use the published world-clock deadlines and each standalone reward schedule.
{
  for(const [event,at,reward] of [['wheel',22,110],['turnip',16,0],['kiln',18,0]]){
    const from=event==='turnip'?'north':event==='kiln'?'astaris':'east',to=event==='turnip'?'astaris':event==='kiln'?'east':'south';
    const s=setup(event,from);stateAt(s,at,from);assert(C.depart(s,to));const f=C.forecast(s,'short');
    assert(f.scenario&&f.late,`${event} forecast detects posted-time lateness`);assert.equal(f.reward,reward);
    assert.equal(f.hours,at+6);assert.equal(f.over,f.hours-s.activeQuest.deadline);assert.equal(f.remaining,0);
  }
  const beforeArrival=setup('wheel','east');stateAt(beforeArrival,3,'east');assert(C.depart(beforeArrival,'astaris'));const beforeForecast=C.forecast(beforeArrival,'short');assert.equal(beforeForecast.hours,9);assert.equal(beforeForecast.handoffPhase,'before_arrival');assert.equal(beforeForecast.handoffStop,null);
  const departed=setup('wheel','east');stateAt(departed,31,'east');assert(C.depart(departed,'south'));const departedForecast=C.forecast(departed,'short');assert.equal(departedForecast.hours,37);assert.equal(departedForecast.handoffPhase,'departed');assert.equal(departedForecast.handoffStop,null);
  const wrong=setup('wheel','east');stateAt(wrong,16,'east');assert(C.depart(wrong,'astaris'));const unavailable=C.forecast(wrong,'short');
  assert.equal(unavailable.hours,22);assert.equal(unavailable.handoffStop,'south');assert.equal(unavailable.arrivalLocation,'astaris');assert.equal(unavailable.handoffAvailable,false);assert.equal(unavailable.reward,0);
  stateAt(wrong,22,'astaris');wrong.phase='town';wrong.journey=null;wrong.battle=null;assert.equal(C.completeQuest(wrong),false,'merchant cannot be received at the other town');
  const moving=setup('wheel','east');stateAt(moving,16,'east');assert(C.depart(moving,'south'));assert.equal(C.forecast(moving,'short').handoffAvailable,true);
  assert(C.travel(moving,'short',()=>.5));assert.equal(moving.worldTime,18);assert.equal(moving.activeQuest.to,'south');assert.equal(moving.activeQuest.text,'替えの車輪をサウスまで届けてください。');
  const s=C.create();s.location='north';const offer=C.board(s).find(q=>!q.scenario&&q.to==='astaris');assert(offer);assert(C.accept(s,offer.id,s.selected.find(id=>C.view(s).roster.find(c=>c.id===id).job==='porter')));assert(C.depart(s,'astaris'));const normal=C.forecast(s,'safe');assert.equal(normal.reward,117);assert.equal(normal.scenario,undefined);
}
// A pre-feature v2 save is read without mutation and gets a fresh calendar at its saved time.
{
  const old=C.create();old.hours=42;delete old.worldTime;delete old.standaloneEvents;const untouchedOld=JSON.stringify(old);
  const loaded=C.deserialize(JSON.stringify({format:'5525-native-campaign',version:C.VERSION,cargoRevision:1,state:old}));
  assert.equal(JSON.stringify(old),untouchedOld,'migration does not mutate the supplied old-save object');
  assert.equal(loaded.worldTime,42);assert.equal(loaded.standaloneEvents.epoch,42);assert.equal(C.validate(loaded).ok,true,C.validate(loaded).error);
  loaded.location='east';const offer=C.board(loaded).find(q=>q.eventId==='wheel');assert(offer);const porter=loaded.selected.find(id=>C.view(loaded).roster.find(c=>c.id===id).job==='porter');assert(C.accept(loaded,offer.id,porter));
  loaded.worldTime=64;loaded.hours=64;const storedQuest=JSON.stringify(loaded.activeQuest),dynamic=C.view(loaded).activeQuest;assert.equal(dynamic.to,'south');assert(dynamic.text.includes('サウス'));assert.equal(JSON.stringify(loaded.activeQuest),storedQuest,'derived presentation does not rewrite stored active quest');
  const round=C.deserialize(C.serialize(loaded));assert.equal(round.standaloneEvents.epoch,42);assert.equal(C.view(round).activeQuest.to,'south');assert(C.view(round).activeQuest.text.includes('サウス'));
}
console.log('standalone quest regressions: 8 groups passed');
