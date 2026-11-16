'use strict';
// Exercise manual-suite boundaries without starting Godot or writing saves.
const assert=require('node:assert/strict');
const C=require('../../native/campaign.js'),B=require('../../native/campaign-battle.js');
const {ids}=require('./ui_current_fixtures.cjs');
const followup=require('./followup_ui_fixtures.cjs');
const skills=require('./feedback_261019_fixtures.cjs');
const current=C.create(),roster=Object.keys(current.characters).sort();
let count=0;
for(const fixtures of [followup,skills]){
 for(const [name,value] of Object.entries(fixtures)){
  const s=C.deserialize(value);
  assert(s,`${name}: canonical round trip`);
  assert(C.validate(s).ok,`${name}: valid state`);
  assert.deepEqual(Object.keys(s.characters).sort(),roster,`${name}: exact current roster`);
  for(const u of s.battle?.units||[]){
   if(u.side==='ally'){
    assert(current.characters[u.id],`${name}: live ally identity`);
    assert.equal(u.name,B.recruitRoster.find(r=>r.id===u.id).name,`${name}: original recruit name`);
   }
  }
  count++;
 }
}
function battle(name){return structuredClone(followup[name].state.battle);}
function actor(b){return b.units.find(u=>u.id===b.actor);}
assert.equal(B.formation(battle('porter'),'ally'),true);
assert.equal(B.formation(battle('broken'),'ally'),false);
assert.equal(actor(battle('mp0')).mp,0);
for(const name of ['heal_left','heal_right']){
 const b=battle(name),a=actor(b),mp=a.mp;
 assert(B.skillTargets(b,a).includes(ids.guard),`${name}: reachable heal target`);
 assert(B.act(b,'skill',ids.guard,()=>0),`${name}: execute heal`);
 assert.equal(b.units.find(u=>u.id===ids.guard).hp,70);
 assert.equal(a.mp,mp-1);
}
{
 const b=battle('cover_staff'),a=actor(b);
 assert(!B.skillTargets(b,a).includes(ids.guard),'cover excludes distance two');
 assert(B.skillTargets(b,a).includes(ids.porter),'cover includes adjacent porter');
 assert(B.act(b,'skill',ids.porter,()=>0));
 assert.equal(a.cover,ids.porter);
}
for(const formed of [true,false]){
 const b=battle(formed?'porter':'broken'),a=actor(b);
 assert.equal(B.skillTargets(b,a).includes(ids.porter),formed);
 if(formed){
  const mp=a.mp,actions=b.actions;
  assert(B.act(b,'skill',ids.porter,()=>0));
  assert(a.boost);assert.equal(a.mp,mp-1);assert.equal(b.actions,actions+1);
 }
}
for(const [name,value] of Object.entries(skills)){
 if(name==='town')continue;
 const b=structuredClone(value.state.battle),a=actor(b);
 if(name.startsWith('sweep')){
  const mp=a.mp;
  assert(B.act(b,'skill',a.id,()=>0));
  assert.equal(a.mp,mp-1);assert.equal(b.actions,1);
 }else if(name==='vault'){
  assert(B.skillTargets(b,a).includes(24));
  assert(B.act(b,'skill',24,()=>0));assert.equal(a.pos,24);
 }else if(name.startsWith('grapple')){
  const enemy=b.units.find(u=>u.side==='enemy'&&u.pos===24);
  assert(B.act(b,'skill',enemy.id,()=>0));
  assert.equal(enemy.pos,name==='grapple'?23:24);
 }
}
console.log(`PASS ${count} manual fixtures: current roster, round trips, formation, healing, cover, boost, sweep, vault and grapple`);
