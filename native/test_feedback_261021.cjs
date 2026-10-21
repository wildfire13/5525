'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const s=C.create();s.location='east';s.gold=1000;
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
// Grandfather valid paid fist+1 saves without silently deleting stock or levels.
const legacy=C.create();legacy.characters.archer.weapon='fist-1';legacy.characters.archer.inventory['fist-1']=1;
assert(C.validate(legacy).ok);const loaded=C.deserialize(C.serialize(legacy));
assert.equal(loaded.characters.archer.weapon,'fist-1');assert.equal(loaded.characters.archer.inventory['fist-1'],1);
assert.equal(B.itemUseLevel({...C.stats(loaded.characters.archer),side:'ally'}),2);
console.log('PASS feedback21 virtual fists, outside-battle use, removed new sales, and legacy preservation');
