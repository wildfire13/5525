'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js');
let checks=0;const test=(label,fn)=>{fn();checks++;console.log('PASS '+label);};
test('accepted quest keeps its owner through transfer and reload',()=>{
 const s=require('./test-current-fixture.cjs')();C.select(s,["recruit-porter-human-female","recruit-porter-human-male"]);
 s.characters["recruit-porter-human-female"].accessory2='pouch-belt-3';s.characters["recruit-porter-human-male"].accessory2='pouch-belt-3';
 assert(C.accept(s,C.board(s)[0].id,"recruit-porter-human-female"));
 const id=s.activeQuest.cargoItemId,q=C.inventoryQuote(s,"recruit-porter-human-female",id,'transfer',"recruit-porter-human-male");
 assert(C.inventoryAction(s,"recruit-porter-human-female",id,'transfer',"recruit-porter-human-male",1,null,q.token));
 const loaded=C.deserialize(C.serialize(s));assert.equal(loaded.activeQuest.cargoOwnerId,"recruit-porter-human-male");assert(!loaded.characters["recruit-porter-human-female"].inventory[id]);assert.equal(loaded.characters["recruit-porter-human-male"].inventory[id],1);
});
test('new save missing cargo rejected rather than repaired',()=>{
 const s=require('./test-current-fixture.cjs')();C.accept(s,C.board(s)[0].id,"recruit-porter-human-female");const e=JSON.parse(C.serialize(s));
 delete e.state.characters["recruit-porter-human-female"].inventory[e.state.activeQuest.cargoItemId];
 assert.throws(()=>C.deserialize(e));
});
test('new envelope with missing state marker cannot masquerade as old',()=>{
 const s=require('./test-current-fixture.cjs')();const e=JSON.parse(C.serialize(s));delete e.state.cargoRevision;assert.throws(()=>C.deserialize(e));
});
console.log(JSON.stringify({passed:true,checks}));
