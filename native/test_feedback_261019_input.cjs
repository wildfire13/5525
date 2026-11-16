'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js'),B=require('./campaign-battle.js');
function fixture(porter=false){
 const s=C.create(),id=porter?'character_yuno':'character_rio';
 assert(C.select(s,[id,'character_merina']));
 if(!porter){s.characters[id].weapon='empty-rightHand';s.characters[id].leftHand='empty-leftHand';}
 s.characters[id].inventory.potion=2;s.characters[id].hp-=20;s.characters['character_merina'].hp-=20;
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
 s.battle.actor=id;return s;
}
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('Lv3 fists reject every non-porter through eligibility, equip quotes and saved equipment validation',()=>{
 for(const {id} of B.recruitRoster.filter(u=>u.job!=='job_porter')){
  const s=C.create(),before=C.serialize(s);const result=C.eligibility(s,id,'fist-2');
  assert(!result.ok);assert(result.reason.includes('ポーター専用'));
  for(const slot of ['rightHand','leftHand'])assert(!C.inventoryQuote(s,id,'fist-2','equip',null,1,slot).ok);
  assert.equal(C.serialize(s),before);
  const bad=structuredClone(s);bad.characters[id].weapon='fist-2';assert(!C.validate(bad).ok);
 }
});
test('porter defaults expose Lv3 without generating stock or permitting attack',()=>{
 const s=C.create(),st=C.stats(s.characters["character_yuno"]);assert.equal(B.itemUseLevel(st),3);assert.deepEqual(st.attackWeapons,[]);
 assert.equal(s.characters["character_yuno"].inventory['fist-2'],undefined);assert(!C.shop(s).some(g=>g.id==='fist-2'));
 const b=fixture(true).battle,a=b.units.find(u=>u.id==="character_yuno"),enemy=b.units.find(u=>u.side==='enemy');
 assert(!B.legalFor(b,a,'action_attack',enemy.id));
});
test('current empty hands and porter whistle check all fifty target cells',()=>{
 for(const [name,level] of [['item1',1],['item3',3]]){
  const b=fixture(level===3).battle,a=b.units.find(u=>u.id===b.actor),ally=b.units.find(u=>u.id==="character_merina"),before=structuredClone(b);
  assert.equal(B.itemUseLevel(a),level);assert(B.legalFor(b,a,'action_item',a.id));
  for(let pos=0;pos<50;pos++){
   ally.pos=pos;const distance=Math.abs(pos%10-a.pos%10)+Math.abs(Math.floor(pos/10)-Math.floor(a.pos/10));
   assert.equal(B.legalFor(b,a,'action_item',ally.id),level===3||level===2&&distance<=1,name+' pos '+pos);
  }
  const enemy=b.units.find(u=>u.side==='enemy');enemy.hp--;assert(!B.legalFor(b,a,'action_item',enemy.id));
  assert.equal(b.actions,before.actions);assert.deepEqual(b.itemInventories,before.itemInventories);
 }
});
test('current non-porter cannot forge Lv3 sources',()=>{
 {
  const s=fixture(),a=s.battle.units.find(u=>u.id===s.battle.actor);
  for(const source of a.skillSources)if(source.id==='skill_item_use')source.level=3;
  assert(!C.validate(s).ok);
 }
});
console.log('PASS '+count+' input-review rule groups');
