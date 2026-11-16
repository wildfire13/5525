'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),S=require('./equipment-slots.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let passed=0;const test=(name,fn)=>{fn();passed++;console.log('PASS '+name);};
const act=(s,id,action,slot)=>C.inventoryAction(s,"character_mirei",id,action,null,1,slot,C.inventoryToken(s));
const clean=s=>{assert(!Object.values(s.characters).some(c=>Object.keys(c.inventory).some(id=>id.startsWith('empty-'))));assert.equal(C.validate(s).ok,true,C.validate(s).error);assert.deepEqual(C.deserialize(C.serialize(s)),s);};
test('all eight empty slots are non-owned placeholders, including legacy accessory placements',()=>{
  for(const slot of Object.keys(S.slots)){
    const id='empty-'+slot,g=C.gear.find(g=>g.id===id),s=require('./test-current-fixture.cjs')();s.location='north';s.characters["character_mirei"][S.storage(slot)]=id;
    assert.equal(g.type,'empty');assert(S.allowed(g).includes(slot));clean(s);
    for(let repeat=0;repeat<3;repeat++){
      const before=clone(s);assert.equal(C.inventoryQuote(s,"character_mirei",id,'unequip',null,1,slot).ok,false);
      assert.equal(act(s,id,'unequip',slot),false);assert.equal(C.saleQuote(s,"character_mirei",id).ok,false);assert.equal(C.sellInventory(s,"character_mirei",id,1,C.inventoryToken(s)),false);assert.deepEqual(s,before);
    }
  }
  const legacy=require('./test-current-fixture.cjs')();legacy.characters["character_mirei"].accessory1='empty-accessory2';legacy.characters["character_mirei"].accessory2='empty-accessory1';clean(legacy);
});
test('single accessory purchases and owner re-equips never retain empty slots',()=>{
  for(const slot of ['accessory1','accessory2']){
    const s=require('./test-current-fixture.cjs')();s.location='north';s.gold=1000;const id='lone-ring-'+slot.slice(-1);
    s.characters["character_mirei"][slot]='empty-'+slot;const q=C.quote(s,"character_mirei",id,slot);assert.equal(q.retained,false);assert(C.buyGear(s,"character_mirei",id,slot));assert.equal(s.gold,930);clean(s);
    for(let repeat=0;repeat<3;repeat++){
      assert(act(s,id,'unequip',slot));assert.equal(s.characters["character_mirei"].inventory[id],1);assert.equal(C.equipment(s.characters["character_mirei"])[slot],'empty-'+slot);
      assert(act(s,id,'equip',slot));assert.equal(s.characters["character_mirei"].inventory[id],undefined);assert.equal(s.gold,930);clean(s);
    }
    const next='return-ring-'+slot.slice(-1);assert(C.buyGear(s,"character_mirei",next,slot));assert.equal(s.characters["character_mirei"].inventory[id],1);assert.equal(s.gold,860);clean(s);
  }
});
test('atomic plans buy into both empty accessories and retain only real replacements',()=>{
  const s=require('./test-current-fixture.cjs')();s.location='north';s.gold=1000;
  s.characters["character_mirei"].accessory1='empty-accessory1';
  s.characters["character_mirei"].accessory2='empty-accessory2';
  const rows=[{characterId:"character_mirei",gearId:'lone-ring-1',slot:'accessory1'},{characterId:"character_mirei",gearId:'return-ring-2',slot:'accessory2'}];
  const before=clone(s),q=C.purchasePlan(s,rows);assert(q.ok,q.reason);assert(q.rows.every(r=>!r.retained));assert.deepEqual(s,before);assert(C.buyPlan(s,rows,q.token));assert.equal(s.gold,860);clean(s);
  const clearing=rows.map(r=>({...r,gearId:'empty-'+r.slot})),remove=C.purchasePlan(s,clearing);
  assert(remove.ok,remove.reason);assert(remove.rows.every(r=>r.retained));assert(C.buyPlan(s,clearing,remove.token));
  assert.equal(s.gold,860);assert.equal(s.characters["character_mirei"].inventory['lone-ring-1'],1);assert.equal(s.characters["character_mirei"].inventory['return-ring-2'],1);clean(s);
});
test('owned accessories equipped into an empty slot consume only the real item',()=>{
  for(const slot of ['accessory1','accessory2']){
    const s=require('./test-current-fixture.cjs')(),id='lone-ring-'+slot.slice(-1);s.characters["character_mirei"].inventory[id]=1;
    s.characters["character_mirei"][slot]='empty-'+slot;const beforeGold=s.gold,q=C.inventoryQuote(s,"character_mirei",id,'equip',null,1,slot);assert(q.ok);assert.equal(q.retained,false);
    assert(act(s,id,'equip',slot));assert.equal(s.gold,beforeGold);assert.equal(C.equipment(s.characters["character_mirei"])[slot],id);clean(s);
  }
});
test('contaminated candidate saves are rejected without silently deleting stock or changing their input',()=>{
  for(const slot of Object.keys(S.slots))for(const rollback of [false,true]){
    const s=require('./test-current-fixture.cjs')();if(rollback)s.rollback=clone(s);const target=rollback?s.rollback:s;
    target.characters["character_mirei"].inventory['empty-'+slot]=3;
    const input={format:'5525-native-campaign',version:C.VERSION,cargoRevision:1,state:s},before=clone(input);
    assert.equal(C.validate(s).ok,false);assert.throws(()=>C.deserialize(input),/空の装備枠/);assert.deepEqual(input,before);
  }
});
console.log(`PASS ${passed} empty-equipment groups`);
