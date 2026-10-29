'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js'),clone=x=>JSON.parse(JSON.stringify(x));
const row=(characterId,gearId,slot='rightHand')=>({characterId,gearId,slot});
let passed=0;const test=(name,fn)=>{fn();passed++;console.log('PASS '+name);};
function town(){const s=require('./test-current-fixture.cjs')();s.location='east';return s;}
function okay(s){assert.equal(C.validate(s).ok,true,C.validate(s).error);assert.deepEqual(C.deserialize(C.serialize(s)),s);}
test('inventory sale display uses the same quote and price as the transaction',()=>{
  const s=town();s.characters.guard.inventory={'sword-wood':2,potion:3};
  const before=clone(s),entries=C.view(s).inventoryByCharacter.guard.entries;
  for(const entry of entries)assert.deepEqual(entry.sale,C.saleQuote(s,'guard',entry.id,1));
  assert(entries.find(e=>e.id==='sword-wood').sale.ok);
  assert.equal(entries.find(e=>e.id==='potion').sale.ok,false);
  assert.deepEqual(s,before,'display quote must not mutate inventory or money');
  s.location='astaris';assert(C.view(s).inventoryByCharacter.guard.entries.every(e=>!e.sale.ok));
});
test('multiple-member plan retains real stock until one atomic checkout',()=>{
  const s=town();s.gold=400;const entries=[row('guard','staff-wood'),row('archer','bow-wood-1')],before=clone(s),q=C.purchasePlan(s,entries);
  assert(q.ok);assert.equal(q.cost,210);assert.equal(q.afterGold,190);assert.deepEqual(s,before);
  assert(C.buyPlan(s,entries,q.token));assert.equal(s.gold,190);assert.equal(s.characters.guard.weapon,'staff-wood');assert.equal(s.characters.archer.weapon,'bow-wood-1');
  assert.equal(s.characters.guard.inventory['sword-wood'],1);assert.equal(s.characters.archer.inventory['bow-wood'],1);
  const paid=clone(s);assert.equal(C.buyPlan(s,entries,q.token),false);assert.deepEqual(s,paid);okay(s);
});
test('independent sale funds same plan; canceled plan does not undo completed sale',()=>{
  const s=town();s.gold=120;s.characters.mage.inventory['hammer-wood']=1;
  const entries=[row('guard','staff-wood'),row('archer','bow-wood-1')];assert.equal(C.purchasePlan(s,entries).shortfall,90);
  const sale=C.saleQuote(s,'mage','hammer-wood');assert(sale.ok);assert.equal(sale.proceeds,100);
  assert(C.sellInventory(s,'mage','hammer-wood',1,sale.token));assert.equal(s.gold,220);assert.equal(s.characters.mage.inventory['hammer-wood'],undefined);
  const afterSale=clone(s),q=C.purchasePlan(s,entries);assert(q.ok);assert.deepEqual(s,afterSale,'review/cancel does not change sale');
  assert(C.buyPlan(s,entries,q.token));assert.equal(s.gold,10);okay(s);
});
test('planned left-hand removal permits two-hand purchase independent of row order',()=>{
  for(const entries of [[row('guard','bow-wood'),row('guard','empty-leftHand','leftHand')],[row('guard','empty-leftHand','leftHand'),row('guard','bow-wood')]]){
    const s=town(),q=C.purchasePlan(s,entries);assert(q.ok,q.reason);assert(C.buyPlan(s,entries,q.token));assert.equal(s.characters.guard.weapon,'bow-wood');assert.equal(s.characters.guard.leftHand,'empty-leftHand');
    assert.equal(s.characters.guard.inventory['guard-shield-wood'],1);assert.equal(s.characters.guard.inventory['sword-wood'],1);assert(!Object.keys(s.characters.guard.inventory).some(id=>id.startsWith('empty-')));okay(s);
  }
});
test('one invalid row, missing money, duplicate slot or final hand collision rejects all',()=>{
  for(const entries of [[row('guard','staff-wood'),row('mage','sword-iron-1')],[row('archer','bow-wood-1'),row('guard','staff-silver-1')],[row('guard','staff-wood'),row('guard','bow-wood')],[row('guard','bow-wood')]]){
    const s=town(),before=clone(s),q=C.purchasePlan(s,entries);assert.equal(q.ok,false);assert.equal(C.buyPlan(s,entries,q.token),false);assert.deepEqual(s,before);
  }
});
test('state change invalidates checkout; only affected character row signature changes',()=>{
  const s=town();s.gold=400;const entries=[row('guard','staff-wood'),row('archer','bow-wood-1')],q=C.purchasePlan(s,entries);
  s.characters.mage.hp=1;const refreshed=C.purchasePlan(s,entries);assert.notEqual(refreshed.token,q.token);assert.deepEqual(refreshed.rows.map(r=>r.signature),q.rows.map(r=>r.signature));
  const before=clone(s);assert.equal(C.buyPlan(s,entries,q.token),false);assert.deepEqual(s,before);
  assert(C.inventoryAction(s,'guard','guard-shield-wood','unequip',null,1,'leftHand',C.inventoryToken(s)));
  const changed=C.purchasePlan(s,entries);assert.notEqual(changed.rows[0].signature,refreshed.rows[0].signature);assert.equal(changed.rows[1].signature,refreshed.rows[1].signature);
});
test('sell confirms owner and quantity; cancel, invalid stock and duplicate submit are unchanged',()=>{
  const s=town();s.characters.guard.inventory['sword-wood']=2;const before=clone(s),q=C.saleQuote(s,'guard','sword-wood',1);
  assert(q.ok);assert.deepEqual(s,before);assert.equal(C.saleQuote(s,'guard','sword-wood',3).ok,false);assert.equal(C.saleQuote(s,'guard','potion',1).ok,false);
  assert(C.sellInventory(s,'guard','sword-wood',1,q.token));assert.equal(s.gold,250);assert.equal(s.characters.guard.inventory['sword-wood'],1);assert.equal(s.characters.guard.weapon,'sword-wood');
  const after=clone(s);assert.equal(C.sellInventory(s,'guard','sword-wood',1,q.token),false);assert.deepEqual(s,after);okay(s);
});
test('actual serialized size and currency bounds reject before any partial mutation',()=>{
  for(const kind of ['transfer','buy','sale']){
    const s=town();s.characters.mage.inventory['hammer-wood']=1;s.history=Array(100).fill('');
    let padding=C.MAX_SAVE_BYTES-Buffer.byteLength(C.serialize(s),'utf8')-1;
    for(let i=0;i<s.history.length&&padding>=3;i++){const n=Math.min(4000,Math.floor(padding/3));s.history[i]='界'.repeat(n);padding-=n*3;}
    s.history[99]+='x'.repeat(padding);
    assert.equal(Buffer.byteLength(C.serialize(s),'utf8'),C.MAX_SAVE_BYTES-1);
    const before=clone(s),token=C.inventoryToken(s);
    if(kind==='transfer')assert.equal(C.inventoryAction(s,'guard','potion','transfer','mage',1,null,token),false);
    if(kind==='buy'){const entries=[row('guard','staff-wood')],q=C.purchasePlan(s,entries);assert(q.ok);assert.equal(C.buyPlan(s,entries,q.token),false);}
    if(kind==='sale')assert.equal(C.sellInventory(s,'mage','hammer-wood',1,token),false);
    assert.deepEqual(s,before);assert.equal(C.inventoryToken(s),token);C.serialize(s);
  }
  const s=town();s.gold=100000000;s.characters.mage.inventory['hammer-wood']=1;const before=clone(s);
  assert.equal(C.sellInventory(s,'mage','hammer-wood',1,C.inventoryToken(s)),false);assert.deepEqual(s,before);
});
test('sale capability and API agree on exactly the three equipment shops',()=>{
  for(const location of ['astaris','east','west','north','south'])for(const phase of ['town','camp','battle']){
    const s=town();s.location=location;s.characters.mage.inventory['hammer-wood']=1;
    const eligible=phase==='town'&&['east','west','north'].includes(location);
    // A quote only reads phase; use a detached invalid-phase snapshot to test its gate.
    s.phase=phase;const before=clone(s),q=C.saleQuote(s,'mage','hammer-wood');
    assert.equal(C.saleAvailable(s),eligible);assert.equal(C.view(s).saleAvailable,eligible);assert.equal(q.ok,eligible);
    if(!eligible){assert.equal(C.sellInventory(s,'mage','hammer-wood',1,q.token),false);assert.deepEqual(s,before);}
    else {assert(C.sellInventory(s,'mage','hammer-wood',1,q.token));assert.equal(s.gold,280);okay(s);}
  }
});
console.log(`PASS ${passed} shop-transaction groups`);
