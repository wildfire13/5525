'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js'),B=require('./campaign-battle.js');
function fixture(porter=false){
 const s=C.create(),id=porter?'recruit-porter-human-female':'recruit-scout-human-female';
 assert(C.select(s,[id,'recruit-mage-elf-female']));
 if(!porter){s.characters[id].weapon='empty-rightHand';s.characters[id].leftHand='empty-leftHand';}
 s.characters[id].inventory.potion=2;s.characters[id].hp-=20;s.characters['recruit-mage-elf-female'].hp-=20;
 assert(C.depart(s,'east'));assert(C.travel(s,'safe',()=>0));assert(C.begin(s));
 s.battle.actor=id;return s;
}
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('Lv3 fists reject every non-porter through eligibility, equip quotes and saved equipment validation',()=>{
 for(const {id} of B.recruitRoster.filter(u=>u.job!=='porter')){
  const s=C.create(),before=C.serialize(s);const result=C.eligibility(s,id,'fist-2');
  assert(!result.ok);assert(result.reason.includes('ポーター専用'));
  for(const slot of ['rightHand','leftHand'])assert(!C.inventoryQuote(s,id,'fist-2','equip',null,1,slot).ok);
  assert.equal(C.serialize(s),before);
  const bad=structuredClone(s);bad.characters[id].weapon='fist-2';assert(!C.validate(bad).ok);
 }
});
test('porter defaults expose Lv3 without generating stock or permitting attack',()=>{
 const s=C.create(),st=C.stats(s.characters["recruit-porter-human-female"]);assert.equal(B.itemUseLevel(st),3);assert.deepEqual(st.attackWeapons,[]);
 assert.equal(s.characters["recruit-porter-human-female"].inventory['fist-2'],undefined);assert(!C.shop(s).some(g=>g.id==='fist-2'));
 const b=fixture(true).battle,a=b.units.find(u=>u.id==="recruit-porter-human-female"),enemy=b.units.find(u=>u.side==='enemy');
 assert(!B.legalFor(b,a,'attack',enemy.id));
});
test('current empty hands and porter whistle check all fifty target cells',()=>{
 for(const [name,level] of [['item1',1],['item3',3]]){
  const b=fixture(level===3).battle,a=b.units.find(u=>u.id===b.actor),ally=b.units.find(u=>u.id==="recruit-mage-elf-female"),before=structuredClone(b);
  assert.equal(B.itemUseLevel(a),level);assert(B.legalFor(b,a,'item',a.id));
  for(let pos=0;pos<50;pos++){
   ally.pos=pos;const distance=Math.abs(pos%10-a.pos%10)+Math.abs(Math.floor(pos/10)-Math.floor(a.pos/10));
   assert.equal(B.legalFor(b,a,'item',ally.id),level===3||level===2&&distance<=1,name+' pos '+pos);
  }
  const enemy=b.units.find(u=>u.side==='enemy');enemy.hp--;assert(!B.legalFor(b,a,'item',enemy.id));
  assert.equal(b.actions,before.actions);assert.deepEqual(b.itemInventories,before.itemInventories);
 }
});
test('current non-porter cannot forge Lv3 sources',()=>{
 {
  const s=fixture(),a=s.battle.units.find(u=>u.id===s.battle.actor);
  for(const source of a.skillSources)if(source.id==='itemUse')source.level=3;
  assert(!C.validate(s).ok);
 }
});
console.log('PASS '+count+' input-review rule groups');
