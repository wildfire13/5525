'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),C=require('./campaign.js'),B=require('./campaign-battle.js'),{Presentation}=require('./battle-presentation.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));let passed=0;const test=(name,fn)=>{fn();passed++;console.log('PASS '+name);};
const transfer=(s,id,target,n=1)=>C.inventoryAction(s,'guard',id,'transfer',target,n,null,C.inventoryToken(s));
function battle(){
  const s=C.create();s.characters.archer.weapon='fist-1';assert(transfer(s,'potion','archer'));assert(transfer(s,'ether','porter'));assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));return s;
}
function choose(s,id){for(const u of s.battle.units)u.next=100000;const a=s.battle.units.find(u=>u.id===id);a.next=1;s.battle.actor=id;if(id==='archer'){const g=s.battle.units.find(u=>u.id==='guard');a.pos=23;g.pos=24;}return a;}
function okay(s){assert.equal(C.validate(s).ok,true,C.validate(s).error);const before=clone(s),loaded=C.deserialize(C.serialize(s));assert.deepEqual(clone(s),before);assert.deepEqual(C.deserialize(C.serialize(loaded)),clone(loaded));}
test('only actor-owned stock makes item legal; another owner and reserves cannot provide it',()=>{
  const s=battle(),b=s.battle,mage=choose(s,'mage'),guard=b.units.find(u=>u.id==='guard');guard.hp-=20;
  assert.equal(b.potions.ally,3);assert.equal(B.legalFor(b,mage,'item',guard.id),false);
  const before=clone(s);assert.equal(C.act(s,'item',guard.id),false);assert.deepEqual(clone(s),before);
  const a=choose(s,'archer');assert(B.legalFor(b,a,'item',guard.id));assert.equal(b.itemInventories.guard.potion,2);okay(s);
});
test('legal preview/cancel is pure; action consumes owner once and leaves other stock exact',()=>{
  const s=battle(),b=s.battle,a=choose(s,'archer'),guard=b.units.find(u=>u.id==='guard');guard.hp-=30;
  const before=clone(s),prediction=B.effectPreview(b,a,'item',guard.id);assert.equal(prediction.find(e=>e.id===guard.id).hp,30);assert.deepEqual(clone(s),before);
  assert(C.act(s,'item',guard.id));assert.equal(b.itemInventories.archer.potion,0);assert.equal(b.itemInventories.guard.potion,2);assert.equal(b.potions.ally,2);okay(s);
  choose(s,'archer');const used=clone(s);guard.hp-=1;const noStock=clone(s);assert.equal(C.act(s,'item',guard.id),false);assert.deepEqual(clone(s),noStock);assert.equal(used.battle.itemInventories.guard.potion,2);
});
test('ether still needs porter role, has infinite range and consumes the porter inventory',()=>{
  const s=battle(),b=s.battle,p=choose(s,'porter'),guard=b.units.find(u=>u.id==='guard');p.pos=0;guard.pos=49;guard.mp=0;
  assert(B.legalFor(b,p,'ether',guard.id));assert.equal(B.legalFor(b,guard,'ether',guard.id),false);assert(C.act(s,'ether',guard.id));assert.equal(guard.mp,3);assert.equal(b.itemInventories.porter.ether,0);assert.equal(b.ethers,0);
  assert.equal(C.inventoryAction(s,'guard','potion','transfer','porter',1,null,C.inventoryToken(s)),false,'battle transfer is not introduced');
});
test('victory returns per-owner remainder once; save before and after cannot duplicate stock',()=>{
  let s=battle();const b=s.battle;choose(s,'archer');b.units.find(u=>u.id==='guard').hp-=20;assert(C.act(s,'item','guard'));
  s=C.deserialize(C.serialize(s));for(const e of s.battle.units.filter(u=>u.side==='enemy'))e.hp=0;s.battle.result='victory';s.battle.actor=null;
  assert(C.finishBattle(s));assert.equal(s.characters.archer.inventory.potion,undefined);assert.equal(s.characters.guard.inventory.potion,2);assert.equal(s.characters.porter.inventory.ether,1);assert.equal(C.finishBattle(s),false);okay(s);
});
test('retreat and porter defeat restore each owner exactly to predeparture snapshot',()=>{
  for(const defeat of [false,true]){
    const s=battle(),before=clone(s.rollback);choose(s,'archer');s.battle.units.find(u=>u.id==='guard').hp-=20;assert(C.act(s,'item','guard'));
    if(defeat){s.battle.units.find(u=>u.id==='porter').hp=0;s.battle.failure='porter';s.battle.result='defeat';s.battle.actor=null;assert(C.finishBattle(s));}else assert(C.retreat(s));
    for(const id of Object.keys(before.characters))assert.deepEqual(s.characters[id].inventory,before.characters[id].inventory);okay(s);
  }
});
test('presentation frames conserve owner counts and cannot accept a duplicate pending action',()=>{
  const s=battle(),b=s.battle;choose(s,'archer');b.units.find(u=>u.id==='guard').hp-=20;
  const presentation=new Presentation();assert(presentation.start(b,B,()=>C.act(s,'item','guard')));
  assert.throws(()=>presentation.start(b,B,()=>C.act(s,'item','guard')));
  while(presentation.pending){assert.equal(b.itemInventories.guard.potion,2);assert.equal(b.potions.ally,Object.values(b.itemInventories).reduce((n,bag)=>n+bag.potion,0));const step=presentation.info();presentation.next(step.id,step.index);}
  assert.equal(b.itemInventories.archer.potion,0);okay(s);
});
test('v1 active battle preserves spent amounts and original source; v2 reload never redistributes',()=>{
  const original=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/campaign-a51a773-battle.json'),'utf8'));original.state.inventory.potion=3;original.state.battle.potions.ally=1;
  const before=JSON.stringify(original),s=C.deserialize(original),first=s.selected[0];assert.equal(JSON.stringify(original),before);
  assert.equal(s.characters[first].inventory.potion,3,'prebattle ownership snapshot retained');assert.equal(s.battle.itemInventories[first].potion,1,'only unspent stock remains usable');
  assert(s.selected.filter(id=>id!==first).every(id=>s.battle.itemInventories[id].potion===0));okay(s);
});
test('forged ownership, totals and missing battle inventory reject without changing running state',()=>{
  const original=battle();for(const edit of [s=>delete s.battle.itemInventories,s=>s.battle.itemInventories.mage.potion=1,s=>s.battle.potions.ally++,s=>s.battle.itemInventories.archer.potion=-1,s=>delete s.battle.itemInventories.archer]){
    const bad=clone(original);edit(bad);assert.equal(C.validate(bad).ok,false);assert.throws(()=>C.deserialize({format:'5525-native-campaign',version:2,state:bad}));
  }okay(original);
});
console.log(`PASS ${passed} inventory-battle groups`);
