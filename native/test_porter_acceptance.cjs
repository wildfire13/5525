'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js');
const J=require('./journey.js');
function acceptWithPorter(s,id){return C.accept(s,id,s.selected.find(uid=>C.view(s).roster.find(u=>u.id===uid)?.job==='porter'));}
let checks=0;const check=(ok,label)=>{assert.ok(ok,label);checks++;console.log('PASS '+label);};
const roundtrip=s=>{let loaded;assert.doesNotThrow(()=>{loaded=C.deserialize(C.serialize(s));},'valid party and cargo must save/reload');assert.deepEqual(loaded,JSON.parse(JSON.stringify(s)));return loaded;};
// Current behavior is tested independently of the historical source hashes.
let journey=J.create();journey.selected=['guard'];
let unchanged=JSON.stringify(journey);
check(!J.accept(journey,'parts')&&JSON.stringify(journey)===unchanged,'legacy zero porter acceptance rejected without mutation');
for(const porter of ['porter','porter-2']){
 for(const kit of ['medicine','ether'])for(const formation of ['convoy','flank']){
  journey=J.create();journey.selected=['guard',porter];
  check(J.accept(journey,'parts')&&journey.phase==='prepare','legacy either porter permits acceptance without departure');
  check(J.select(journey,['guard']),'legacy accepted quest permits removing last porter');
  check(J.depart(journey,kit,formation)&&journey.phase==='road','legacy zero porter departure with valid kit and formation');
 }
}
journey=J.create();check(J.accept(journey,'parts'),'legacy acceptance fixture');
for(const ids of [['guard','guard'],['missing']]){
 unchanged=JSON.stringify(journey);
 check(!J.select(journey,ids)&&JSON.stringify(journey)===unchanged,'legacy duplicate unknown and oversized compositions rejected');
}
J.select(journey,[]);unchanged=JSON.stringify(journey);
check(!J.depart(journey,'medicine','convoy')&&JSON.stringify(journey)===unchanged,'legacy empty party cannot depart');
J.select(journey,['guard']);
for(const args of [['missing','convoy'],['medicine','missing']]){
 unchanged=JSON.stringify(journey);
 check(!J.depart(journey,...args)&&JSON.stringify(journey)===unchanged,'legacy invalid departure option rejected without mutation');
}
let s=require('./test-current-fixture.cjs')();
check(s.selected.join(',')==='guard,archer,mage,scout,porter','initial cast unchanged');
const people=JSON.stringify(s.characters),gold=s.gold;
check(C.select(s,['guard','archer','mage','scout']),'remove last porter while other members remain');
check(JSON.stringify(s.characters)===people&&s.gold===gold,'composition preserves personal records and gold');
check(roundtrip(s).selected.length===4,'zero porter save roundtrip');
let before=C.serialize(s);
check(!acceptWithPorter(s,C.board(s)[0].id)&&C.serialize(s)===before,'zero porter acceptance rejected without mutation');
check(C.depart(s,'east'),'zero porter free departure');
check(roundtrip(s).journey.selected.length===4,'zero porter journey and rollback save roundtrip');
check(!C.select(s,['guard']),'road composition remains forbidden');
s=require('./test-current-fixture.cjs')();
check(C.select(s,['guard','porter','porter-2']),'two porter composition');
check(C.select(s,['guard','porter-2']),'two to one porter');
check(C.select(s,['guard','porter']),'porter to porter exchange');
check(C.select(s,['guard','archer']),'porter to other job exchange');
check(C.select(s,['guard']),'one member zero porter allowed');
for(const ids of [[],['guard','guard'],['missing']]){
 before=C.serialize(s);check(!C.select(s,ids)&&C.serialize(s)===before,'composition limits preserved '+JSON.stringify(ids));
}
check(C.select(s,['guard','porter-2'])&&acceptWithPorter(s,C.board(s)[0].id),'one porter acceptance succeeds');
check(s.phase==='town'&&!s.journey,'acceptance remains separate from departure');
check(C.select(s,['guard']),'accepted quest permits removing last porter at guild');
const quest={...s.activeQuest},owner=quest.cargoOwnerId;
check(s.characters[owner].inventory[quest.cargoItemId]===1&&!C.view(s).cargoAboard,'reserve porter retains cargo without locking composition');
const loaded=roundtrip(s);
check(loaded.activeQuest.cargoOwnerId===owner&&loaded.characters[owner].inventory[quest.cargoItemId]===1,'accepted quest zero porter save retains cargo and owner');
check(C.depart(s,s.activeQuest.to),'accepted quest departure does not extend acceptance rule');
roundtrip(s);
s=require('./test-current-fixture.cjs')();s.characters.porter.hp=0;
check(!C.depart(s,'east'),'dead porter departure restriction preserved');
console.log(JSON.stringify({suite:'porter-acceptance',passed:true,checks}));
