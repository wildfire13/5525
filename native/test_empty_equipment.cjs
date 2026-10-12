'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),S=require('./equipment-slots.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let passed=0;const test=(name,fn)=>{fn();passed++;console.log('PASS '+name);};
const act=(s,id,action,slot)=>C.inventoryAction(s,'guard',id,action,null,1,slot,C.inventoryToken(s));
const clean=s=>{assert(!Object.values(s.characters).some(c=>Object.keys(c.inventory).some(id=>id.startsWith('empty-'))));assert.equal(C.validate(s).ok,true,C.validate(s).error);assert.deepEqual(C.deserialize(C.serialize(s)),s);};
test('all eight empty slots are non-owned placeholders, including legacy accessory placements',()=>{
  for(const slot of Object.keys(S.slots)){
    const id='empty-'+slot,g=C.gear.find(g=>g.id===id),s=C.create();s.location='north';s.characters.guard[S.storage(slot)]=id;
    assert.equal(g.type,'empty');assert(S.allowed(g).includes(slot));clean(s);
    for(let repeat=0;repeat<3;repeat++){
      const before=clone(s);assert.equal(C.inventoryQuote(s,'guard',id,'unequip',null,1,slot).ok,false);
      assert.equal(act(s,id,'unequip',slot),false);assert.equal(C.saleQuote(s,'guard',id).ok,false);assert.equal(C.sellInventory(s,'guard',id,1,C.inventoryToken(s)),false);assert.deepEqual(s,before);
    }
  }
  const legacy=C.create();legacy.characters.guard.accessory1='empty-accessory2';legacy.characters.guard.accessory2='empty-accessory1';clean(legacy);
});
test('single accessory purchases and owner re-equips never retain empty slots',()=>{
  for(const slot of ['accessory1','accessory2']){
    const s=C.create();s.location='north';s.gold=1000;const id='lone-ring-'+slot.slice(-1);
    const q=C.quote(s,'guard',id,slot);assert.equal(q.retained,false);assert(C.buyGear(s,'guard',id,slot));assert.equal(s.gold,930);clean(s);
    for(let repeat=0;repeat<3;repeat++){
      assert(act(s,id,'unequip',slot));assert.equal(s.characters.guard.inventory[id],1);assert.equal(C.equipment(s.characters.guard)[slot],'empty-'+slot);
      assert(act(s,id,'equip',slot));assert.equal(s.characters.guard.inventory[id],undefined);assert.equal(s.gold,930);clean(s);
    }
    const next='return-ring-'+slot.slice(-1);assert(C.buyGear(s,'guard',next,slot));assert.equal(s.characters.guard.inventory[id],1);assert.equal(s.gold,860);clean(s);
  }
});
test('atomic plans buy into both empty accessories and retain only real replacements',()=>{
  const s=C.create();s.location='north';s.gold=1000;
  const rows=[{characterId:'guard',gearId:'lone-ring-1',slot:'accessory1'},{characterId:'guard',gearId:'return-ring-2',slot:'accessory2'}];
  const before=clone(s),q=C.purchasePlan(s,rows);assert(q.ok,q.reason);assert(q.rows.every(r=>!r.retained));assert.deepEqual(s,before);assert(C.buyPlan(s,rows,q.token));assert.equal(s.gold,860);clean(s);
  const clearing=rows.map(r=>({...r,gearId:'empty-'+r.slot})),remove=C.purchasePlan(s,clearing);
  assert(remove.ok,remove.reason);assert(remove.rows.every(r=>r.retained));assert(C.buyPlan(s,clearing,remove.token));
  assert.equal(s.gold,860);assert.equal(s.characters.guard.inventory['lone-ring-1'],1);assert.equal(s.characters.guard.inventory['return-ring-2'],1);clean(s);
});
test('owned accessories equipped into an empty slot consume only the real item',()=>{
  for(const slot of ['accessory1','accessory2']){
    const s=C.create(),id='lone-ring-'+slot.slice(-1);s.characters.guard.inventory[id]=1;
    const beforeGold=s.gold,q=C.inventoryQuote(s,'guard',id,'equip',null,1,slot);assert(q.ok);assert.equal(q.retained,false);
    assert(act(s,id,'equip',slot));assert.equal(s.gold,beforeGold);assert.equal(C.equipment(s.characters.guard)[slot],id);clean(s);
  }
});
test('contaminated candidate saves are rejected without silently deleting stock or changing their input',()=>{
  for(const slot of Object.keys(S.slots))for(const rollback of [false,true]){
    const s=C.create();if(rollback)s.rollback=clone(s);const target=rollback?s.rollback:s;
    target.characters.guard.inventory['empty-'+slot]=3;
    const input={format:'5525-native-campaign',version:2,state:s},before=clone(input);
    assert.equal(C.validate(s).ok,false);assert.throws(()=>C.deserialize(input),/空の装備枠/);assert.deepEqual(input,before);
  }
});
console.log(`PASS ${passed} empty-equipment groups`);
