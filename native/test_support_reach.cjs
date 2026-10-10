'use strict';
const assert=require('node:assert/strict'),C=require('./campaign.js'),B=require('./campaign-battle.js');
let checks=0;const test=(name,fn)=>{fn();checks++;console.log('PASS '+name);};
function setup(right,left,skill){
 const s=B.create({ally:['guard','mage','archer','porter'],enemy:['guard'],deployment:true});
 const a=s.units.find(u=>u.id==='guard'),t=s.units.find(u=>u.id==='mage'),p=s.units.find(u=>u.id==='porter');
 const char=C.create().characters.guard;char.weapon=right;char.leftHand=left;
 // These are canonical equipment-stat calculations, not a purchase/requirements bypass test.
 const stats=C.stats(char);Object.assign(a,{attackWeapons:stats.attackWeapons,attackBonus:stats.attackBonus,activeSkills:stats.activeSkills,reach:stats.reach});
 a.selectedSkill=skill;a.pos=22;a.mp=3;a.next=0;t.pos=23;t.hp=20;t.mp=0;t.next=1;p.pos=0;p.next=2;
 for(const u of s.units)if(![a.id,t.id,p.id].includes(u.id))u.next=1000;
 s.deploying=false;s.actor=a.id;return {s,a,t,p};
}
for(const weapon of ['hammer-wood','staff-wood','javelin-wood','empty-rightHand']){
 for(const reverse of [false,true]){
  if(reverse&&weapon==='empty-rightHand')continue;
  const right=reverse?'guard-shield-wood':weapon,left=reverse?weapon:'guard-shield-wood';
  test(`cover fixed 1 with ${right} / ${left}`,()=>{
   const {s,a,t}=setup(right,left,'guard');assert(a.activeSkills.includes('guard'));assert.equal(B.attackReach(a,'skill'),1);
   for(const [pos,legal] of [[12,true],[21,true],[23,true],[32,true],[11,false],[13,false],[20,false],[24,false],[25,false]]){t.pos=pos;assert.equal(B.legal(s,'skill',t.id),legal,`cell ${pos}`);}
   t.pos=23;t.hp=0;assert(!B.legal(s,'skill',t.id));t.hp=20;assert(!B.legal(s,'skill',a.id));
   const enemy=s.units.find(u=>u.side==='enemy');enemy.pos=23;assert(!B.legal(s,'skill',enemy.id));enemy.pos=25;
   a.mp=0;const before=structuredClone(s);assert(!B.act(s,'skill',t.id));assert.deepEqual(s,before);
   a.mp=1;assert(B.act(s,'skill',t.id));assert.equal(a.mp,0);assert.equal(a.cover,t.id);assert.equal(s.actions,1);
  });
 }
}
for(const pair of [['sword-wood','staff-wood'],['staff-wood','sword-wood'],['javelin-wood','staff-wood'],['staff-wood','javelin-wood'],['guard-shield-wood','staff-wood'],['staff-wood','guard-shield-wood']]){
 test(`heal fixed 2 with ${pair.join(' / ')}`,()=>{
  const {s,a,t}=setup(...pair,'mage');assert(a.activeSkills.includes('mage'));assert.equal(B.attackReach(a,'skill'),2);
  a.hp=20;assert(B.legal(s,'skill',a.id));
  for(const [pos,legal] of [[12,true],[23,true],[13,true],[24,true],[25,false],[2,true],[3,false]]){t.pos=pos;assert.equal(B.legal(s,'skill',t.id),legal,`cell ${pos}`);}
  t.pos=24;t.hp=t.max;assert(!B.legal(s,'skill',t.id));t.hp=0;assert(!B.legal(s,'skill',t.id));t.hp=20;
  a.mp=0;assert(!B.legal(s,'skill',t.id));a.mp=1;
  const oldHp=t.hp;assert(B.act(s,'skill',t.id));assert.equal(t.hp,Math.min(t.max,oldHp+60));assert.equal(a.mp,0);assert.equal(s.actions,1);
 });
}
test('support selection follows skill ID and preserves normal weapon union/ATK',()=>{
 const {s,a,t}=setup('staff-wood','guard-shield-wood','mage');t.pos=24;
 assert(B.legal(s,'skill',t.id));assert(B.selectSkill(s,'guard'));assert(!B.legal(s,'skill',t.id));assert.equal(B.attackReach(a,'skill'),1);
 assert(B.selectSkill(s,'mage'));assert(B.legal(s,'skill',t.id));assert.equal(s.actions,0);assert.equal(a.mp,3);
 for(const pair of [['sword-wood','staff-wood'],['staff-wood','sword-wood']]){
  const {a,t}=setup(...pair,'mage');assert.equal(B.attackReach(a,'attack'),2);
  for(const [pos,power] of [[23,40],[24,14],[25,0]]){t.pos=pos;assert.equal(B.reachFilteredPower(a,t,'attack').base,power);}
 }
});
test('snipe still extends each contributing weapon by one',()=>{
 const {a,t}=setup('sword-wood','staff-wood','mage');a.activeSkills=['archer'];a.selectedSkill='archer';
 assert.equal(B.attackReach(a,'skill'),3);assert.equal(B.attackReach(a,'attack'),2);
 for(const [pos,power] of [[23,40],[24,40],[25,14],[26,0]]){t.pos=pos;assert.equal(B.reachFilteredPower(a,t,'skill').base,power);}
});
test('cover survives target movement, receives damage and clears at user next turn',()=>{
 const {s,a,t,p}=setup('staff-wood','guard-shield-wood','guard');assert(B.act(s,'skill',t.id));assert.equal(s.actor,t.id);
 assert(B.act(s,'move',14));assert.equal(a.cover,t.id);assert(B.range(a,t)>1);
 const hp=t.hp,coverHp=a.hp;B.receive(s,t,40);assert.equal(t.hp,hp);assert(a.hp<coverHp);
 assert.equal(s.actor,p.id);a.next=3;assert(B.act(s,'guard'));assert.equal(s.actor,a.id);assert.equal(a.cover,null);
});
console.log(JSON.stringify({suite:'support_reach',checks,passed:true}));
