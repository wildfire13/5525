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
assert.deepEqual(enemy.map(u=>u.job),['job_warrior','job_scout','job_mage','job_scout','job_warrior']);
const appearances=require('./data/enemy-appearances.json');
const reached=new Set();
for(const id of ['guard','archer','mage','scout']){
  for(const rank of ['normal','strong']){
    for(let i=0;i<appearances.length;i++){
      const battle=B.create({ally:[],enemy:[id],deployment:true,strongEnemy:rank==='strong'?0:-1,
        appearanceRolls:[i/appearances.length]});
      const unit=battle.units[0];
      const row=appearances.find(row=>row.portraitKey===unit.portraitKey);
      assert.deepEqual([unit.job,unit.race,unit.sex,unit.rank],[row.job,row.race,row.sex,rank]);
      assert.equal(row.rank,rank);
      const number=Number(unit.portraitKey.split('-e').at(-1));
      assert(rank==='normal'?number<100:number>100);
      assert.equal(unit.image,'enemy/'+unit.portraitKey+'.png');
      assert(fs.existsSync(path.join(__dirname,'assets',unit.image)));
      if(id==='archer')assert.deepEqual([unit.job,unit.weapon,B.activeSkill(unit)],['job_scout','bow','skill_snipe']);
      reached.add(unit.portraitKey);
    }
  }
}
assert.equal(reached.size,appearances.length);
assert(C.validate(state).ok);
console.log('PASS fixture contains exactly 24 production recruits, real portraits and unchanged enemy identities');
