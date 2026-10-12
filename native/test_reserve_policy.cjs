'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
const copy=x=>JSON.parse(JSON.stringify(x));
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
function fixture(){
  const s=C.create(),c=s.characters.warrior;
  c.inventory={potion:7,ether:2,'sword-wood':2};c.hp=31;c.mp=1;
  c.level=2;c.xp=100;c.statPoints=2;c.skillPoints=1;
  s.characters.guard.hp=20;s.characters.guard.mp=1;
  s.gold=1000;assert(C.validate(s).ok);return s;
}
function unchanged(s,fn,expected=false){const before=copy(s);assert.equal(fn(),expected);assert.deepEqual(s,before);}
function action(s,owner,id,kind,target=null,slot=null){
  assert.equal(C.inventoryQuote(s,owner,id,kind,target,1,slot).ok,false);
  unchanged(s,()=>C.inventoryAction(s,owner,id,kind,target,1,slot,C.inventoryToken(s)));
}
for(const place of ['astaris','east','west','north','south'])test('reserve inventory refusal matrix in '+place,()=>{
  const s=fixture();s.location=place;
  for(const phase of ['town','camp']){
    s.phase=phase;
    action(s,'warrior','potion','use','guard');
    action(s,'warrior','ether','use','guard');
    action(s,'guard','potion','use','warrior');
    action(s,'guard','ether','use','warrior');
    action(s,'warrior','potion','transfer','guard');
    action(s,'guard','potion','transfer','warrior');
    action(s,'warrior','sword-wood','transfer','guard');
    action(s,'warrior','potion','discard');
    action(s,'warrior','sword-wood','equip',null,'rightHand');
    action(s,'warrior','hammer-iron-1','unequip',null,'rightHand');
    unchanged(s,()=>C.useItem(s,'potion','guard','warrior',C.inventoryToken(s)));
  }
});
test('reserve cannot purchase, receive a plan, sell, grow, or start a trial',()=>{
  const s=fixture();
  for(const place of ['astaris','east','west','north','south']){
    s.location=place;
    unchanged(s,()=>C.buyItem(s,'potion',1,'warrior',C.inventoryToken(s)));
    unchanged(s,()=>C.buyGear(s,'warrior','sword-wood','rightHand'));
    const rows=[{characterId:'warrior',gearId:'sword-wood',slot:'rightHand'}],q=C.purchasePlan(s,rows);
    assert.equal(q.ok,false);unchanged(s,()=>C.buyPlan(s,rows,q.token));
    assert.equal(C.saleQuote(s,'warrior','sword-wood',1).ok,false);
    unchanged(s,()=>C.sellInventory(s,'warrior','sword-wood',1,C.inventoryToken(s)));
    unchanged(s,()=>C.allocate(s,'warrior','str',1));
    unchanged(s,()=>C.allocateBatch(s,'warrior',{str:1,int:0,agi:0},C.allocationToken(s,'warrior')));
    unchanged(s,()=>C.trial(s,'warrior','sword-wood','rightHand'),null);
  }
});
test('selected allies still act; leaving and rejoining keeps every personal field exact',()=>{
  let s=fixture();const old=copy(s.characters.warrior),others=copy(s.characters);
  assert(C.select(s,['guard','warrior','porter']));assert.deepEqual(s.characters,others);
  assert(C.allocateBatch(s,'warrior',{str:1,int:0,agi:0},C.allocationToken(s,'warrior')));
  const grown=copy(s.characters.warrior);assert(C.select(s,['guard','porter']));
  s=C.deserialize(C.serialize(s));assert.deepEqual(s.characters.warrior,grown);
  assert(C.select(s,['porter','warrior','guard']));assert.deepEqual(s.characters.warrior,grown);
  assert.deepEqual(grown.inventory,old.inventory);assert.equal(grown.weapon,old.weapon);
  assert(C.inventoryAction(s,'warrior','potion','use','guard',1,null,C.inventoryToken(s)));
  assert.equal(s.characters.warrior.inventory.potion,6);assert(C.validate(s).ok);
});
test('reserve stocks survive departure, retreat, rollback and repeated save-load exactly',()=>{
  let s=fixture();const reserve=copy(s.characters.warrior);
  assert(C.depart(s,'east'));assert.deepEqual(s.rollback.characters.warrior,reserve);
  s=C.deserialize(C.serialize(s));assert.equal(s.location,'astaris');assert.equal(s.phase,'road');
  assert.deepEqual(s.characters.warrior,reserve);
  C.travel(s,'safe',()=>.2);assert(s.battle);C.begin(s);assert(C.retreat(s));assert(C.acknowledge(s));
  s=C.deserialize(C.serialize(s));assert.deepEqual(s.characters.warrior,reserve);
  assert(C.select(s,['porter','warrior']));assert.deepEqual(s.characters.warrior,reserve);
});
test('old confirmations cannot mutate a removed character or buy for a reserve',()=>{
  const s=fixture();assert(C.select(s,['guard','warrior','porter']));
  const token=C.inventoryToken(s),allocation=C.allocationToken(s,'warrior');
  assert(C.select(s,['guard','porter']));
  unchanged(s,()=>C.inventoryAction(s,'warrior','potion','discard',null,1,null,token));
  unchanged(s,()=>C.allocateBatch(s,'warrior',{str:1,int:0,agi:0},allocation));
  assert(C.select(s,['guard','warrior','porter']));
  unchanged(s,()=>C.inventoryAction(s,'warrior','potion','discard',null,1,null,token));
});
test('training supporters always accompany the party, including alternative and solo porters',()=>{
  for(const ids of [['warrior','porter'],['guard-2','mage-2','porter-2'],['porter'],['porter','porter-2']]){
    const s=fixture();assert(C.select(s,ids));s.location='north';const before=copy(s);
    for(const id of ids){
      const t=C.trial(s,id,'victory-earring-1');assert(t);
      assert(t.battle.units.filter(u=>u.side==='ally').every(u=>ids.includes(u.id)));
      assert.deepEqual(s,before);
      if(ids.length===1){assert.equal(t.supportActorId,null);assert.match(t.metadata.notice,/仲間を編成/);assert(C.trialAct(t,'guard'));}
    }
  }
});
console.log(`PASS ${passed} reserve-policy groups`);
