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
  const s=C.create();s.location='east';const before=JSON.stringify(s);
  assert(!C.shop(s).some(g=>g.id==='sword-wood'));
  assert.equal(C.purchaseQuote(s,'sword-wood').ok,false);
  assert.equal(C.buyGear(s,"character_rio",'sword-wood','rightHand'),false);
  assert.equal(JSON.stringify(s),before);
}));
test('sale price is independent, explicit zero is retained, legacy price fallback unchanged',()=>{
  const s=C.create();s.location='east';s.characters["character_mirei"].inventory['sword-wood']=2;
  withGear('sword-wood',{salePrice:15},()=>{const q=C.saleQuote(s,"character_mirei",'sword-wood',2);assert(q.ok);assert.equal(q.proceeds,30);});
  withGear('sword-wood',{salePrice:0},()=>assert.equal(C.saleQuote(s,"character_mirei",'sword-wood').proceeds,0));
  assert.equal(C.saleQuote(s,"character_mirei",'sword-wood').proceeds,70);
});
test('nonsellable item is retained when sale requested',()=>withGear('sword-wood',{sellable:false},()=>{
  const s=C.create();s.location='east';s.characters["character_mirei"].inventory['sword-wood']=1;const before=JSON.stringify(s);
  assert.equal(C.sellInventory(s,"character_mirei",'sword-wood',1,C.inventoryToken(s)),false);
  assert.equal(JSON.stringify(s),before);
}));
test('nontransferable item cannot move to another character',()=>withGear('sword-wood',{transferable:false},()=>{
  const s=C.create();s.characters["character_mirei"].inventory['sword-wood']=1;const before=JSON.stringify(s);
  assert.equal(C.inventoryAction(s,"character_mirei",'sword-wood','transfer',"character_merina",1,null,C.inventoryToken(s)),false);
  assert.equal(JSON.stringify(s),before);
}));
test('locked equipment refuses unequip and equip replacement',()=>withGear('sword-wood',{removable:false},()=>{
  const s=C.create();s.location='east';s.characters["character_mirei"].inventory['sword-iron-1']=1;const before=JSON.stringify(s);
  assert.equal(C.inventoryQuote(s,"character_mirei",'sword-wood','unequip',null,1,'rightHand').ok,false);
  assert.equal(C.inventoryQuote(s,"character_mirei",'sword-iron-1','equip',null,1,'rightHand').ok,false);
  assert.equal(C.buyGear(s,"character_mirei",'sword-iron-1','rightHand'),false);
  assert.equal(JSON.stringify(s),before);
}));
test('explicit race/sex conditions use real recruits without mutating their identity',()=>{
  const s=C.create();
  withGear('cloth-head',{raceOnly:'elf'},()=>{assert.equal(C.eligibility(s,"character_mirei",'cloth-head').ok,false);assert(C.eligibility(s,"character_merina",'cloth-head').ok);});
  withGear('cloth-head',{excludedRaces:['elf']},()=>assert.equal(C.eligibility(s,"character_merina",'cloth-head').ok,false));
  withGear('cloth-head',{sexOnly:'male'},()=>{assert.equal(C.eligibility(s,"character_mirei",'cloth-head').ok,false);assert(C.eligibility(s,"character_gareth",'cloth-head').ok);});
});
console.log(`${passed} equipment permission checks passed`);
