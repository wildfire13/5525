'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const old=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/campaign-a51a773-battle.json'),'utf8')),clone=x=>JSON.parse(JSON.stringify(x));
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('actual a51a773 battle migrates equipment and clears old trip without mutating source',()=>{
 const saved=JSON.stringify(old),s=C.deserialize(old),c=s.characters.guard;
 assert.equal(JSON.stringify(old),saved);assert.equal(c.weapon,'sword-wood');assert.equal(c.leftHand,'guard-shield-wood');
 assert.equal(s.rollback,null);assert.equal(s.battle,null);assert.equal(s.phase,'town');assert.equal(s.location,'astaris');
 assert.equal(s.gold,old.state.gold);const oldUnit=old.state.battle.units.find(u=>u.id==='guard');assert.equal(c.hp,oldUnit.hp);assert.equal(c.mp,oldUnit.mp);
 assert.equal(C.stats(c).atk,26);assert.equal(C.stats(c).skillSources.find(x=>x.id==='guard').slot,'leftHand');assert.equal(c.equipmentRevision,2);
 assert.deepEqual(C.deserialize(C.serialize(s)),s);assert.equal(C.retreat(s),false);
});
test('old town iron set keeps total value and power, shield is only guard source',()=>{
 const s=clone(old.state.rollback);s.characters.guard.weapon='sword-iron-1';const n=C.deserialize({format:old.format,version:1,state:s});const c=n.characters.guard,st=C.stats(c);assert.equal(c.leftHand,'guard-shield-iron-1');assert.equal(st.atk,32);assert.equal(st.skillSources.find(x=>x.id==='guard').itemId,'guard-shield-iron-1');assert.equal(C.gear.find(x=>x.id===c.weapon).price+C.gear.find(x=>x.id===c.leftHand).price,135);
 n.location='east';assert.ok(C.buyGear(n,'guard','empty-leftHand','leftHand'));assert.equal(C.stats(c).activeSkills.includes('guard'),false);
});
test('internal left-hand conflicts reject before changing source object',()=>{
 const input={format:old.format,version:1,state:clone(old.state.rollback)};input.state.characters.guard.leftHand='breaker-hammer';const before=clone(input);assert.throws(()=>C.deserialize(input),/競合/);assert.deepEqual(input,before);
});
test('malformed legacy save is rejected before normalization can repair it',()=>{
 for(const mutate of [x=>x.state.characters.guard.hp=-1,x=>x.state.battle.units.find(u=>u.id==='guard').atk=999,x=>x.state.characters.guard.equipmentRevision=7]){const input=clone(old);mutate(input);assert.throws(()=>C.deserialize(input));}
});
console.log(`PASS ${count} migration groups`);
