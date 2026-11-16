'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const s=require('./test-current-fixture.cjs')();s.location='east';s.gold=1000;
assert(!C.shop(s).some(g=>g.type==='fist'));
for(const id of ['fist','fist-1','fist-2'])assert(!C.purchaseQuote(s,id).ok);
function unequip(id,slot){const q=C.inventoryQuote(s,"character_mirei",id,'unequip',null,1,slot);assert(q.ok,q.reason);assert(C.inventoryAction(s,"character_mirei",id,'unequip',null,1,slot,q.token));}
const guard=s.characters["character_mirei"];
assert.equal(B.itemUseLevel({...C.stats(guard),side:'ally'}),0);
guard.hp=1;guard.inventory.potion=1;
assert(C.inventoryQuote(s,"character_mirei",'potion','use',"character_mirei",1).ok,'outside battle both occupied hands can use items');
unequip('guard-shield-wood','leftHand');
assert.equal(B.itemUseLevel({...C.stats(s.characters["character_mirei"]),side:'ally'}),1);
assert.equal(C.view(s).roster.find(u=>u.id==="character_mirei").equipmentDetails.leftHand.name,'拳');
unequip('sword-wood','rightHand');
for(const slot of ['rightHand','leftHand'])assert.equal(C.view(s).roster.find(u=>u.id==="character_mirei").equipmentDetails[slot].name,'拳');
assert(!Object.keys(s.characters["character_mirei"].inventory).some(id=>id.startsWith('fist')));
assert(B.equipmentSkills.skill_item_use.description.startsWith('バトル中にもアイテムを使用できる'));
console.log('PASS virtual fists, equipment labels and item use');
