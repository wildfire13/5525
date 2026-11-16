'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const C=require('./campaign.js');
const B=require('./campaign-battle.js');
const fixture=require('./test-current-fixture.cjs');
const original=C.create(),state=fixture({extraCapacity:false});
assert.deepEqual(state,original,'unmodified fixture is exactly a newly created campaign');
const ids=B.recruitRoster.map(u=>u.id);
assert.equal(ids.length,24);
assert.equal(new Set(ids).size,24);
assert.deepEqual(Object.keys(state.characters).sort(),[...ids].sort());
assert.deepEqual(C.view(state).roster.map(u=>u.id).sort(),[...ids].sort());
assert.deepEqual(state.selected,original.selected);
for(const recruit of B.recruitRoster){
  assert(recruit.id.startsWith('character_'));
  assert(['job_warrior','job_mage','job_scout','job_porter'].includes(recruit.job));
  assert.equal(recruit.image.startsWith('characters/'),true);
  assert(fs.existsSync(path.join(__dirname,'assets',recruit.image)),recruit.image);
  assert.deepEqual(state.characters[recruit.id],original.characters[recruit.id]);
}
const expanded=fixture();
for(const id of ids){
  const expected={...original.characters[id],accessory2:'pouch-belt-3'};
  assert.deepEqual(expanded.characters[id],expected,'capacity setup changes only its declared equipment slot');
}
const enemy=B.create({ally:[ids[0]],enemy:['guard','archer','mage','scout','warrior'],deployment:true})
  .units.filter(u=>u.side==='enemy');
assert.deepEqual(enemy.map(u=>u.id),['enemy-guard','enemy-archer','enemy-mage','enemy-scout','enemy-warrior']);
assert.deepEqual(enemy.map(u=>u.job),['job_warrior','job_archer','job_mage','job_scout','job_warrior']);
assert(C.validate(state).ok);
console.log('PASS fixture contains exactly 24 production recruits, real portraits and unchanged enemy identities');
