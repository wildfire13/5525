'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js'),B=require('./campaign-battle.js');
const fixtures=require('../godot/tests/feedback_261019_fixtures.cjs');
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('Lv3 fists reject every non-porter through eligibility, equip quotes and saved equipment validation',()=>{
 for(const id of ['guard','archer','mage','scout']){
  const s=C.create(),before=C.serialize(s);const result=C.eligibility(s,id,'fist-2');
  assert(!result.ok);assert(result.reason.includes('ポーター専用'));
  for(const slot of ['rightHand','leftHand'])assert(!C.inventoryQuote(s,id,'fist-2','equip',null,1,slot).ok);
  assert.equal(C.serialize(s),before);
  const bad=structuredClone(s);bad.characters[id].weapon='fist-2';assert(!C.validate(bad).ok);
 }
});
test('porter defaults expose Lv3 without generating stock or permitting attack',()=>{
 const s=C.create(),st=C.stats(s.characters.porter);assert.equal(B.skillLevel(st,'itemUse'),3);assert.deepEqual(st.attackWeapons,[]);
 assert.equal(s.characters.porter.inventory['fist-2'],undefined);assert(!C.shop(s).some(g=>g.id==='fist-2'));
 const b=C.deserialize(fixtures.item3).battle,a=b.units.find(u=>u.id==='porter'),enemy=b.units.find(u=>u.side==='enemy');
 assert(!B.legalFor(b,a,'attack',enemy.id));
});
test('item use checks all fifty target cells: Lv1 self, Lv2 orthogonal adjacency, Lv3 unrestricted',()=>{
 for(const [name,level] of [['item1',1],['item2',2],['item3',3]]){
  const b=C.deserialize(fixtures[name]).battle,a=b.units.find(u=>u.id===b.actor),ally=b.units.find(u=>u.id==='mage'),before=structuredClone(b);
  assert.equal(B.itemUseLevel(a),level);assert(B.legalFor(b,a,'item',a.id));
  for(let pos=0;pos<50;pos++){
   ally.pos=pos;const distance=Math.abs(pos%10-a.pos%10)+Math.abs(Math.floor(pos/10)-Math.floor(a.pos/10));
   assert.equal(B.legalFor(b,a,'item',ally.id),level===3||level===2&&distance<=1,name+' pos '+pos);
  }
  const enemy=b.units.find(u=>u.side==='enemy');enemy.hp--;assert(!B.legalFor(b,a,'item',enemy.id));
  assert.equal(b.actions,before.actions);assert.deepEqual(b.itemInventories,before.itemInventories);
 }
});
test('non-porter save cannot forge Lv3 sources while wearing Lv1 or Lv2 fists',()=>{
 for(const name of ['item1','item2']){
  const s=C.deserialize(fixtures[name]),a=s.battle.units.find(u=>u.id===s.battle.actor);
  for(const source of a.skillSources)if(source.id==='itemUse')source.level=3;
  assert(!C.validate(s).ok);
 }
});
console.log('PASS '+count+' input-review rule groups');
