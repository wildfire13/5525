'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
const copy=x=>JSON.parse(JSON.stringify(x));
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
function fixture(){
  const s=require('./test-current-fixture.cjs')(),c=s.characters["character_grant"];
  c.inventory={potion:7,ether:2,'sword-wood':2};c.hp=31;c.mp=1;
  c.level=2;c.xp=100;c.statPoints=2;c.skillPoints=1;
  s.characters["character_mirei"].hp=20;s.characters["character_mirei"].mp=1;
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
    action(s,"character_grant",'potion','use',"character_mirei");
    action(s,"character_grant", 'ether','use',"character_mirei");
    action(s,"character_mirei",'potion','use',"character_grant");
    action(s,"character_mirei", 'ether','use',"character_grant");
    action(s,"character_grant",'potion','transfer',"character_mirei");
    action(s,"character_mirei",'potion','transfer',"character_grant");
    action(s,"character_grant",'sword-wood','transfer',"character_mirei");
    action(s,"character_grant",'potion','discard');
    action(s,"character_grant",'sword-wood','equip',null,'rightHand');
    action(s,"character_grant",'hammer-iron-1','unequip',null,'rightHand');
    unchanged(s,()=>C.useItem(s,'potion',"character_mirei","character_grant",C.inventoryToken(s)));
  }
});
test('reserve cannot purchase, receive a plan, sell, grow, or start a trial',()=>{
  const s=fixture();
  for(const place of ['astaris','east','west','north','south']){
    s.location=place;
    unchanged(s,()=>C.buyItem(s,'potion',1,"character_grant",C.inventoryToken(s)));
    unchanged(s,()=>C.buyGear(s,"character_grant",'sword-wood','rightHand'));
    const rows=[{characterId:"character_grant",gearId:'sword-wood',slot:'rightHand'}],q=C.purchasePlan(s,rows);
    assert.equal(q.ok,false);unchanged(s,()=>C.buyPlan(s,rows,q.token));
    assert.equal(C.saleQuote(s,"character_grant",'sword-wood',1).ok,false);
    unchanged(s,()=>C.sellInventory(s,"character_grant",'sword-wood',1,C.inventoryToken(s)));
    unchanged(s,()=>C.allocate(s,"character_grant",'str',1));
    unchanged(s,()=>C.allocateBatch(s,"character_grant",{str:1,int:0,agi:0},C.allocationToken(s,"character_grant")));
    unchanged(s,()=>C.trial(s,"character_grant",'sword-wood','rightHand'),null);
  }
});
test('selected allies still act; leaving and rejoining keeps every personal field exact',()=>{
  let s=fixture();const old=copy(s.characters["character_grant"]),others=copy(s.characters);
  assert(C.select(s,["character_mirei","character_grant","character_yuno"]));assert.deepEqual(s.characters,others);
  assert(C.allocateBatch(s,"character_grant",{str:1,int:0,agi:0},C.allocationToken(s,"character_grant")));
  const grown=copy(s.characters["character_grant"]);assert(C.select(s,["character_mirei","character_yuno"]));
  s=C.deserialize(C.serialize(s));assert.deepEqual(s.characters["character_grant"],grown);
  assert(C.select(s,["character_yuno","character_grant","character_mirei"]));assert.deepEqual(s.characters["character_grant"],grown);
  assert.deepEqual(grown.inventory,old.inventory);assert.equal(grown.weapon,old.weapon);
  assert(C.inventoryAction(s,"character_grant",'potion','use',"character_mirei",1,null,C.inventoryToken(s)));
  assert.equal(s.characters["character_grant"].inventory.potion,6);assert(C.validate(s).ok);
});
test('reserve stocks survive departure, retreat, rollback and repeated save-load exactly',()=>{
  let s=fixture();const reserve=copy(s.characters["character_grant"]);
  assert(C.depart(s,'east'));assert.deepEqual(s.rollback.characters["character_grant"],reserve);
  s=C.deserialize(C.serialize(s));assert.equal(s.location,'astaris');assert.equal(s.phase,'road');
  assert.deepEqual(s.characters["character_grant"],reserve);
  C.travel(s,'safe',()=>.2);assert(s.battle);C.begin(s);assert(C.retreat(s));assert(C.acknowledge(s));
  s=C.deserialize(C.serialize(s));assert.deepEqual(s.characters["character_grant"],reserve);
  assert(C.select(s,["character_yuno","character_grant"]));assert.deepEqual(s.characters["character_grant"],reserve);
});
test('old confirmations cannot mutate a removed character or buy for a reserve',()=>{
  const s=fixture();assert(C.select(s,["character_mirei","character_grant","character_yuno"]));
  const token=C.inventoryToken(s),allocation=C.allocationToken(s,"character_grant");
  assert(C.select(s,["character_mirei","character_yuno"]));
  unchanged(s,()=>C.inventoryAction(s,"character_grant",'potion','discard',null,1,null,token));
  unchanged(s,()=>C.allocateBatch(s,"character_grant",{str:1,int:0,agi:0},allocation));
  assert(C.select(s,["character_mirei","character_grant","character_yuno"]));
  unchanged(s,()=>C.inventoryAction(s,"character_grant",'potion','discard',null,1,null,token));
});
test('training supporters always accompany the party, including alternative and solo porters',()=>{
  for(const ids of [['character_grant','character_yuno'],['character_sera','character_roze','character_teo'],['character_yuno'],['character_yuno','character_teo']]){
    const s=fixture();assert(C.select(s,ids));s.location='north';const before=copy(s);
    for(const id of ids){
      const t=C.trial(s,id,'victory-earring-1');assert(t);
      assert(t.battle.units.filter(u=>u.side==='ally').every(u=>ids.includes(u.id)));
      assert.deepEqual(s,before);
      if(ids.length===1){assert.equal(t.supportActorId,null);assert.match(t.metadata.notice,/仲間を編成/);assert(C.trialAct(t, 'action_defend'));}
    }
  }
});
console.log(`PASS ${passed} reserve-policy groups`);
