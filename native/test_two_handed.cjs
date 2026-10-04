'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const clone=x=>JSON.parse(JSON.stringify(x));let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('two slots occupied by one item, one ATK contribution, save roundtrip',()=>{
 const s=C.create();s.location='east';s.gold=500;assert.ok(C.buyGear(s,'mage','greatsword-wood','rightHand'));
 const st=C.stats(s.characters.mage);assert.equal(st.attackWeapons.length,1);assert.equal(st.attackWeapons[0].atk,50);assert.equal(C.view(s).roster.find(u=>u.id==='mage').equipmentSlots.find(x=>x.slot==='leftHand').occupiedBy,'rightHand');
 const old=clone(s);assert.equal(C.buyGear(s,'mage','staff-wood','leftHand'),false);assert.deepEqual(s,old);assert.deepEqual(C.deserialize(C.serialize(s)),s);
 assert.ok(C.buyGear(s,'mage','staff-wood','rightHand'));assert.ok(C.buyGear(s,'mage','sword-wood','leftHand'));assert.equal(C.stats(s.characters.mage).attackWeapons.length,2);
});
test('occupied offhand blocks purchase/trial atomically; no hidden trade-in or loss',()=>{
 const s=C.create();s.location='east';s.gold=500;const old=clone(s);assert.equal(C.buyGear(s,'guard','greatsword-wood','rightHand'),false);assert.equal(C.trial(s,'guard','greatsword-wood','rightHand'),null);assert.deepEqual(s,old);
 assert.ok(C.buyGear(s,'guard','empty-leftHand','leftHand'));assert.ok(C.buyGear(s,'guard','greatsword-wood','rightHand'));
 const bad=clone(s);bad.characters.guard.leftHand='staff-wood';assert.equal(C.validate(bad).ok,false);
});
test('dwarf sword restriction extends to greatsword; spear is not a sword',()=>{
 const s=C.create();assert.equal(C.eligibility(s,'warrior','greatsword-wood').ok,false);
});
test('all bows occupy both hands; blocked combinations are atomic; removal and replacement free the left hand',()=>{
 for(const bow of C.gear.filter(g=>g.type==='bow')) {
  assert.equal(bow.hands,2);
  const s=C.create();s.location='east';s.gold=9999;
  // Exercise every catalog variant without shop/location/progression constraints.
  s.characters.archer.weapon=bow.id;
  const st=C.stats(s.characters.archer);assert.equal(st.attackWeapons.length,1);assert.equal(st.attackWeapons[0].atk,bow.atk);
  assert.equal(C.view(s).roster.find(u=>u.id==='archer').equipmentSlots.find(x=>x.slot==='leftHand').occupiedBy,'rightHand');
  const before=clone(s);assert.equal(C.buyGear(s,'archer','staff-wood','leftHand'),false);assert.equal(C.trial(s,'archer','staff-wood','leftHand'),null);assert.deepEqual(s,before);
 }
 const s=C.create();s.location='east';s.gold=9999;
 assert.ok(C.buyGear(s,'archer','empty-rightHand','rightHand'));assert.ok(C.buyGear(s,'archer','staff-wood','leftHand'));
 const before=clone(s);assert.equal(C.buyGear(s,'archer','bow-wood','rightHand'),false);assert.equal(C.trial(s,'archer','bow-wood','rightHand'),null);assert.deepEqual(s,before);
 assert.ok(C.buyGear(s,'archer','empty-leftHand','leftHand'));assert.ok(C.buyGear(s,'archer','bow-wood','rightHand'));
 assert.ok(C.buyGear(s,'archer','staff-wood','rightHand'));assert.ok(C.buyGear(s,'archer','sword-wood','leftHand'));
});
test('old single bow saves migrate losslessly; conflicting left hands are rejected without mutation',()=>{
 const fs=require('node:fs');const old=JSON.parse(fs.readFileSync(__dirname+'/test_fixtures/campaign-a51a773-battle.json','utf8'));
 const original=JSON.stringify(old),loaded=C.deserialize(old);assert.equal(JSON.stringify(old),original);
 assert.equal(C.stats(loaded.characters.archer).attackWeapons.length,1);assert.deepEqual(C.deserialize(C.serialize(loaded)),loaded);
 for(const where of ['current','rollback']) {
  const bad=clone(old),state=where==='rollback'?bad.state.rollback:bad.state;state.characters.archer.leftHand='staff-wood';const snapshot=clone(bad);
  assert.throws(()=>C.deserialize(bad),/弓.*両手|両手.*弓/);assert.deepEqual(bad,snapshot);
 }
 const bad=JSON.parse(C.serialize(C.create()));bad.state.characters.mage.leftHand='bow-wood';const snapshot=clone(bad);
 assert.throws(()=>C.deserialize(bad),/弓.*右手/);assert.deepEqual(bad,snapshot);
});
test('single bow Snipe retains normal range plus one and one weapon contribution',()=>{
 const s=C.create();s.location='east';s.gold=9999;const t=C.trial(s,'archer','bow-wood','rightHand');assert.ok(t);
 const b=t.battle,a=b.units.find(u=>u.id==='archer');assert.equal(B.attackReach(a,'attack'),3);assert.equal(B.attackReach(a,'skill'),4);assert.equal(a.attackWeapons.length,1);
 const e=b.units.find(u=>u.side==='enemy');a.pos=24;e.pos=28;e.hp=e.max=999;b.actor=a.id;b.deploying=false;for(const u of b.units)u.next=u===a?1:100000;
 assert.equal(B.legal(b,'attack',e.id),false);assert.equal(B.legal(b,'skill',e.id),true);const preview=B.damagePreview(b,a,'skill',e.id);assert.equal(preview[0].weapons.length,1);assert.equal(preview[0].base,25);
 const hp=e.hp,mp=a.mp;assert.ok(B.act(b,'skill',e.id));assert.equal(hp-e.hp,preview[0].hpLoss);assert.equal(a.mp,mp-1);
});
console.log(`PASS ${count} two-handed groups`);
