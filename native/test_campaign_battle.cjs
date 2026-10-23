'use strict';
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const B=require('./campaign-battle.js');
const reference=require('./test_fixtures/campaign-default-reference.json');
// Keep every step of the shared default match against an independent frozen
// reference. This is one named scenario, not general legacy/campaign equality.
// New campaign rules are checked separately in test_equipment_ambush_def.cjs.
assert.equal(reference.sourceModuleSha256,require('./source_tests/provenance.json').modules['battle.js']);
function defaultMatchDigest(s){
 const value=JSON.parse(JSON.stringify(s));
 for(const [index,u] of value.units.entries()){
  assert.equal(u.def,0,'default match has zero DEF: '+u.id);
  assert.equal(Object.hasOwn(s.units[index],'skillStage'),false,'default campaign has no legacy skillStage: '+u.id);
  delete u.def; // Only after asserting its exact campaign contract above.
  if(u.job==='scout'&&u.intent?.kind==='skill'){
   assert.equal(u.intent.reason,'装備の奇襲Lvの範囲内にいる弱った敵へ奇襲');
   u.intent.reason='default-match-scout-ambush';
  }
 }
 return crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
}
const defaultMatch=B.create();
assert.equal(defaultMatchDigest(defaultMatch),reference.initial,'default match initial state');
assert.equal(reference.steps.length,30);
for(const [index,step] of reference.steps.entries()){
 assert.equal(B.act(defaultMatch,step.kind,step.target),true,'default command '+(index+1));
 assert.equal(defaultMatchDigest(defaultMatch),step.expected,'default match complete state after action '+(index+1));
}
assert.equal(defaultMatch.actions,30);assert.equal(defaultMatch.result,'勝利！ ミラーマッチを制した。');
function scenario(job,skill){
 const s=B.create({ally:[job],enemy:['guard','archer'],enemyPotions:0,deployment:true});
 const a=s.units[0];a.equippedSkill=skill;a.pos=24;a.reach=skill==='archer'?3:2;a.atk=26;a.mp=6;
 s.units.filter(u=>u.side==='enemy').forEach(u=>u.next=1e9);s.deploying=false;s.actor=a.id;return {s,a};
}
{
 const {s,a}=scenario('mage','stamp');s.units[1].pos=15;s.units[2].pos=25;
 assert.equal(B.activeSkill(a),'stamp');assert.equal(B.legal(s,'skill',25),true);
 assert.equal(B.act(s,'skill',25),true);assert.equal(a.mp,5);assert.ok(s.units[1].hp<180);assert.ok(s.units[2].hp<100);assert.equal(a.job,'mage');
}
{
 const {s,a}=scenario('guard','mage');a.hp=100;assert.equal(B.legal(s,'skill',a.id),true);assert.equal(B.act(s,'skill',a.id),true);assert.ok(a.hp>100);assert.equal(a.job,'guard');
}
{
 const {s,a}=scenario('mage','archer');s.units[1].pos=28;
 assert.equal(B.legal(s,'attack',s.units[1].id),false);assert.equal(B.legal(s,'skill',s.units[1].id),true);assert.equal(B.act(s,'skill',s.units[1].id),true);assert.ok(s.units[1].hp<180);
}
{
 const {s,a}=scenario('mage','scout');s.units[1].pos=27;
 assert.equal(B.ambush(s,a,s.units[1]),null,'dagger skill alone does not grant invasion');
 a.canInvade=true;assert.equal(B.ambush(s,a,s.units[1]).destination,26);
}
{
 const {s,a}=scenario('porter','stamp');assert.equal(B.activeSkill(a),'porter');assert.equal(B.legal(s,'attack',s.units[1].id),false);assert.equal(B.legal(s,'skill',25),false);
}
console.log('PASS campaign battle extension: 31 default-match reference states with explicit campaign metadata, cross-job stamp/heal/snipe, separate invasion, porter restriction');
