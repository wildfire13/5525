'use strict';
const assert=require('node:assert/strict');
const V=require('./voice-events.cjs'), B=require('./campaign-battle.js');
function scenario(id,skill){
  const s=B.create({ally:[id,"character_yuno"],enemy:['guard'],enemyPotions:0,deployment:true});
  const a=s.units[0];a.equippedSkill=skill;a.pos=24;a.reach=3;
  s.units[1].pos=23;s.units[1].hp=40;
  s.units[2].pos=25;s.units[2].next=1e9;
  s.deploying=false;s.actor=a.id;
  return {s,a};
}
for(const id of B.recruitRoster.filter(u=>u.job!=='job_porter').map(u=>u.id)){
  for(const skill of ['skill_cover','skill_heal','skill_snipe','skill_ambush','skill_stamp']){
    const {s,a}=scenario(id,skill);
    const target=['skill_cover','skill_heal'].includes(skill)?'character_yuno':skill==='skill_stamp'?25:'enemy-guard';
    const observed=V.capture(s,B,'action_skill',()=>B.act(s,'action_skill',target));
    assert.equal(observed.ok,true,`${id} ${skill}`);
    assert.deepEqual(observed.events,[{character_id:id,cue:'skill:'+skill}]);
    assert.equal(Object.getOwnPropertyDescriptor(a,'hp').get,undefined);
  }
  const {s}=scenario(id,'skill_heal');
  assert.deepEqual(V.capture(s,B,'action_attack',()=>B.act(s,'action_attack','enemy-guard')).events,
    [{character_id:id,cue:'attack'}]);
}
{
  const {s}=scenario("character_mirei",'skill_heal');
  const before=JSON.stringify(s);
  assert.deepEqual(V.capture(s,B,'action_skill',()=>B.act(s,'action_skill','missing')), {ok:false,events:[]});
  assert.equal(JSON.stringify(s),before);
}
{
  const {s,a}=scenario("character_mirei",'skill_heal');
  a.cover='character_yuno';
  const observed=V.capture(s,B,'action_defend',()=>{
    B.receive(s,s.units[1],20,false);
    a.hp+=20; // Net HP is unchanged, but the real recipient still spoke.
    B.receive(s,s.units[1],20,false);
    return true;
  });
  assert.deepEqual(observed.events,[{character_id:'character_mirei',cue:'hurt'},{character_id:'character_mirei',cue:'hurt'}]);
}
{
  const {s,a}=scenario("character_mirei",'skill_heal');
  assert.throws(()=>V.capture(s,B,'action_attack',()=>{throw Error('failure');}));
  assert.equal(Object.getOwnPropertyDescriptor(a,'hp').get,undefined);
}
for(const id of B.recruitRoster.filter(u=>u.job==='job_porter').map(u=>u.id)){
  const s=B.create({ally:[id,"character_mirei","character_merina","character_kyle"],enemy:['guard'],deployment:true});
  const a=s.units.find(u=>u.id===id);a.pos=22;
  s.units.find(u=>u.id==="character_mirei").pos=24;s.units.find(u=>u.id==="character_merina").pos=13;s.units.find(u=>u.id==="character_kyle").pos=33;
  s.units.find(u=>u.side==='enemy').next=1e9;s.deploying=false;s.actor=id;
  assert.deepEqual(V.capture(s,B,'action_skill',()=>B.act(s,'action_skill',id)).events,[{character_id:id,cue:'skill:skill_formation_boost'}]);
}
{
  const engine=B;
  const s=engine.create({ally:["character_mirei","character_yuno"],enemy:['scout'],deployment:true});
  s.units.find(u=>u.id==="character_mirei").pos=4;
  const before=JSON.stringify(s);
  assert.deepEqual(V.capture(s,engine,null,()=>false).events,[]);
  assert.equal(JSON.stringify(s),before,'cancel before begin is silent and unchanged');
  assert.deepEqual(V.capture(s,engine,null,()=>engine.begin(s)).events,[{character_id:'character_mirei',cue:'hurt'}]);
  assert.deepEqual(V.capture(s,engine,null,()=>engine.begin(s)),{ok:false,events:[]});
}
console.log('PASS exact current actor/skill: 18 non-porters × 5 skill assignments, 18 attacks, six porters, cover/hit/heal, rejection/cleanup and opening-hit cancellation');
