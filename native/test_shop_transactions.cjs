'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),clone=x=>JSON.parse(JSON.stringify(x));
let passed=0;const test=(name,fn)=>{fn();passed++;console.log('PASS '+name);};
function town(){const s=require('./test-current-fixture.cjs')();s.characters['character_mirei'].inventory={potion:3};s.location='east';return s;}
function okay(s){assert.equal(C.validate(s).ok,true,C.validate(s).error);assert.deepEqual(C.deserialize(C.serialize(s)),s);}
test('inventory sale display uses the same quote and price as the transaction',()=>{
  const s=town();s.characters["character_mirei"].inventory={'sword-wood':2,potion:3};
  const before=clone(s),entries=C.view(s).inventoryByCharacter["character_mirei"].entries;
  for(const entry of entries)assert.deepEqual(entry.sale,C.saleQuote(s,"character_mirei",entry.id,1));
  assert(entries.find(e=>e.id==='sword-wood').sale.ok);
  assert.equal(entries.find(e=>e.id==='potion').sale.ok,false);
  assert.deepEqual(s,before,'display quote must not mutate inventory or money');
  s.location='astaris';assert(C.view(s).inventoryByCharacter["character_mirei"].entries.every(e=>!e.sale.ok));
});
test('sell confirms owner and quantity; cancel, invalid stock and duplicate submit are unchanged',()=>{
  const s=town();s.characters["character_mirei"].inventory['sword-wood']=2;const before=clone(s),q=C.saleQuote(s,"character_mirei",'sword-wood',1);
  assert(q.ok);assert.deepEqual(s,before);assert.equal(C.saleQuote(s,"character_mirei",'sword-wood',3).ok,false);assert.equal(C.saleQuote(s,"character_mirei",'potion',1).ok,false);
  assert(C.sellInventory(s,"character_mirei",'sword-wood',1,q.token));assert.equal(s.gold,250);assert.equal(s.characters["character_mirei"].inventory['sword-wood'],1);assert.equal(s.characters["character_mirei"].weapon,'sword-wood');
  const after=clone(s);assert.equal(C.sellInventory(s,"character_mirei",'sword-wood',1,q.token),false);assert.deepEqual(s,after);okay(s);
});
test('actual serialized size and currency bounds reject before any partial mutation',()=>{
  for(const kind of ['transfer','buy','sale']){
    const s=town();s.characters["character_merina"].inventory['hammer-wood']=1;s.history=Array(100).fill('');
    let padding=C.MAX_SAVE_BYTES-Buffer.byteLength(C.serialize(s),'utf8')-1;
    for(let i=0;i<s.history.length&&padding>=3;i++){const n=Math.min(4000,Math.floor(padding/3));s.history[i]='界'.repeat(n);padding-=n*3;}
    s.history[99]+='x'.repeat(padding);
    assert.equal(Buffer.byteLength(C.serialize(s),'utf8'),C.MAX_SAVE_BYTES-1);
    const before=clone(s),token=C.inventoryToken(s);
    if(kind==='transfer')assert.equal(C.inventoryAction(s,"character_mirei",'potion','transfer',"character_merina",1,null,token),false);
    if(kind==='buy'){
      const q=C.purchaseQuote(s,'staff-wood',"character_mirei");assert(q.ok,q.reason);
      assert.equal(C.buyInventory(s,"character_mirei",'staff-wood',q.token),false);
    }
    if(kind==='sale')assert.equal(C.sellInventory(s,"character_merina",'hammer-wood',1,token),false);
    assert.deepEqual(s,before);assert.equal(C.inventoryToken(s),token);C.serialize(s);
  }
  const s=town();s.gold=100000000;s.characters["character_merina"].inventory['hammer-wood']=1;const before=clone(s);
  assert.equal(C.sellInventory(s,"character_merina",'hammer-wood',1,C.inventoryToken(s)),false);assert.deepEqual(s,before);
});
test('sale capability and API agree on exactly the three equipment shops',()=>{
  for(const location of ['astaris','east','west','north','south'])for(const phase of ['town','camp','battle']){
    const s=town();s.location=location;s.characters["character_merina"].inventory['hammer-wood']=1;
    const eligible=phase==='town'&&['east','west','north'].includes(location);
    // A quote only reads phase; use a detached invalid-phase snapshot to test its gate.
    s.phase=phase;const before=clone(s),q=C.saleQuote(s,"character_merina",'hammer-wood');
    assert.equal(C.saleAvailable(s),eligible);assert.equal(C.view(s).saleAvailable,eligible);assert.equal(q.ok,eligible);
    if(!eligible){assert.equal(C.sellInventory(s,"character_merina",'hammer-wood',1,q.token),false);assert.deepEqual(s,before);}
    else {assert(C.sellInventory(s,"character_merina",'hammer-wood',1,q.token));assert.equal(s.gold,280);okay(s);}
  }
});
console.log(`PASS ${passed} shop-transaction groups`);
