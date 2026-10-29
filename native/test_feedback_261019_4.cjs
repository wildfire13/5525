'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js');
const action=(s,id,kind,slot,token=C.inventoryToken(s))=>C.inventoryAction(s,'guard',id,kind,null,1,slot,token);
const count=(s,id)=>(s.characters.guard.inventory[id]||0)+Object.values(C.equipment(s.characters.guard)).filter(x=>x===id).length;
let checks=0;
function check(value){assert(value);checks++;}
for(const gear of C.gear.filter(g=>g.type==='accessory'&&g.shopProductId)){
 const s=require('./test-current-fixture.cjs')();s.location='north';s.gold=999;
 // Legacy copies are preserved, never renamed or combined in persisted state.
 s.characters.guard.inventory[gear.id]=3;
 const old=C.serialize(s), round=C.deserialize(old);assert.equal(C.serialize(round),old);checks++;
 check(gear.price===70 && !gear.name.includes('［装飾'));
 const canonical=C.gear.find(g=>g.id===gear.shopProductId);
 check(canonical && canonical.effect===gear.effect && canonical.price===gear.price);
 for(const slot of ['accessory1','accessory2','accessory1']){
  const before=C.serialize(s),q=C.inventoryQuote(s,'guard',gear.id,'equip',null,1,slot);
  check(q.ok);assert.equal(C.serialize(s),before);checks++;
  check(action(s,gear.id,'equip',slot,q.token));check(C.equipment(s.characters.guard)[slot]===gear.id);check(count(s,gear.id)===3);
  const committed=C.serialize(s);check(!action(s,gear.id,'equip',slot,q.token));assert.equal(C.serialize(s),committed);checks++;
  check(action(s,gear.id,'unequip',slot));check(count(s,gear.id)===3);
  check(C.validate(s).ok);assert.equal(C.serialize(C.deserialize(C.serialize(s))),C.serialize(s));checks++;
 }
 check(s.gold===999);
}
const legacy=require('./test-current-fixture.cjs')();legacy.location='north';legacy.characters.guard.accessory1='return-ring-1';legacy.characters.guard.accessory2='return-ring-2';
const before=C.serialize(legacy),loaded=C.deserialize(before);assert.equal(C.serialize(loaded),before);checks++;
check(C.stats(loaded.characters.guard).skillSources.filter(x=>x.id==='returnHome').length===2);
const s=require('./test-current-fixture.cjs')();s.location='north';s.gold=999;const quote=C.purchaseQuote(s,'return-ring-1'),unchanged=C.serialize(s);check(quote.ok);assert.equal(C.serialize(s),unchanged);checks++;
check(C.buyInventory(s,'guard','return-ring-1',quote.token));check(count(s,'return-ring-1')===1 && s.gold===929);
const bought=C.serialize(s);check(!C.buyInventory(s,'guard','return-ring-1',quote.token));assert.equal(C.serialize(s),bought);checks++;
console.log(`PASS ${checks} feedback4 accessory compatibility checks`);
