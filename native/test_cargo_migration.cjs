'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let checks=0;const test=(label,fn)=>{fn();checks++;console.log('PASS '+label);};
test('accepted quest keeps its owner through transfer and reload',()=>{
 const s=require('./test-current-fixture.cjs')();C.select(s,['porter','porter-2']);
 s.characters.porter.accessory2='pouch-belt-3';s.characters['porter-2'].accessory2='pouch-belt-3';
 assert(C.accept(s,C.board(s)[0].id,'porter'));
 const id=s.activeQuest.cargoItemId,q=C.inventoryQuote(s,'porter',id,'transfer','porter-2');
 assert(C.inventoryAction(s,'porter',id,'transfer','porter-2',1,null,q.token));
 const loaded=C.deserialize(C.serialize(s));assert.equal(loaded.activeQuest.cargoOwnerId,'porter-2');assert(!loaded.characters.porter.inventory[id]);assert.equal(loaded.characters['porter-2'].inventory[id],1);
});
test('new save missing cargo rejected rather than repaired',()=>{
 const s=require('./test-current-fixture.cjs')();C.accept(s,C.board(s)[0].id,'porter');const e=JSON.parse(C.serialize(s));
 delete e.state.characters.porter.inventory[e.state.activeQuest.cargoItemId];
 assert.throws(()=>C.deserialize(e));
});
test('new envelope with missing state marker cannot masquerade as old',()=>{
 const s=require('./test-current-fixture.cjs')();const e=JSON.parse(C.serialize(s));delete e.state.cargoRevision;assert.throws(()=>C.deserialize(e));
});
console.log(JSON.stringify({passed:true,checks}));
