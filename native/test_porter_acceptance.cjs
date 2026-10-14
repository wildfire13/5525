'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
function acceptWithPorter(s,id){return C.accept(s,id,s.selected.find(uid=>C.view(s).roster.find(u=>u.id===uid)?.job==='porter'));}
let checks=0;const check=(ok,label)=>{assert.ok(ok,label);checks++;console.log('PASS '+label);};
const roundtrip=s=>{const loaded=C.deserialize(C.serialize(s));assert.deepEqual(loaded,JSON.parse(JSON.stringify(s)));return loaded;};
let s=C.create();
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
s=C.create();
check(C.select(s,['guard','porter','porter-2']),'two porter composition');
check(C.select(s,['guard','porter-2']),'two to one porter');
check(C.select(s,['guard','porter']),'porter to porter exchange');
check(C.select(s,['guard','archer']),'porter to other job exchange');
check(C.select(s,['guard']),'one member zero porter allowed');
for(const ids of [[],['guard','guard'],['missing'],['guard','archer','mage','scout','porter','porter-2']]){
 before=C.serialize(s);check(!C.select(s,ids)&&C.serialize(s)===before,'composition limits preserved '+JSON.stringify(ids));
}
check(C.select(s,['guard','porter-2'])&&acceptWithPorter(s,C.board(s)[0].id),'one porter acceptance succeeds');
check(s.phase==='town'&&!s.journey,'acceptance remains separate from departure');
check(C.select(s,['guard']),'accepted quest permits removing last porter at guild');
check(roundtrip(s).activeQuest!==null,'accepted quest zero porter save roundtrip');
check(C.depart(s,s.activeQuest.to),'accepted quest departure does not extend acceptance rule');
roundtrip(s);
s=C.create();s.characters.porter.hp=0;
check(!C.depart(s,'east'),'dead porter departure restriction preserved');
console.log(JSON.stringify({suite:'porter-acceptance',passed:true,checks}));
