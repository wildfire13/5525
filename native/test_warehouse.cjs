'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let passed=0;const clone=structuredClone;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
function fixture(){const s=require('./test-current-fixture.cjs')({extraCapacity:false});s.characters["character_mirei"].accessory1='pouch-belt-3';s.characters["character_merina"].accessory1='pouch-belt-3';s.characters["character_mirei"].inventory={potion:3,ether:1};s.characters["character_merina"].inventory={};return s;}
const move=(s,id,direction,n=1,owner='character_mirei',token=C.inventoryToken(s))=>C.warehouseAction(s,owner,id,direction,n,token);
test('quote is pure; deposit and withdrawal preserve quantities and resources',()=>{
 const s=fixture(),before=clone(s),q=C.warehouseQuote(s,"character_mirei",'potion','deposit',2);
 assert(q.ok);assert.deepEqual(s,before);assert(move(s,'potion','deposit',2));
 assert.equal(s.characters["character_mirei"].inventory.potion,1);assert.equal(s.warehouse.potion,2);
 assert(move(s,'potion','withdraw',1,'character_merina'));assert.equal(s.characters["character_merina"].inventory.potion,1);assert.equal(s.warehouse.potion,1);
 assert.equal(s.gold,before.gold);assert.equal(s.hours,before.hours);
});
test('duplicate or stale transaction cannot repeat ownership changes',()=>{
 const s=fixture(),token=C.inventoryToken(s);assert(move(s,'potion','deposit',1,'character_mirei',token));
 const after=clone(s);assert.equal(move(s,'potion','deposit',1,'character_mirei',token),false);assert.deepEqual(s,after);
});
test('save/reload retains warehouse and invalidates prior session token',()=>{
 const s=fixture();assert(move(s,'potion','deposit',3));const token=C.inventoryToken(s),data=C.serialize(s),loaded=C.deserialize(data);
 assert.deepEqual(loaded,s);assert.equal(move(loaded,'potion','withdraw',1,'character_mirei',token),false);
 assert(move(loaded,'potion','withdraw',3));assert.deepEqual(loaded.warehouse,{});
 assert.deepEqual(C.deserialize(C.serialize(loaded)),loaded);
});
test('non-Astaris and non-town operations reject without mutation',()=>{
 for(const patch of [{location:'east'},{phase:'camp'},{phase:'battle'},{phase:'deployment'}]){
  const s=fixture();Object.assign(s,patch);const before=clone(s);
  assert.equal(move(s,'potion','deposit'),false);assert.deepEqual(s,before);
 }
});
test('unknown members, reserve members, invalid counts and invalid direction reject',()=>{
 for(const [owner,n,direction] of [['unknown',1,'deposit'],['character_grant',1,'deposit'],['character_mirei',0,'deposit'],['character_mirei',-1,'deposit'],['character_mirei',.5,'deposit'],['character_mirei',4,'deposit'],['character_mirei',1,'wrong']]){
  const s=fixture(),before=clone(s);assert.equal(move(s,'potion',direction,n,owner),false);assert.deepEqual(s,before);
 }
});
test('quest cargo, virtual fists, empty slots and equipped-only items cannot be deposited',()=>{
 for(const id of ['quest-cargo:1','fist','empty-rightHand','sword-wood']){
  const s=fixture(),before=clone(s);assert.equal(move(s,id,'deposit'),false);assert.deepEqual(s,before);
 }
});
test('nontransferable equipment refuses warehouse and malformed stored copy rejects',()=>{
 const g=C.gear.find(g=>g.id==='sword-wood');g.transferable=false;
 try{const s=fixture();s.characters["character_mirei"].inventory[g.id]=1;const before=clone(s);
  assert.equal(move(s,g.id,'deposit'),false);assert.deepEqual(s,before);
  s.warehouse={[g.id]:1};assert.equal(C.validate(s).ok,false);
 }finally{delete g.transferable;}
});
test('warehouse has no type capacity; capacity zero rejects incoming but allows outgoing',()=>{
 const s=fixture();s.characters["character_merina"].inventory={potion:3,ether:1};assert(move(s,'potion','deposit',3,'character_merina'));assert(move(s, 'ether','deposit',1,'character_merina'));
 s.characters["character_merina"].accessory1='empty-accessory1';s.characters["character_merina"].accessory2='empty-accessory2';s.characters["character_merina"].lowerBody='empty-lowerBody';assert.equal(C.inventoryCapacity(s,"character_merina"),0);
 s.characters["character_merina"].inventory={ether:1};assert(move(s, 'ether','deposit',1,'character_merina'),'outgoing items remain allowed at zero capacity');
 const before=clone(s);assert.equal(move(s,'potion','withdraw',1,'character_merina'),false);assert.deepEqual(s,before);
 assert.equal(Object.keys(s.warehouse).length,2);
 assert.deepEqual(C.deserialize(C.serialize(s)),s);
});
test('corrupt storage rejects without changing source save',()=>{
 for(const storage of [null,[],{unknown:1},{potion:0},{potion:-1},{potion:1.2},{'empty-head':1},{fist:1},{'quest-cargo:1':1}]){
  const s=fixture();s.warehouse=storage;const before=clone(s);assert.equal(C.validate(s).ok,false);assert.deepEqual(s,before);
 }
});
console.log(`${passed} warehouse checks passed`);
