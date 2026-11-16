'use strict';
const assert=require('node:assert/strict');
const V=require('./voice-events.cjs'), B=require('./campaign-battle.js');
function scenario(id,skill){
  const s=B.create({ally:[id,"recruit-porter-human-female"],enemy:['guard'],enemyPotions:0,deployment:true});
  const a=s.units[0];a.equippedSkill=skill;a.pos=24;a.reach=3;
  s.units[1].pos=23;s.units[1].hp=40;
  s.units[2].pos=25;s.units[2].next=1e9;
  s.deploying=false;s.actor=a.id;
  return {s,a};
}
for(const id of B.recruitRoster.filter(u=>u.job!=='porter').map(u=>u.id)){
  for(const skill of ['guard','mage','archer','scout','stamp']){
    const {s,a}=scenario(id,skill);
    const target=['guard','mage'].includes(skill)?'recruit-porter-human-female':skill==='stamp'?25:'enemy-guard';
    const observed=V.capture(s,B,'skill',()=>B.act(s,'skill',target));
    assert.equal(observed.ok,true,`${id} ${skill}`);
    assert.deepEqual(observed.events,[{character_id:id,cue:'skill:'+skill}]);
    assert.equal(Object.getOwnPropertyDescriptor(a,'hp').get,undefined);
  }
  const {s}=scenario(id,'mage');
  assert.deepEqual(V.capture(s,B,'attack',()=>B.act(s,'attack','enemy-guard')).events,
    [{character_id:id,cue:'attack'}]);
}
{
  const {s}=scenario("recruit-guard-human-female",'mage');
  const before=JSON.stringify(s);
  assert.deepEqual(V.capture(s,B,'skill',()=>B.act(s,'skill','missing')), {ok:false,events:[]});
  assert.equal(JSON.stringify(s),before);
}
{
  const {s,a}=scenario("recruit-guard-human-female",'mage');
  a.cover='recruit-porter-human-female';
  const observed=V.capture(s,B,'guard',()=>{
    B.receive(s,s.units[1],20,false);
    a.hp+=20; // Net HP is unchanged, but the real recipient still spoke.
    B.receive(s,s.units[1],20,false);
    return true;
  });
  assert.deepEqual(observed.events,[{character_id:'recruit-guard-human-female',cue:'hurt'},{character_id:'recruit-guard-human-female',cue:'hurt'}]);
}
{
  const {s,a}=scenario("recruit-guard-human-female",'mage');
  assert.throws(()=>V.capture(s,B,'attack',()=>{throw Error('failure');}));
  assert.equal(Object.getOwnPropertyDescriptor(a,'hp').get,undefined);
}
for(const id of B.recruitRoster.filter(u=>u.job==='porter').map(u=>u.id)){
  const s=B.create({ally:[id,"recruit-guard-human-female","recruit-mage-elf-female","recruit-scout-human-male"],enemy:['guard'],deployment:true});
  const a=s.units.find(u=>u.id===id);a.pos=22;
  s.units.find(u=>u.id==="recruit-guard-human-female").pos=24;s.units.find(u=>u.id==="recruit-mage-elf-female").pos=13;s.units.find(u=>u.id==="recruit-scout-human-male").pos=33;
  s.units.find(u=>u.side==='enemy').next=1e9;s.deploying=false;s.actor=id;
  assert.deepEqual(V.capture(s,B,'skill',()=>B.act(s,'skill',id)).events,[{character_id:id,cue:'skill:porter'}]);
}
{
  const engine=B;
  const s=engine.create({ally:["recruit-guard-human-female","recruit-porter-human-female"],enemy:['scout'],deployment:true});
  s.units.find(u=>u.id==="recruit-guard-human-female").pos=4;
  const before=JSON.stringify(s);
  assert.deepEqual(V.capture(s,engine,null,()=>false).events,[]);
  assert.equal(JSON.stringify(s),before,'cancel before begin is silent and unchanged');
  assert.deepEqual(V.capture(s,engine,null,()=>engine.begin(s)).events,[{character_id:'recruit-guard-human-female',cue:'hurt'}]);
  assert.deepEqual(V.capture(s,engine,null,()=>engine.begin(s)),{ok:false,events:[]});
}
console.log('PASS exact current actor/skill: 18 non-porters × 5 skill assignments, 18 attacks, six porters, cover/hit/heal, rejection/cleanup and opening-hit cancellation');
