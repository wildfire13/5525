'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const old=JSON.parse(fs.readFileSync(require.resolve('./test_fixtures/campaign-a51a773-battle.json'),'utf8')),clone=x=>JSON.parse(JSON.stringify(x));
let count=0;const test=(name,fn)=>{fn();count++;console.log('PASS '+name);};
test('actual a51a773 battle and rollback split sets, preserve values and flags',()=>{
 const saved=JSON.stringify(old),s=C.deserialize(old),c=s.characters.guard,u=s.battle.units.find(u=>u.id==='guard');assert.equal(JSON.stringify(old),saved);assert.equal(c.weapon,'sword-wood');assert.equal(c.leftHand,'guard-shield-wood');assert.equal(s.rollback.characters.guard.leftHand,'guard-shield-wood');
 assert.equal(s.gold,old.state.gold);assert.equal(c.hp,old.state.characters.guard.hp);assert.equal(c.mp,old.state.characters.guard.mp);assert.equal(u.atk,26);assert.equal(u.returnUsed,true);assert.equal(u.firstMoveUsed,true);assert.equal(u.cover,'archer');assert.equal(u.skillSources.find(x=>x.id==='guard').slot,'leftHand');assert.equal(u.attackWeapons.length,1);assert.equal(u.attackWeapons[0].atk,26);assert.deepEqual(C.deserialize(C.serialize(s)),s);
 assert.ok(C.retreat(s));assert.equal(s.characters.guard.leftHand,'guard-shield-wood');assert.equal(s.characters.guard.equipmentRevision,2);
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
