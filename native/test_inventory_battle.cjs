'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js'),{Presentation}=require('./battle-presentation.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));let passed=0;const test=(name,fn)=>{fn();passed++;console.log('PASS '+name);};
const transfer=(s,id,target,n=1)=>C.inventoryAction(s,"character_mirei",id,'transfer',target,n,null,C.inventoryToken(s));
// The current scout's bare fist is self-only. The porter's starter fist
// grants level 3 item use, so it can exercise owner-to-ally recovery.
const itemOwner='character_yuno';
function battle(){
  const s=require('./test-current-fixture.cjs')();
  assert(C.select(s,['character_mirei','character_kyle','character_merina','character_rio','character_yuno']));
  s.characters['character_mirei'].inventory={potion:3,ether:1};
  assert(transfer(s,'potion',itemOwner));assert(transfer(s, 'ether',itemOwner));assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));return s;
}
function choose(s,id){for(const u of s.battle.units)u.next=100000;const a=s.battle.units.find(u=>u.id===id);a.next=1;s.battle.actor=id;if(id==='character_kyle'){const g=s.battle.units.find(u=>u.id==="character_mirei");a.pos=23;g.pos=24;}return a;}
function okay(s){assert.equal(C.validate(s).ok,true,C.validate(s).error);const before=clone(s),loaded=C.deserialize(C.serialize(s));assert.deepEqual(clone(s),before);assert.deepEqual(C.deserialize(C.serialize(loaded)),clone(loaded));}
test('item catalog keeps item identities and exposes semantic action and role IDs',()=>{
  const definitions=C.view(C.create()).itemDefinitions;
  assert.deepEqual(definitions.map(({id,battleKind,battleRole})=>({id,battleKind,battleRole})),[
    {id:'potion',battleKind:'action_item',battleRole:undefined},
    {id:'ether',battleKind:'action_ether',battleRole:'job_porter'},
  ]);
});
test('only actor-owned stock makes item legal; another owner and reserves cannot provide it',()=>{
  const s=battle(),b=s.battle,mage=choose(s,"character_merina"),guard=b.units.find(u=>u.id==="character_mirei");guard.hp-=20;
  assert.equal(b.potions.ally,3);assert.equal(B.legalFor(b,mage,'action_item',guard.id),false);
  const before=clone(s);assert.equal(C.act(s,'action_item',guard.id),false);assert.deepEqual(clone(s),before);
  const a=choose(s,itemOwner);assert(B.legalFor(b,a,'action_item',guard.id));assert.equal(b.itemInventories["character_mirei"].potion,2);okay(s);
});
test('legal preview/cancel is pure; action consumes owner once and leaves other stock exact',()=>{
  const s=battle(),b=s.battle,a=choose(s,itemOwner),guard=b.units.find(u=>u.id==="character_mirei");guard.hp-=30;
  const before=clone(s),prediction=B.effectPreview(b,a,'action_item',guard.id);assert.equal(prediction.find(e=>e.id===guard.id).hp,30);assert.deepEqual(clone(s),before);
  assert(C.act(s,'action_item',guard.id));assert.equal(b.itemInventories[itemOwner].potion,0);assert.equal(b.itemInventories["character_mirei"].potion,2);assert.equal(b.potions.ally,2);okay(s);
  choose(s,itemOwner);const used=clone(s);guard.hp-=1;const noStock=clone(s);assert.equal(C.act(s,'action_item',guard.id),false);assert.deepEqual(clone(s),noStock);assert.equal(used.battle.itemInventories["character_mirei"].potion,2);
});
test('ether still needs porter role, has infinite range and consumes the porter inventory',()=>{
  const s=battle(),b=s.battle,p=choose(s,"character_yuno"),guard=b.units.find(u=>u.id==="character_mirei");p.pos=0;guard.pos=49;guard.mp=0;
  assert(B.legalFor(b,p,'action_ether',guard.id));assert.equal(B.legalFor(b,guard,'action_ether',guard.id),false);assert(C.act(s,'action_ether',guard.id));assert.equal(guard.mp,3);assert.equal(b.itemInventories["character_yuno"].ether,0);assert.equal(b.ethers,0);
  assert.equal(C.inventoryAction(s,"character_mirei",'potion','transfer',"character_yuno",1,null,C.inventoryToken(s)),false,'battle transfer is not introduced');
});
test('victory returns per-owner remainder once; save before and after cannot duplicate stock',()=>{
   let s=battle();const b=s.battle;choose(s,itemOwner);b.units.find(u=>u.id==="character_mirei").hp-=20;assert(C.act(s,'action_item',"character_mirei"));
  s=C.deserialize(C.serialize(s));for(const e of s.battle.units.filter(u=>u.side==='enemy'))e.hp=0;s.battle.result='victory';s.battle.actor=null;
   assert(C.finishBattle(s));assert.equal(s.characters[itemOwner].inventory.potion,undefined);assert.equal(s.characters["character_mirei"].inventory.potion,2);assert.equal(s.characters["character_yuno"].inventory.ether,1);assert.equal(C.finishBattle(s),false);okay(s);
});
test('retreat and porter defeat restore each owner exactly to predeparture snapshot',()=>{
  for(const defeat of [false,true]){
    const s=battle(),before=clone(s.rollback);choose(s,itemOwner);s.battle.units.find(u=>u.id==="character_mirei").hp-=20;assert(C.act(s,'action_item',"character_mirei"));
    if(defeat){s.battle.units.find(u=>u.id==="character_yuno").hp=0;s.battle.failure='porter';s.battle.result='defeat';s.battle.actor=null;assert(C.finishBattle(s));}else assert(C.retreat(s));
    for(const id of Object.keys(before.characters))assert.deepEqual(s.characters[id].inventory,before.characters[id].inventory);okay(s);
  }
});
test('presentation frames conserve owner counts and cannot accept a duplicate pending action',()=>{
  const s=battle(),b=s.battle;choose(s,itemOwner);b.units.find(u=>u.id==="character_mirei").hp-=20;
  const presentation=new Presentation();assert(presentation.start(b,B,()=>C.act(s,'action_item',"character_mirei")));
  assert.throws(()=>presentation.start(b,B,()=>C.act(s,'action_item',"character_mirei")));
  while(presentation.pending){assert.equal(b.itemInventories["character_mirei"].potion,2);assert.equal(b.potions.ally,Object.values(b.itemInventories).reduce((n,bag)=>n+bag.potion,0));const step=presentation.info();presentation.next(step.id,step.index);}
  assert.equal(b.itemInventories[itemOwner].potion,0);okay(s);
});
test('forged ownership, totals and missing battle inventory reject without changing running state',()=>{
  const original=battle();for(const edit of [s=>delete s.battle.itemInventories,s=>s.battle.itemInventories["character_merina"].potion=1,s=>s.battle.potions.ally++,s=>s.battle.itemInventories[itemOwner].potion=-1,s=>delete s.battle.itemInventories[itemOwner]]){
    const bad=clone(original);edit(bad);assert.equal(C.validate(bad).ok,false);assert.throws(()=>C.deserialize({format:'5525-native-campaign',version:C.VERSION,cargoRevision:1,state:bad}));
  }okay(original);
});
console.log(`PASS ${passed} inventory-battle groups`);
