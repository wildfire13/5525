'use strict';
const assert=require('node:assert/strict');
const B=require('./campaign-battle.js');
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
 assert.equal(B.ambush(s,a,s.units[1]).destination,26,'ambush skill is available without initial-deployment permission');
}
{
 const {s,a}=scenario('porter','stamp');assert.equal(B.activeSkill(a),'porter');assert.equal(B.legal(s,'attack',s.units[1].id),false);assert.equal(B.legal(s,'skill',25),false);
}
console.log('PASS campaign battle extension: cross-job stamp/heal/snipe, unrestricted ambush movement, porter restriction');
