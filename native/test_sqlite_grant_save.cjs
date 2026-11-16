'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));
let count=0;function test(name,fn){fn();count++;console.log('PASS '+name);}
function town(){const s=require('./test-current-fixture.cjs')();s.location='east';s.gold=5000;return s;}
function battle(s){assert.ok(C.depart(s,'astaris'));assert.ok(C.travel(s,'safe',()=>.2));assert.ok(C.begin(s));return s.battle;}
function returnRings(){
 const s=town(),id='recruit-guard-human-female';s.location='north';
 assert.ok(C.buyGear(s,id,'return-ring-1','accessory1'));assert.ok(C.buyGear(s,id,'return-ring-2','accessory2'));
 // Both displaced capacity belts are retained. Discard them explicitly so
 // departure tests the rings, not the unrelated inventory-capacity gate.
 for(const item of ['pouch-belt','pouch-belt-3']){
  assert.equal(s.characters[id].inventory[item],1);
  assert.ok(C.inventoryAction(s,id,item,'discard',null,1,null,C.inventoryToken(s)));
 }
 assert.deepEqual(C.inventoryView(s,id).capacity.overflow,[]);roundtrip(s);return s;
}
function roundtrip(s){const result=C.deserialize(C.serialize(s));assert.deepEqual(result,clone(s));return result;}
test('two owned copies equip separately and inventory consumption is atomic',()=>{
 const s=town(),c=s.characters["recruit-mage-elf-female"];
 c.inventory['staff-wood']=1;
 const q=C.inventoryQuote(s,"recruit-mage-elf-female",'staff-wood','equip',null,1,'leftHand');assert.ok(q.ok);
 assert.ok(C.inventoryAction(s,"recruit-mage-elf-female",'staff-wood','equip',null,1,'leftHand',q.token));
 assert.equal(c.inventory['staff-wood']||0,0);assert.equal(c.weapon,'staff-wood');assert.equal(c.leftHand,'staff-wood');
 const st=C.stats(c);assert.equal(st.skillSources.filter(x=>x.id==='mage').length,2);
 assert.deepEqual(st.skillSources.filter(x=>x.id==='mage').map(x=>x.grantSlot),[1,1]);
 const before=clone(s);assert.equal(C.inventoryAction(s,"recruit-mage-elf-female",'staff-wood','equip',null,1,'leftHand',q.token),false);assert.deepEqual(s,before);
 assert.equal(C.inventoryQuote(s,"recruit-mage-elf-female",'staff-wood','equip',null,1,'rightHand').ok,false);roundtrip(s);
});
test('duplicate non-hand slot remains rejected',()=>{
 const s=town();s.location='north';assert.ok(C.buyGear(s,"recruit-guard-human-female",'lone-ring-1','accessory1'));
 const before=clone(s);assert.equal(C.buyGear(s,"recruit-guard-human-female",'lone-ring-1','accessory2'),false);assert.deepEqual(s,before);
 const bad=clone(s);bad.characters["recruit-guard-human-female"].accessory2='lone-ring-1';assert.equal(C.validate(bad).ok,false);
});
test('retired fists cannot be duplicated to manufacture a second migration refund',()=>{
  const s=town(),id='recruit-scout-human-female';roundtrip(s);
  s.characters[id].weapon='fist-1';assert.equal(C.validate(s).ok,true);
  const envelope={format:'5525-native-campaign',version:C.VERSION,cargoRevision:1,state:s};
  const before=clone(s),loaded=C.deserialize(envelope);assert.equal(loaded.gold,s.gold+100);assert.deepEqual(s,before);
  const bad=clone(envelope);bad.state.characters[id].leftHand='fist-1';assert.equal(C.validate(bad.state).ok,false);
  assert.throws(()=>C.deserialize(bad));
});
test('selected grant and cooldown survive save reload and cannot be forged',()=>{
 const s=town();assert.ok(C.buyGear(s,"recruit-mage-elf-female",'staff-wood','leftHand'));const b=battle(s),a=b.units.find(u=>u.id==="recruit-mage-elf-female");
 const options=B.activeSkillOptions(a);assert.equal(options.length,2);assert.notEqual(options[0].key,options[1].key);
 b.actor=a.id;assert.ok(B.selectSkill(b,options[1].key));a.skillCooldowns={[options[1].key]:1};
 const loaded=roundtrip(s),u=loaded.battle.units.find(u=>u.id==="recruit-mage-elf-female");assert.equal(u.selectedSkillKey,options[1].key);
 assert.deepEqual(B.activeSkillOptions(u).map(x=>x.cooldown),[0,1]);
 for(const mutate of [u=>u.selectedSkillKey='fake',u=>u.skillCooldowns={fake:1},u=>u.skillCooldowns={[options[1].key]:2},u=>u.skillCooldowns={[options[1].key]:-1},u=>u.skillSources[0].grantSlot=2,u=>u.skillSources[0].itemId='staff-silver-1']){
   const bad=clone(s);mutate(bad.battle.units.find(u=>u.id==="recruit-mage-elf-female"));assert.equal(C.validate(bad).ok,false);
 }
});
test('product trials opt in and retreat/new battle does not carry cooldown',()=>{
 const s=town(),trial=C.trial(s,"recruit-mage-elf-female",'staff-wood','leftHand');assert.equal(trial.battle.skillCooldownVersion,1);
 const b=battle(s),a=b.units.find(u=>u.id==="recruit-mage-elf-female");assert.equal(b.skillCooldownVersion,1);
 const option=B.activeSkillOptions(a)[0];a.skillCooldowns={[option.key]:1};roundtrip(s);
 assert.ok(C.retreat(s));assert.ok(C.acknowledge(s));battle(s);
 assert.ok(s.battle.units.every(u=>u.skillCooldowns===undefined));roundtrip(s);
 const bad=clone(s);bad.battle.skillCooldownVersion=2;assert.equal(C.validate(bad).ok,false);
});
test('return grants preserve independent used states and reject forged keys',()=>{
  const s=returnRings();
 const b=battle(s),a=b.units.find(u=>u.id==="recruit-guard-human-female"),options=B.returnSkillOptions(a);assert.equal(options.length,2);
 b.actor=a.id;for(const u of b.units)u.next=u.id===a.id?1:100000;
 assert.ok(B.selectReturnSkill(b,options[1].key));assert.ok(C.act(s,'return',0));
 const loaded=roundtrip(s),hero=loaded.battle.units.find(u=>u.id===a.id);
 assert.deepEqual(B.returnSkillOptions(hero).map(o=>o.used),[false,true]);assert.equal(hero.selectedReturnSkillKey,options[1].key);
 for(const mutate of [u=>u.returnUsedGrants={fake:true},u=>u.returnUsedGrants={[options[0].key]:1},u=>u.selectedReturnSkillKey='fake',u=>u.returnUsed=true]){
  const bad=clone(s);mutate(bad.battle.units.find(u=>u.id===a.id));assert.equal(C.validate(bad).ok,false);
 }
});
test('old actor-wide used return remains consumed for every grant after load',()=>{
  const s=returnRings();battle(s);
 const a=s.battle.units.find(u=>u.id==="recruit-guard-human-female");a.returnUsed=true;
 const source=C.serialize(s),loaded=C.deserialize(source),hero=loaded.battle.units.find(u=>u.id==="recruit-guard-human-female");
  assert.equal(hero.returnUsed,true);assert.equal(B.returnSkillOptions(hero).length,2);assert.ok(B.returnSkillOptions(hero).every(o=>o.used));assert.equal(JSON.stringify(s),JSON.stringify(JSON.parse(source).state));
 roundtrip(loaded);
});
console.log(`PASS ${count} SQLite grant-save groups`);
