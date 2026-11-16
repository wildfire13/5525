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
  s.characters['recruit-guard-human-female'].inventory={potion:3,ether:1};
  return s;
}
test('quote/cancel never mutates; transfer is conserved and stale confirmation cannot replay',()=>{
  const s=inventoryFixture(),before=clone(s),q=C.inventoryQuote(s,"recruit-guard-human-female",'potion','transfer',"recruit-mage-elf-female",2);
  assert(q.ok);assert.deepEqual(s,before);assert(action(s,"recruit-guard-human-female",'potion','transfer',"recruit-mage-elf-female",2,null,q.token));
  assert.equal(s.characters["recruit-guard-human-female"].inventory.potion,1);assert.equal(s.characters["recruit-mage-elf-female"].inventory.potion,2);assert.equal(total(s,'potion'),3);
  const after=clone(s);assert.equal(action(s,"recruit-guard-human-female",'potion','transfer',"recruit-mage-elf-female",2,null,q.token),false);assert.deepEqual(s,after);okay(s);
});
test('invalid quantities, self/unknown/reserve targets and wrong phase are atomic refusals',()=>{
  for(const [target,amount] of [['recruit-guard-human-female',1],['missing',1],['recruit-guard-dwarf-male',1],['recruit-mage-elf-female',0],['recruit-mage-elf-female',-1],['recruit-mage-elf-female',.5],['recruit-mage-elf-female',4],['recruit-mage-elf-female',NaN],['recruit-mage-elf-female',Infinity]]){
    const s=inventoryFixture(),before=clone(s);assert.equal(action(s,"recruit-guard-human-female",'potion','transfer',target,amount),false);assert.deepEqual(s,before);
  }
  const s=inventoryFixture();s.phase='road';const before=clone(s);assert.equal(action(s,"recruit-guard-human-female",'potion','discard'),false);assert.deepEqual(s,before);
});
test('use distinguishes owner and recipient, clamps recovery, consumes exactly one',()=>{
  const s=inventoryFixture();s.characters["recruit-mage-elf-female"].hp=65;const max=C.stats(s.characters["recruit-mage-elf-female"]).max;
  const q=C.inventoryQuote(s,"recruit-guard-human-female",'potion','use',"recruit-mage-elf-female");assert(q.ok);assert.equal(q.after,max);
  assert(action(s,"recruit-guard-human-female",'potion','use',"recruit-mage-elf-female",1,null,q.token));assert.equal(s.characters["recruit-mage-elf-female"].hp,max);assert.equal(s.characters["recruit-guard-human-female"].inventory.potion,2);
  assert.equal(s.characters["recruit-mage-elf-female"].inventory.potion,undefined);okay(s);
});
test('noncombat ether remains usable on a selected ally; full/dead targets do not consume',()=>{
  const s=inventoryFixture();s.characters["recruit-mage-elf-female"].mp=1;assert(action(s,"recruit-guard-human-female",'ether','use',"recruit-mage-elf-female"));assert.equal(s.characters["recruit-mage-elf-female"].mp,4);
  for(const hp of [C.stats(s.characters["recruit-mage-elf-female"]).max,0]){s.characters["recruit-mage-elf-female"].hp=hp;const before=clone(s);assert.equal(action(s,"recruit-guard-human-female",'potion','use',"recruit-mage-elf-female"),false);assert.deepEqual(s,before);}okay(s);
});
test('discard quote/cancel retains stock; confirmation affects only stated owner and count',()=>{
  const s=inventoryFixture();assert(action(s,"recruit-guard-human-female",'potion','transfer',"recruit-mage-elf-female"));const before=clone(s),q=C.inventoryQuote(s,"recruit-mage-elf-female",'potion','discard');
  assert(q.ok);assert.deepEqual(s,before);assert(action(s,"recruit-mage-elf-female",'potion','discard',null,1,null,q.token));
  assert.equal(s.characters["recruit-mage-elf-female"].inventory.potion,undefined);assert.equal(s.characters["recruit-guard-human-female"].inventory.potion,2);okay(s);
});
test('purchase requires explicit recipient; no old shared-stock API or arbitrary assignment',()=>{
  const s=inventoryFixture();s.location='south';const before=clone(s);assert.equal(C.buyItem(s,'potion',1),false);assert.deepEqual(s,before);
  assert(C.buyItem(s,'potion',1,"recruit-mage-elf-female",C.inventoryToken(s)));assert.equal(s.characters["recruit-mage-elf-female"].inventory.potion,1);assert.equal(s.characters["recruit-guard-human-female"].inventory.potion,3);assert.equal(s.gold,140);okay(s);
});
test('existing consumable total cap is retained without creating a per-character capacity',()=>{
  const s=inventoryFixture();s.location='south';s.gold=10000;s.characters["recruit-guard-human-female"].inventory.potion=99;
  assert(action(s,"recruit-guard-human-female",'potion','transfer',"recruit-mage-elf-female",50));assert.equal(s.characters["recruit-mage-elf-female"].inventory.potion,50);
  const before=clone(s);assert.equal(C.buyItem(s,'potion',1,"recruit-mage-elf-female",C.inventoryToken(s)),false);assert.deepEqual(s,before);okay(s);
});
test('intervening resource change invalidates confirmation without consuming anything',()=>{
  const s=inventoryFixture();s.characters["recruit-mage-elf-female"].hp=1;const q=C.inventoryQuote(s,"recruit-guard-human-female",'potion','use',"recruit-mage-elf-female");
  s.characters["recruit-mage-elf-female"].hp=2;const before=clone(s);assert.equal(action(s,"recruit-guard-human-female",'potion','use',"recruit-mage-elf-female",1,null,q.token),false);assert.deepEqual(s,before);
});
test('ABA transfer and identical save reload cannot revive an old confirmation token',()=>{
  const s=inventoryFixture(),q=C.inventoryQuote(s,"recruit-guard-human-female",'potion','discard');
  assert(action(s,"recruit-guard-human-female",'potion','transfer',"recruit-mage-elf-female"));assert(action(s,"recruit-mage-elf-female",'potion','transfer',"recruit-guard-human-female"));
  const before=clone(s);assert.equal(action(s,"recruit-guard-human-female",'potion','discard',null,1,null,q.token),false);assert.deepEqual(s,before);
  const token=C.inventoryToken(s),loaded=C.deserialize(C.serialize(s));assert.notEqual(C.inventoryToken(loaded),token);
  assert.equal(action(loaded,"recruit-guard-human-female",'potion','discard',null,1,null,token),false);okay(loaded);
});
test('buy and remove gear retain it with owner, no refund or duplicated placeholder items',()=>{
  const s=inventoryFixture();assert(C.select(s,[...s.selected,'recruit-scout-human-male']));const bow=s.characters['recruit-scout-human-male'];bow.weapon='bow-wood';Object.assign(bow,{xp:100,level:2,statPoints:2,skillPoints:1});assert(C.allocate(s,bow.id,'str'));s.location='east';const before=total(s,'bow-wood');assert(C.buyGear(s,"recruit-scout-human-male",'bow-wood-1','rightHand'));
  assert.equal(s.gold,40);assert.equal(s.characters["recruit-scout-human-male"].inventory['bow-wood'],1);assert.equal(total(s,'bow-wood'),before);
  assert(action(s,"recruit-scout-human-male",'bow-wood-1','unequip',null,1,'rightHand'));assert.equal(s.characters["recruit-scout-human-male"].weapon,'empty-rightHand');
  assert.equal(s.characters["recruit-scout-human-male"].inventory['bow-wood-1'],1);assert.equal(s.gold,40);
  assert(action(s,"recruit-scout-human-male",'bow-wood','equip',null,1,'rightHand'));assert.equal(s.characters["recruit-scout-human-male"].inventory['bow-wood'],undefined);okay(s);
});
test('hand occupancy and race restrictions remain authoritative when equipping owned gear',()=>{
  const s=require('./test-current-fixture.cjs')();s.characters["recruit-guard-human-female"].inventory['bow-wood']=1;s.characters["recruit-mage-elf-female"].inventory['sword-iron-1']=1;
  const before=clone(s);assert.equal(action(s,"recruit-guard-human-female",'bow-wood','equip',null,1,'rightHand'),false);
  assert.equal(action(s,"recruit-mage-elf-female",'sword-iron-1','equip',null,1,'rightHand'),false);assert.deepEqual(s,before);
  assert(action(s,"recruit-guard-human-female",'guard-shield-wood','unequip',null,1,'leftHand'));
  assert(action(s,"recruit-guard-human-female",'bow-wood','equip',null,1,'rightHand'));okay(s);
});
test('porter keeps locked whistle and can re-equip removable starter armor without gaining attacks',()=>{
  const s=inventoryFixture(),before=clone(s);assert.equal(action(s,"recruit-porter-human-female",'porter-whistle','unequip',null,1,'rightHand'),false);assert.deepEqual(s,before);
  assert(action(s,"recruit-porter-human-female",'armor-cloth','unequip',null,1,'upperBody'));
  assert(action(s,"recruit-porter-human-female",'armor-cloth','equip',null,1,'upperBody'));assert.equal(C.stats(s.characters["recruit-porter-human-female"]).atk,0);okay(s);
});
test('new save rejects unknown, empty-slot, zero, negative and duplicated legacy stock',()=>{
  for(const mutate of [s=>s.characters["recruit-guard-human-female"].inventory.missing=1,s=>s.characters["recruit-guard-human-female"].inventory['empty-leftHand']=1,s=>s.characters["recruit-guard-human-female"].inventory.potion=0,s=>s.characters["recruit-guard-human-female"].inventory.potion=-1,s=>s.inventory={potion:3,ether:1}]){
    const s=require('./test-current-fixture.cjs')();mutate(s);assert.equal(C.validate(s).ok,false);assert.throws(()=>C.deserialize({format:'5525-native-campaign',version:C.VERSION,cargoRevision:1,state:s}));
  }
});
console.log(`PASS ${passed} character-inventory groups`);
