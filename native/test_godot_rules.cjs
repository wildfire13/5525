'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
let checks=0;const test=(name,fn)=>{fn();checks++;console.log('PASS '+name);};
test('enemy chooses from its current position without storing a telegraph',()=>{
 const s=B.create({ally:["recruit-guard-human-female","recruit-porter-human-female"],enemy:['warrior'],deployment:true,enemyPotions:0});
 const ally=s.units.find(u=>u.id==="recruit-guard-human-female"),porter=s.units.find(u=>u.job==='porter'),enemy=s.units.find(u=>u.side==='enemy');
 ally.pos=24;porter.pos=22;enemy.pos=25;enemy.mp=0;s.deploying=false;
 const first=B.chooseAction(s,enemy);assert.equal(first.kind,'attack');assert.equal(first.target,ally.id);assert.equal(Object.hasOwn(enemy,'intent'),false);
 ally.pos=15;porter.pos=25;const moved=B.chooseAction(s,enemy);assert.equal(moved.kind,'attack');assert.equal(moved.target,porter.id);assert.equal(Object.hasOwn(enemy,'intent'),false);
});
test('allied combat movement can cross into enemy territory',()=>{
 const s=B.create({ally:["recruit-porter-human-female","recruit-guard-human-female"],enemy:['guard'],deployment:true});const guard=s.units.find(u=>u.id==="recruit-guard-human-female");
 s.deploying=false;s.actor=guard.id;guard.pos=44;assert(B.legalFor(s,guard,'move',45));
});
test('invasion grants enemy-side starting placement only',()=>{
 const s=B.create({ally:["recruit-scout-human-female","recruit-guard-human-female"],enemy:['guard'],deployment:true});const scout=s.units.find(u=>u.id==="recruit-scout-human-female"),guard=s.units.find(u=>u.id==="recruit-guard-human-female");
 scout.canDeployEnemySide=true;assert(B.deploy(s,"recruit-scout-human-female",27));assert.equal(scout.pos,27);assert(!B.deploy(s,"recruit-guard-human-female",28));
});
test('porter reaches the far edge for breakthrough success',()=>{
 const s=B.create({ally:["recruit-porter-human-female"],enemy:['guard'],deployment:true,enemyPotions:0});const porter=s.units.find(u=>u.job==='porter');
 s.deploying=false;s.actor=porter.id;porter.pos=18;porter.next=0;s.units.filter(u=>u.side==='enemy').forEach(u=>u.next=100000);
 assert(B.act(s,'move',19));assert.equal(s.resultKind,'breakthrough');assert.equal(s.failure,undefined);
});
console.log(JSON.stringify({suite:'godot_rules',checks,passed:true}));
