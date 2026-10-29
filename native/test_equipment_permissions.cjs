'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let passed=0;
function test(name,fn){fn();console.log('PASS '+name);passed++;}
// Isolated master fixtures: do not alter the source/SQLite or a user's save.
function withGear(id,properties,fn){
  const g=C.gear.find(g=>g.id===id),original=structuredClone(g);
  try{Object.assign(g,properties);fn();}
  finally{for(const key of Object.keys(g))delete g[key];Object.assign(g,original);}
}
test('nonpurchasable equipment cannot be bought through any purchase route',()=>withGear('sword-wood',{purchasable:false},()=>{
  const s=C.createLegacy();s.location='east';const before=JSON.stringify(s);
  assert(!C.shop(s).some(g=>g.id==='sword-wood'));
  assert.equal(C.purchaseQuote(s,'sword-wood').ok,false);
  assert.equal(C.buyGear(s,'scout','sword-wood','rightHand'),false);
  assert.equal(C.purchasePlan(s,[{characterId:'guard',gearId:'sword-wood',slot:'leftHand'}]).ok,false);
  assert.equal(JSON.stringify(s),before);
}));
test('sale price is independent, explicit zero is retained, legacy price fallback unchanged',()=>{
  const s=C.createLegacy();s.location='east';s.characters.guard.inventory['sword-wood']=2;
  withGear('sword-wood',{salePrice:15},()=>{const q=C.saleQuote(s,'guard','sword-wood',2);assert(q.ok);assert.equal(q.proceeds,30);});
  withGear('sword-wood',{salePrice:0},()=>assert.equal(C.saleQuote(s,'guard','sword-wood').proceeds,0));
  assert.equal(C.saleQuote(s,'guard','sword-wood').proceeds,70);
});
test('nonsellable item is retained when sale requested',()=>withGear('sword-wood',{sellable:false},()=>{
  const s=C.createLegacy();s.location='east';s.characters.guard.inventory['sword-wood']=1;const before=JSON.stringify(s);
  assert.equal(C.sellInventory(s,'guard','sword-wood',1,C.inventoryToken(s)),false);
  assert.equal(JSON.stringify(s),before);
}));
test('nontransferable item cannot move to another character',()=>withGear('sword-wood',{transferable:false},()=>{
  const s=C.createLegacy();s.characters.guard.inventory['sword-wood']=1;const before=JSON.stringify(s);
  assert.equal(C.inventoryAction(s,'guard','sword-wood','transfer','mage',1,null,C.inventoryToken(s)),false);
  assert.equal(JSON.stringify(s),before);
}));
test('locked equipment refuses unequip, equip replacement and purchase-plan replacement',()=>withGear('sword-wood',{removable:false},()=>{
  const s=C.createLegacy();s.location='east';s.characters.guard.inventory['sword-iron-1']=1;const before=JSON.stringify(s);
  assert.equal(C.inventoryQuote(s,'guard','sword-wood','unequip',null,1,'rightHand').ok,false);
  assert.equal(C.inventoryQuote(s,'guard','sword-iron-1','equip',null,1,'rightHand').ok,false);
  assert.equal(C.buyGear(s,'guard','sword-iron-1','rightHand'),false);
  assert.equal(C.purchasePlan(s,[{characterId:'guard',gearId:'sword-iron-1',slot:'rightHand'}]).ok,false);
  assert.equal(JSON.stringify(s),before);
}));
test('explicit race/sex conditions are checked, legacy undefined sex is preserved',()=>{
  const s=C.createLegacy();
  withGear('cloth-head',{raceOnly:'elf'},()=>{assert.equal(C.eligibility(s,'guard','cloth-head').ok,false);assert(C.eligibility(s,'mage','cloth-head').ok);});
  withGear('cloth-head',{excludedRaces:['elf']},()=>assert.equal(C.eligibility(s,'mage','cloth-head').ok,false));
  withGear('cloth-head',{sexOnly:'male'},()=>{assert(C.eligibility(s,'guard','cloth-head').ok);s.characters.guard.sex='female';assert.equal(C.eligibility(s,'guard','cloth-head').ok,false);s.characters.guard.sex='male';assert(C.eligibility(s,'guard','cloth-head').ok);});
});
console.log(`${passed} equipment permission checks passed`);
