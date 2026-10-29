'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const s=require('./test-current-fixture.cjs')();s.location='east';s.gold=1000;
assert(!C.shop(s).some(g=>g.type==='fist'));
for(const id of ['fist','fist-1','fist-2'])assert(!C.purchaseQuote(s,id).ok);
function unequip(id,slot){const q=C.inventoryQuote(s,'guard',id,'unequip',null,1,slot);assert(q.ok,q.reason);assert(C.inventoryAction(s,'guard',id,'unequip',null,1,slot,q.token));}
const guard=s.characters.guard;
assert.equal(B.itemUseLevel({...C.stats(guard),side:'ally'}),0);
guard.hp=1;guard.inventory.potion=1;
assert(C.inventoryQuote(s,'guard','potion','use','guard',1).ok,'outside battle both occupied hands can use items');
unequip('guard-shield-wood','leftHand');
assert.equal(B.itemUseLevel({...C.stats(s.characters.guard),side:'ally'}),1);
assert.equal(C.view(s).roster.find(u=>u.id==='guard').equipmentDetails.leftHand.name,'拳');
unequip('sword-wood','rightHand');
for(const slot of ['rightHand','leftHand'])assert.equal(C.view(s).roster.find(u=>u.id==='guard').equipmentDetails[slot].name,'拳');
assert(!Object.keys(s.characters.guard.inventory).some(id=>id.startsWith('fist')));
assert(B.equipmentSkills.itemUse.description.startsWith('バトル中にもアイテムを使用できる'));
// Valid paid fists are refunded once per owned item; source data stays intact.
const legacy=require('./test-current-fixture.cjs')();legacy.characters.archer.weapon='fist-1';legacy.characters.archer.inventory['fist-1']=2;
legacy.characters.mage.leftHand='fist-1';
assert(C.validate(legacy).ok);const original=C.serialize(legacy),loaded=C.deserialize(original);
assert.equal(C.serialize(legacy),original);
assert.equal(loaded.gold,legacy.gold+400);
assert.equal(loaded.characters.archer.weapon,'empty-rightHand');assert.equal(loaded.characters.mage.leftHand,'empty-leftHand');
assert.equal(loaded.characters.archer.inventory['fist-1'],undefined);
assert.equal(B.itemUseLevel({...C.stats(loaded.characters.archer),side:'ally'}),1);
assert.deepEqual(C.deserialize(C.serialize(loaded)),loaded);
assert(C.depart(legacy,'east'));const road=C.deserialize(C.serialize(legacy));
assert.equal(road.gold,legacy.gold+400);assert.equal(road.rollback.gold,legacy.rollback.gold+400);
assert(C.travel(road,'safe',()=>0));assert(C.begin(road));assert(C.retreat(road));assert.equal(road.gold,legacy.rollback.gold+400);
assert.deepEqual(C.deserialize(C.serialize(road)),road);
const overflow=require('./test-current-fixture.cjs')();overflow.gold=100000000;overflow.characters.archer.weapon='fist-1';
const before=JSON.stringify(overflow);assert.throws(()=>C.deserialize(C.serialize(overflow)),/所持金上限/);assert.equal(JSON.stringify(overflow),before);
const battle=require('./test-current-fixture.cjs')();battle.characters.archer.weapon='fist-1';assert(C.depart(battle,'east'));assert(C.travel(battle,'safe',()=>0));assert(C.begin(battle));
const migrated=C.deserialize(C.serialize(battle));assert(C.validate(migrated).ok);
const actor=migrated.battle.units.find(u=>u.id==='archer');assert.equal(actor.equipment.rightHand,'empty-rightHand');assert.equal(B.itemUseLevel(actor),1);
assert.deepEqual(C.deserialize(C.serialize(migrated)),migrated);
const duplicate=require('./test-current-fixture.cjs')();duplicate.characters.guard.weapon='fist-1';duplicate.characters.guard.leftHand='fist-1';
const duplicateBefore=JSON.stringify(duplicate);assert.throws(()=>C.deserialize({format:'5525-native-campaign',version:2,state:duplicate}),/装備の二重使用/);assert.equal(JSON.stringify(duplicate),duplicateBefore);
console.log('PASS feedback21 virtual fists, refunds, rollback, active battle, idempotence and source preservation');
