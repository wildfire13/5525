'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
const master=require('./master-data.cjs').getMaster();
const hammer=C.gear.find(g=>g.id==='hammer-wood'),originalSkill=hammer.skill,originalGrants=master.grantsByEquipment[hammer.id];
// A process-local existing-item fixture exercises slots 2 and 3. No master
// artifact or gameplay item is added, and the canonical cache is restored.
let checks=0;
try{
 for(const stampSlot of [2,3]){
  hammer.skill='mage';
  master.grantsByEquipment[hammer.id]=[
   {slotNo:1,id:'mage',level:1,sourceField:'skill',explicitLevel:false},
   ...(stampSlot===3?[{slotNo:2,id:'guard',level:1,sourceField:'skill',explicitLevel:false}]:[]),
   {slotNo:stampSlot,id:'stamp',level:1,sourceField:'skill',explicitLevel:false}];
  const state=C.create();state.location='east';state.characters.guard.weapon=hammer.id;
  assert.equal(C.stats(state.characters.guard).skillSources.find(g=>g.id==='stamp').grantSlot,stampSlot);
  const displayed=C.view(state).roster.find(u=>u.id==='guard').equipmentDetails.rightHand;
  assert.equal(displayed.skillGrants.find(g=>g.id==='stamp').slotNo,stampSlot);
  const trial=C.trial(state,'guard',hammer.id,'rightHand');assert.ok(trial);
  const battle=trial.battle,actor=battle.units.find(u=>u.id==='guard');
  actor.pos=24;actor.next=1;actor.mp=actor.maxMp=10;battle.actor=actor.id;
  let allyIndex=0,enemyIndex=0;
  for(const u of battle.units.filter(u=>u!==actor)){
   u.next=100000;u.guard=false;u.cover=null;u.def=0;
   u.pos=u.side==='enemy'?[15,25,35][enemyIndex++]:[0,10][allyIndex++];
  }
  assert.equal(enemyIndex,3,'three actual recipients exercise both outer cells');
  const option=B.activeSkillOptions(actor).find(g=>g.id==='stamp');assert.equal(option.grantSlot,stampSlot);
  assert.ok(B.selectSkill(battle,option.key));assert.deepEqual(B.stampCells(actor,25).sort((a,b)=>a-b),[15,25,35]);
  const before=structuredClone(battle),preview=B.damagePreview(battle,actor,'skill',25);
  assert.deepEqual(battle,before,'preview must not consume any grant or mutate battle');
  assert.equal(preview.length,3);
  for(const hit of preview){assert.equal(hit.base,29,'secondary stamp grant powers all three cells');assert.equal(hit.damage,29);}
  const hp=Object.fromEntries(battle.units.map(u=>[u.id,u.hp]));
  assert.ok(C.trialAct(trial,'skill',25));assert.equal(actor.mp,9);assert.equal(battle.actions,1);
  for(const hit of preview)assert.equal(hp[hit.recipientId]-battle.units.find(u=>u.id===hit.recipientId).hp,hit.hpLoss);
  assert.equal(B.activeSkillOptions(actor).find(g=>g.id==='stamp').cooldown,1);
  assert.equal(B.activeSkillOptions(actor).find(g=>g.id==='mage').cooldown,0);
  checks++;
 }
}finally{hammer.skill=originalSkill;master.grantsByEquipment[hammer.id]=originalGrants;}
console.log(`PASS ${checks} secondary-slot stamp grant groups: stats/view, all three cells, preview/execution, independent cost/cooldown`);
