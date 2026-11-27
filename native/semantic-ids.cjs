'use strict';
// Domain maps are used only at typed input boundaries, never on arbitrary text,
// character IDs, equipment IDs, filenames, or event/audio manifest keys.
const snake=id=>id.replace(/[A-Z]/g,c=>'_'+c.toLowerCase());
const jobs=Object.fromEntries(['warrior','scout','porter','mage','archer'].map(id=>[id,'job_'+id]));
jobs.guard='job_warrior';
const skills={guard:'skill_cover',archer:'skill_snipe',mage:'skill_heal',scout:'skill_ambush',porter:'skill_formation_boost'};
for(const id of ['stamp','itemUse','legSweep','grapple','poleVault','swift','retreatSlash','knockback','splitShot','pincer','healingCross','defenseLine','manaGift','returnHome','victoryBreath','loneWolf','firstStride','secretPouch','holePouch','fourDimensional','evasion','speedUp','speedDown','elfProof','dwarfProof','spearThrow','invasion'])skills[id]='skill_'+snake(id);
const actions=Object.fromEntries(['attack','move','guard','skill','item','ether','return','skip','cast'].map(id=>[id,'action_'+id]));
actions.guard='action_defend';
const lookup=(map,id)=>Object.hasOwn(map,id)?map[id]:id;
const job=id=>lookup(jobs,id);
const skill=id=>lookup(skills,id);
const action=id=>lookup(actions,id);
const characters=Object.fromEntries(require('./character-identities.cjs').filter(({legacyId})=>typeof legacyId==='string'&&legacyId.length>0).map(({legacyId,id})=>[legacyId,id]));
const identities=new Map(require('./character-identities.cjs').map(identity=>[identity.id,identity]));
const person=id=>Object.hasOwn(characters,id)?characters[id]:(typeof id==='string'&&id.startsWith('enemy-')&&Object.hasOwn(characters,id.slice(6))?'enemy-'+characters[id.slice(6)]:id);
const key=value=>typeof value==='string'&&value.startsWith('legacy:')?'legacy:'+skill(value.slice(7)):value;
const keyed=value=>{
  if(!value||typeof value!=='object'||Array.isArray(value))return value;
  const seen=new Set();
  return Object.fromEntries(Object.entries(value).map(([id,v])=>{
    const next=key(id);
    if(seen.has(next))throw new Error('技能付与元IDの移行先が重複しています: '+next);
    seen.add(next);return [next,v];
  }));
};
function unit(value,enrich=false) {
  if(!value||typeof value!=='object')return;
  if(typeof value.job==='string')value.job=job(value.job);
  if(typeof value.id==='string')value.id=person(value.id);
  if(enrich&&typeof value.id==='string'){
    const identity=identities.get(value.id.replace(/^enemy-/,''));
    if(identity)for(const field of ['portraitKey','voiceKey'])if(value[field]===undefined)value[field]=identity[field];
  }
  for(const field of ['cover','actorId','sourceId','targetId','recipientId'])if(typeof value[field]==='string')value[field]=person(value[field]);
  if(Array.isArray(value.covers))value.covers=value.covers.map(person);
  if(value.intent&&typeof value.intent==='object'){
    if(typeof value.intent.kind==='string')value.intent.kind=action(value.intent.kind);
    if(typeof value.intent.target==='string')value.intent.target=person(value.intent.target);
    if(Array.isArray(value.intent.target))value.intent.target=value.intent.target.map(person);
  }
  for(const field of ['equippedSkill','selectedSkill','selectedReturnSkill'])if(typeof value[field]==='string')value[field]=skill(value[field]);
  for(const field of ['selectedSkillKey','selectedReturnSkillKey'])if(typeof value[field]==='string')value[field]=key(value[field]);
  if(value.pendingStamp&&typeof value.pendingStamp.key==='string')value.pendingStamp.key=key(value.pendingStamp.key);
  for(const field of ['activeSkills','effects'])if(Array.isArray(value[field]))value[field]=value[field].map(skill);
  if(Array.isArray(value.skillSources))for(const source of value.skillSources)if(source&&typeof source.id==='string')source.id=skill(source.id);
  if(Array.isArray(value.attackWeapons))for(const weapon of value.attackWeapons)if(typeof weapon.skill==='string')weapon.skill=skill(weapon.skill);
  for(const field of ['skillCooldowns','skillUses','returnUses','returnUsedGrants','spearThrownGrants'])if(value[field])value[field]=keyed(value[field]);
}
function state(value) {
  if(!value||typeof value!=='object')return value;
  if(Array.isArray(value.units))value.units.forEach(value=>unit(value,true));
  for(const field of ['selected','battleSelected','guildOrder','buriedRecruitIds','rosterOrder','travelling','deployed','battleMembers','partyOrder','memberOrder'])if(Array.isArray(value[field]))value[field]=value[field].map(person);
  for(const field of ['actor','ownerId','carrierId','selectedCharacterId'])if(typeof value[field]==='string')value[field]=person(value[field]);
  for(const field of ['characters','itemInventories','contractRenewals'])if(value[field]&&typeof value[field]==='object'&&!Array.isArray(value[field])){
    const entries=Object.entries(value[field]),seen=new Set();
    value[field]=Object.fromEntries(entries.map(([id,record])=>{
      const next=person(id);
      if(seen.has(next))throw new Error('人物IDの移行先が重複しています: '+next);
      seen.add(next);if(field==='characters')unit(record);return [next,record];
    }));
  }
  if(Array.isArray(value.skillEvents))for(const event of value.skillEvents){if(typeof event.skillId==='string')event.skillId=skill(event.skillId);unit(event);}
  if(Array.isArray(value.deploymentInitial))value.deploymentInitial.forEach(value=>unit(value));
  if(Array.isArray(value.party))value.party.forEach(value=>unit(value,true));
  if(value.journey)state(value.journey);
  for(const quest of [value.activeQuest,value.job])if(quest&&typeof quest==='object')for(const field of ['ownerId','carrierId','cargoOwnerId'])if(typeof quest[field]==='string')quest[field]=person(quest[field]);
  if(value.battle)state(value.battle);
  if(value.rollback)state(value.rollback);
  return value;
}
const defaultSkill={job_warrior:'skill_cover',job_archer:'skill_snipe',job_mage:'skill_heal',job_scout:'skill_ambush',job_porter:'skill_formation_boost'};
module.exports={jobs,skills,actions,characters,job,skill,action,person,key,state,unit,defaultSkill};
