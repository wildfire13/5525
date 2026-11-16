'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let checks=0;function check(ok,label){assert.ok(ok,label);checks++;console.log('PASS '+label);}
const make=()=>{const s=require('./test-current-fixture.cjs')();s.characters["recruit-guard-human-female"].inventory={potion:2};s.characters["recruit-guard-elf-female"].inventory={ether:4};return s;};
const snap=s=>C.serialize(s);
for(const ids of [['recruit-porter-human-female','recruit-porter-human-female'],['recruit-porter-human-female','missing']]){
 const s=make(),before=snap(s);check(!C.select(s,ids)&&snap(s)===before,'invalid composition rejected '+JSON.stringify(ids));
}
let s=make(),characters=JSON.stringify(s.characters),gold=s.gold;
check(C.select(s,["recruit-guard-elf-female","recruit-scout-human-male","recruit-mage-elf-female","recruit-scout-human-female","recruit-porter-human-female"]),'existing select atomically swaps full party');
assert.deepEqual(s.selected,['recruit-guard-elf-female','recruit-scout-human-male','recruit-mage-elf-female','recruit-scout-human-female','recruit-porter-human-female']);
check(true,'selected order preserves swapped slot and all other members');
check(JSON.stringify(s.characters)===characters&&s.gold===gold,'membership changes preserve all character fields and gold');
check(C.inventoryTotals(s).potion===0&&C.inventoryTotals(s).ether===4,'reserve goods stay owned and do not pool with companions');
let q=C.inventoryQuote(s,"recruit-guard-human-female",'potion','discard');
check(!q.ok&&!C.inventoryAction(s,"recruit-guard-human-female",'potion','discard',null,1,null,q.token),'reserve inventory action remains denied');
check(C.select(s,["recruit-guard-elf-female","recruit-mage-elf-female","recruit-scout-human-female","recruit-porter-human-female"])&&C.select(s,["recruit-guard-elf-female","recruit-mage-elf-female","recruit-scout-human-female","recruit-porter-human-female","recruit-scout-human-male"]),'remove and append reuse existing composition rule');
const loaded=C.deserialize(C.serialize(s));check(loaded.selected.join(',')===s.selected.join(',')&&JSON.stringify(loaded.characters)===characters,'save/load preserves order and every owner field');
check(C.depart(s,'east')&&s.journey.selected.join(',')===s.selected.join(','),'departure includes selected members only');
const before=snap(s);check(!C.select(s,["recruit-guard-human-female","recruit-porter-human-female"])&&snap(s)===before,'road composition changes remain forbidden');
check(C.travel(s,'safe',()=>.5)&&s.battle.units.filter(u=>u.side==='ally').map(u=>u.id).join(',')===s.selected.join(','),'battle allies include selected members only');
console.log(JSON.stringify({suite:'guild-existing-contract',passed:true,checks}));
