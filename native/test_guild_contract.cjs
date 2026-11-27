'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let checks=0;function check(ok,label){assert.ok(ok,label);checks++;console.log('PASS '+label);}
const make=()=>{const s=require('./test-current-fixture.cjs')();s.characters["character_mirei"].inventory={potion:2};s.characters["character_sera"].inventory={ether:4};return s;};
const snap=s=>C.serialize(s);
for(const ids of [['character_yuno','character_yuno'],['character_yuno','missing']]){
 const s=make(),before=snap(s);check(!C.select(s,ids)&&snap(s)===before,'invalid composition rejected '+JSON.stringify(ids));
}
let s=make(),characters=JSON.stringify(s.characters),gold=s.gold;
check(C.select(s,["character_sera","character_kyle","character_merina","character_rio","character_yuno"]),'existing select atomically swaps full party');
assert.deepEqual(s.selected,['character_sera','character_kyle','character_merina','character_rio','character_yuno']);
check(true,'selected order preserves swapped slot and all other members');
check(JSON.stringify(s.characters)===characters&&s.gold===gold-4,'membership preserves personal records and prepays two new hires');
check(C.inventoryTotals(s).potion===0&&C.inventoryTotals(s).ether===4,'reserve goods stay owned and do not pool with companions');
let q=C.inventoryQuote(s,"character_mirei",'potion','discard');
check(!q.ok&&!C.inventoryAction(s,"character_mirei",'potion','discard',null,1,null,q.token),'reserve inventory action remains denied');
check(C.select(s,["character_sera","character_merina","character_rio","character_yuno"])&&C.select(s,["character_sera","character_merina","character_rio","character_yuno","character_kyle"]),'remove and append reuse existing composition rule');
const loaded=C.deserialize(C.serialize(s));check(loaded.selected.join(',')===s.selected.join(',')&&JSON.stringify(loaded.characters)===characters,'save/load preserves order and every owner field');
check(C.depart(s,'east')&&s.journey.selected.join(',')===s.selected.join(','),'departure includes selected members only');
const before=snap(s);check(!C.select(s,["character_mirei","character_yuno"])&&snap(s)===before,'road composition changes remain forbidden');
check(C.travel(s,'safe',()=>.5)&&s.battle.units.filter(u=>u.side==='ally').map(u=>u.id).join(',')===s.selected.join(','),'battle allies include selected members only');
console.log(JSON.stringify({suite:'guild-existing-contract',passed:true,checks}));
