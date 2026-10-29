'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),fs=require('node:fs'),C=require('./campaign.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
function action(s,owner,id,kind,target=null,count=1,slot=null,token=C.inventoryToken(s)){
  return C.inventoryAction(s,owner,id,kind,target,count,slot,token);
}
function okay(s){const v=C.validate(s);assert.equal(v.ok,true,v.error);assert.deepEqual(C.deserialize(C.serialize(s)),s);}
function total(s,id){return Object.values(s.characters).reduce((n,c)=>n+(c.inventory[id]||0)+Object.values(C.equipment(c)).filter(x=>x===id).length,0);}
function legacyTown(){const old=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/campaign-a51a773-battle.json'),'utf8'));return {format:old.format,version:1,state:clone(old.state.rollback)};}

test('migrated historical stock retains quantities on first displayed member',()=>{
  const s=require('./test-current-fixture.cjs')();assert.equal(s.selected[0],'guard');assert.deepEqual(s.characters.guard.inventory,{potion:3,ether:1});
  assert.equal(Object.hasOwn(s,'inventory'),false);assert.deepEqual(C.inventoryTotals(s),{potion:3,ether:1});okay(s);
});
test('legacy full stock migrates once to explicit saved party order, not roster or object order',()=>{
  const old=legacyTown();old.state.selected=['mage','porter','guard'];old.state.inventory={potion:99,ether:99};
  const bytes=JSON.stringify(old),s=C.deserialize(old);assert.equal(JSON.stringify(old),bytes);
  assert.deepEqual(s.characters.mage.inventory,{potion:99,ether:99});assert.deepEqual(s.characters.guard.inventory,{});
  const once=C.serialize(s);assert.deepEqual(C.deserialize(once),s);assert.equal(C.serialize(C.deserialize(once)),once);okay(s);
});
test('missing, empty, corrupt, or mixed legacy recipient data is rejected without source mutation',()=>{
  for(const change of [s=>s.selected=[],s=>s.selected[0]='missing',s=>delete s.characters[s.selected[0]],s=>s.characters[s.selected[0]].inventory={potion:7},s=>s.inventory.potion=-1]){
    const old=legacyTown();change(old.state);const bytes=JSON.stringify(old);assert.throws(()=>C.deserialize(old));assert.equal(JSON.stringify(old),bytes);
  }
});
test('rollback snapshot independently retains its original first member and exact stock',()=>{
  const old=legacyTown();old.state.rollback=clone(old.state);old.state.selected=['porter','guard'];
  old.state.sequence++;old.state.activeQuest={...C.board(old.state)[0],token:old.state.sequence};
  old.state.inventory={potion:5,ether:2};old.state.rollback.inventory={potion:9,ether:4};
  const s=C.deserialize(old);
  // Existing cargo migration issues the accepted legacy quest exactly once.
  assert.equal(s.activeQuest,null);
  assert.deepEqual(s.characters.porter.inventory,{potion:5,ether:2});
  assert.equal(s.rollback,null);assert.equal(s.phase,'town');assert.equal(s.location,'astaris');okay(s);
});
test('quote/cancel never mutates; transfer is conserved and stale confirmation cannot replay',()=>{
  const s=require('./test-current-fixture.cjs')(),before=clone(s),q=C.inventoryQuote(s,'guard','potion','transfer','mage',2);
  assert(q.ok);assert.deepEqual(s,before);assert(action(s,'guard','potion','transfer','mage',2,null,q.token));
  assert.equal(s.characters.guard.inventory.potion,1);assert.equal(s.characters.mage.inventory.potion,2);assert.equal(total(s,'potion'),3);
  const after=clone(s);assert.equal(action(s,'guard','potion','transfer','mage',2,null,q.token),false);assert.deepEqual(s,after);okay(s);
});
test('invalid quantities, self/unknown/reserve targets and wrong phase are atomic refusals',()=>{
  for(const [target,amount] of [['guard',1],['missing',1],['warrior',1],['mage',0],['mage',-1],['mage',.5],['mage',4],['mage',NaN],['mage',Infinity]]){
    const s=require('./test-current-fixture.cjs')(),before=clone(s);assert.equal(action(s,'guard','potion','transfer',target,amount),false);assert.deepEqual(s,before);
  }
  const s=require('./test-current-fixture.cjs')();s.phase='road';const before=clone(s);assert.equal(action(s,'guard','potion','discard'),false);assert.deepEqual(s,before);
});
test('use distinguishes owner and recipient, clamps recovery, consumes exactly one',()=>{
  const s=require('./test-current-fixture.cjs')();s.characters.mage.hp=65;const max=C.stats(s.characters.mage).max;
  const q=C.inventoryQuote(s,'guard','potion','use','mage');assert(q.ok);assert.equal(q.after,max);
  assert(action(s,'guard','potion','use','mage',1,null,q.token));assert.equal(s.characters.mage.hp,max);assert.equal(s.characters.guard.inventory.potion,2);
  assert.equal(s.characters.mage.inventory.potion,undefined);okay(s);
});
test('noncombat ether remains usable on a selected ally; full/dead targets do not consume',()=>{
  const s=require('./test-current-fixture.cjs')();s.characters.mage.mp=1;assert(action(s,'guard','ether','use','mage'));assert.equal(s.characters.mage.mp,4);
  for(const hp of [C.stats(s.characters.mage).max,0]){s.characters.mage.hp=hp;const before=clone(s);assert.equal(action(s,'guard','potion','use','mage'),false);assert.deepEqual(s,before);}okay(s);
});
test('discard quote/cancel retains stock; confirmation affects only stated owner and count',()=>{
  const s=require('./test-current-fixture.cjs')();assert(action(s,'guard','potion','transfer','mage'));const before=clone(s),q=C.inventoryQuote(s,'mage','potion','discard');
  assert(q.ok);assert.deepEqual(s,before);assert(action(s,'mage','potion','discard',null,1,null,q.token));
  assert.equal(s.characters.mage.inventory.potion,undefined);assert.equal(s.characters.guard.inventory.potion,2);okay(s);
});
test('purchase requires explicit recipient; no old shared-stock API or arbitrary assignment',()=>{
  const s=require('./test-current-fixture.cjs')();s.location='south';const before=clone(s);assert.equal(C.buyItem(s,'potion',1),false);assert.deepEqual(s,before);
  assert(C.buyItem(s,'potion',1,'mage',C.inventoryToken(s)));assert.equal(s.characters.mage.inventory.potion,1);assert.equal(s.characters.guard.inventory.potion,3);assert.equal(s.gold,140);okay(s);
});
test('existing consumable total cap is retained without creating a per-character capacity',()=>{
  const s=require('./test-current-fixture.cjs')();s.location='south';s.gold=10000;s.characters.guard.inventory.potion=99;
  assert(action(s,'guard','potion','transfer','mage',50));assert.equal(s.characters.mage.inventory.potion,50);
  const before=clone(s);assert.equal(C.buyItem(s,'potion',1,'mage',C.inventoryToken(s)),false);assert.deepEqual(s,before);okay(s);
});
test('intervening resource change invalidates confirmation without consuming anything',()=>{
  const s=require('./test-current-fixture.cjs')();s.characters.mage.hp=1;const q=C.inventoryQuote(s,'guard','potion','use','mage');
  s.characters.mage.hp=2;const before=clone(s);assert.equal(action(s,'guard','potion','use','mage',1,null,q.token),false);assert.deepEqual(s,before);
});
test('ABA transfer and identical save reload cannot revive an old confirmation token',()=>{
  const s=require('./test-current-fixture.cjs')(),q=C.inventoryQuote(s,'guard','potion','discard');
  assert(action(s,'guard','potion','transfer','mage'));assert(action(s,'mage','potion','transfer','guard'));
  const before=clone(s);assert.equal(action(s,'guard','potion','discard',null,1,null,q.token),false);assert.deepEqual(s,before);
  const token=C.inventoryToken(s),loaded=C.deserialize(C.serialize(s));assert.notEqual(C.inventoryToken(loaded),token);
  assert.equal(action(loaded,'guard','potion','discard',null,1,null,token),false);okay(loaded);
});
test('buy and remove gear retain it with owner, no refund or duplicated placeholder items',()=>{
  const s=require('./test-current-fixture.cjs')();s.location='east';const before=total(s,'bow-wood');assert(C.buyGear(s,'archer','bow-wood-1','rightHand'));
  assert.equal(s.gold,40);assert.equal(s.characters.archer.inventory['bow-wood'],1);assert.equal(total(s,'bow-wood'),before);
  assert(action(s,'archer','bow-wood-1','unequip',null,1,'rightHand'));assert.equal(s.characters.archer.weapon,'empty-rightHand');
  assert.equal(s.characters.archer.inventory['bow-wood-1'],1);assert.equal(s.gold,40);
  assert(action(s,'archer','bow-wood','equip',null,1,'rightHand'));assert.equal(s.characters.archer.inventory['bow-wood'],undefined);okay(s);
});
test('hand occupancy and race restrictions remain authoritative when equipping owned gear',()=>{
  const s=require('./test-current-fixture.cjs')();s.characters.guard.inventory['bow-wood']=1;s.characters.mage.inventory['sword-iron-1']=1;
  const before=clone(s);assert.equal(action(s,'guard','bow-wood','equip',null,1,'rightHand'),false);
  assert.equal(action(s,'mage','sword-iron-1','equip',null,1,'rightHand'),false);assert.deepEqual(s,before);
  assert(action(s,'guard','guard-shield-wood','unequip',null,1,'leftHand'));
  assert(action(s,'guard','bow-wood','equip',null,1,'rightHand'));okay(s);
});
test('porter can re-equip own starter tool after removal without gaining attacks',()=>{
  const s=require('./test-current-fixture.cjs')();assert(action(s,'porter','porter-kit','unequip',null,1,'rightHand'));
  assert(action(s,'porter','porter-kit','equip',null,1,'rightHand'));assert.equal(C.stats(s.characters.porter).atk,0);okay(s);
});
test('new save rejects unknown, empty-slot, zero, negative and duplicated legacy stock',()=>{
  for(const mutate of [s=>s.characters.guard.inventory.missing=1,s=>s.characters.guard.inventory['empty-leftHand']=1,s=>s.characters.guard.inventory.potion=0,s=>s.characters.guard.inventory.potion=-1,s=>s.inventory={potion:3,ether:1}]){
    const s=require('./test-current-fixture.cjs')();mutate(s);assert.equal(C.validate(s).ok,false);assert.throws(()=>C.deserialize({format:'5525-native-campaign',version:2,state:s}));
  }
});
console.log(`PASS ${passed} character-inventory groups`);
