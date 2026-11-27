'use strict';
const assert=require('node:assert/strict');
const C=require('./campaign.js'),B=require('./campaign-battle.js'),IDs=require('./semantic-ids.cjs');
const clone=value=>JSON.parse(JSON.stringify(value));
const master=require('./master-data.cjs').getMaster();
assert.equal(IDs.skills.guard,'skill_cover');
assert.equal(IDs.actions.guard,'action_defend');
assert.equal(IDs.jobs.guard,'job_warrior');
assert.equal(Object.keys(IDs.characters).length,24);
assert.equal(new Set(Object.values(IDs.characters)).size,24);
assert(Object.keys(master.definitions).every(id=>/^skill_[a-z_]+$/.test(id)));
assert(Object.keys(master.legacySkills).every(id=>/^skill_[a-z_]+$/.test(id)));
for(const gear of master.gear){
  for(const field of ['skill','effect','legacySkill'])if(gear[field])assert.match(gear[field],/^skill_[a-z_]+$/);
  if(gear.jobOnly)assert.match(gear.jobOnly,/^job_[a-z_]+$/);
}
for(const recruit of B.recruitRoster){
  assert.match(recruit.id,/^character_[a-z]+$/);
  assert.equal(recruit.image,`characters/${recruit.portraitKey}.png`);
  assert.equal(IDs.characters[recruit.voiceKey],recruit.id);
  if(recruit.job==='job_warrior')assert(recruit.portraitKey.startsWith('guard-'));
}
// The previous CURRENT roster, not a historical fixed roster scenario.
const reverse=Object.fromEntries([...Object.entries(IDs.characters),...Object.entries(IDs.jobs).filter(([id])=>id!=='guard'),...Object.entries(IDs.skills),...Object.entries(IDs.actions)].map(([old,next])=>[next,old]));
function prior(value){
  if(typeof value==='string'){
    if(value.startsWith('enemy-')&&reverse[value.slice(6)])return 'enemy-'+reverse[value.slice(6)];
    if(value.startsWith('legacy:'))return 'legacy:'+(reverse[value.slice(7)]||value.slice(7));
    return reverse[value]||value;
  }
  if(Array.isArray(value))return value.map(prior);
  if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([id,item])=>[reverse[id]||id,prior(item)]));
  return value;
}
function checkRoundtrip(state){
  const expected=JSON.parse(C.serialize(state)),old=prior(expected),source=clone(old);
  const loaded=C.deserialize(old);
  assert.deepEqual(old,source,'load does not mutate caller data');
  assert.deepEqual(JSON.parse(C.serialize(loaded)),expected,'old and canonical CURRENT states agree');
  assert.deepEqual(C.deserialize(C.serialize(loaded)),loaded,'second reload is idempotent');
  assert.deepEqual(C.deserialize(expected),loaded,'canonical input follows the same path');
}
const s=C.create();
checkRoundtrip(s);
assert(C.accept(s,C.board(s)[0].id,'character_yuno'));
assert(C.depart(s,s.activeQuest.to));
assert(C.travel(s,'safe',()=>.5));
checkRoundtrip(s);
const resumed=JSON.parse(C.serialize(s));
for(const unit of resumed.state.battle.units.filter(u=>u.side==='ally')){delete unit.portraitKey;delete unit.voiceKey;}
const enriched=C.deserialize(resumed);
assert.deepEqual(enriched,clone(s),'resumed CURRENT battle gains the same explicit asset keys as a fresh battle');
const custom=JSON.parse(C.serialize(s)),customUnit=custom.state.battle.units.find(unit=>unit.id==='character_mirei');
customUnit.portraitKey='custom-portrait';customUnit.voiceKey='independent-voice';customUnit.image='custom-picture.png';
const preserved=C.deserialize(custom).battle.units.find(unit=>unit.id==='character_mirei');
assert.equal(preserved.portraitKey,'custom-portrait');assert.equal(preserved.voiceKey,'independent-voice');assert.equal(preserved.image,'custom-picture.png');
// Typed references include owner, covers, actor, intent and legacy grant keys.
const oldPerson='recruit-guard-human-female',nextPerson='character_mirei';
const sample={selected:[oldPerson],battleSelected:[oldPerson],guildOrder:[oldPerson],characters:{[oldPerson]:{id:oldPerson}},
  activeQuest:{cargoOwnerId:oldPerson},journey:{party:[{id:oldPerson,job:'warrior'}]},
  battle:{actor:oldPerson,itemInventories:{[oldPerson]:{ether:2}},deploymentInitial:[{id:oldPerson,pos:24}],
    units:[{id:oldPerson,job:'warrior',guard:true,cover:oldPerson,covers:[oldPerson],activeSkills:['guard'],effects:['returnHome'],selectedSkill:'guard',selectedSkillKey:'legacy:guard',
      skillCooldowns:{'legacy:guard':1},pendingStamp:{key:'legacy:stamp'},returnUsedGrants:{'legacy:returnHome':true},skillSources:[{id:'guard',itemId:'guard-shield-wood'}],
      attackWeapons:[{skill:'guard',itemId:'guard-shield-wood'}],intent:{kind:'guard',target:oldPerson}}],
    skillEvents:[{actorId:oldPerson,sourceId:oldPerson,skillId:'returnHome'}]},
  note:'guard',image:'characters/guard-human-female-01.png'};
IDs.state(sample);
assert.equal(sample.battle.actor,nextPerson);
assert.equal(sample.battle.units[0].guard,true);
assert.equal(sample.battle.units[0].intent.kind,'action_defend');
assert.equal(sample.battle.units[0].selectedSkillKey,'legacy:skill_cover');
assert.equal(sample.battle.units[0].skillCooldowns['legacy:skill_cover'],1);
assert.equal(sample.battle.units[0].skillSources[0].itemId,'guard-shield-wood');
assert.equal(sample.activeQuest.cargoOwnerId,nextPerson);
assert.equal(sample.journey.party[0].id,nextPerson);
assert.equal(sample.note,'guard');
assert.equal(sample.image,'characters/guard-human-female-01.png');
const once=clone(sample);IDs.state(sample);assert.deepEqual(sample,once);
assert.throws(()=>IDs.state({characters:{[oldPerson]:{},[nextPerson]:{}}}),/重複/);
assert.equal(IDs.skill('constructor'),'constructor');
assert.throws(()=>IDs.unit({skillCooldowns:{'legacy:guard':1,'legacy:skill_cover':1}}),/重複/);
const bad=JSON.parse(C.serialize(C.create()));bad.state.selected[0]='character_unknown';assert.throws(()=>C.deserialize(bad));
console.log('PASS semantic domain inventory, current save migration, typed references, idempotency and collision rejection');
