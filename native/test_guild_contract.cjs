'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let checks=0;function check(ok,label){assert.ok(ok,label);checks++;console.log('PASS '+label);}
const make=()=>{const s=C.create();s.characters.guard.inventory={potion:2};s.characters['guard-2'].inventory={ether:4};return s;};
const snap=s=>C.serialize(s);
for(const ids of [[],['porter','porter'],['porter','missing'],['porter','guard','archer','mage','scout','guard-2']]){
 const s=make(),before=snap(s);check(!C.select(s,ids)&&snap(s)===before,'invalid composition rejected '+JSON.stringify(ids));
}
let s=make(),characters=JSON.stringify(s.characters),gold=s.gold;
check(C.select(s,['guard-2','archer','mage','scout','porter']),'existing select atomically swaps full party');
check(s.selected[0]==='guard-2'&&s.selected.slice(1).join(',')==='archer,mage,scout,porter','selected order preserves swapped slot and all other members');
check(JSON.stringify(s.characters)===characters&&s.gold===gold,'membership changes preserve all character fields and gold');
check(C.inventoryTotals(s).potion===0&&C.inventoryTotals(s).ether===4,'reserve goods stay owned and do not pool with companions');
let q=C.inventoryQuote(s,'guard','potion','discard');
check(!q.ok&&!C.inventoryAction(s,'guard','potion','discard',null,1,null,q.token),'reserve inventory action remains denied');
check(C.select(s,['guard-2','mage','scout','porter'])&&C.select(s,['guard-2','mage','scout','porter','archer']),'remove and append reuse existing composition rule');
const loaded=C.deserialize(C.serialize(s));check(loaded.selected.join(',')===s.selected.join(',')&&JSON.stringify(loaded.characters)===characters,'save/load preserves order and every owner field');
check(C.depart(s,'east')&&s.journey.selected.join(',')===s.selected.join(','),'departure includes selected members only');
const before=snap(s);check(!C.select(s,['guard','porter'])&&snap(s)===before,'road composition changes remain forbidden');
check(C.travel(s,'safe',()=>.5)&&s.battle.units.filter(u=>u.side==='ally').map(u=>u.id).join(',')===s.selected.join(','),'battle allies include selected members only');
console.log(JSON.stringify({suite:'guild-existing-contract',passed:true,checks}));
