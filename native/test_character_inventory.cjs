'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
function action(s,owner,id,kind,target=null,count=1,slot=null,token=C.inventoryToken(s)){
  return C.inventoryAction(s,owner,id,kind,target,count,slot,token);
}
function okay(s){const v=C.validate(s);assert.equal(v.ok,true,v.error);assert.deepEqual(C.deserialize(C.serialize(s)),s);}
function total(s,id){return Object.values(s.characters).reduce((n,c)=>n+(c.inventory[id]||0)+Object.values(C.equipment(c)).filter(x=>x===id).length,0);}
function inventoryFixture(){
  const s=require('./test-current-fixture.cjs')();
  s.characters['character_mirei'].inventory={potion:3,ether:1};
  return s;
}
test('quote/cancel never mutates; transfer is conserved and stale confirmation cannot replay',()=>{
  const s=inventoryFixture(),before=clone(s),q=C.inventoryQuote(s,"character_mirei",'potion','transfer',"character_merina",2);
  assert(q.ok);assert.deepEqual(s,before);assert(action(s,"character_mirei",'potion','transfer',"character_merina",2,null,q.token));
  assert.equal(s.characters["character_mirei"].inventory.potion,1);assert.equal(s.characters["character_merina"].inventory.potion,2);assert.equal(total(s,'potion'),3);
  const after=clone(s);assert.equal(action(s,"character_mirei",'potion','transfer',"character_merina",2,null,q.token),false);assert.deepEqual(s,after);okay(s);
});
test('invalid quantities, self/unknown/reserve targets and wrong phase are atomic refusals',()=>{
  for(const [target,amount] of [['character_mirei',1],['missing',1],['character_grant',1],['character_merina',0],['character_merina',-1],['character_merina',.5],['character_merina',4],['character_merina',NaN],['character_merina',Infinity]]){
    const s=inventoryFixture(),before=clone(s);assert.equal(action(s,"character_mirei",'potion','transfer',target,amount),false);assert.deepEqual(s,before);
  }
  const s=inventoryFixture();s.phase='road';const before=clone(s);assert.equal(action(s,"character_mirei",'potion','discard'),false);assert.deepEqual(s,before);
});
test('use distinguishes owner and recipient, clamps recovery, consumes exactly one',()=>{
  const s=inventoryFixture();s.characters["character_merina"].hp=65;const max=C.stats(s.characters["character_merina"]).max;
  const q=C.inventoryQuote(s,"character_mirei",'potion','use',"character_merina");assert(q.ok);assert.equal(q.after,max);
  assert(action(s,"character_mirei",'potion','use',"character_merina",1,null,q.token));assert.equal(s.characters["character_merina"].hp,max);assert.equal(s.characters["character_mirei"].inventory.potion,2);
  assert.equal(s.characters["character_merina"].inventory.potion,undefined);okay(s);
});
test('noncombat ether remains usable on a selected ally; full/dead targets do not consume',()=>{
  const s=inventoryFixture();s.characters["character_merina"].mp=1;assert(action(s,"character_mirei", 'ether','use',"character_merina"));assert.equal(s.characters["character_merina"].mp,4);
  for(const hp of [C.stats(s.characters["character_merina"]).max,0]){s.characters["character_merina"].hp=hp;const before=clone(s);assert.equal(action(s,"character_mirei",'potion','use',"character_merina"),false);assert.deepEqual(s,before);}okay(s);
});
test('discard quote/cancel retains stock; confirmation affects only stated owner and count',()=>{
  const s=inventoryFixture();assert(action(s,"character_mirei",'potion','transfer',"character_merina"));const before=clone(s),q=C.inventoryQuote(s,"character_merina",'potion','discard');
  assert(q.ok);assert.deepEqual(s,before);assert(action(s,"character_merina",'potion','discard',null,1,null,q.token));
  assert.equal(s.characters["character_merina"].inventory.potion,undefined);assert.equal(s.characters["character_mirei"].inventory.potion,2);okay(s);
});
test('purchase requires explicit recipient; no old shared-stock API or arbitrary assignment',()=>{
  const s=inventoryFixture();s.location='south';const before=clone(s);assert.equal(C.buyItem(s,'potion',1),false);assert.deepEqual(s,before);
  assert(C.buyItem(s,'potion',1,"character_merina",C.inventoryToken(s)));assert.equal(s.characters["character_merina"].inventory.potion,1);assert.equal(s.characters["character_mirei"].inventory.potion,3);assert.equal(s.gold,140);okay(s);
});
test('existing consumable total cap is retained without creating a per-character capacity',()=>{
  const s=inventoryFixture();s.location='south';s.gold=10000;s.characters["character_mirei"].inventory.potion=99;
  assert(action(s,"character_mirei",'potion','transfer',"character_merina",50));assert.equal(s.characters["character_merina"].inventory.potion,50);
  const before=clone(s);assert.equal(C.buyItem(s,'potion',1,"character_merina",C.inventoryToken(s)),false);assert.deepEqual(s,before);okay(s);
});
test('intervening resource change invalidates confirmation without consuming anything',()=>{
  const s=inventoryFixture();s.characters["character_merina"].hp=1;const q=C.inventoryQuote(s,"character_mirei",'potion','use',"character_merina");
  s.characters["character_merina"].hp=2;const before=clone(s);assert.equal(action(s,"character_mirei",'potion','use',"character_merina",1,null,q.token),false);assert.deepEqual(s,before);
});
test('ABA transfer and identical save reload cannot revive an old confirmation token',()=>{
  const s=inventoryFixture(),q=C.inventoryQuote(s,"character_mirei",'potion','discard');
  assert(action(s,"character_mirei",'potion','transfer',"character_merina"));assert(action(s,"character_merina",'potion','transfer',"character_mirei"));
  const before=clone(s);assert.equal(action(s,"character_mirei",'potion','discard',null,1,null,q.token),false);assert.deepEqual(s,before);
  const token=C.inventoryToken(s),loaded=C.deserialize(C.serialize(s));assert.notEqual(C.inventoryToken(loaded),token);
  assert.equal(action(loaded,"character_mirei",'potion','discard',null,1,null,token),false);okay(loaded);
});
test('buy and remove gear retain it with owner, no refund or duplicated placeholder items',()=>{
  const s=inventoryFixture();assert(C.select(s,[...s.selected,'character_kyle']));const bow=s.characters['character_kyle'];bow.weapon='bow-wood';Object.assign(bow,{xp:100,level:2,statPoints:2,skillPoints:1});assert(C.allocate(s,bow.id,'str'));s.location='east';const funds=s.gold,before=total(s,'bow-wood');assert(C.buyGear(s,"character_kyle",'bow-wood-1','rightHand'));
  assert.equal(s.gold,funds-140);assert.equal(s.characters["character_kyle"].inventory['bow-wood'],1);assert.equal(total(s,'bow-wood'),before);
  assert(action(s,"character_kyle",'bow-wood-1','unequip',null,1,'rightHand'));assert.equal(s.characters["character_kyle"].weapon,'empty-rightHand');
  assert.equal(s.characters["character_kyle"].inventory['bow-wood-1'],1);assert.equal(s.gold,funds-140);
  assert(action(s,"character_kyle",'bow-wood','equip',null,1,'rightHand'));assert.equal(s.characters["character_kyle"].inventory['bow-wood'],undefined);okay(s);
});
test('hand occupancy and race restrictions remain authoritative when equipping owned gear',()=>{
  const s=require('./test-current-fixture.cjs')();s.characters["character_mirei"].inventory['bow-wood']=1;s.characters["character_merina"].inventory['sword-iron-1']=1;
  const before=clone(s);assert.equal(action(s,"character_mirei",'bow-wood','equip',null,1,'rightHand'),false);
  assert.equal(action(s,"character_merina",'sword-iron-1','equip',null,1,'rightHand'),false);assert.deepEqual(s,before);
  assert(action(s,"character_mirei",'guard-shield-wood','unequip',null,1,'leftHand'));
  assert(action(s,"character_mirei",'bow-wood','equip',null,1,'rightHand'));okay(s);
});
test('porter keeps locked whistle and can re-equip removable starter armor without gaining attacks',()=>{
  const s=inventoryFixture(),before=clone(s);assert.equal(action(s,"character_yuno",'porter-whistle','unequip',null,1,'rightHand'),false);assert.deepEqual(s,before);
  assert(action(s,"character_yuno",'armor-cloth','unequip',null,1,'upperBody'));
  assert(action(s,"character_yuno",'armor-cloth','equip',null,1,'upperBody'));assert.equal(C.stats(s.characters["character_yuno"]).atk,0);okay(s);
});
test('new save rejects unknown, empty-slot, zero, negative and duplicated legacy stock',()=>{
  for(const mutate of [s=>s.characters["character_mirei"].inventory.missing=1,s=>s.characters["character_mirei"].inventory['empty-leftHand']=1,s=>s.characters["character_mirei"].inventory.potion=0,s=>s.characters["character_mirei"].inventory.potion=-1,s=>s.inventory={potion:3,ether:1}]){
    const s=require('./test-current-fixture.cjs')();mutate(s);assert.equal(C.validate(s).ok,false);assert.throws(()=>C.deserialize({format:'5525-native-campaign',version:C.VERSION,cargoRevision:1,state:s}));
  }
});
console.log(`PASS ${passed} character-inventory groups`);
