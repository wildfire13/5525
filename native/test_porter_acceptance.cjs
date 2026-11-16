'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
function acceptWithPorter(s,id){return C.accept(s,id,s.selected.find(uid=>C.view(s).roster.find(u=>u.id===uid)?.job==='job_porter'));}
let checks=0;const check=(ok,label)=>{assert.ok(ok,label);checks++;console.log('PASS '+label);};
const roundtrip=s=>{let loaded;assert.doesNotThrow(()=>{loaded=C.deserialize(C.serialize(s));},'valid party and cargo must save/reload');assert.deepEqual(loaded,JSON.parse(JSON.stringify(s)));return loaded;};
// Retired eleven-person Journey acceptance checks are replaced by campaign rules.
let s=require('./test-current-fixture.cjs')();
assert.deepEqual(s.selected,C.create().selected);check(s.selected.length===5,'actual current initial party');
const people=JSON.stringify(s.characters),gold=s.gold;
check(C.select(s,["character_mirei","character_kyle","character_merina","character_rio"]),'remove last porter while other members remain');
check(JSON.stringify(s.characters)===people&&s.gold===gold,'composition preserves personal records and gold');
check(roundtrip(s).selected.length===4,'zero porter save roundtrip');
let before=C.serialize(s);
check(!acceptWithPorter(s,C.board(s)[0].id)&&C.serialize(s)===before,'zero porter acceptance rejected without mutation');
check(C.depart(s,'east'),'zero porter free departure');
check(roundtrip(s).journey.selected.length===4,'zero porter journey and rollback save roundtrip');
check(!C.select(s,["character_mirei"]),'road composition remains forbidden');
s=require('./test-current-fixture.cjs')();
check(C.select(s,["character_mirei","character_yuno","character_teo"]),'two porter composition');
check(C.select(s,["character_mirei","character_teo"]),'two to one porter');
check(C.select(s,["character_mirei","character_yuno"]),'porter to porter exchange');
check(C.select(s,["character_mirei","character_kyle"]),'porter to other job exchange');
check(C.select(s,["character_mirei"]),'one member zero porter allowed');
for(const ids of [['character_mirei','character_mirei'],['missing']]){
 before=C.serialize(s);check(!C.select(s,ids)&&C.serialize(s)===before,'composition limits preserved '+JSON.stringify(ids));
}
check(C.select(s,["character_mirei","character_teo"])&&acceptWithPorter(s,C.board(s)[0].id),'one porter acceptance succeeds');
check(s.phase==='town'&&!s.journey,'acceptance remains separate from departure');
check(C.select(s,["character_mirei"]),'accepted quest permits removing last porter at guild');
const quest={...s.activeQuest},owner=quest.cargoOwnerId;
check(s.characters[owner].inventory[quest.cargoItemId]===1&&!C.view(s).cargoAboard,'reserve porter retains cargo without locking composition');
const loaded=roundtrip(s);
check(loaded.activeQuest.cargoOwnerId===owner&&loaded.characters[owner].inventory[quest.cargoItemId]===1,'accepted quest zero porter save retains cargo and owner');
check(C.depart(s,s.activeQuest.to),'accepted quest departure does not extend acceptance rule');
roundtrip(s);
s=require('./test-current-fixture.cjs')();s.characters["character_yuno"].hp=0;
check(!C.depart(s,'east'),'dead porter departure restriction preserved');
console.log(JSON.stringify({suite:'porter-acceptance',passed:true,checks}));
