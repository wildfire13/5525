'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let checks=0;const test=(label,fn)=>{fn();checks++;console.log('PASS '+label);};
test('accepted quest keeps its owner through transfer and reload',()=>{
 const s=require('./test-current-fixture.cjs')();C.select(s,["character_yuno","character_teo"]);
 s.characters["character_yuno"].accessory2='pouch-belt-3';s.characters["character_teo"].accessory2='pouch-belt-3';
 assert(C.accept(s,C.board(s)[0].id,"character_yuno"));
 const id=s.activeQuest.cargoItemId,q=C.inventoryQuote(s,"character_yuno",id,'transfer',"character_teo");
 assert(C.inventoryAction(s,"character_yuno",id,'transfer',"character_teo",1,null,q.token));
 const loaded=C.deserialize(C.serialize(s));assert.equal(loaded.activeQuest.cargoOwnerId,"character_teo");assert(!loaded.characters["character_yuno"].inventory[id]);assert.equal(loaded.characters["character_teo"].inventory[id],1);
});
test('new save missing cargo rejected rather than repaired',()=>{
 const s=require('./test-current-fixture.cjs')();C.accept(s,C.board(s)[0].id,"character_yuno");const e=JSON.parse(C.serialize(s));
 delete e.state.characters["character_yuno"].inventory[e.state.activeQuest.cargoItemId];
 assert.throws(()=>C.deserialize(e));
});
test('new envelope with missing state marker cannot masquerade as old',()=>{
 const s=require('./test-current-fixture.cjs')();const e=JSON.parse(C.serialize(s));delete e.state.cargoRevision;assert.throws(()=>C.deserialize(e));
});
console.log(JSON.stringify({passed:true,checks}));
