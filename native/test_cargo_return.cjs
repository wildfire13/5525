'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
function fight(s){
 assert(C.begin(s));
 for(let n=0;n<300&&!s.battle.result;n++){
  const b=clone(s.battle),actor=b.units.find(u=>u.id===b.actor);B.plan(b,actor);let {kind,target}=actor.intent;
  if(actor.job==='porter'){
   const hurt=b.units.filter(u=>u.side==='ally'&&u.hp>0&&u.hp<30).sort((a,b)=>a.hp-b.hp).find(u=>B.legal(b,'item',u.id));
   if(hurt){kind='item';target=hurt.id;}else{kind=B.legal(b,'skill',actor.id)?'skill':'guard';target=kind==='skill'?actor.id:null;}
  }
  assert(C.act(s,kind,target));
 }
 assert(s.battle.result&&!s.battle.failure);assert(C.finishBattle(s));assert.notEqual(s.result?.outcome,'failed');
}
function trip(s,to){
 let seed=5525;const rng=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
 assert(C.depart(s,to));for(let stage=0;stage<2;stage++){assert(C.travel(s,'safe',rng));fight(s);if(!stage){assert(C.rest(s));assert(C.onward(s));}}
 const cash=s.gold,bag=clone(s.characters);assert(C.arrive(s));assert.equal(s.phase,'town');assert.equal(s.gold,cash);assert.deepEqual(s.characters,bag);
 assert.deepEqual(C.deserialize(C.serialize(s)),s);
}
const s=C.create();assert(C.accept(s,C.board(s)[0].id,'porter'));const id=s.activeQuest.cargoItemId;
assert(C.select(s,['guard','archer','mage','scout']));trip(s,'east');
assert(!C.completeQuest(s));assert(s.activeQuest&&s.characters.porter.inventory[id]===1);
trip(s,'astaris');assert(C.select(s,['guard','archer','mage','scout','porter']));assert(C.inn(s));
const potions=C.inventoryQuote(s,'guard','potion','transfer','porter',3);
assert(potions.ok&&C.inventoryAction(s,'guard','potion','transfer','porter',3,null,potions.token));
assert(!C.completeQuest(s));trip(s,'east');
assert.equal(s.activeQuest.elapsedHours,36);assert(C.completeQuest(s));assert.equal(s.result.gold,117);assert(!s.characters.porter.inventory[id]);assert(!C.completeQuest(s));
console.log(JSON.stringify({passed:true,checks:1,actualBattles:6,hours:36,lateReward:117,route:['astaris','east','astaris','east'],warp:false}));
