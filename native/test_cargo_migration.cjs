'use strict';
// Historical-ID fixtures retain the old roster; new-game/one-time migration
// behavior is tested separately in test_updateplan_roster.cjs.
const assert=require('node:assert/strict'),C=require('./campaign.js');
let checks=0;const test=(label,fn)=>{fn();checks++;console.log('PASS '+label);};
function legacy(){
 const s=C.createLegacy();C.select(s,['guard','porter','porter-2']);assert(C.accept(s,C.board(s)[0].id,'porter-2'));
 const e=JSON.parse(C.serialize(s));
 delete e.cargoRevision;delete e.state.cargoRevision;delete e.state.rollback.cargoRevision;
 const q=e.state.activeQuest;
 delete e.state.characters[q.cargoOwnerId].inventory[q.cargoItemId];delete q.cargoItemId;delete q.cargoOwnerId;
 return e;
}
test('legacy accepted quest is cleared by the one-time update without moving other stock',()=>{
 const old=legacy();old.state.selected=['guard','porter-2'];const original=JSON.stringify(old);
 const s=C.deserialize(old);assert.equal(s.activeQuest,null);assert.equal(s.location,'astaris');assert.equal(s.cargoRevision,1);assert.equal(JSON.stringify(old),original);
 assert(Object.values(s.characters).every(c=>!Object.keys(c.inventory).some(id=>id.startsWith('quest-cargo:'))));
 assert.deepEqual(C.deserialize(C.serialize(s)),s);
});
test('quest accepted after migration keeps its owner through transfer and reload',()=>{
 const s=C.deserialize(legacy());C.select(s,['porter','porter-2']);
 s.characters.porter.accessory2='pouch-belt-3';s.characters['porter-2'].accessory2='pouch-belt-3';
 assert(C.accept(s,C.board(s)[0].id,'porter'));
 const id=s.activeQuest.cargoItemId,q=C.inventoryQuote(s,'porter',id,'transfer','porter-2');
 assert(C.inventoryAction(s,'porter',id,'transfer','porter-2',1,null,q.token));
 const loaded=C.deserialize(C.serialize(s));assert.equal(loaded.activeQuest.cargoOwnerId,'porter-2');assert(!loaded.characters.porter.inventory[id]);assert.equal(loaded.characters['porter-2'].inventory[id],1);
});
test('new save missing cargo rejected rather than repaired',()=>{
 const s=C.createLegacy();C.accept(s,C.board(s)[0].id,'porter');const e=JSON.parse(C.serialize(s));
 delete e.state.characters.porter.inventory[e.state.activeQuest.cargoItemId];
 assert.throws(()=>C.deserialize(e));
});
test('new envelope with missing state marker cannot masquerade as old',()=>{
 const s=C.createLegacy();const e=JSON.parse(C.serialize(s));delete e.state.cargoRevision;assert.throws(()=>C.deserialize(e));
});
test('missing old porter record rejected without character generation',()=>{
 const old=legacy();delete old.state.characters.porter;const original=JSON.stringify(old);assert.throws(()=>C.deserialize(old));assert.equal(JSON.stringify(old),original);
});
test('old completed quest receives no new cargo',()=>{
 const s=C.createLegacy(),e=JSON.parse(C.serialize(s));delete e.cargoRevision;delete e.state.cargoRevision;const loaded=C.deserialize(e);
 assert.equal(loaded.activeQuest,null);assert(Object.values(loaded.characters).every(c=>!Object.keys(c.inventory).some(id=>id.startsWith('quest-cargo:'))));
});
console.log(JSON.stringify({passed:true,checks}));
