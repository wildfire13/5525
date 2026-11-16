'use strict';
const assert=require('node:assert/strict');
const B=require('./campaign-battle.js');
{
 const battle=B.create({ally:["character_mirei","character_grant"],enemy:['guard','warrior'],deployment:true});
 for(const unit of battle.units){
  assert.equal(unit.job,'job_warrior');
  assert.equal(B.activeSkill(unit),unit.weapon==='hammer'?'skill_stamp':'skill_cover');
 }
}
function scenario(job,skill){
 const s=B.create({ally:[job],enemy:['guard','archer'],enemyPotions:0,deployment:true});
 const a=s.units[0];a.equippedSkill=skill;a.pos=24;a.reach=skill==='skill_snipe'?3:2;a.atk=26;a.mp=6;
 s.units.filter(u=>u.side==='enemy').forEach(u=>u.next=1e9);s.deploying=false;s.actor=a.id;return {s,a};
}
{
 const {s,a}=scenario("character_merina",'skill_stamp');s.units[1].pos=15;s.units[2].pos=25;
 assert.equal(B.activeSkill(a),'skill_stamp');assert.equal(B.legal(s,'action_skill',25),true);
 assert.equal(B.act(s,'action_skill',25),true);assert.equal(a.mp,5);assert.ok(s.units[1].hp<180);assert.ok(s.units[2].hp<100);assert.equal(a.job,'job_mage');
}
{
 const {s,a}=scenario("character_mirei",'skill_heal');a.hp=100;assert.equal(B.legal(s,'action_skill',a.id),true);assert.equal(B.act(s,'action_skill',a.id),true);assert.ok(a.hp>100);assert.equal(a.job,'job_warrior');
}
{
 const {s,a}=scenario("character_merina",'skill_snipe');s.units[1].pos=28;
 assert.equal(B.legal(s,'action_attack',s.units[1].id),false);assert.equal(B.legal(s,'action_skill',s.units[1].id),true);assert.equal(B.act(s,'action_skill',s.units[1].id),true);assert.ok(s.units[1].hp<180);
}
{
 const {s,a}=scenario("character_merina",'skill_ambush');s.units[1].pos=27;
 assert.equal(B.ambush(s,a,s.units[1]).destination,26,'ambush skill is available without initial-deployment permission');
}
{
 const {s,a}=scenario("character_yuno",'skill_stamp');assert.equal(B.activeSkill(a),'skill_formation_boost');assert.equal(B.legal(s,'action_attack',s.units[1].id),false);assert.equal(B.legal(s,'action_skill',25),false);
}
console.log('PASS campaign battle extension: cross-job stamp/heal/snipe, unrestricted ambush movement, porter restriction');
